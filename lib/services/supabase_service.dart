import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/period_cycle.dart';

class SupabaseService {
  SupabaseService(this.client);

  final SupabaseClient client;

  static const historicalCycles = <List<String?>>[
    ['2025-02-19', null], ['2025-03-17', '23:00'], ['2025-04-16', '04:00'],
    ['2025-05-14', '04:30'], ['2025-06-13', '20:30'], ['2025-07-13', '22:30'],
    ['2025-08-11', '14:26'], ['2025-09-08', '13:00'], ['2025-10-08', '13:00'],
    ['2025-11-06', '13:00'], ['2025-12-06', '13:00'], ['2026-01-04', '14:30'],
    ['2026-02-02', '13:10'], ['2026-03-03', '15:30'], ['2026-04-02', '12:00'],
    ['2026-05-01', '19:30'], ['2026-06-02', '04:50'], ['2026-07-02', '06:08'],
    ['2026-08-02', '21:30'],
  ];

  Future<void> ensureAnonymousUser() async {
    if (client.auth.currentUser != null) return;
    await client.auth.signInAnonymously();
  }

  Future<List<PeriodCycle>> loadCycles() async {
    final rows = await client
        .from('shared_period_cycles')
        .select('id,period_start,period_start_time,period_end,created_at')
        .order('period_start', ascending: false);
    return (rows as List)
        .map((row) => PeriodCycle.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<void> seedIfEmpty() async {
    if ((await loadCycles()).isNotEmpty) return;
    await client.from('shared_period_cycles').upsert(
      historicalCycles
          .map((e) => {'period_start': e[0], 'period_start_time': e[1]})
          .toList(),
      onConflict: 'period_start,period_start_time,period_end',
      ignoreDuplicates: true,
    );
  }

  Future<void> addCycle({
    required String start,
    String? time,
    String? end,
  }) =>
      client.from('shared_period_cycles').upsert(
        {'period_start': start, 'period_start_time': time, 'period_end': end},
        onConflict: 'period_start,period_start_time,period_end',
        ignoreDuplicates: true,
      );

  Future<void> deleteCycle(String id) =>
      client.from('shared_period_cycles').delete().eq('id', id);

  Future<int> loadIntimacyCount() async {
    final row = await client
        .from('shared_relationship_stats')
        .select('intimacy_count')
        .eq('id', true)
        .maybeSingle();
    return (row?['intimacy_count'] as num?)?.toInt() ?? 0;
  }

  Future<int> incrementIntimacy() async {
    final result = await client.rpc('increment_shared_intimacy');
    return (result as num).toInt();
  }
}
