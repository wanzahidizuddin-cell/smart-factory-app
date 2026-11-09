import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_factory_qc/core/theme/app_colors.dart';
import 'package:smart_factory_qc/core/theme/app_theme.dart';
import 'package:smart_factory_qc/core/widgets/responsive_content.dart';
import 'package:smart_factory_qc/core/widgets/section_label.dart';
import 'package:smart_factory_qc/domain/models/activity_entry.dart';
import 'package:smart_factory_qc/domain/models/audit_event.dart';
import 'package:smart_factory_qc/domain/models/batch_status.dart';
import 'package:smart_factory_qc/domain/models/inspection_record.dart';
import 'package:smart_factory_qc/features/shared/providers/app_state.dart';
import 'package:smart_factory_qc/features/shared/widgets/app_bottom_nav_bar.dart';

class ProductionInspectionScreen extends ConsumerStatefulWidget {
  const ProductionInspectionScreen({super.key});

  @override
  ConsumerState<ProductionInspectionScreen> createState() =>
      _ProductionInspectionScreenState();
}

class _ProductionInspectionScreenState
    extends ConsumerState<ProductionInspectionScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    ref.read(inspectionDraftProvider.notifier).reset();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(inspectionDraftProvider);
    final controller = ref.read(inspectionDraftProvider.notifier);

    return PopScope<void>(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) ref.read(inspectionDraftProvider.notifier).reset();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Back',
            onPressed: () {
              final navigator = Navigator.of(context);
              if (navigator.canPop()) {
                navigator.pop();
              } else {
                controller.reset();
                ref.read(activeTabProvider.notifier).select(AppTab.home);
              }
            },
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Production inspection'),
              SizedBox(height: 2),
              Text(
                'SAMPLE CHECK • 18 OCT 2026, 09:18',
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
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.s16),
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final serialField = TextFormField(
                      initialValue: draft.serialNumber,
                      onChanged: controller.setSerialNumber,
                      style: AppTextStyles.mono.copyWith(fontSize: 12),
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 10),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Required'
                              : null,
                    );
                    final batchField = TextFormField(
                      initialValue: draft.batchNumber,
                      onChanged: controller.setBatchNumber,
                      style: AppTextStyles.mono.copyWith(fontSize: 12),
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 10),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Required'
                              : null,
                    );
                    if (constraints.maxWidth < 480) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionLabel('Serial number'),
                          const SizedBox(height: 4),
                          serialField,
                          const SizedBox(height: 8),
                          const SectionLabel('Batch'),
                          const SizedBox(height: 4),
                          batchField,
                        ],
                      );
                    }
                    return Column(
                      children: [
                        const Row(
                          children: [
                            Expanded(child: SectionLabel('Serial number')),
                            SizedBox(width: 8),
                            Expanded(child: SectionLabel('Batch')),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(child: serialField),
                            const SizedBox(width: 8),
                            Expanded(child: batchField),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                const SectionLabel('Machine'),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: draft.machine,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'M-04 · Injection press',
                      child: Text('M-04 · Injection press'),
                    ),
                    DropdownMenuItem(
                      value: 'M-02 · CNC mill',
                      child: Text('M-02 · CNC mill'),
                    ),
                    DropdownMenuItem(
                      value: 'M-07 · Assembly line',
                      child: Text('M-07 · Assembly line'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) controller.setMachine(value);
                  },
                ),
                const SizedBox(height: 8),
                const SectionLabel('Result'),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: _ResultChoice(
                        label: 'Pass',
                        selected: draft.result == BatchStatus.passed,
                        color: AppColors.passed,
                        onTap: () => controller.setResult(BatchStatus.passed),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ResultChoice(
                        label: 'Fail',
                        selected: draft.result == BatchStatus.failed,
                        color: AppColors.failed,
                        onTap: () => controller.setResult(BatchStatus.failed),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const SectionLabel('Defect category'),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: draft.defectCategory,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Scratch', child: Text('Scratch')),
                    DropdownMenuItem(value: 'Crack', child: Text('Crack')),
                    DropdownMenuItem(
                      value: 'Misalignment',
                      child: Text('Misalignment'),
                    ),
                    DropdownMenuItem(value: 'Burr', child: Text('Burr')),
                  ],
                  onChanged: (value) {
                    if (value != null) controller.setDefectCategory(value);
                  },
                ),
                const SizedBox(height: 4),
                Text(
                  'Categories: Scratch · Crack · Misalignment · Burr',
                  style: AppTextStyles.caption.copyWith(fontSize: 10),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: controller.attachPhoto,
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: Text(
                    draft.photoCount == 0
                        ? 'Add photo from camera'
                        : '${draft.photoCount} photo${draft.photoCount == 1 ? '' : 's'} attached',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  draft.photoCount == 0
                      ? 'No photos attached • Capture defect close-up'
                      : 'Photo attached to this inspection record',
                  style: AppTextStyles.caption.copyWith(fontSize: 10),
                ),
                const SizedBox(height: 8),
                const SectionLabel('Inspection notes'),
                const SizedBox(height: 4),
                TextFormField(
                  initialValue: draft.notes,
                  minLines: 2,
                  maxLines: 3,
                  onChanged: controller.setNotes,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.all(10),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter inspection notes'
                      : null,
                ),
                const SizedBox(height: 8),
                Text(
                  'Inspector: Asha Patel • ${draft.result?.label ?? "Result required"} record',
                  style: AppTextStyles.caption.copyWith(fontSize: 10),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 44,
                  child: FilledButton.icon(
                    onPressed: _isSubmitting ? null : _signOff,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.edit_outlined),
                    label: Text(_isSubmitting ? 'Submitting...' : 'Sign off'),
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: AppBottomNavBar(
          selectedIndex: AppTab.home.index,
          onTap: (index) => returnToTab(context, ref, AppTab.values[index]),
        ),
      ),
    );
  }

  Future<void> _signOff() async {
    final draft = ref.read(inspectionDraftProvider);
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid || draft.result == null) {
      if (draft.result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Select Pass or Fail before signing off.')),
        );
      }
      return;
    }

    setState(() => _isSubmitting = true);
    final recordedAt = '09:18';
    final record = InspectionRecord(
      serialNumber: draft.serialNumber.trim(),
      batchNumber: draft.batchNumber.trim(),
      machine: draft.machine,
      result: draft.result!,
      defectCategory: draft.defectCategory,
      notes: draft.notes.trim(),
      photoCount: draft.photoCount,
      inspector: 'Asha Patel',
      recordedAt: recordedAt,
    );
    try {
      await ref.read(inspectionSubmitterProvider)(record);
      if (!mounted) return;

      ref.read(inspectionRecordsProvider.notifier).add(record);
      ref.invalidate(recentActivityProvider);
      ref.read(auditTrailProvider.notifier).add(
            AuditEvent(
              recordId: record.serialNumber,
              time: recordedAt,
              title: 'Sample inspection signed',
              description:
                  '${record.inspector} · ${record.serialNumber} / ${record.machine.split(" · ").first}\n'
                  '${record.result.label}: ${record.defectCategory}, ${record.notes}',
              icon: record.result == BatchStatus.passed
                  ? Icons.check_circle_outline
                  : Icons.cancel_outlined,
              status: record.result,
            ),
          );
      ref.read(activityProvider.notifier).add(
            ActivityEntry(
              title:
                  '${record.serialNumber} ${record.result.label.toLowerCase()}',
              reference:
                  '${record.machine.split(" · ").first} • ${record.inspector} • ${record.recordedAt}',
              status: record.result,
              minutesAgo: 0,
            ),
          );

      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Inspection signed off successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not submit inspection: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

class _ResultChoice extends StatelessWidget {
  const _ResultChoice({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor:
            selected ? color.withValues(alpha: 0.14) : AppColors.white,
        foregroundColor: selected ? color : AppColors.slate600,
        side: BorderSide(color: selected ? color : AppColors.slate300),
      ),
      icon: Icon(
        selected
            ? (label == 'Pass' ? Icons.check_circle : Icons.cancel)
            : Icons.radio_button_unchecked,
        size: 16,
      ),
      label: Text(label),
    );
  }
}
