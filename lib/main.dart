import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/supabase_service.dart';
import 'services/preferences_service.dart';
import 'models/period_cycle.dart';
import 'theme/app_theme.dart';

const supabaseUrl = 'https://tyqnrqhhogbwjpwnmzvk.supabase.co';
const supabasePublishableKey = 'sb_publishable_AZQid6LZmmBv-Hy8-_QjDg_HMwYT7Sp';

DateTime today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}
String keyOf(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
String longDate(DateTime d) => DateFormat('d MMMM yyyy').format(d);
int dayDiff(DateTime a, DateTime b) => DateTime(b.year,b.month,b.day).difference(DateTime(a.year,a.month,a.day)).inDays;

int averageCycle(List<PeriodCycle> cycles) {
  if (cycles.length < 2) return 28;
  final values = <int>[];
  for (var i = 0; i < cycles.length - 1; i++) {
    final n = dayDiff(cycles[i + 1].startDate, cycles[i].startDate);
    if (n > 0 && n < 60) values.add(n);
  }
  if (values.isEmpty) return 28;
  return (values.reduce((a,b) => a+b) / values.length).round();
}

String phaseFor(int day, int avg) {
  if (day <= 5) return 'Menstrual phase';
  if (day <= (avg / 2).round()) return 'Follicular phase';
  if (day <= avg - 10) return 'Around ovulation';
  return 'Luteal phase';
}

class AppState extends ChangeNotifier {
  final api = SupabaseService.instance;
  final prefs = PreferencesService();

  List<PeriodCycle> cycles = [];
  int intimacyCount = 0;
  String? mood;
  Set<String> symptoms = {};
  bool dark = false;
  bool loading = true;
  String? error;

  Future<void> initialize() async {
    try {
      await api.ensureAnonymousUser();
      dark = await prefs.loadDark();
      mood = await prefs.loadMood();
      symptoms = await prefs.loadSymptoms();
      await api.seedIfEmpty();
      await reload();
    } catch (e) {
      error = e.toString();
      loading = false;
      notifyListeners();
    }
  }

  Future<void> reload() async {
    try {
      final results = await Future.wait([
        api.loadCycles(),
        api.loadIntimacyCount(),
      ]);
      cycles = results[0] as List<PeriodCycle>;
      intimacyCount = results[1] as int;
      error = null;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> addCycle(String start, String? time, String? end) async {
    await api.addCycle(start: start, time: time, end: end);
    await reload();
  }

  Future<void> deleteCycle(String id) async {
    await api.deleteCycle(id);
    await reload();
  }

  Future<void> addMoment() async {
    intimacyCount = await api.incrementIntimacy();
    notifyListeners();
  }

  Future<void> setMood(String? value) async {
    mood = value;
    await prefs.saveMood(value);
    notifyListeners();
  }

  Future<void> toggleSymptom(String value) async {
    if (symptoms.contains(value)) {
      symptoms.remove(value);
    } else {
      symptoms.add(value);
    }
    await prefs.saveSymptoms(symptoms);
    notifyListeners();
  }

  Future<void> toggleDark() async {
    dark = !dark;
    await prefs.saveDark(dark);
    notifyListeners();
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );
  final state = AppState();
  await state.initialize();
  runApp(App(state: state));
}

class App extends StatefulWidget {
  final AppState state;
  const App({super.key, required this.state});
  @override State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  Timer? timer;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(minutes: 1), (_) {
      widget.state.notifyListeners();
    });
  }
  @override
  void dispose() { timer?.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.state,
    builder: (_, __) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Harini's Little Space",
      theme: appTheme(widget.state.dark),
      home: HomeShell(state: widget.state),
    ),
  );
}

class HomeShell extends StatefulWidget {
  final AppState state;
  const HomeShell({super.key, required this.state});
  @override State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: index,
          children: [
            TodayPage(state: widget.state, openHistory: () => setState(() => index = 1)),
            HistoryPage(state: widget.state),
            UsPage(state: widget.state),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.wb_sunny_outlined), selectedIcon: Icon(Icons.wb_sunny), label: 'Today'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'History'),
          NavigationDestination(icon: Icon(Icons.favorite_border), selectedIcon: Icon(Icons.favorite), label: 'Us'),
        ],
      ),
    );
  }
}

