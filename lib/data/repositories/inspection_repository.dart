import 'package:smart_factory_qc/domain/models/batch_status.dart';
import 'package:smart_factory_qc/domain/models/inspection_record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InspectionRepository {
  InspectionRepository() : _client = Supabase.instance.client;

  final SupabaseClient _client;

  Future<void> submitInspection(InspectionRecord record) async {
    final inspectorId = _client.auth.currentUser?.id;
    if (inspectorId == null) {
      throw StateError('Sign in before submitting an inspection.');
    }

    final delivery = await _client
        .from('deliveries')
        .select('id')
        .eq('batch_number', record.batchNumber)
        .maybeSingle();
    if (delivery == null) {
      throw StateError('Batch ${record.batchNumber} was not found.');
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

    await _client.from('inspections').insert({
      'serial_number': record.serialNumber,
      'delivery_id': delivery['id'] as String,
      'machine': record.machine,
      'defect_category': record.defectCategory,
      'result': result,
      'notes': record.notes,
      'photo_count': record.photoCount,
      'inspector_id': inspectorId,
    });
  }
}
