import 'package:smart_factory_qc/domain/models/audit_log_record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuditLogRepository {
  AuditLogRepository([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<AuditLogRecord>> fetchLogs() async {
    final rows = await _client
        .from('audit_logs')
        .select(
          'id, action_type, user_id, module, record_id, previous_state, '
          'new_state, created_at',
        )
        .order('created_at', ascending: false)
        .limit(500);
    return rows
        .map((row) => AuditLogRecord.fromMap(row))
        .toList(growable: false);
  }
}
