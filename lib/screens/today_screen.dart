import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/period_cycle.dart';
import '../theme.dart';
import '../widgets/common.dart';

class TodayScreen extends StatelessWidget {
  final List<PeriodCycle> cycles; final String mood; final List<String> symptoms;
  final ValueChanged<String> onMood, onSymptom; final VoidCallback onLogPeriod, onHistory; final DateTime now;
  const TodayScreen({super.key, required this.cycles, required this.mood, required this.symptoms, required this.onMood, required this.onSymptom, required this.onLogPeriod, required this.onHistory, required this.now});
  DateTime d(String s)=>DateTime.parse(s); int days(DateTime a,DateTime b)=>DateUtils.dateOnly(b).difference(DateUtils.dateOnly(a)).inDays;
  int get cycleLength=>cycles.length>1?days(d(cycles[1].periodStart),d(cycles[0].periodStart)):28;
  int get currentDay=>cycles.isEmpty?0:(days(d(cycles[0].periodStart),now)+1).clamp(1,999);
  int get averageLength{if(cycles.length<2)return cycleLength;final v=<int>[];for(var i=0;i<cycles.length-1;i++){final n=days(d(cycles[i+1].periodStart),d(cycles[i].periodStart));if(n>0&&n<100)v.add(n);}return v.isEmpty?cycleLength:(v.reduce((a,b)=>a+b)/v.length).round();}
  String phase(int x)=>x<=5?'Menstrual':x<=13?'Follicular':x<=16?'Ovulation':'Luteal';
  String phaseIcon(int x)=>x<=5?'🌸':x<=13?'🌱':x<=16?'✨':'🌙';
  String phaseNote(int x)=>x<=5?'Slow down, rest, and be gentle with yourself.':x<=13?'Energy may gradually start to rise.':x<=16?'A brighter, more social part of the cycle for many people.':'A softer phase · listen to what your body asks for.';
  @override Widget build(BuildContext context){
    final latest=cycles.isEmpty?null:cycles.first;final start=latest==null?null:d(latest.periodStart);final next=start?.add(Duration(days:cycleLength));
    final fs=cycles.isEmpty?0:(averageLength-19).clamp(1,averageLength);final fe=cycles.isEmpty?0:(averageLength-13).clamp(fs,averageLength);final fertile=latest!=null&&currentDay>=fs&&currentDay<=fe;
    return ListView(padding:const EdgeInsets.fromLTRB(20,28,20,50),children:[_hero(context,latest,next),if(fertile)...[const SizedBox(height:24),_alert()],const SizedBox(height:24),_stats(latest),const SizedBox(height:70),_checkIn(),const SizedBox(height:70),_recent()]);
  }
  Widget _hero(BuildContext c,PeriodCycle? latest,DateTime? next){
    final copy=Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Kicker('Good evening, Harini'),const SizedBox(height:12),Text('Your body has a rhythm.\nLet’s move with it.',style:TextStyle(fontSize:42,height:.98,fontWeight:FontWeight.w500,letterSpacing:-2.5)),const SizedBox(height:15),const Text('A soft little space to notice your cycle, check in with yourself, and keep the everyday things that matter close.',style:TextStyle(fontSize:11,height:1.7,color:AppColors.lightMuted)),const SizedBox(height:18),latest==null?PrimaryButton(label:'Log your first period',icon:Icons.add,onPressed:onLogPeriod):Wrap(spacing:10,runSpacing:10,children:[_meta('Today',DateFormat('EEEE, d MMMM','en_IN').format(now)),_meta('Next period · estimated',DateFormat('d MMM yyyy','en_IN').format(next!))])]);
    final card = SoftCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Expanded(child: Text('Your current rhythm', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
            if (latest != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(color: AppColors.roseSoft, borderRadius: BorderRadius.circular(30)),
                child: Text('${phaseIcon(currentDay)} ${phase(currentDay)}', style: const TextStyle(fontSize: 9, color: AppColors.rose, fontWeight: FontWeight.w700)),
              ),
          ]),
          const SizedBox(height: 22),
          if (latest == null)
            Column(children: [
              const Text('🌷', style: TextStyle(fontSize: 45)),
              const SizedBox(height: 8),
              const Text('Your cycle starts here.', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text('Log the first day of your period to begin tracking.', style: TextStyle(fontSize: 10, color: AppColors.lightMuted), textAlign: TextAlign.center),
              const SizedBox(height: 15),
              OutlinedButton(onPressed: onLogPeriod, child: const Text('Add period')),
            ])
          else
            Column(children: [
              Center(child: SizedBox(width: 190, height: 190, child: Stack(alignment: Alignment.center, children: [
                SizedBox(width: 190, height: 190, child: CircularProgressIndicator(value: (currentDay / cycleLength).clamp(0, 1), strokeWidth: 12, backgroundColor: Theme.of(c).dividerColor, color: AppColors.rose)),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('$currentDay', style: const TextStyle(fontSize: 46, fontWeight: FontWeight.w500, color: AppColors.rose)),
                  const Text('cycle day', style: TextStyle(fontSize: 9, color: AppColors.lightMuted)),
                ]),
              ]))),
              const SizedBox(height: 22),
              Text('${phaseIcon(currentDay)} ${phase(currentDay)}', style: const TextStyle(color: AppColors.rose, fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 7),
              Text(phaseNote(currentDay), style: const TextStyle(fontSize: 10, color: AppColors.lightMuted, height: 1.6)),
            ]),
        ],
      ),
    );
    return LayoutBuilder(builder:(context,box)=>box.maxWidth>900?Row(children:[Expanded(child:copy),const SizedBox(width:42),Expanded(child:card)]):Column(children:[copy,const SizedBox(height:28),card]));
  }
  Widget _meta(String a,String b)=>SoftCard(padding:const EdgeInsets.symmetric(horizontal:14,vertical:11),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(a,style:const TextStyle(fontSize:8,color:AppColors.lightMuted)),const SizedBox(height:4),Text(b,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w700))]));
  Widget _alert()=>Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(color:const Color(0xFFFFF1F2),border:Border.all(color:const Color(0xFFE9C7CB)),borderRadius:BorderRadius.circular(22)),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('⚠️',style:TextStyle(fontSize:24)),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Kicker('Cycle awareness'),const SizedBox(height:7),const Text('Higher pregnancy possibility',style:TextStyle(fontSize:20,fontWeight:FontWeight.w600)),const SizedBox(height:7),Text('You are around cycle day $currentDay, which falls within the estimated fertile window based on your logged cycles. Calendar estimates cannot confirm ovulation or rule out pregnancy.',style:const TextStyle(fontSize:10,height:1.8)),const SizedBox(height:9),const Text('For pregnancy prevention, do not rely on calendar predictions alone. Consider a reliable contraceptive method.',style:TextStyle(fontSize:9,color:AppColors.lightMuted,fontStyle:FontStyle.italic))]))]));
  Widget _recent()=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[SectionHeading(kicker:'Recent cycles',title:'A record that grows with you.',action:'View all',onAction:onHistory),if(cycles.isEmpty)const SoftCard(child:Text('No cycle history yet. Add the first period to start building your history.',style:TextStyle(fontSize:10,color:AppColors.lightMuted))) else SoftCard(padding:EdgeInsets.zero,child:Column(children:cycles.take(3).toList().asMap().entries.map((e){final i=e.key,cy=e.value;final len=i+1<cycles.length?days(d(cycles[i+1].periodStart),d(cy.periodStart)):null;return ListTile(contentPadding:const EdgeInsets.symmetric(horizontal:18,vertical:5),leading:CircleAvatar(backgroundColor:AppColors.roseSoft,foregroundColor:AppColors.rose,child:Text('${d(cy.periodStart).day}')),title:Text(DateFormat('d MMM yyyy','en_IN').format(d(cy.periodStart)),style:const TextStyle(fontSize:11,fontWeight:FontWeight.w700)),subtitle:Text(cy.periodEnd==null?'Currently logged':'Ended ${DateFormat('d MMM yyyy','en_IN').format(d(cy.periodEnd!))}',style:const TextStyle(fontSize:9)),trailing:Text(len==null?'Current':'$len d',style:const TextStyle(fontSize:10,fontWeight:FontWeight.w700,color:AppColors.rose)));}).toList()))]);
}
  Widget _stats(PeriodCycle? latest) {
    final items = [
      ('Latest period', latest == null ? 'Not logged' : DateFormat('d MMM yyyy', 'en_IN').format(d(latest.periodStart))),
      ('Mood', mood),
      ('Average cycle', '$averageLength days'),
    ];
    return Row(
      children: items.map((item) => Expanded(
        child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: SoftCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.$1, style: const TextStyle(fontSize: 8, color: AppColors.lightMuted)),
              const SizedBox(height: 4),
              Text(item.$2, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      )).toList(),
    );
  }
