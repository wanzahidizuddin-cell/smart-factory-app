import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_factory_qc/app/sync_status.dart';
import 'package:smart_factory_qc/core/theme/app_colors.dart';
import 'package:smart_factory_qc/core/theme/app_theme.dart';
import 'package:smart_factory_qc/core/widgets/responsive_content.dart';
import 'package:smart_factory_qc/core/widgets/section_label.dart';
import 'package:smart_factory_qc/data/repositories/profile_repository.dart';
import 'package:smart_factory_qc/data/repositories/settings_repository.dart';
import 'package:smart_factory_qc/features/shared/providers/app_state.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncStatus = ref.watch(syncStatusProvider);
    final profile = ref.watch(currentProfileProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ResponsiveContent(
        maxWidth: 900,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.s16),
          children: [
            profile.when(
              loading: () => const Card(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.s24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (error, stackTrace) => Card(
                child: ListTile(
                  title: const Text('Unable to load your profile.'),
                  trailing: IconButton(
                    tooltip: 'Retry',
                    onPressed: () => ref.invalidate(currentProfileProvider),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ),
              ),
              data: (user) => _personalDetailsCard(context, ref, user),
            ),
            const SizedBox(height: AppSpacing.s16),
            _preferencesCard(ref, settings),
            const SizedBox(height: AppSpacing.s16),
            Card(
              child: SwitchListTile(
                value: syncStatus.isOffline,
                onChanged: ref.read(syncStatusProvider.notifier).setOffline,
                thumbColor: const WidgetStatePropertyAll(AppColors.white),
                activeTrackColor: AppColors.quarantined,
                title: const Text('Simulate offline',
                    style: AppTextStyles.bodyStrong),
                subtitle: const Text('Demo only', style: AppTextStyles.caption),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
              ),
            ),
            if (profile.valueOrNull case final user?
                when _canManageUsers(user.role)) ...[
              const SizedBox(height: AppSpacing.s16),
              _userManagementSection(context, ref),
            ],
            const SizedBox(height: AppSpacing.s16),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.support_agent_rounded),
                    title: const Text('Support Center',
                        style: AppTextStyles.bodyStrong),
                    subtitle: const Text('Contact the Smart Factory team'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _showSupportCenter(context),
                  ),
                  const Divider(height: 1),
                  const ListTile(
                    leading: Icon(Icons.info_outline_rounded),
                    title: Text('App version',
                        style: AppTextStyles.bodyStrong),
                    trailing: Text('v1.0.0+1', style: AppTextStyles.caption),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s24),
            SizedBox(
              height: AppSpacing.primaryButtonHeight,
              child: OutlinedButton.icon(
                onPressed: onSignOut,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign out'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _personalDetailsCard(
    BuildContext context,
    WidgetRef ref,
    UserProfile user,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel('Personal details'),
            const SizedBox(height: AppSpacing.s8),
            Text(user.fullName, style: AppTextStyles.bodyStrong),
            const SizedBox(height: AppSpacing.s4),
            Text(user.employeeId, style: AppTextStyles.mono),
            const SizedBox(height: AppSpacing.s12),
            const SectionLabel('Role & account status'),
            const SizedBox(height: AppSpacing.s4),
            Text('${user.role} · ${user.status}', style: AppTextStyles.body),
            const SizedBox(height: AppSpacing.s8),
            Wrap(
              spacing: AppSpacing.s8,
              runSpacing: AppSpacing.s8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _editPersonalDetails(context, ref, user),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit details'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _changePassword(context, ref),
                  icon: const Icon(Icons.lock_outline_rounded),
                  label: const Text('Change password'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _preferencesCard(WidgetRef ref, AppSettings settings) {
    final controller = ref.read(settingsProvider.notifier);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel('Preferences'),
            const SizedBox(height: AppSpacing.s12),
            DropdownButtonFormField<String>(
              initialValue: settings.language,
              decoration: const InputDecoration(labelText: 'Language'),
              items: const [
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'es', child: Text('Español')),
                DropdownMenuItem(value: 'ms', child: Text('Bahasa Melayu')),
              ],
              onChanged: (value) {
                if (value != null) controller.setLanguage(value);
              },
            ),
            const SizedBox(height: AppSpacing.s12),
            DropdownButtonFormField<String>(
              initialValue: settings.currency,
              decoration: const InputDecoration(labelText: 'Currency'),
              items: const [
                DropdownMenuItem(value: 'USD', child: Text('USD')),
                DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                DropdownMenuItem(value: 'MYR', child: Text('MYR')),
              ],
              onChanged: (value) {
                if (value != null) controller.setCurrency(value);
              },
            ),
            const SizedBox(height: AppSpacing.s12),
            DropdownButtonFormField<String>(
              initialValue: settings.stockUnit,
              decoration: const InputDecoration(labelText: 'Stock units'),
              items: const [
                DropdownMenuItem(value: 'kg', child: Text('Kilograms (kg)')),
                DropdownMenuItem(value: 'lbs', child: Text('Pounds (lbs)')),
                DropdownMenuItem(value: 'units', child: Text('Units')),
              ],
              onChanged: (value) {
                if (value != null) controller.setStockUnit(value);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _userManagementSection(BuildContext context, WidgetRef ref) {
    final pendingUsers = ref.watch(pendingUsersProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel('User approval & management'),
            const SizedBox(height: AppSpacing.s8),
            pendingUsers.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.s16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stackTrace) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Unable to load pending users.'),
                trailing: IconButton(
                  tooltip: 'Retry',
                  onPressed: () => ref.invalidate(pendingUsersProvider),
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ),
              data: (users) => users.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.s8),
                      child: Text('No users are waiting for approval.',
                          style: AppTextStyles.body),
                    )
                  : Column(
                      children: [
                        for (final user in users)
                          _PendingUserTile(
                            user: user,
                            onApprove: (role) => _approveUser(
                              context,
                              ref,
                              user,
                              role,
                            ),
                            onReject: () => _rejectUser(context, ref, user),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingUserTile extends StatelessWidget {
  const _PendingUserTile({
    required this.user,
    required this.onApprove,
    required this.onReject,
  });

  final UserProfile user;
  final ValueChanged<String> onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(user.fullName, style: AppTextStyles.bodyStrong),
      subtitle: Text('${user.employeeId} · Pending'),
      trailing: PopupMenuButton<String>(
        tooltip: 'Approve or reject user',
        onSelected: (role) {
          if (role == 'reject') {
            onReject();
          } else {
            onApprove(role);
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'QA', child: Text('Approve as QA')),
          PopupMenuItem(value: 'QA Lead', child: Text('Approve as QA Lead')),
          PopupMenuItem(value: 'Warehouse', child: Text('Approve as Warehouse')),
          PopupMenuItem(value: 'Admin', child: Text('Approve as Admin')),
          PopupMenuDivider(),
          PopupMenuItem(
            value: 'reject',
            child: Text('Reject user', style: TextStyle(color: Colors.red)),
          ),
        ],
        child: const Icon(Icons.more_vert_rounded),
      ),
    );
  }
}

bool _canManageUsers(String role) {
  final normalized = role.trim().toLowerCase();
  return normalized == 'admin' || normalized == 'qa lead';
}

Future<void> _editPersonalDetails(
  BuildContext context,
  WidgetRef ref,
  UserProfile user,
) async {
  final nameController = TextEditingController(text: user.fullName);
  final employeeIdController = TextEditingController(text: user.employeeId);
  final formKey = GlobalKey<FormState>();
  try {
    final details = await showDialog<(String, String)>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit personal details'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: _requiredValidator,
              ),
              const SizedBox(height: AppSpacing.s12),
              TextFormField(
                controller: employeeIdController,
                decoration: const InputDecoration(labelText: 'Employee ID'),
                validator: _requiredValidator,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(
                  dialogContext,
                  (
                    nameController.text.trim(),
                    employeeIdController.text.trim(),
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (details == null) return;
    await ref.read(profileRepositoryProvider).updateProfile(
          fullName: details.$1,
          employeeId: details.$2,
        );
    ref.invalidate(currentProfileProvider);
    if (context.mounted) _showMessage(context, 'Profile details updated.');
  } catch (error) {
    if (context.mounted) {
      _showMessage(context, 'Could not update profile details: $error');
    }
  } finally {
    nameController.dispose();
    employeeIdController.dispose();
  }
}

Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
  final passwordController = TextEditingController();
  final confirmationController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  try {
    final password = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change password'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password'),
                validator: (value) => (value == null || value.length < 8)
                    ? 'Use at least 8 characters'
                    : null,
              ),
              const SizedBox(height: AppSpacing.s12),
              TextFormField(
                controller: confirmationController,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Confirm new password'),
                validator: (value) => value != passwordController.text
                    ? 'Passwords do not match'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(dialogContext, passwordController.text);
              }
            },
            child: const Text('Update password'),
          ),
        ],
      ),
    );
    if (password == null) return;
    await ref.read(profileRepositoryProvider).changePassword(password);
    if (context.mounted) _showMessage(context, 'Password updated.');
  } catch (error) {
    if (context.mounted) _showMessage(context, 'Could not change password: $error');
  } finally {
    passwordController.dispose();
    confirmationController.dispose();
  }
}

Future<void> _approveUser(
  BuildContext context,
  WidgetRef ref,
  UserProfile user,
  String role,
) async {
  try {
    await ref.read(profileRepositoryProvider).approveUser(
          userId: user.id,
          role: role,
        );
    ref
      ..invalidate(pendingUsersProvider)
      ..invalidate(currentProfileProvider);
    if (context.mounted) {
      _showMessage(context, '${user.fullName} approved as $role.');
    }
  } catch (error) {
    if (context.mounted) _showMessage(context, 'Could not approve user: $error');
  }
}

Future<void> _rejectUser(
  BuildContext context,
  WidgetRef ref,
  UserProfile user,
) async {
  try {
    await ref.read(profileRepositoryProvider).rejectUser(user.id);
    ref.invalidate(pendingUsersProvider);
    if (context.mounted) _showMessage(context, '${user.fullName} rejected.');
  } catch (error) {
    if (context.mounted) _showMessage(context, 'Could not reject user: $error');
  }
}

String? _requiredValidator(String? value) =>
    value == null || value.trim().isEmpty ? 'Required' : null;

void _showSupportCenter(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Support Center'),
      content: const Text(
        'For help with Smart Factory QC, contact your system administrator.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
