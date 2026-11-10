import 'package:smart_factory_qc/domain/models/batch_status.dart';
import 'package:smart_factory_qc/domain/models/inspection_record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class QcRepository {
  QcRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  Future<List<InspectionRecord>> fetchInspections() async {
    final rows = await _supabase
        .from('inspections')
        .select(
          'serial_number, machine, defect_category, result, notes, '
          'photo_count, inspector_id, recorded_at, created_at, '
          'deliveries(batch_number)',
        )
        .order('created_at', ascending: false);

    return rows.map(_inspectionFromMap).toList(growable: false);
  }

  InspectionRecord _inspectionFromMap(Map<String, dynamic> map) {
    final delivery = map['deliveries'] as Map<String, dynamic>?;
    if (delivery == null) {
      throw const FormatException(
        'Inspection record is missing its related delivery.',
      );
    }

    final result = switch (map['result'] as String) {
      'Pass' => BatchStatus.passed,
      'Fail' => BatchStatus.failed,
      final value => throw FormatException(
          'Unsupported inspection result: $value',
        ),
    };

    return InspectionRecord(
      serialNumber: map['serial_number'] as String,
      batchNumber: delivery['batch_number'] as String,
      machine: map['machine'] as String,
      result: result,
      defectCategory: map['defect_category'] as String,
      notes: map['notes'] as String,
      photoCount: map['photo_count'] as int,
      inspector: map['inspector_id'] as String,
      recordedAt: map['recorded_at'] as String? ?? map['created_at'] as String,
    );
  }
}