class TodayPage extends StatelessWidget {
  final AppState state;
  final VoidCallback openHistory;
  const TodayPage({super.key, required this.state, required this.openHistory});

  @override
  Widget build(BuildContext context) {
    final latest = state.cycles.isEmpty ? null : state.cycles.first;
    final avg = averageCycle(state.cycles);
    final cycleDay = latest == null ? 0 : dayDiff(latest.startDate, today()) + 1;
    final next = latest?.startDate.add(Duration(days: avg));
    final fertileStart = (avg - 19).clamp(1, 99);
    final fertileEnd = (avg - 13).clamp(fertileStart, 99);
    final fertile = latest != null && cycleDay >= fertileStart && cycleDay <= fertileEnd;

    return RefreshIndicator(
      onRefresh: state.reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
        children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('TODAY', style: TextStyle(fontSize:10,letterSpacing:1.5,fontWeight:FontWeight.w800,color:AppColors.rose)),
              const SizedBox(height:4),
              Text(DateFormat('EEEE, d MMMM').format(today()), style: const TextStyle(fontWeight:FontWeight.w600)),
            ])),
            IconButton(
              onPressed: state.toggleDark,
              icon: Icon(state.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            ),
          ]),
          const SizedBox(height:22),
          Text(
            latest == null ? 'Start your cycle log' : 'Your body, your rhythm.',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.w700,letterSpacing:-.7),
          ),
          const SizedBox(height:8),
          const Text(
            'A quiet place to keep track of your cycle, how you feel, and the little details that matter.',
            style: TextStyle(color:AppColors.muted,height:1.55),
          ),
          const SizedBox(height:18),
          if (state.error != null) ErrorBanner(text: state.error!),
          if (latest == null)
            EmptyCard(onAdd: () => showPeriodDialog(context, state))
          else ...[
            CycleCard(day: cycleDay, phase: phaseFor(cycleDay, avg), average: avg, next: next!),
            const SizedBox(height:14),
            if (fertile) ...[
              PregnancyAlert(day: cycleDay),
              const SizedBox(height:14),
            ],
            MoodCard(state: state),
            const SizedBox(height:14),
            RecentCycles(state: state, openHistory: openHistory),
          ],
        ],
      ),
    );
  }
}

class CycleCard extends StatelessWidget {
  final int day;
  final String phase;
  final int average;
  final DateTime next;
  const CycleCard({super.key,required this.day,required this.phase,required this.average,required this.next});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors:[Color(0xFFF9E7E9),Color(0xFFFFF8F6)]),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color:AppColors.line),
    ),
    child: Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(crossAxisAlignment:CrossAxisAlignment.end,children:[
        Text(day.toString(),style:Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight:FontWeight.w700,color:AppColors.rose)),
        const SizedBox(width:10),
        const Padding(padding:EdgeInsets.only(bottom:8),child:Text('cycle day',style:TextStyle(color:AppColors.muted))),
      ]),
      const SizedBox(height:12),
      Text(phase,style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w700)),
      const SizedBox(height:6),
      Text('Average cycle: ' + average.toString() + ' days',style:const TextStyle(color:AppColors.muted)),
      const SizedBox(height:16),
      Row(children:[
        const Icon(Icons.event_outlined,size:17,color:AppColors.rose),
        const SizedBox(width:8),
        Text('Estimated next period · ' + DateFormat('d MMM').format(next),style:const TextStyle(color:AppColors.muted)),
      ]),
    ]),
  );
}

