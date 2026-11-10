import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_factory_qc/domain/models/delivery.dart';
import 'package:smart_factory_qc/domain/models/inventory.dart';
import 'package:smart_factory_qc/features/deliveries/deliveries_screen.dart';
import 'package:smart_factory_qc/features/inventory/inventory_screen.dart';
import 'package:smart_factory_qc/features/shared/providers/app_state.dart';

void main() {
  testWidgets(
      'deliveries show shimmer while loading and empty state after fetch',
      (tester) async {
    final response = Completer<List<Delivery>>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deliveryFetcherProvider.overrideWithValue(() => response.future),
        ],
        child: const MaterialApp(home: DeliveriesScreen()),
      ),
    );

    expect(find.text('Loading deliveries...'), findsOneWidget);
    response.complete(const []);
    await tester.pumpAndSettle();
    expect(find.text('No incoming HDD/SSD batches today'), findsOneWidget);
    expect(find.text('Refresh'), findsOneWidget);
  });

  testWidgets('inventory fetch failures show retry state', (tester) async {
    final retryResponse = Completer<List<InventoryItem>>();
    var calls = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inventoryFetcherProvider.overrideWithValue(() {
            calls++;
            if (calls == 1) {
              return Future<List<InventoryItem>>.error(
                StateError('offline test'),
              );
            }
            return retryResponse.future;
          }),
        ],
        child: const MaterialApp(home: InventoryScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Couldn’t load inventory'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(find.text('Loading inventory...'), findsOneWidget);
    retryResponse.complete(const []);
    await tester.pumpAndSettle();
    expect(find.text('No storage drives yet'), findsOneWidget);
  });

  testWidgets('inventory successful empty response shows refresh state',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inventoryFetcherProvider.overrideWithValue(
            () async => const <InventoryItem>[],
          ),
        ],
        child: const MaterialApp(home: InventoryScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No storage drives yet'), findsOneWidget);
    expect(find.text('Refresh'), findsOneWidget);
  });
}
