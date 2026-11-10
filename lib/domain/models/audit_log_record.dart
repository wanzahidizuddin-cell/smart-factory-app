class AuditLogRecord {
  const AuditLogRecord({
    required this.id,
    required this.actionType,
    required this.userId,
    required this.module,
    required this.recordId,
    required this.previousState,
    required this.newState,
    required this.createdAt,
  });

  factory AuditLogRecord.fromMap(Map<String, dynamic> map) => AuditLogRecord(
        id: map['id'] as String,
        actionType: map['action_type'] as String,
        userId: map['user_id'] as String,
        module: map['module'] as String,
        recordId: map['record_id'] as String,
        previousState: map['previous_state'] as Map<String, dynamic>?,
        newState: map['new_state'] as Map<String, dynamic>,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  final String id;
  final String actionType;
  final String userId;
  final String module;
  final String recordId;
  final Map<String, dynamic>? previousState;
  final Map<String, dynamic> newState;
  final DateTime createdAt;
}