class PregnancyAlert extends StatelessWidget {
  final int day;
  const PregnancyAlert({super.key,required this.day});
  @override
  Widget build(BuildContext context) => Container(
    padding:const EdgeInsets.all(18),
    decoration:BoxDecoration(color:const Color(0xFFFFF4E8),borderRadius:BorderRadius.circular(20),border:Border.all(color:const Color(0xFFF1D4AF))),
    child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('⚠️',style:TextStyle(fontSize:20)),
      const SizedBox(width:12),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('CYCLE AWARENESS',style:TextStyle(fontSize:10,letterSpacing:1.3,fontWeight:FontWeight.w800,color:AppColors.rose)),
        const SizedBox(height:4),
        Text('Higher pregnancy possibility',style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.w700)),
        const SizedBox(height:5),
        Text('You are around cycle day ' + day.toString() + ', which falls within the estimated fertile window based on your logged cycles. Calendar estimates cannot confirm ovulation or rule out pregnancy.',style:const TextStyle(color:AppColors.muted,height:1.45)),
        const SizedBox(height:7),
        const Text('For pregnancy prevention, do not rely on calendar predictions alone. Consider a reliable contraceptive method.',style:TextStyle(fontSize:12,color:AppColors.muted,height:1.4)),
      ])),
    ]),
  );
}

class MoodCard extends StatelessWidget {
  final AppState state;
  const MoodCard({super.key,required this.state});
  static const moods=['😊 Good','🌿 Calm','🥹 Sensitive','😴 Tired','✨ Energized'];
  static const symptoms=['Cramps','Bloating','Headache','Backache','Tenderness'];
  @override
  Widget build(BuildContext context)=>Card(
    child:Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('How are you feeling?',style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.w700)),
      const SizedBox(height:14),
      Wrap(spacing:8,runSpacing:8,children:moods.map((m)=>ChoicePill(label:m,selected:state.mood==m,onTap:()=>state.setMood(state.mood==m?null:m))).toList()),
      const SizedBox(height:16),
      const Text('Anything noticeable?',style:TextStyle(fontSize:12,color:AppColors.muted)),
      const SizedBox(height:10),
      Wrap(spacing:8,runSpacing:8,children:symptoms.map((s)=>ChoicePill(label:s,selected:state.symptoms.contains(s),onTap:()=>state.toggleSymptom(s))).toList()),
    ])),
  );
}

class ChoicePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const ChoicePill({super.key,required this.label,required this.selected,required this.onTap});
  @override
  Widget build(BuildContext context)=>InkWell(
    borderRadius:BorderRadius.circular(30),
    onTap:onTap,
    child:AnimatedContainer(
      duration:const Duration(milliseconds:180),
      padding:const EdgeInsets.symmetric(horizontal:13,vertical:9),
      decoration:BoxDecoration(color:selected?AppColors.roseSoft:Colors.transparent,borderRadius:BorderRadius.circular(30),border:Border.all(color:selected?AppColors.rose:AppColors.line)),
      child:Text(label,style:TextStyle(fontSize:12,color:selected?AppColors.rose:AppColors.muted,fontWeight:selected?FontWeight.w700:FontWeight.w500)),
    ),
  );
}

class RecentCycles extends StatelessWidget {
  final AppState state;
  final VoidCallback openHistory;
  const RecentCycles({super.key,required this.state,required this.openHistory});
  @override
  Widget build(BuildContext context)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[
      Expanded(child:Text('Recent cycles',style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.w700))),
      TextButton(onPressed:openHistory,child:const Text('View all')),
    ]),
    ...state.cycles.take(3).map((c)=>CycleRow(cycle:c)),
  ]);
}

class CycleRow extends StatelessWidget {
  final PeriodCycle cycle;
  const CycleRow({super.key,required this.cycle});
  @override
  Widget build(BuildContext context)=>Padding(
    padding:const EdgeInsets.symmetric(vertical:8),
    child:Row(children:[
      Container(width:42,height:42,decoration:BoxDecoration(color:AppColors.roseSoft,borderRadius:BorderRadius.circular(14)),child:const Icon(Icons.water_drop_outlined,size:18,color:AppColors.rose)),
      const SizedBox(width:12),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(longDate(cycle.startDate),style:const TextStyle(fontWeight:FontWeight.w600)),
        Text(cycle.startTime==null?'Start time not recorded':'Started at '+cycle.startTime!,style:const TextStyle(fontSize:12,color:AppColors.muted)),
      ])),
      if(cycle.endDate!=null)Text((dayDiff(cycle.startDate,cycle.endDate!)+1).toString()+' days',style:const TextStyle(fontSize:12,color:AppColors.muted)),
    ]),
  );
}

