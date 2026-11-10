import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_factory_qc/core/theme/app_colors.dart';
import 'package:smart_factory_qc/core/theme/app_theme.dart';
import 'package:smart_factory_qc/core/utils/format.dart';
import 'package:smart_factory_qc/core/widgets/section_label.dart';
import 'package:smart_factory_qc/core/widgets/status_badge.dart';
import 'package:smart_factory_qc/domain/models/batch_status.dart';
import 'package:smart_factory_qc/domain/models/delivery.dart';
import 'package:smart_factory_qc/features/deliveries/delivery_detail_screen.dart';
import 'package:smart_factory_qc/features/shared/providers/app_state.dart';
import 'package:smart_factory_qc/features/shared/widgets/async_collection_states.dart';

class DeliveriesScreen extends ConsumerWidget {
  const DeliveriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(deliveryFilterProvider);
    final deliveries = ref.watch(filteredDeliveriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Deliveries'),
            SizedBox(height: 2),
            Text(
              'Incoming materials • Today, 18 Oct',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: AppColors.slate300,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s16,
              AppSpacing.s16,
              AppSpacing.s16,
              AppSpacing.s8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Find delivery'),
                const SizedBox(height: AppSpacing.s8),
                TextField(
                  onChanged: ref.read(deliveryFilterProvider.notifier).setQuery,
                  style: AppTextStyles.body,
                  decoration: const InputDecoration(
                    hintText: 'Search storage batches, SKUs, or suppliers...',
                    suffixIcon:
                        Icon(Icons.search_rounded, color: AppColors.slate500),
                  ),
                ),
                const SizedBox(height: AppSpacing.s8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final option in DeliveryStatusFilter.values) ...[
                        if (option != DeliveryStatusFilter.values.first)
                          const SizedBox(width: AppSpacing.s8),
                        _StatusFilterChip(
                          label: switch (option) {
                            DeliveryStatusFilter.all => 'All',
                            DeliveryStatusFilter.passed => 'Passed',
                            DeliveryStatusFilter.quarantined => 'Quarantined',
                            DeliveryStatusFilter.released => 'Released',
                          },
                          selected: filter.status == option &&
                              !filter.needsReviewOnly,
                          onSelected: () => ref
                              .read(deliveryFilterProvider.notifier)
                              .setStatus(option),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: deliveries.when(
              loading: () =>
                  const CollectionLoadingState(feature: 'deliveries'),
              error: (error, stackTrace) => CollectionErrorState(
                feature: 'deliveries',
                onRetry: () => ref.read(deliveriesProvider.notifier).fetch(),
              ),
              data: (items) {
                if (items.isEmpty) {
                  final noFilters = filter.query.isEmpty &&
                      filter.status == DeliveryStatusFilter.all &&
                      !filter.needsReviewOnly;
                  return CollectionEmptyState(
                    icon: Icons.inbox_outlined,
                    title: noFilters
                        ? 'No incoming HDD/SSD batches today'
                        : 'No matching storage batches',
                    description: noFilters
                        ? 'Incoming hard-drive and SSD batches will appear here when receiving logs a delivery.'
                        : filter.needsReviewOnly
                            ? 'No pending QC batches for HDDs/SSDs.'
                            : 'No storage batches match your search or selected QC status.',
                    actionLabel: 'Refresh',
                    footer: 'Showing all records • Assembly plant 01',
                    onAction: () =>
                        ref.read(deliveriesProvider.notifier).fetch(),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.s16,
                    AppSpacing.s8,
                    AppSpacing.s16,
                    AppSpacing.s16,
                  ),
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.s12),
                  itemBuilder: (context, index) =>
                      _DeliveryCard(delivery: items[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusFilterChip extends StatelessWidget {
  const _StatusFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => onSelected(),
        labelStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: selected ? AppColors.white : AppColors.slate700,
        ),
        backgroundColor: AppColors.white,
        selectedColor: AppColors.navy,
        side: BorderSide(color: selected ? AppColors.navy : AppColors.slate300),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      );
}

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({required this.delivery});

  final Delivery delivery;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                DeliveryDetailScreen(batchNumber: delivery.batchNumber),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.s8),
                    child: Icon(
                      delivery.status == BatchStatus.quarantined
                          ? Icons.thermostat
                          : delivery.material.toLowerCase().contains('nvme')
                              ? Icons.memory
                              : Icons.storage,
                      color: delivery.status == BatchStatus.quarantined
                          ? AppColors.failed
                          : AppColors.accent,
                      size: 20,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      delivery.batchNumber,
                      style: AppTextStyles.mono.copyWith(
                        color: AppColors.slate900,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  StatusBadge(delivery.status),
                ],
              ),
              const SizedBox(height: AppSpacing.s8),
              Text(delivery.supplier,
                  style: AppTextStyles.bodyStrong.copyWith(fontSize: 14)),
              const SizedBox(height: AppSpacing.s8),
              Text(
                '${delivery.materialCode} • ${delivery.material}',
                style:
                    AppTextStyles.caption.copyWith(color: AppColors.slate600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.s4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${formatQty(delivery.quantity)} ${delivery.unit} · '
                      '${delivery.packaging} · ${delivery.receivedAt}',
                      style: AppTextStyles.caption.copyWith(fontSize: 12),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.slate500),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
