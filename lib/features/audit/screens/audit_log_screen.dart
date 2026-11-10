import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_factory_qc/domain/models/audit_log_record.dart';
import 'package:smart_factory_qc/features/shared/providers/app_state.dart';

class AuditLogScreen extends ConsumerWidget {
  const AuditLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(filteredAuditLogsProvider);
    final records = ref.watch(auditLogsProvider).valueOrNull ?? const [];
    final users = records.map((record) => record.userId).toSet().toList()
      ..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit log'),
        actions: [
          IconButton(
            tooltip: 'Refresh audit log',
            onPressed: () => ref.invalidate(auditLogsProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search audit log',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: (value) =>
                      ref.read(auditLogSearchProvider.notifier).state = value,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: ref.watch(auditLogModuleFilterProvider),
                        decoration: const InputDecoration(labelText: 'Module'),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All')),
                          DropdownMenuItem(
                            value: 'inspections',
                            child: Text('Inspections'),
                          ),
                          DropdownMenuItem(
                            value: 'inventory',
                            child: Text('Inventory'),
                          ),
                          DropdownMenuItem(
                            value: 'deliveries',
                            child: Text('Deliveries'),
                          ),
                          DropdownMenuItem(
                            value: 'profiles',
                            child: Text('Profiles'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            ref
                                .read(auditLogModuleFilterProvider.notifier)
                                .state = value;
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: ref.watch(auditLogUserFilterProvider),
                        decoration: const InputDecoration(labelText: 'User'),
                        items: [
                          const DropdownMenuItem(
                            value: 'all',
                            child: Text('All users'),
                          ),
                          for (final user in users)
                            DropdownMenuItem(
                              value: user,
                              child: Text(
                                user,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            ref
                                .read(auditLogUserFilterProvider.notifier)
                                .state = value;
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: logs.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Unable to load audit log: $error'),
                    TextButton(
                      onPressed: () => ref.invalidate(auditLogsProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (items) => items.isEmpty
                  ? const Center(child: Text('No matching audit records.'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) =>
                          _AuditLogTile(items[index]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuditLogTile extends StatelessWidget {
  const _AuditLogTile(this.record);

  final AuditLogRecord record;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text('${record.actionType} · ${record.recordId}'),
        subtitle: Text(
          '${record.module} · ${record.userId}\n'
          '${record.createdAt.toLocal()}',
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(record.actionType),
            content: SingleChildScrollView(
              child: SelectableText(
                'Module: ${record.module}\n'
                'Record: ${record.recordId}\n'
                'User: ${record.userId}\n'
                'Previous state: ${record.previousState ?? 'None'}\n'
                'New state: ${record.newState}',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      );
}
