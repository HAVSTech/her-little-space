class PeriodCycle{
 final String id,periodStart; final String? periodStartTime,periodEnd;
 const PeriodCycle({required this.id,required this.periodStart,this.periodStartTime,this.periodEnd});
 factory PeriodCycle.fromMap(Map<String,dynamic> m)=>PeriodCycle(
  id:m['id'] as String,periodStart:m['period_start'] as String,periodStartTime:m['period_start_time'] as String?,periodEnd:m['period_end'] as String?);
}