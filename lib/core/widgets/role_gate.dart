import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_factory_qc/domain/models/app_role.dart';
import 'package:smart_factory_qc/features/shared/providers/app_state.dart';

class RoleGate extends ConsumerWidget {
  const RoleGate({
    super.key,
    required this.allowedRoles,
    required this.child,
    this.fallback = const SizedBox.shrink(),
  });

  final List<AppRole> allowedRoles;
  final Widget child;
  final Widget fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(userRoleProvider);
    return role.when(
      data: (value) =>
          value != null && allowedRoles.contains(value) ? child : fallback,
      error: (_, __) => fallback,
      loading: () => fallback,
    );
  }
}
