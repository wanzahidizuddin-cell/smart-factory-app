import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:smart_factory_qc/data/local/local_db_service.dart';
import 'package:smart_factory_qc/data/services/audit_log_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef SyncStateUpdater = void Function({
  int? pendingRecords,
  bool? isSyncing,
  String? errorMessage,
  bool? clearError,
});

class SyncService {
  SyncService({
    required this.canSync,
    required this.onNetworkChanged,
    required this.onStateChanged,
    Connectivity? connectivity,
    SupabaseClient? client,
  })  : _connectivity = connectivity ?? Connectivity(),
        _clientOverride = client;

  final bool Function() canSync;
  final ValueChanged<bool> onNetworkChanged;
  final SyncStateUpdater onStateChanged;
  final Connectivity _connectivity;
  final SupabaseClient? _clientOverride;
  SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _pollingTimer;
  bool _started = false;
  bool _syncing = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      final database = await LocalDbService.open();
      await database.recoverInterruptedActions();
      await _refreshPendingCount(database);
      if (defaultTargetPlatform == TargetPlatform.windows) {
        _pollingTimer = Timer.periodic(
          const Duration(seconds: 15),
          (_) => _pollConnectivity(),
        );
        await _pollConnectivity();
      } else {
        _subscription = _connectivity.onConnectivityChanged.listen(
          _handleConnectivity,
          onError: (Object error, StackTrace stackTrace) {
            _reportError(error);
            debugPrintStack(stackTrace: stackTrace);
          },
        );
        final connectivity = await _connectivity.checkConnectivity();
        await _handleConnectivity(connectivity);
      }
    } catch (error, stackTrace) {
      _reportError(error);
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _pollConnectivity() async {
    try {
      await _handleConnectivity(await _connectivity.checkConnectivity());
    } catch (error, stackTrace) {
      _reportError(error);
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _handleConnectivity(List<ConnectivityResult> results) async {
    final isOffline = results.every(
      (result) => result == ConnectivityResult.none,
    );
    onNetworkChanged(isOffline);
    if (!isOffline && canSync()) {
      try {
        await syncPending();
      } catch (error, stackTrace) {
        _reportError(error);
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  Future<void> syncPending() async {
    final database = await LocalDbService.open();
    await _refreshPendingCount(database);
    if (_syncing || !canSync()) return;

    _syncing = true;
    onStateChanged(isSyncing: true, clearError: true);
    final failures = <Object>[];
    try {
      final actions = await database.pendingActions();
      for (final action in actions) {
        try {
          await database.markSyncing(action.id);
          await _execute(action);
          await database.removeAction(action.id);
        } catch (error, stackTrace) {
          await database.markFailed(action.id, error);
          failures.add(error);
          debugPrintStack(stackTrace: stackTrace);
        }
      }

      final pendingCount = await database.pendingActionCount();
      if (failures.isNotEmpty) {
        final message =
            '${failures.length} queued action(s) could not be synchronized. '
            'They remain queued for retry. First error: ${failures.first}';
        onStateChanged(pendingRecords: pendingCount, errorMessage: message);
        throw StateError(message);
      }
      onStateChanged(pendingRecords: pendingCount, clearError: true);
    } finally {
      _syncing = false;
      onStateChanged(isSyncing: false);
    }
  }

  Future<void> _execute(SyncQueueEntry action) async {
    switch (action.actionType) {
      case 'inspection_submit':
        await _submitInspection(action);
      case 'stock_movement_append':
        await _appendStockMovement(action);
      default:
        throw StateError('Unsupported queued action: ${action.actionType}');
    }
  }

  Future<void> _appendStockMovement(SyncQueueEntry action) async {
    final payload = action.payload;
    final existing = await _client
        .from('stock_movements')
        .select('id')
        .eq('client_action_id', action.id)
        .maybeSingle();
    final movementId = existing == null
        ? (await _client
            .from('stock_movements')
            .insert({
              ...payload,
              'client_action_id': action.id,
            })
            .select('id')
            .single())['id'] as String
        : existing['id'] as String;

    await AuditLogService(_client).record(
      actionId: action.id,
      actionType: 'stock_movement_recorded',
      userId: payload['performed_by'] as String,
      module: 'inventory',
      recordId: payload['item_id'] as String,
      previousState: null,
      newState: {
        ...payload,
        'id': movementId,
      },
    );
  }

  Future<void> _submitInspection(SyncQueueEntry action) async {
    final payload = action.payload;
    final existing = await _client
        .from('inspections')
        .select('id')
        .eq('client_action_id', action.id)
        .maybeSingle();
    final String inspectionId;
    if (existing != null) {
      inspectionId = existing['id'] as String;
    } else {
      final delivery = await _client
          .from('deliveries')
          .select('id')
          .eq('batch_number', payload['batch_number'] as String)
          .maybeSingle();
      if (delivery == null) {
        throw StateError(
          'Batch ${payload['batch_number']} was not found while synchronizing.',
        );
      }

      final inspection = <String, dynamic>{
        'client_action_id': action.id,
        'serial_number': payload['serial_number'],
        'delivery_id': delivery['id'],
        'machine': payload['machine'],
        'defect_category': payload['defect_category'],
        'result': payload['result'],
        'notes': payload['notes'],
        'photo_count': payload['photo_count'],
        'inspector_id': payload['inspector_id'],
      };
      final inserted = await _client
          .from('inspections')
          .insert(inspection)
          .select('id')
          .single();
      inspectionId = inserted['id'] as String;
    }

    await AuditLogService(_client).record(
      actionId: action.id,
      actionType: 'inspection_recorded',
      userId: payload['inspector_id'] as String,
      module: 'inspections',
      recordId: payload['serial_number'] as String,
      previousState: null,
      newState: {
        'id': inspectionId,
        'batch_number': payload['batch_number'],
        'serial_number': payload['serial_number'],
        'machine': payload['machine'],
        'defect_category': payload['defect_category'],
        'result': payload['result'],
        'notes': payload['notes'],
        'photo_count': payload['photo_count'],
      },
    );
  }

  Future<void> _refreshPendingCount(LocalDbService database) async {
    onStateChanged(pendingRecords: await database.pendingActionCount());
  }

  void _reportError(Object error) {
    onStateChanged(errorMessage: error.toString());
    debugPrint('Sync service error: $error');
  }

  Future<void> dispose() async {
    _pollingTimer?.cancel();
    await _subscription?.cancel();
  }
}
