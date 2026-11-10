import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_factory_qc/data/repositories/qc_repository.dart';
import 'package:smart_factory_qc/domain/models/batch_status.dart';
import 'package:smart_factory_qc/domain/models/inspection_record.dart';
import 'package:smart_factory_qc/data/repositories/trace_repository.dart';
import 'package:smart_factory_qc/features/deliveries/batch_released_screen.dart';
import 'package:smart_factory_qc/features/deliveries/delivery_detail_screen.dart';
import 'package:smart_factory_qc/features/inspections/production_inspection_screen.dart';
import 'package:smart_factory_qc/features/shared/providers/app_state.dart';
import 'package:smart_factory_qc/features/trace/trace_search_screen.dart';

void main() {
  testWidgets(
      'releasing a quarantined delivery opens confirmation and updates state',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        inspectionSubmitterProvider.overrideWithValue((_) async {}),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: DeliveryDetailScreen(batchNumber: 'B-1007'),
        ),
      ),
    );

    await tester.drag(find.byType(ListView), const Offset(0, -320));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Release batch'));
    await tester.pumpAndSettle();

    expect(find.byType(BatchReleasedScreen), findsOneWidget);
    expect(find.text('Released by exception'), findsOneWidget);
    expect(
      container
          .read(deliveryStateProvider)
          .firstWhere((record) => record.batchNumber == 'B-1007')
          .status,
      BatchStatus.released,
    );
  });

  testWidgets('inspection form attaches a photo and signs off', (tester) async {
    final submittedRecords = <InspectionRecord>[];
    final container = ProviderContainer(
      overrides: [
        inspectionSubmitterProvider.overrideWithValue(
          (record) async => submittedRecords.add(record),
        ),
        qcRepositoryProvider.overrideWithValue(
          _FakeQcRepository(() => submittedRecords),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ProductionInspectionScreen(),
                    ),
                  ),
                  child: const Text('Open inspection'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open inspection'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add photo from camera'));
    await tester.tap(find.text('Add photo from camera'));
    await tester.pump();
    expect(find.text('1 photo attached'), findsOneWidget);

    await tester.ensureVisible(find.text('Sign off'));
    await tester.tap(find.text('Sign off'));
    await tester.pumpAndSettle();
    expect(
      await container.read(inspectionRecordsProvider.future),
      hasLength(1),
    );
    expect(
      find.text('Inspection signed off successfully.'),
      findsOneWidget,
    );
  });

  testWidgets('inspection submission errors are shown without recording',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        inspectionSubmitterProvider.overrideWithValue(
          (_) => Future<void>.error(StateError('submission failed')),
        ),
        qcRepositoryProvider.overrideWithValue(
          _FakeQcRepository(() => const []),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ProductionInspectionScreen(),
                    ),
                  ),
                  child: const Text('Open inspection'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open inspection'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add photo from camera'));
    await tester.tap(find.text('Add photo from camera'));
    await tester.pump();
    await tester.ensureVisible(find.text('Sign off'));
    await tester.tap(find.text('Sign off'));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not submit inspection: Bad state: submission failed'),
      findsOneWidget,
    );
    expect(
      await container.read(inspectionRecordsProvider.future),
      isEmpty,
    );
  });

  testWidgets('trace screen searches and displays matching records',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        traceRepositoryProvider.overrideWithValue(_FakeTraceRepository()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: TraceSearchScreen()),
      ),
    );

    await tester.pumpAndSettle();
    expect(
      find.text('Search storage drive SKUs, batches, or suppliers.'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byType(TextField),
      'resin',
    );
    await tester.pumpAndSettle();
    expect(find.text('Industrial resin'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(Chip),
        matching: find.text('Inventory'),
      ),
      findsOneWidget,
    );
  });
}

class _FakeQcRepository implements QcRepository {
  _FakeQcRepository(this.records);

  final List<InspectionRecord> Function() records;

  @override
  Future<List<InspectionRecord>> fetchInspections() async => records();
}

class _FakeTraceRepository extends TraceRepository {
  @override
  Future<List<Map<String, dynamic>>> searchTraceHistory(String query) async {
    if (query.toLowerCase() == 'resin') {
      return [
        {
          'id': 'inventory-1',
          'type': 'Inventory',
          'name': 'Industrial resin',
          'sku': 'RM-204',
          'rack_location': 'Rack B-02',
          'current_quantity': 12,
          'unit': 'kg',
        },
      ];
    }
    return const [];
  }
}
