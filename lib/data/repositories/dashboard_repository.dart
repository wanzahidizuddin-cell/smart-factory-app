import 'package:smart_factory_qc/domain/models/activity_entry.dart';
import 'package:smart_factory_qc/domain/models/batch_status.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardStats {
  const DashboardStats({
    required this.pendingDeliveries,
    required this.quarantinedDeliveries,
    required this.lowStockItems,
  });

  final int pendingDeliveries;
  final int quarantinedDeliveries;
  final int lowStockItems;
}

class DashboardRepository {
  DashboardRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  Future<DashboardStats> fetchDashboardStats() async {
    final counts = await Future.wait<int>([
      _supabase
          .from('deliveries')
          .count()
          .or('status.eq.Pending,needs_review.eq.true'),
      _supabase
          .from('deliveries')
          .count()
          .eq('status', 'Quarantined'),
    ]);

    return DashboardStats(
      pendingDeliveries: counts[0],
      quarantinedDeliveries: counts[1],
      lowStockItems: 0,
    );
  }

  Future<List<ActivityEntry>> fetchRecentActivity() async {
    final rows = await _supabase
        .from('inspections')
        .select('serial_number, machine, result, created_at')
        .order('created_at', ascending: false)
        .limit(5);
    final now = DateTime.now();

    return rows.map((row) {
      final result = row['result'] as String;
      final status = switch (result) {
        'Pass' => BatchStatus.passed,
        'Fail' => BatchStatus.failed,
        _ => throw FormatException('Unsupported inspection result: $result'),
      };
      final createdAt = DateTime.parse(row['created_at'] as String).toLocal();

      return ActivityEntry(
        title: '${row['serial_number']} ${result.toLowerCase()}',
        reference: '${row['machine']} • ${_formatTime(createdAt)}',
        status: status,
        minutesAgo:
            now.difference(createdAt).inMinutes.clamp(0, 1 << 31).toInt(),
      );
    }).toList(growable: false);
  }

  String _formatTime(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
}