class EmptyCard extends StatelessWidget {
  final VoidCallback onAdd;
  const EmptyCard({super.key,required this.onAdd});
  @override
  Widget build(BuildContext context)=>Container(
    margin:const EdgeInsets.only(top:20),
    padding:const EdgeInsets.all(22),
    decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(24),border:Border.all(color:AppColors.line)),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Icon(Icons.favorite_border,color:AppColors.rose,size:30),
      const SizedBox(height:12),
      Text('Nothing logged yet',style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w700)),
      const SizedBox(height:7),
      const Text('Add a period start to begin your shared cycle history.',style:TextStyle(color:AppColors.muted,height:1.45)),
      const SizedBox(height:18),
      FilledButton.icon(onPressed:onAdd,icon:const Icon(Icons.add),label:const Text('Log period')),
    ]),
  );
}

class HistoryPage extends StatelessWidget {
  final AppState state;
  const HistoryPage({super.key,required this.state});
  @override
  Widget build(BuildContext context)=>RefreshIndicator(
    onRefresh:state.reload,
    child:ListView(
      padding:const EdgeInsets.fromLTRB(20,18,20,32),
      children:[
        const Text('CYCLE HISTORY',style:TextStyle(fontSize:10,letterSpacing:1.5,fontWeight:FontWeight.w800,color:AppColors.rose)),
        const SizedBox(height:6),
        Text('Your rhythm over time',style:Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.w700,letterSpacing:-.7)),
        const SizedBox(height:8),
        Text(state.cycles.length.toString()+' logged periods · average '+averageCycle(state.cycles).toString()+' days',style:const TextStyle(color:AppColors.muted)),
        const SizedBox(height:20),
        if(state.cycles.length>1)HistoryChart(cycles:state.cycles),
        const SizedBox(height:18),
        Row(children:[
          Expanded(child:Text('All logged cycles',style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.w700))),
          IconButton(onPressed:()=>showPeriodDialog(context,state),icon:const Icon(Icons.add_circle_outline)),
        ]),
        ...state.cycles.map((c)=>Dismissible(
          key:ValueKey(c.id),
          direction:DismissDirection.endToStart,
          confirmDismiss:(_)=>confirmDelete(context),
          onDismissed:(_)=>state.deleteCycle(c.id),
          background:Container(
            margin:const EdgeInsets.only(bottom:8),
            padding:const EdgeInsets.only(right:20),
            alignment:Alignment.centerRight,
            decoration:BoxDecoration(color:const Color(0xFFF7D9DC),borderRadius:BorderRadius.circular(18)),
            child:const Icon(Icons.delete_outline,color:AppColors.rose),
          ),
          child:Container(
            margin:const EdgeInsets.only(bottom:8),
            padding:const EdgeInsets.all(16),
            decoration:BoxDecoration(color:Theme.of(context).cardColor,borderRadius:BorderRadius.circular(18),border:Border.all(color:AppColors.line)),
            child:Row(children:[
              const Icon(Icons.calendar_today_outlined,size:18,color:AppColors.rose),
              const SizedBox(width:12),
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text(longDate(c.startDate),style:const TextStyle(fontWeight:FontWeight.w700)),
                Text(c.startTime==null?'Start time not recorded':'Started at '+c.startTime!,style:const TextStyle(fontSize:12,color:AppColors.muted)),
              ])),
              if(c.endDate!=null)Text((dayDiff(c.startDate,c.endDate!)+1).toString()+' d',style:const TextStyle(color:AppColors.muted)),
            ]),
          ),
        )),
      ],
    ),
  );

  Future<bool> confirmDelete(BuildContext context) async {
    final result=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(
      title:const Text('Delete this entry?'),
      content:const Text('This removes the shared cycle record for everyone using this app.'),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),
        FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Delete')),
      ],
    ));
    return result??false;
  }
}

