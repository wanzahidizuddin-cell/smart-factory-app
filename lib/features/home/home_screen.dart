import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_factory_qc/app/sync_status.dart';
import 'package:smart_factory_qc/core/theme/app_colors.dart';
import 'package:smart_factory_qc/core/theme/app_theme.dart';
import 'package:smart_factory_qc/core/utils/format.dart';
import 'package:smart_factory_qc/core/widgets/responsive_content.dart';
import 'package:smart_factory_qc/core/widgets/section_label.dart';
import 'package:smart_factory_qc/core/widgets/status_badge.dart';
import 'package:smart_factory_qc/data/dummy_data.dart';
import 'package:smart_factory_qc/domain/models/activity_entry.dart';
import 'package:smart_factory_qc/features/inspections/production_inspection_screen.dart';
import 'package:smart_factory_qc/features/shared/providers/app_state.dart';
import 'package:smart_factory_qc/core/widgets/offline_banner.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardStatsProvider);
    final inspections = ref.watch(inspectionsProvider);
    final localActivity = ref.watch(activityProvider);
    final sync = ref.watch(syncStatusProvider);
    final lastSync = ref.watch(lastSyncProvider);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Home'),
            SizedBox(height: 2),
            Text(
              'NORTHWORKS • ASSEMBLY PLANT 01',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.3,
                color: AppColors.slate300,
              ),
            ),
          ],
        ),
      ),
      body: ResponsiveContent(
        maxWidth: 1120,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.s16),
          children: [
            if (sync.isOffline || sync.isSyncing) ...[
              OfflineBanner(
                pendingRecords: sync.pendingRecords,
                isSyncing: sync.isSyncing,
                onTap: () => ref.read(syncStatusProvider.notifier).sync(),
              ),
              const SizedBox(height: AppSpacing.s12),
            ],
            if (sync.errorMessage != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Sync issue: ${sync.errorMessage}',
                      style: const TextStyle(color: AppColors.failed),
                    ),
                  ),
                  TextButton(
                    onPressed: sync.isSyncing
                        ? null
                        : () => ref.read(syncStatusProvider.notifier).sync(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s8),
            ],
            Text('Good morning', style: AppTextStyles.title),
            const SizedBox(height: AppSpacing.s4),
            Text(
              'Sun, 18 Oct 2026 • Shift A • 06:00–14:00',
              style: AppTextStyles.caption.copyWith(fontSize: 12),
            ),
            const SizedBox(height: AppSpacing.s12),
            stats.when(
              data: (dashboardStats) => IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _SummaryTile(
                        label: 'Deliveries to review',
                        value: dashboardStats.pendingDeliveries,
                        color: AppColors.slate900,
                        onTap: () {
                          ref
                              .read(deliveryFilterProvider.notifier)
                              .showNeedsReview();
                          ref
                              .read(activeTabProvider.notifier)
                              .select(AppTab.deliveries);
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(
                      child: _SummaryTile(
                        label: 'Quarantined batches',
                        value: dashboardStats.quarantinedDeliveries,
                        color: AppColors.quarantinedText,
                        onTap: () {
                          ref
                              .read(deliveryFilterProvider.notifier)
                              .showQuarantined();
                          ref
                              .read(activeTabProvider.notifier)
                              .select(AppTab.deliveries);
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(
                      child: _SummaryTile(
                        label: 'Low-stock items',
                        value: dashboardStats.lowStockItems,
                        color: AppColors.slate900,
                        onTap: () {
                          ref
                              .read(inventoryFilterProvider.notifier)
                              .showLowStock();
                          ref
                              .read(activeTabProvider.notifier)
                              .select(AppTab.inventory);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.s24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stackTrace) => Card(
                child: ListTile(
                  title: const Text('Unable to load dashboard stats.'),
                  trailing: IconButton(
                    tooltip: 'Retry',
                    onPressed: () =>
                        ref.read(dashboardStatsProvider.notifier).refresh(),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            const SectionLabel('Quick actions'),
            const SizedBox(height: AppSpacing.s8),
            SizedBox(
              height: 44,
              child: OutlinedButton.icon(
                onPressed: () => _showNewInspection(context),
                icon: const Icon(Icons.assignment_add, size: 20),
                label: const Text('New inspection'),
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            const SectionLabel('Recent activity'),
            const SizedBox(height: AppSpacing.s8),
            inspections.when(
              data: (records) {
                final recentActivity = records.map((record) {
                  final recordedAt =
                      DateTime.parse(record.recordedAt).toLocal();
                  return ActivityEntry(
                    title:
                        '${record.serialNumber} ${record.result.label.toLowerCase()}',
                    reference:
                        '${record.machine} • ${record.inspector} • ${TimeOfDay.fromDateTime(recordedAt).format(context)}',
                    status: record.result,
                    minutesAgo: DateTime.now()
                        .difference(recordedAt)
                        .inMinutes
                        .clamp(0, 1 << 31)
                        .toInt(),
                  );
                }).toList(growable: false);
                final localTitles =
                    localActivity.map((entry) => entry.title).toSet();
                final entries = [
                  ...localActivity,
                  ...recentActivity
                      .where((entry) => !localTitles.contains(entry.title)),
                ].take(5).toList(growable: false);
                if (entries.isEmpty) {
                  return const Text(
                    'No recent inspections.',
                    style: AppTextStyles.caption,
                  );
                }
                return Column(
                  children: [
                    for (var index = 0; index < entries.length; index++) ...[
                      if (index > 0) const SizedBox(height: AppSpacing.s8),
                      _ActivityCard(
                        entry: entries[index],
                        onTap: () =>
                            _showActivityDetails(context, entries[index]),
                      ),
                    ],
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.s16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stackTrace) => Card(
                child: ListTile(
                  title: const Text('Unable to load recent inspections.'),
                  trailing: IconButton(
                    tooltip: 'Retry',
                    onPressed: () => ref.invalidate(inspectionsProvider),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
            Text(
              lastSync == null
                  ? 'Not synced yet'
                  : 'Last synced ${TimeOfDay.fromDateTime(lastSync.toLocal()).format(context)}',
              style: AppTextStyles.caption.copyWith(fontSize: 11),
            ),
            const SizedBox(height: AppSpacing.s8),
          ],
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  final String label;
  final int value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value.toString().padLeft(2, '0'),
                style: AppTextStyles.bigNumber.copyWith(
                  fontSize: 26,
                  color: color,
                ),
              ),
              const SizedBox(height: AppSpacing.s8),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.slate700,
                  fontSize: 10,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.entry, required this.onTap});

  final ActivityEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s12,
            vertical: AppSpacing.s8,
          ),
          child: Row(
            children: [
              Icon(
                statusIcon(entry.status),
                color: statusForeground(entry.status),
                size: 20,
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: AppTextStyles.bodyStrong.copyWith(fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      entry.reference,
                      style: AppTextStyles.caption.copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _showActivityDetails(BuildContext context, ActivityEntry entry) {
  final delivery = DummyData.deliveries
      .where((item) => entry.title.contains(item.batchNumber))
      .firstOrNull;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppSpacing.radius)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(entry.title,
                      style: AppTextStyles.title.copyWith(fontSize: 20)),
                ),
                StatusBadge(entry.status),
              ],
            ),
            const SizedBox(height: AppSpacing.s16),
            Text(entry.reference, style: AppTextStyles.body),
            if (delivery != null) ...[
              const SizedBox(height: AppSpacing.s12),
              Text(
                '${delivery.supplier} • ${delivery.material} • '
                '${formatQty(delivery.quantity)} ${delivery.unit}',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: AppSpacing.s8),
              Text(delivery.inspectionNotes, style: AppTextStyles.caption),
            ],
            const SizedBox(height: AppSpacing.s16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void _showNewInspection(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => const ProductionInspectionScreen(),
    ),
  );
}
