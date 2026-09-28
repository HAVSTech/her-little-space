import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/supabase_service.dart';
import 'services/preferences_service.dart';
import 'models/period_cycle.dart';
import 'theme/app_theme.dart';
import 'widgets/common.dart';

const supabaseUrl = 'https://tyqnrqhhogbwjpwnmzvk.supabase.co';
const supabasePublishableKey = 'sb_publishable_AZQid6LZmmBv-Hy8-_QjDg_HMwYT7Sp';

DateTime today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}
String keyOf(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
String longDate(DateTime d) => DateFormat('d MMMM yyyy').format(d);

String formatStoredTime(String? raw) {
  if (raw == null || raw.isEmpty) return 'Start time not recorded';
  try {
    final parsed = DateFormat('HH:mm').parse(raw);
    return DateFormat('h:mm a').format(parsed);
  } catch (_) {
    try {
      final parsed = DateTime.parse('2000-01-01T$raw');
      return DateFormat('h:mm a').format(parsed);
    } catch (_) {
      return raw;
    }
  }
}
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

  void tick() => notifyListeners();

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
  await initializeDateFormatting('en_IN');
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
      widget.state.tick();
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

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: index,
          children: [
            TodayPage(
              state: widget.state,
              openHistory: () => setState(() => index = 1),
            ),
            HistoryPage(state: widget.state),
            UsPage(state: widget.state),
          ],
        ),
      ),
      bottomNavigationBar: _FloatingBottomNav(
        index: index,
        onChanged: (value) => setState(() => index = value),
      ),
    );
  }
}