class HistoryChart extends StatelessWidget {
  final List<PeriodCycle> cycles;
  const HistoryChart({super.key,required this.cycles});
  @override
  Widget build(BuildContext context){
    final values=<double>[];
    for(var i=0;i<cycles.length-1;i++) values.add(dayDiff(cycles[i+1].startDate,cycles[i].startDate).toDouble());
    return Container(
      height:190,
      padding:const EdgeInsets.all(16),
      decoration:BoxDecoration(color:Theme.of(context).cardColor,borderRadius:BorderRadius.circular(24),border:Border.all(color:AppColors.line)),
      child:CustomPaint(painter:ChartPainter(values),child:const SizedBox.expand()),
    );
  }
}

class ChartPainter extends CustomPainter {
  final List<double> values;
  ChartPainter(this.values);
  @override
  void paint(Canvas canvas,Size size){
    final min=values.reduce((a,b)=>a<b?a:b);
    final max=values.reduce((a,b)=>a>b?a:b);
    final range=(max-min).abs()<1?1:max-min;
    final left=8.0,right=size.width-8,top=18.0,bottom=size.height-24;
    final grid=Paint()..color=AppColors.line..strokeWidth=1;
    for(var i=0;i<3;i++){final y=top+(bottom-top)*i/2;canvas.drawLine(0,y,size.width,y,grid);}
    final line=Paint()..color=AppColors.rose..strokeWidth=2.5..style=PaintingStyle.stroke;
    final dots=Paint()..color=AppColors.rose;
    final path=Path();
    for(var i=0;i<values.length;i++){
      final x=values.length==1?(left+right)/2:left+(right-left)*i/(values.length-1);
      final y=bottom-(values[i]-min)/range*(bottom-top);
      if(i==0)path.moveTo(x,y);else path.lineTo(x,y);
      canvas.drawCircle(Offset(x,y),4,dots);
    }
    canvas.drawPath(path,line);
    final tp=TextPainter(text:TextSpan(text:values.last.toInt().toString()+' days',style:const TextStyle(fontSize:11,color:AppColors.muted)),textDirection:TextDirection.ltr)..layout();
    tp.paint(canvas,Offset(left,size.height-16));
  }
  @override bool shouldRepaint(covariant ChartPainter oldDelegate)=>oldDelegate.values!=values;
}

class UsPage extends StatelessWidget {
  final AppState state;
  const UsPage({super.key,required this.state});
  @override
  Widget build(BuildContext context)=>ListView(
    padding:const EdgeInsets.fromLTRB(20,18,20,36),
    children:[
      const Text('A LITTLE MORE OF US',style:TextStyle(fontSize:10,letterSpacing:1.5,fontWeight:FontWeight.w800,color:AppColors.rose)),
      const SizedBox(height:6),
      Text('Some dates are worth keeping forever.',style:Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.w700,letterSpacing:-.7)),
      const SizedBox(height:8),
      const Text('Not everything beautiful needs a big explanation. Some things are simply worth remembering.',style:TextStyle(color:AppColors.muted,height:1.55)),
      const SizedBox(height:22),
      TogetherCard(),
      const SizedBox(height:18),
      Text('Dates that matter',style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.w700)),
      const SizedBox(height:10),
      DateList(),
      const SizedBox(height:18),
      MemoryCard(kicker:"A morning I'll always remember",title:'Our first selfie & first short outing.',date:'1 January 2023 · Around 6:00 AM',note:'Just a quiet walk around Spectrum School in the early morning — simple, peaceful, and special because it was one of our first little adventures together.'),
      const SizedBox(height:14),
      MemoryCard(kicker:'A memory close to the heart',title:'The day we became even closer.',date:'3 March 2026',note:'Some moments are not about the details. They are about trust, closeness, and the feeling of being completely present with each other.'),
      const SizedBox(height:14),
      MomentCard(state:state),
      const SizedBox(height:22),
      const Center(child:Text('More memories waiting to be written.',style:TextStyle(color:AppColors.muted,fontStyle:FontStyle.italic))),
    ],
  );
}

