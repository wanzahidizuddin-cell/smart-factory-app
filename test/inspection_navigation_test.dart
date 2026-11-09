import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_factory_qc/features/inspections/production_inspection_screen.dart';
import 'package:smart_factory_qc/features/shared/providers/app_state.dart';

void main() {
  testWidgets('popping inspection resets its form draft', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ProductionInspectionScreen(),
                  ),
                ),
                child: const Text('Start inspection'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Start inspection'));
    await tester.pumpAndSettle();
    container
        .read(inspectionDraftProvider.notifier)
        .setNotes('Draft to discard');

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(
      container.read(inspectionDraftProvider).notes,
      'Surface scratch, 12 mm, near gate. Sample held for review.',
    );
  });

  testWidgets('back button is safe when inspection has no route to pop',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ProductionInspectionScreen()),
      ),
    );

    await tester.tap(find.byTooltip('Back'));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