class _FloatingBottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const _FloatingBottomNav({
    required this.index,
    required this.onChanged,
  });

  static const items = [
    (Icons.wb_sunny_outlined, Icons.wb_sunny, 'Today'),
    (Icons.calendar_month_outlined, Icons.calendar_month, 'History'),
    (Icons.favorite_border, Icons.favorite, 'Us'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(18, 0, 18, bottom + 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            height: 72,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(36),
              border: Border.all(
                color: Colors.white.withValues(alpha: .30),
                width: 1,
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: .22),
                  Colors.white.withValues(alpha: .10),
                  Colors.white.withValues(alpha: .05),
                ],
                stops: const [0, .42, 1],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .18),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: .06),
                  blurRadius: 8,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              children: List.generate(items.length, (i) {
                final selected = index == i;
                final item = items[i];

                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(i),
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutCubic,
                        constraints: const BoxConstraints(minHeight: 50),
                        padding: EdgeInsets.symmetric(
                          horizontal: selected ? 12 : 14,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.white.withValues(alpha: .72)
                              : Colors.white.withValues(alpha: .015),
                          borderRadius: BorderRadius.circular(28),
                          border: selected
                              ? Border.all(
                                  color: Colors.white.withValues(alpha: .82),
                                  width: 1,
                                )
                              : Border.all(
                                  color: Colors.white.withValues(alpha: .03),
                                  width: 1,
                                ),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: .10),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: AnimatedSize(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                transitionBuilder: (child, animation) =>
                                    ScaleTransition(
                                  scale: animation,
                                  child: child,
                                ),
                                child: Icon(
                                  selected ? item.$2 : item.$1,
                                  key: ValueKey(selected),
                                  size: 18,
                                  color: selected
                                      ? const Color(0xFF29252D)
                                      : Colors.white.withValues(alpha: .88),
                                ),
                              ),
                              if (selected) ...[
                                const SizedBox(width: 5),
                                Text(
                                  item.$3,
                                  overflow: TextOverflow.clip,
                                  softWrap: false,
                                  style: const TextStyle(
                                    color: Color(0xFF29252D),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -.1,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'GOOD MORNING, THANGAME ✨';
  if (hour < 17) return 'GOOD AFTERNOON, THANGAME ✨';
  return 'GOOD EVENING, THANGAME ✨';
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
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _greeting(),
                      style: const TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.rose,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      DateFormat('EEEE, d MMMM').format(today()),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: state.toggleDark,
                icon: Icon(
                  state.dark
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 34),
          RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    letterSpacing: -2.2,
                    height: .98,
                    color: AppColors.ink,
                  ),
              children: const [
                TextSpan(text: 'Your body has a\n'),
                TextSpan(
                  text: 'rhythm.\n',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(
                  text: 'Let’s move with it.',
                  style: TextStyle(
                    color: AppColors.rose,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'A soft little space to notice your cycle, check in with yourself, and keep the everyday things that matter close.',
            style: TextStyle(
              color: AppColors.muted,
              height: 1.65,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 24),
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
        Text(cycle.startTime==null?'Start time not recorded':'Started at '+formatStoredTime(cycle.startTime),style:const TextStyle(fontSize:12,color:AppColors.muted)),
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
        if(state.cycles.length>1)HistoryChart(state:state),
        const SizedBox(height:18),
        Text(
          'All logged cycles',
          style:Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight:FontWeight.w700,
            fontSize:18,
            letterSpacing:-.3,
          ),
        ),
        const SizedBox(height:12),
        Center(
          child:Tooltip(
            message:'Log a period',
            child:Material(
              color:Colors.transparent,
              child:InkWell(
                borderRadius:BorderRadius.circular(10),
                onTap:()=>showPeriodDialog(context,state),
                child:Container(
                  padding:const EdgeInsets.symmetric(horizontal:16,vertical:9),
                  decoration:BoxDecoration(
                    color:AppColors.rose,
                    borderRadius:BorderRadius.circular(10),
                    boxShadow:[
                      BoxShadow(
                        color:AppColors.rose.withValues(alpha:.18),
                        blurRadius:14,
                        offset:const Offset(0,6),
                      ),
                    ],
                  ),
                  child:const Row(
                    mainAxisSize:MainAxisSize.min,
                    children:[
                      Icon(Icons.add_rounded,color:Colors.white,size:14),
                      SizedBox(width:6),
                      Text(
                        'Log period',
                        style:TextStyle(
                          color:Colors.white,
                          fontSize:10,
                          fontWeight:FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height:14),
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
              Expanded(
                child:Column(
                  crossAxisAlignment:CrossAxisAlignment.start,
                  children:[
                    Text(
                      longDate(c.startDate),
                      style:const TextStyle(fontWeight:FontWeight.w700),
                    ),
                    Text(
                      c.startTime==null
                          ? 'Start time not recorded'
                          : 'Started at '+formatStoredTime(c.startTime),
                      style:const TextStyle(
                        fontSize:12,
                        color:AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (c != state.cycles.last)
                Padding(
                  padding:const EdgeInsets.only(left:10),
                  child:Container(
                    padding:const EdgeInsets.only(left:10),
                    decoration:const BoxDecoration(
                      border:Border(
                        left:BorderSide(
                          color:AppColors.rose,
                          width:1.2,
                        ),
                      ),
                    ),
                    child:Column(
                      crossAxisAlignment:CrossAxisAlignment.start,
                      children:[
                        const Text(
                          'CYCLE',
                          style:TextStyle(
                            fontSize:8,
                            letterSpacing:1.2,
                            color:AppColors.muted,
                            fontWeight:FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height:2),
                        Text(
                          dayDiff(
                            c.startDate,
                            state.cycles[state.cycles.indexOf(c)-1].startDate,
                          ).toString()+' days',
                          style:const TextStyle(
                            fontSize:10,
                            fontWeight:FontWeight.w800,
                            color:AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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

class HistoryChart extends StatefulWidget {
  final AppState state;

  const HistoryChart({super.key, required this.state});

  @override
  State<HistoryChart> createState() => _HistoryChartState();
}

class _HistoryChartState extends State<HistoryChart> {
  int? hoverIndex;

  List<PeriodCycle> get ordered =>
      widget.state.cycles.take(10).toList().reversed.toList();

  List<double> get values {
    final result = <double>[];
    final items = ordered;
    for (var i = 0; i < items.length - 1; i++) {
      result.add(
        dayDiff(items[i].startDate, items[i + 1].startDate).toDouble(),
      );
    }
    return result;
  }

  void updateHover(Offset position, double width) {
    final count = values.length;
    if (count == 0) return;
    const left = 32.0;
    const right = 10.0;
    final chartWidth = width - left - right;
    if (chartWidth <= 0) return;

    final raw = ((position.dx - left) / chartWidth) * (count - 1);
    final index = raw.round().clamp(0, count - 1);

    if (index != hoverIndex) {
      setState(() => hoverIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = ordered;
    final data = values;
    if (data.isEmpty) return const SizedBox.shrink();

    final average = data.reduce((a, b) => a + b) / data.length;
    final labels = items
        .take(data.length)
        .map((c) => DateFormat('MMM', 'en_IN').format(c.startDate))
        .toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Kicker('Visual history'),
          const SizedBox(height: 7),
          Text(
            'Your cycle, month by month.',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.5,
                ),
          ),
          const SizedBox(height: 5),
          const Text(
            'A gentle view of how your cycle length has changed.',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.muted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 210,
            child: LayoutBuilder(
              builder: (context, constraints) => MouseRegion(
                cursor: SystemMouseCursors.click,
                onHover: (event) => updateHover(event.localPosition, constraints.maxWidth),
                onExit: (_) => setState(() => hoverIndex = null),
                child: GestureDetector(
                  onLongPressStart: (details) =>
                      updateHover(details.localPosition, constraints.maxWidth),
                  child: CustomPaint(
                    painter: CycleChartPainter(
                      values: data,
                      labels: labels,
                      average: average,
                      hoverIndex: hoverIndex,
                      lineColor: AppColors.rose,
                      gridColor: AppColors.line,
                      textColor: AppColors.muted,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.rose,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              const Text(
                'Cycle length',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                'Average · ' + average.round().toString() + ' days',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CycleChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final double average;
  final int? hoverIndex;
  final Color lineColor;
  final Color gridColor;
  final Color textColor;

  CycleChartPainter({
    required this.values,
    required this.labels,
    required this.average,
    required this.hoverIndex,
    required this.lineColor,
    required this.gridColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    const left = 32.0;
    const right = 10.0;
    const top = 10.0;
    const bottom = 32.0;

    final chart = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );

    var minValue = values.reduce((a, b) => a < b ? a : b);
    var maxValue = values.reduce((a, b) => a > b ? a : b);

    minValue = minValue.floorToDouble() - 2;
    maxValue = maxValue.ceilToDouble() + 2;

    if (maxValue - minValue < 6) {
      final middle = (maxValue + minValue) / 2;
      minValue = middle - 3;
      maxValue = middle + 3;
    }

    double yFor(double value) {
      final ratio = (value - minValue) / (maxValue - minValue);
      return chart.bottom - ratio * chart.height;
    }

    double xFor(int index) {
      if (values.length == 1) return chart.center.dx;
      return chart.left + chart.width * index / (values.length - 1);
    }

    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: .72)
      ..strokeWidth = 1;

    final labelStyle = TextStyle(
      fontSize: 9,
      color: textColor,
      fontWeight: FontWeight.w500,
    );

    for (var i = 0; i < 4; i++) {
      final ratio = i / 3;
      final y = chart.top + chart.height * ratio;
      canvas.drawLine(
        Offset(chart.left, y),
        Offset(chart.right, y),
        gridPaint,
      );

      final value = maxValue - (maxValue - minValue) * ratio;
      final painter = TextPainter(
        text: TextSpan(
          text: value.round().toString(),
          style: labelStyle,
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();

      painter.paint(canvas, Offset(0, y - painter.height / 2));
    }

    final averageY = yFor(average.clamp(minValue, maxValue));
    final averagePaint = Paint()
      ..color = lineColor.withValues(alpha: .25)
      ..strokeWidth = 1.2;

    const dash = 5.0;
    const gap = 5.0;
    var x = chart.left;
    while (x < chart.right) {
      canvas.drawLine(
        Offset(x, averageY),
        Offset((x + dash).clamp(chart.left, chart.right), averageY),
        averagePaint,
      );
      x += dash + gap;
    }

    final points = List.generate(
      values.length,
      (i) => Offset(xFor(i), yFor(values[i])),
    );

    final fillPath = Path()
      ..moveTo(points.first.dx, chart.bottom)
      ..lineTo(points.first.dx, points.first.dy);

    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final controlX = (previous.dx + current.dx) / 2;
      fillPath.cubicTo(
        controlX,
        previous.dy,
        controlX,
        current.dy,
        current.dx,
        current.dy,
      );
    }

    fillPath.lineTo(points.last.dx, chart.bottom);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withValues(alpha: .16),
          lineColor.withValues(alpha: .015),
        ],
      ).createShader(chart);

    canvas.drawPath(fillPath, fillPaint);

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final controlX = (previous.dx + current.dx) / 2;
      linePath.cubicTo(
        controlX,
        previous.dy,
        controlX,
        current.dy,
        current.dx,
        current.dy,
      );
    }

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(linePath, linePaint);

    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      if (i == hoverIndex) {
        canvas.drawCircle(
          point,
          9,
          Paint()..color = lineColor.withValues(alpha: .12),
        );
        canvas.drawCircle(
          point,
          6,
          Paint()..color = Colors.white,
        );
        canvas.drawCircle(
          point,
          3.5,
          Paint()..color = lineColor,
        );
      } else {
        canvas.drawCircle(point, 5, Paint()..color = Colors.white);
        canvas.drawCircle(point, 3, Paint()..color = lineColor);
      }
    }

    if (hoverIndex != null &&
        hoverIndex! >= 0 &&
        hoverIndex! < points.length) {
      final i = hoverIndex!;
      final point = points[i];
      final dayValue = values[i].round();
      final month = labels[i];

      final tooltipPainter = TextPainter(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$month  ·  ',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
            TextSpan(
              text: '$dayValue days',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();

      final tooltipWidth = tooltipPainter.width + 22;
      final tooltipHeight = tooltipPainter.height + 14;
      final tooltipX = (point.dx - tooltipWidth / 2)
          .clamp(4.0, size.width - tooltipWidth - 4);
      final tooltipY = (point.dy - tooltipHeight - 14).clamp(
        2.0,
        size.height - tooltipHeight - 2,
      );

      final tooltipRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          tooltipX,
          tooltipY,
          tooltipWidth,
          tooltipHeight,
        ),
        const Radius.circular(12),
      );

      canvas.drawShadow(
        Path()..addRRect(tooltipRect),
        Colors.black.withValues(alpha: .14),
        8,
        true,
      );

      canvas.drawRRect(
        tooltipRect,
        Paint()..color = const Color(0xFF28232B),
      );

      tooltipPainter.paint(
        canvas,
        Offset(
          tooltipX + 11,
          tooltipY + (tooltipHeight - tooltipPainter.height) / 2,
        ),
      );
    }

    for (var i = 0; i < labels.length && i < points.length; i++) {
      final painter = TextPainter(
        text: TextSpan(text: labels[i], style: labelStyle),
        textDirection: ui.TextDirection.ltr,
      )..layout();

      var labelX = points[i].dx - painter.width / 2;
      labelX = labelX.clamp(0.0, size.width - painter.width);
      painter.paint(canvas, Offset(labelX, chart.bottom + 9));
    }
  }

  @override
  bool shouldRepaint(covariant CycleChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.average != average ||
        oldDelegate.hoverIndex != hoverIndex ||
        oldDelegate.labels != labels;
  }
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
    if(context.mounted) {
      await showDialog<void>(
        context:context,
        barrierColor:Colors.black.withValues(alpha:.28),
        builder:(dialog)=>Dialog(
          backgroundColor:Colors.transparent,
          insetPadding:const EdgeInsets.symmetric(horizontal:32),
          child:Container(
            padding:const EdgeInsets.fromLTRB(24,26,24,20),
            decoration:BoxDecoration(
              color:Theme.of(dialog).cardColor,
              borderRadius:BorderRadius.circular(28),
              border:Border.all(color:AppColors.rose.withValues(alpha:.16)),
              boxShadow:[
                BoxShadow(
                  color:AppColors.rose.withValues(alpha:.12),
                  blurRadius:30,
                  offset:const Offset(0,14),
                ),
              ],
            ),
            child:Column(
              mainAxisSize:MainAxisSize.min,
              children:[
                Container(
                  width:58,
                  height:58,
                  decoration:const BoxDecoration(
                    color:AppColors.roseSoft,
                    shape:BoxShape.circle,
                  ),
                  child:const Icon(
                    Icons.favorite_rounded,
                    color:AppColors.rose,
                    size:25,
                  ),
                ),
                const SizedBox(height:18),
                const Text(
                  'Take care, thangame!!',
                  textAlign:TextAlign.center,
                  style:TextStyle(
                    fontSize:20,
                    fontWeight:FontWeight.w700,
                    color:AppColors.ink,
                    letterSpacing:-.4,
                  ),
                ),
                const SizedBox(height:8),
                const Text(
                  'Soon I will stop this cycle.',
                  textAlign:TextAlign.center,
                  style:TextStyle(
                    fontSize:12,
                    color:AppColors.muted,
                    height:1.55,
                  ),
                ),
                const SizedBox(height:20),
                FilledButton(
                  onPressed:()=>Navigator.pop(dialog),
                  style:FilledButton.styleFrom(
                    backgroundColor:AppColors.rose,
                    foregroundColor:Colors.white,
                    elevation:0,
                    padding:const EdgeInsets.symmetric(
                      horizontal:24,
                      vertical:12,
                    ),
                    shape:RoundedRectangleBorder(
                      borderRadius:BorderRadius.circular(12),
                    ),
                  ),
                  child:const Text(
                    'Okay, thangame ♡',
                    style:TextStyle(
                      fontSize:11,
                      fontWeight:FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }catch(e){
    if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content:Text('Could not save: '+e.toString())),
    );
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
