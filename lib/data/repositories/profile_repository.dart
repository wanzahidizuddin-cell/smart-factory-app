import 'package:supabase_flutter/supabase_flutter.dart';

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

    await _client.from('profiles').update({
      'full_name': fullName.trim(),
      'employee_id': employeeId.trim(),
    }).eq('id', userId);
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

    await _client.from('profiles').update({
      'role': role,
      'status': 'approved',
    }).eq('id', userId);
  }

  Future<void> rejectUser(String userId) async {
    await _client
        .from('profiles')
        .update({'status': 'rejected'}).eq('id', userId);
  }
}
