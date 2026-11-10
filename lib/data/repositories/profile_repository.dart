import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_factory_qc/domain/models/app_role.dart';
import 'package:smart_factory_qc/data/services/audit_log_service.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.fullName,
    required this.employeeId,
    required this.role,
    required this.status,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
        id: map['id'] as String,
        fullName: map['full_name'] as String,
        employeeId: map['employee_id'] as String,
        role: map['role'] as String,
        status: map['status'] as String,
      );

  final String id;
  final String fullName;
  final String employeeId;
  final String role;
  final String status;

  AppRole get appRole => AppRole.fromDatabase(role);
}

class ProfileRepository {
  ProfileRepository() : _client = Supabase.instance.client;

  final SupabaseClient _client;

  static const _profileColumns = 'id, full_name, employee_id, role, status';

  Future<UserProfile> fetchCurrentProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Sign in before loading your profile.');
    }

    final profile = await _client
        .from('profiles')
        .select(_profileColumns)
        .eq('id', userId)
        .single();
    return UserProfile.fromMap(profile);
  }

  Future<void> updateProfile({
    required String fullName,
    required String employeeId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Sign in before updating your profile.');
    }

    final before = await _client
        .from('profiles')
        .select('full_name, employee_id')
        .eq('id', userId)
        .single();
    final after = {
      'full_name': fullName.trim(),
      'employee_id': employeeId.trim(),
    };
    await _client.from('profiles').update(after).eq('id', userId);
    await _auditProfileChange(
      actionType: 'profile_updated',
      recordId: userId,
      previousState: before,
      newState: after,
    );
  }

  Future<void> changePassword(String password) async {
    await _client.auth.updateUser(UserAttributes(password: password));
  }

  Future<List<UserProfile>> fetchPendingUsers() async {
    final profiles = await _client
        .from('profiles')
        .select(_profileColumns)
        .eq('status', 'pending')
        .order('created_at');
    return profiles
        .map((profile) => UserProfile.fromMap(profile))
        .toList(growable: false);
  }

  Future<void> approveUser({
    required String userId,
    required String role,
  }) async {
    if (!const {'Admin', 'QA Lead', 'QA', 'Warehouse'}.contains(role)) {
      throw ArgumentError.value(role, 'role', 'Unsupported profile role.');
    }

    final before = await _client
        .from('profiles')
        .select('full_name, employee_id, role, status')
        .eq('id', userId)
        .single();
    final after = {
      'role': role,
      'status': 'approved',
    };
    await _client.from('profiles').update(after).eq('id', userId);
    await _auditProfileChange(
      actionType: 'profile_approved',
      recordId: userId,
      previousState: before,
      newState: {...before, ...after},
    );
  }

  Future<void> rejectUser(String userId) async {
    final before = await _client
        .from('profiles')
        .select('full_name, employee_id, role, status')
        .eq('id', userId)
        .single();
    const after = {'status': 'rejected'};
    await _client.from('profiles').update(after).eq('id', userId);
    await _auditProfileChange(
      actionType: 'profile_rejected',
      recordId: userId,
      previousState: before,
      newState: {...before, ...after},
    );
  }

  Future<void> _auditProfileChange({
    required String actionType,
    required String recordId,
    required Map<String, dynamic> previousState,
    required Map<String, dynamic> newState,
  }) async {
    final actorId = _client.auth.currentUser?.id;
    if (actorId == null) {
      throw StateError('Sign in before recording profile changes.');
    }
    final actionId =
        'profile-$recordId-${DateTime.now().toUtc().microsecondsSinceEpoch}';
    await AuditLogService(_client).record(
      actionId: actionId,
      actionType: actionType,
      userId: actorId,
      module: 'profiles',
      recordId: recordId,
      previousState: previousState,
      newState: newState,
    );
  }
}
