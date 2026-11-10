import 'package:flutter_test/flutter_test.dart';
import 'package:smart_factory_qc/app/sync_status.dart';
import 'package:smart_factory_qc/domain/models/batch_status.dart';
import 'package:smart_factory_qc/features/shared/providers/app_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  test('release updates delivery status and removes review requirement', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(deliveryStateProvider.notifier).release(
          'B-1007',
          note: 'Approved exception EX-042',
          authorisedBy: 'Maya Chen',
          authorisedAt: '09:36',
        );

    final record = container
        .read(deliveryStateProvider)
        .firstWhere((delivery) => delivery.batchNumber == 'B-1007');
    expect(record.status, BatchStatus.released);
    expect(record.needsReview, isFalse);
    expect(record.releaseNote, 'Approved exception EX-042');
  });

  test('trace search includes matching serial audit events', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(traceQueryProvider.notifier).state = 'SN-20481';
    final results = container.read(filteredAuditTrailProvider);
    expect(results, hasLength(1));
    expect(results.single.recordId, 'SN-20481');
  });

  test('offline simulation does not clear queued records', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final sync = container.read(syncStatusProvider.notifier);

    sync.update(pendingRecords: 3);
    sync.setOffline(true);
    expect(container.read(syncStatusProvider).pendingRecords, 3);

    sync.setOffline(false);
    expect(container.read(syncStatusProvider).isOffline, isFalse);
    expect(container.read(syncStatusProvider).pendingRecords, 3);
    expect(container.read(syncStatusProvider).isSyncing, isFalse);
  });
}
