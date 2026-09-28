class PeriodCycle {
  final String id;
  final String start;
  final String? startTime;
  final String? end;

  const PeriodCycle({
    required this.id,
    required this.start,
    this.startTime,
    this.end,
  });

  factory PeriodCycle.fromMap(Map<String, dynamic> map) => PeriodCycle(
    id: map['id'].toString(),
    start: map['period_start'].toString(),
    startTime: map['period_start_time']?.toString(),
    end: map['period_end']?.toString(),
  );

  DateTime get startDate => DateTime.parse(start);
  DateTime? get endDate => end == null ? null : DateTime.tryParse(end!);

  // Compatibility aliases used by the screen widgets.
  String get periodStart => start;
  String? get periodStartTime => startTime;
  String? get periodEnd => end;
}