class TogetherCard extends StatelessWidget {
  @override
  Widget build(BuildContext context){
    final days=dayDiff(DateTime(2022,10,12),today());
    return Container(
      padding:const EdgeInsets.all(24),
      decoration:BoxDecoration(color:Theme.of(context).cardColor,borderRadius:BorderRadius.circular(24),border:Border.all(color:AppColors.line)),
      child:Row(children:[
        Container(width:58,height:58,decoration:BoxDecoration(color:AppColors.roseSoft,borderRadius:BorderRadius.circular(18)),child:const Icon(Icons.favorite,color:AppColors.rose)),
        const SizedBox(width:16),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('SINCE 12 OCTOBER 2022',style:TextStyle(fontSize:10,letterSpacing:1.3,fontWeight:FontWeight.w800,color:AppColors.rose)),
          const SizedBox(height:4),
          Text('Still writing the story.',style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w700)),
        ])),
        Column(children:[
          Text(days.toString(),style:Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.w700,color:AppColors.rose)),
          const Text('days together',style:TextStyle(fontSize:10,color:AppColors.muted)),
        ]),
      ]),
    );
  }
}

class DateList extends StatelessWidget {
  @override
  Widget build(BuildContext context){
    const dates=[
      ['12 Oct 2022','Our love anniversary'],
      ['21 Oct 2004','Your birthday'],
      ['21 Feb 2005','My birthday'],
    ];
    return Column(children:dates.map((e)=>Container(
      width:double.infinity,
      margin:const EdgeInsets.only(bottom:8),
      padding:const EdgeInsets.all(16),
      decoration:BoxDecoration(color:Theme.of(context).cardColor,borderRadius:BorderRadius.circular(18),border:Border.all(color:AppColors.line)),
      child:Row(children:[
        Container(width:8,height:38,decoration:BoxDecoration(color:AppColors.rose,borderRadius:BorderRadius.circular(10))),
        const SizedBox(width:14),
        Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(e[0],style:const TextStyle(fontWeight:FontWeight.w700)),
          const SizedBox(height:3),
          Text(e[1],style:const TextStyle(fontSize:12,color:AppColors.muted)),
        ]),
      ]),
    )).toList());
  }
}

class MemoryCard extends StatelessWidget {
  final String kicker,title,date,note;
  const MemoryCard({super.key,required this.kicker,required this.title,required this.date,required this.note});
  @override
  Widget build(BuildContext context)=>Container(
    padding:const EdgeInsets.all(24),
    decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFFFAEFF1),Color(0xFFFFFEFD)]),borderRadius:BorderRadius.circular(24),border:Border.all(color:AppColors.line)),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(kicker.toUpperCase(),style:const TextStyle(fontSize:10,letterSpacing:1.3,fontWeight:FontWeight.w800,color:AppColors.rose)),
      const SizedBox(height:8),
      Text(title,style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w700)),
      const SizedBox(height:6),
      Text(date,style:const TextStyle(color:AppColors.rose,fontWeight:FontWeight.w600)),
      const SizedBox(height:18),
      Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('♡',style:TextStyle(fontSize:25,color:AppColors.rose)),
        const SizedBox(width:12),
        Expanded(child:Text(note,style:const TextStyle(fontSize:12,color:AppColors.muted,height:1.7,fontStyle:FontStyle.italic))),
      ]),
    ]),
  );
}

