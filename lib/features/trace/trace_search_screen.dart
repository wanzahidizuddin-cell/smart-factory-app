import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_factory_qc/core/theme/app_colors.dart';
import 'package:smart_factory_qc/core/theme/app_theme.dart';
import 'package:smart_factory_qc/core/widgets/responsive_content.dart';
import 'package:smart_factory_qc/core/widgets/section_label.dart';
import 'package:smart_factory_qc/features/shared/providers/app_state.dart';
import 'package:smart_factory_qc/features/shared/widgets/app_bottom_nav_bar.dart';

class TraceSearchScreen extends ConsumerStatefulWidget {
  const TraceSearchScreen({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  ConsumerState<TraceSearchScreen> createState() => _TraceSearchScreenState();
}

class _TraceSearchScreenState extends ConsumerState<TraceSearchScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    final query = widget.initialQuery ?? '';
    _searchController = TextEditingController(text: query);
    ref.read(traceQueryProvider.notifier).state = query;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(traceQueryProvider);
    final results = ref.watch(traceSearchProvider(query));

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
            Text('Trace a record'),
            SizedBox(height: 2),
            Text(
              'DELIVERIES & INVENTORY',
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
          padding: const EdgeInsets.all(AppSpacing.s16),
          children: [
            const SectionLabel('Search deliveries and inventory'),
            const SizedBox(height: AppSpacing.s8),
            TextField(
              controller: _searchController,
              onChanged: (value) =>
                  ref.read(traceQueryProvider.notifier).state = value,
              style: AppTextStyles.body.copyWith(fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Batch, supplier, item or SKU',
                suffixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            results.when(
              data: (items) {
                if (items.isEmpty) {
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.s24),
                    child: Center(
                      child: Text(
                        query.trim().isEmpty
                            ? 'Enter a search term to find records.'
                            : 'No matching records found.',
                        style: AppTextStyles.caption,
                      ),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (var index = 0; index < items.length; index++) ...[
                      if (index > 0) const SizedBox(height: AppSpacing.s8),
                      _TraceResultCard(result: items[index]),
                    ],
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.s24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stackTrace) => Card(
                child: ListTile(
                  leading: const Icon(Icons.error_outline_rounded),
                  title: const Text('Unable to search trace history.'),
                  subtitle: Text(error.toString()),
                  trailing: IconButton(
                    tooltip: 'Retry',
                    onPressed: () => ref.invalidate(traceSearchProvider(query)),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ),
              ),
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
}

class _TraceResultCard extends StatelessWidget {
  const _TraceResultCard({required this.result});

  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final type = result['type'] as String;
    final isDelivery = type == 'Delivery';
    final title = isDelivery
        ? (result['batch_number'] as String? ?? 'Delivery')
        : (result['name'] as String? ?? 'Inventory item');
    final details = isDelivery
        ? [
            result['supplier'],
            result['material'],
            result['material_code'],
            result['status'],
          ]
        : [
            'SKU ${result['sku']}',
            result['rack_location'],
            if (result['current_quantity'] != null)
              '${result['current_quantity']} ${result['unit'] ?? ''} in stock',
          ];
    final subtitle =
        details.whereType<String>().where((value) => value.isNotEmpty).join(' · ');

    return Card(
      child: ListTile(
        leading: Icon(
          isDelivery
              ? Icons.local_shipping_outlined
              : Icons.inventory_2_outlined,
          color: AppColors.accent,
        ),
        title: Text(title, style: AppTextStyles.bodyStrong),
        subtitle: Text(subtitle, style: AppTextStyles.caption),
        trailing: Chip(
          label: Text(type),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}
