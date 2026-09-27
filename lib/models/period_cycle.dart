class PeriodCycle {
  final String id;
  final String periodStart;
  final String? periodStartTime;
  final String? periodEnd;
  const PeriodCycle({required this.id, required this.periodStart, this.periodStartTime, this.periodEnd});
  factory PeriodCycle.fromMap(Map<String, dynamic> map) => PeriodCycle(
    id: map['id'] as String,
    periodStart: map['period_start'] as String,
    periodStartTime: map['period_start_time'] as String?,
    periodEnd: map['period_end'] as String?,
  );
}
