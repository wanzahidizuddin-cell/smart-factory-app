import 'package:smart_factory_qc/data/local/local_db_service.dart';
import 'package:smart_factory_qc/domain/models/inventory.dart';
import 'package:smart_factory_qc/domain/repositories/stock_movement_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseStockMovementRepository implements StockMovementRepository {
  SupabaseStockMovementRepository({
    Future<void> Function()? syncPending,
    SupabaseClient? client,
  })  : _syncPending = syncPending,
        _client = client ?? Supabase.instance.client;

  final Future<void> Function()? _syncPending;
  final SupabaseClient _client;

  @override
  Future<void> append(StockMovement movement) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Sign in before recording a stock movement.');
    }
    if (movement.performedBy != userId) {
      throw ArgumentError.value(
        movement.performedBy,
        'movement.performedBy',
        'The performer must be the current signed-in user.',
      );
    }
    if (movement.delta == 0 || movement.reason.trim().isEmpty) {
      throw ArgumentError(
        'A stock movement requires a non-zero quantity and a reason.',
      );
    }

    final database = await LocalDbService.open();
    await database.enqueueAction(
      actionType: 'stock_movement_append',
      payload: {
        'id': movement.id,
        'item_id': movement.itemId,
        'location_id': movement.locationId,
        'delta': movement.delta,
        'reason': movement.reason.trim(),
        'performed_by': userId,
        'recorded_at': movement.recordedAt.toUtc().toIso8601String(),
        'batch_number': movement.batchNumber,
      },
    );
    await _syncPending?.call();
  }

  @override
  Future<List<StockMovement>> history({
    String? itemId,
    String? batchNumber,
  }) async {
    final filters = <String, Object>{
      if (itemId != null) 'item_id': itemId,
      if (batchNumber != null) 'batch_number': batchNumber,
    };
    final rows = await _client
        .from('stock_movements')
        .select(
          'id, item_id, location_id, delta, reason, performed_by, '
          'recorded_at, batch_number',
        )
        .match(filters)
        .order('recorded_at', ascending: false);
    return rows
        .map(
          (row) => StockMovement(
            id: row['id'] as String,
            itemId: row['item_id'] as String,
            locationId: row['location_id'] as String,
            delta: (row['delta'] as num).toDouble(),
            reason: row['reason'] as String,
            performedBy: row['performed_by'] as String,
            recordedAt: DateTime.parse(row['recorded_at'] as String),
            batchNumber: row['batch_number'] as String?,
          ),
        )
        .toList(growable: false);
  }
}
