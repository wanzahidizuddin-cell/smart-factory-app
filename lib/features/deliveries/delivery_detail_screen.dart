import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_factory_qc/core/theme/app_colors.dart';
import 'package:smart_factory_qc/core/theme/app_theme.dart';
import 'package:smart_factory_qc/core/utils/format.dart';
import 'package:smart_factory_qc/core/widgets/responsive_content.dart';
import 'package:smart_factory_qc/core/widgets/section_label.dart';
import 'package:smart_factory_qc/core/widgets/status_badge.dart';
import 'package:smart_factory_qc/domain/models/audit_event.dart';
import 'package:smart_factory_qc/domain/models/batch_status.dart';
import 'package:smart_factory_qc/domain/models/delivery.dart';
import 'package:smart_factory_qc/features/inspections/production_inspection_screen.dart';
import 'package:smart_factory_qc/features/shared/providers/app_state.dart';
import 'package:smart_factory_qc/features/shared/widgets/app_bottom_nav_bar.dart';
import 'package:smart_factory_qc/features/trace/trace_search_screen.dart';
import 'package:smart_factory_qc/features/deliveries/batch_released_screen.dart';

class DeliveryDetailScreen extends ConsumerStatefulWidget {
  const DeliveryDetailScreen({super.key, required this.batchNumber});

  final String batchNumber;

  @override
  ConsumerState<DeliveryDetailScreen> createState() =>
      _DeliveryDetailScreenState();
}

class _DeliveryDetailScreenState extends ConsumerState<DeliveryDetailScreen> {
  late final TextEditingController _releaseNoteController;

  @override
  void initState() {
    super.initState();
    _releaseNoteController = TextEditingController(
      text: ref.read(releaseNoteDraftProvider),
    );
  }

  @override
  void dispose() {
    _releaseNoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final delivery = ref
        .watch(deliveryStateProvider)
        .where((record) => record.batchNumber == widget.batchNumber)
        .firstOrNull;

    if (delivery == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Delivery detail')),
        body: const Center(child: Text('Delivery record not found.')),
        bottomNavigationBar: AppBottomNavBar(
          selectedIndex: AppTab.deliveries.index,
          onTap: (index) => returnToTab(context, ref, AppTab.values[index]),
        ),
      );
    }

    final isQuarantined = delivery.status == BatchStatus.quarantined;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Delivery detail'),
            SizedBox(height: 2),
            Text(
              'RECEIVING CHECK • 18 OCT 2026',
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
        maxWidth: 1080,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
          Row(
            children: [
              Expanded(
                child: Text(delivery.batchNumber, style: AppTextStyles.title),
              ),
              StatusBadge(delivery.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${delivery.supplier} • ${delivery.materialCode} / ${delivery.material}',
            style: AppTextStyles.bodyStrong.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            '${formatQty(delivery.quantity)} ${delivery.unit} · '
            '${delivery.packaging} · Received ${delivery.receivedAt}',
            style: AppTextStyles.caption.copyWith(fontSize: 11),
          ),
          const SizedBox(height: 8),
          const SectionLabel('Sample results · A. Patel · 09:22'),
          const SizedBox(height: 8),
          const _TestResultCard(
            label: 'Bag weight',
            limit: 'Limit: 4.9–5.1 kg',
            result: '5.0 kg',
            passed: true,
          ),
          const SizedBox(height: 8),
          const _TestResultCard(
            label: 'Dimension',
            limit: 'Limit: 99.5–100.5 mm',
            result: '100.1 mm',
            passed: true,
          ),
          const SizedBox(height: 8),
          const _TestResultCard(
            label: 'Moisture',
            limit: 'Limit: ≤ 8.0%',
            result: '8.7%',
            passed: false,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.quarantinedSoft,
              borderRadius: BorderRadius.circular(AppSpacing.radius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hold reason: ${delivery.holdReason.isEmpty ? "moisture exceeds limit by 0.7 pp" : delivery.holdReason}',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.quarantinedText,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Quarantined 09:24. Release requires an exception.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    color: AppColors.quarantinedText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const SectionLabel('Release note • required'),
          const SizedBox(height: 4),
          TextField(
            controller: _releaseNoteController,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Enter authorisation and exception details',
              contentPadding: EdgeInsets.all(12),
            ),
            onChanged: (value) =>
                ref.read(releaseNoteDraftProvider.notifier).state = value,
          ),
          const SizedBox(height: 4),
          Text(
            'Authorised by Maya Chen, QA lead · 09:36',
            style: AppTextStyles.caption.copyWith(fontSize: 10),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: FilledButton(
              onPressed: !isQuarantined ? null : () => _releaseBatch(delivery),
              child: const Text('Release batch'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: OutlinedButton(
              onPressed: !isQuarantined
                  ? null
                  : () {
                      ref
                          .read(deliveryStateProvider.notifier)
                          .keepQuarantined(delivery.batchNumber);
                      Navigator.of(context).pop();
                    },
              child: const Text('Keep quarantined'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ProductionInspectionScreen(),
              ),
            ),
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('Start production inspection'),
          ),
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    TraceSearchScreen(initialQuery: delivery.batchNumber),
              ),
            ),
            icon: const Icon(Icons.timeline_rounded),
            label: const Text('View batch trace'),
          ),
        ],
      ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        selectedIndex: AppTab.deliveries.index,
        onTap: (index) => returnToTab(context, ref, AppTab.values[index]),
      ),
    );
  }

  void _releaseBatch(Delivery delivery) {
    final note = ref.read(releaseNoteDraftProvider).trim();
    if (note.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a release note before releasing.')),
      );
      return;
    }
    ref.read(deliveryStateProvider.notifier).release(
          delivery.batchNumber,
          note: note,
          authorisedBy: 'Maya Chen, QA lead',
          authorisedAt: '09:36',
        );
    ref.read(auditTrailProvider.notifier).add(
          AuditEvent(
            recordId: delivery.batchNumber,
            time: '09:41',
            title: 'Released by authorised exception',
            description: note,
            icon: Icons.lock_open_rounded,
            status: BatchStatus.released,
          ),
        );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BatchReleasedScreen(batchNumber: delivery.batchNumber),
      ),
    );
  }
}

class _TestResultCard extends StatelessWidget {
  const _TestResultCard({
    required this.label,
    required this.limit,
    required this.result,
    required this.passed,
  });

  final String label;
  final String limit;
  final String result;
  final bool passed;

  @override
  Widget build(BuildContext context) {
    final color = passed ? AppColors.passed : AppColors.failed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(
          color: passed ? AppColors.slate200 : AppColors.failed,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radius),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTextStyles.bodyStrong.copyWith(fontSize: 11)),
                Text(limit, style: AppTextStyles.caption.copyWith(fontSize: 9)),
              ],
            ),
          ),
          Text(
            result,
            style:
                AppTextStyles.bodyStrong.copyWith(color: color, fontSize: 16),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              Icon(
                passed ? Icons.check_circle_outline : Icons.cancel_outlined,
                color: color,
                size: 18,
              ),
              Text(
                passed ? 'PASS' : 'FAIL',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
