import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_factory_qc/core/theme/app_colors.dart';
import 'package:smart_factory_qc/core/theme/app_theme.dart';
import 'package:smart_factory_qc/core/widgets/responsive_content.dart';
import 'package:smart_factory_qc/core/utils/format.dart';
import 'package:smart_factory_qc/core/widgets/status_badge.dart';
import 'package:smart_factory_qc/domain/models/batch_status.dart';
import 'package:smart_factory_qc/domain/models/delivery.dart';
import 'package:smart_factory_qc/features/shared/providers/app_state.dart';
import 'package:smart_factory_qc/features/shared/widgets/app_bottom_nav_bar.dart';
import 'package:smart_factory_qc/features/trace/trace_search_screen.dart';

class BatchReleasedScreen extends ConsumerWidget {
  const BatchReleasedScreen({super.key, required this.batchNumber});

  final String batchNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final delivery = ref
        .watch(deliveryStateProvider)
        .where((record) => record.batchNumber == batchNumber)
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Batch released'),
            SizedBox(height: 2),
            Text(
              'DISPOSITION RECORDED • 18 OCT 2026',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                fontWeight: FontWeight.w400,
                color: AppColors.slate300,
              ),
            ),
          ],
        ),
      ),
      body: ResponsiveContent(
        maxWidth: 960,
        child: delivery == null
            ? const Center(child: Text('Delivery record not found.'))
            : _ConfirmationContent(
                delivery: delivery,
                onViewTrace: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => TraceSearchScreen(initialQuery: batchNumber),
                  ),
                ),
                onBackHome: () => returnToTab(context, ref, AppTab.home),
              ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        selectedIndex: AppTab.deliveries.index,
        onTap: (index) => returnToTab(context, ref, AppTab.values[index]),
      ),
    );
  }
}

class _ConfirmationContent extends StatelessWidget {
  const _ConfirmationContent({
    required this.delivery,
    required this.onViewTrace,
    required this.onBackHome,
  });

  final Delivery delivery;
  final VoidCallback onViewTrace;
  final VoidCallback onBackHome;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.s16),
      children: [
        const SizedBox(height: AppSpacing.s8),
        Center(
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(AppSpacing.radius),
            ),
            child: const Icon(
              Icons.lock_open_rounded,
              color: AppColors.accent,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        Text(
          'Released by exception',
          textAlign: TextAlign.center,
          style: AppTextStyles.title.copyWith(fontSize: 20),
        ),
        const SizedBox(height: AppSpacing.s8),
        Text(
          'Batch ${delivery.batchNumber} is released for controlled '
          'dry-and-retest, not unrestricted use.',
          textAlign: TextAlign.center,
          style: AppTextStyles.caption.copyWith(height: 1.4),
        ),
        const SizedBox(height: AppSpacing.s16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
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
                    const StatusBadge(BatchStatus.released),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${delivery.supplier} • ${delivery.materialCode} / ${delivery.material}',
                  style: AppTextStyles.caption.copyWith(fontSize: 11),
                ),
                Text(
                  '${formatQty(delivery.quantity)} ${delivery.unit} · ${delivery.packaging}',
                  style: AppTextStyles.caption.copyWith(fontSize: 11),
                ),
                const SizedBox(height: 8),
                const Text(
                  'AUTHORISED EXCEPTION · EX-042',
                  style: AppTextStyles.label,
                ),
                const SizedBox(height: 8),
                Text(
                  'Approved: ${delivery.authorisedBy.isEmpty ? "Maya Chen, QA lead" : delivery.authorisedBy} · 09:36\n'
                  'Recorded: Asha Patel · 09:41',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.slate900,
                    height: 1.5,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        Container(
          padding: const EdgeInsets.all(AppSpacing.s12),
          decoration: BoxDecoration(
            color: AppColors.quarantinedSoft,
            borderRadius: BorderRadius.circular(AppSpacing.radius),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Moisture failure remains on record',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.quarantinedText,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '8.7% measured • Limit ≤ 8.0% • Not passed',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  color: AppColors.quarantinedText,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        const Text('RECORDED RELEASE NOTE', style: AppTextStyles.label),
        const SizedBox(height: AppSpacing.s4),
        Text(
          '“${delivery.releaseNote.isEmpty ? "M. Chen approved dry-and-retest under EX-042." : delivery.releaseNote}”',
          style: AppTextStyles.body.copyWith(fontSize: 12),
        ),
        const SizedBox(height: AppSpacing.s16),
        SizedBox(
          height: 44,
          child: FilledButton.icon(
            onPressed: onViewTrace,
            icon: const Icon(Icons.timeline_rounded),
            label: const Text('View batch trace'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 44,
          child: OutlinedButton(
            onPressed: onBackHome,
            child: const Text('Back to Home'),
          ),
        ),
      ],
    );
  }
}