class MomentCard extends StatelessWidget {
  final AppState state;
  const MomentCard({super.key,required this.state});
  @override
  Widget build(BuildContext context)=>Container(
    padding:const EdgeInsets.all(22),
    decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFFF9E7E9),Color(0xFFFFF8F6)]),borderRadius:BorderRadius.circular(24),border:Border.all(color:AppColors.line)),
    child:Row(children:[
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('OUR LITTLE MOMENTS',style:TextStyle(fontSize:10,letterSpacing:1.3,fontWeight:FontWeight.w800,color:AppColors.rose)),
        const SizedBox(height:7),
        Text('A number only we need to understand.',style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w700)),
        const SizedBox(height:6),
        const Text("For every moment we've shared that made us feel a little closer.",style:TextStyle(color:AppColors.muted,height:1.45)),
      ])),
      const SizedBox(width:12),
      Column(children:[
        Text(state.intimacyCount.toString(),style:Theme.of(context).textTheme.displaySmall?.copyWith(color:AppColors.rose,fontWeight:FontWeight.w700)),
        const Text('little moments',style:TextStyle(fontSize:10,color:AppColors.muted)),
        const SizedBox(height:9),
        FilledButton.icon(
          onPressed:()async{
            try{await state.addMoment();}catch(e){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Could not save: '+e.toString())));}
          },
          icon:const Icon(Icons.favorite,size:15),
          label:const Text('Add one'),
        ),
      ]),
    ]),
  );
}

Future<void> showPeriodDialog(BuildContext context,AppState state) async {
  DateTime date=today();
  DateTime? end;
  TimeOfDay? time;
  final save=await showDialog<bool>(
    context:context,
    builder:(dialog)=>StatefulBuilder(builder:(context,setState)=>AlertDialog(
      title:const Text('Log period'),
      content:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Period started',style:TextStyle(fontWeight:FontWeight.w600)),
        const SizedBox(height:8),
        OutlinedButton.icon(
          onPressed:()async{
            final d=await showDatePicker(context:context,firstDate:DateTime(2020),lastDate:DateTime(2100),initialDate:date);
            if(d!=null)setState(()=>date=d);
          },
          icon:const Icon(Icons.calendar_today_outlined),
          label:Text(longDate(date)),
        ),
        const SizedBox(height:12),
        const Text('Started at (optional)',style:TextStyle(fontWeight:FontWeight.w600)),
        const SizedBox(height:8),
        OutlinedButton.icon(
          onPressed:()async{
            final t=await showTimePicker(context:context,initialTime:time??TimeOfDay.now());
            if(t!=null)setState(()=>time=t);
          },
          icon:const Icon(Icons.schedule_outlined),
          label:Text(time?.format(context)??'Add a time'),
        ),
        const SizedBox(height:12),
        const Text('Period ended (optional)',style:TextStyle(fontWeight:FontWeight.w600)),
        const SizedBox(height:8),
        OutlinedButton.icon(
          onPressed:()async{
            final d=await showDatePicker(context:context,firstDate:date,lastDate:DateTime(2100),initialDate:end??date);
            if(d!=null)setState(()=>end=d);
          },
          icon:const Icon(Icons.event_available_outlined),
          label:Text(end==null?'Add end date':longDate(end!)),
        ),
      ])),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(dialog,false),child:const Text('Cancel')),
        FilledButton(onPressed:()=>Navigator.pop(dialog,true),child:const Text('Save')),
      ],
    )),
  );
  if(save!=true)return;
  final timeText=time==null?null:time!.hour.toString().padLeft(2,'0')+':'+time!.minute.toString().padLeft(2,'0');
  try{
    await state.addCycle(keyOf(date),timeText,end==null?null:keyOf(end!));
    if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Cycle saved to shared history.')));
  }catch(e){
    if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Could not save: '+e.toString())));
  }
}

class ErrorBanner extends StatelessWidget {
  final String text;
  const ErrorBanner({super.key,required this.text});
  @override
  Widget build(BuildContext context)=>Container(
    margin:const EdgeInsets.only(bottom:12),
    padding:const EdgeInsets.all(14),
    decoration:BoxDecoration(color:const Color(0xFFFFECEC),borderRadius:BorderRadius.circular(16)),
    child:Text(text,style:const TextStyle(color:Color(0xFF9B3D47),fontSize:12)),
  );
}
