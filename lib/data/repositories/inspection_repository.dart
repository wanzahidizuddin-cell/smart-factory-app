import 'package:smart_factory_qc/data/local/local_db_service.dart';
import 'package:smart_factory_qc/domain/models/batch_status.dart';
import 'package:smart_factory_qc/domain/models/inspection_record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InspectionRepository {
  InspectionRepository({Future<void> Function()? syncPending})
      : _client = Supabase.instance.client,
        _syncPending = syncPending;

  final SupabaseClient _client;
  final Future<void> Function()? _syncPending;

  Future<void> submitInspection(InspectionRecord record) async {
    final inspectorId = _client.auth.currentUser?.id;
    if (inspectorId == null) {
      throw StateError('Sign in before submitting an inspection.');
    }

    final result = switch (record.result) {
      BatchStatus.passed => 'Pass',
      BatchStatus.failed => 'Fail',
      _ => throw ArgumentError.value(
          record.result,
          'record.result',
          'An inspection result must be Passed or Failed.',
        ),
    };

    final database = await LocalDbService.open();
    await database.enqueueAction(
      actionType: 'inspection_submit',
      payload: {
        'serial_number': record.serialNumber,
        'batch_number': record.batchNumber,
        'machine': record.machine,
        'defect_category': record.defectCategory,
        'result': result,
        'notes': record.notes,
        'photo_count': record.photoCount,
        'inspector_id': inspectorId,
      },
    );
    await _syncPending?.call();
  }
}
