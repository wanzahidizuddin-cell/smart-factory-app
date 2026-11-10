import 'package:supabase_flutter/supabase_flutter.dart';

class AuditLogService {
  AuditLogService([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<void> record({
    required String actionId,
    required String actionType,
    required String userId,
    required String module,
    required String recordId,
    required Map<String, dynamic>? previousState,
    required Map<String, dynamic> newState,
  }) async {
    final existing = await _client
        .from('audit_logs')
        .select('id')
        .eq('action_id', actionId)
        .maybeSingle();
    if (existing != null) return;

    await _client.from('audit_logs').insert({
      'action_id': actionId,
      'action_type': actionType,
      'user_id': userId,
      'module': module,
      'record_id': recordId,
      'previous_state': previousState,
      'new_state': newState,
    });
  }
}
