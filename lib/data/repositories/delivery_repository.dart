import 'package:smart_factory_qc/domain/models/batch_status.dart';
import 'package:smart_factory_qc/domain/models/delivery.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeliveryRepository {
  DeliveryRepository() : _client = Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<Delivery>> fetchDeliveries() async {
    final rows = await _client
        .from('deliveries')
        .select()
        .order('received_at', ascending: false);

    return rows.map(_deliveryFromJson).toList(growable: false);
  }

  Delivery _deliveryFromJson(Map<String, dynamic> json) {
    final status = switch (json['status'] as String) {
      'Passed' => BatchStatus.passed,
      'Quarantined' => BatchStatus.quarantined,
      'Released' => BatchStatus.released,
      final value => throw FormatException(
          'Unsupported delivery status: $value',
        ),
    };

    return Delivery(
      batchNumber: json['batch_number'] as String,
      supplier: json['supplier'] as String,
      material: json['material'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit'] as String,
      status: status,
      needsReview: json['needs_review'] as bool,
      materialCode: json['material_code'] as String? ?? '',
      packaging: json['packaging'] as String? ?? '',
      receivedAt: json['received_at'] as String? ?? '',
      inspectionNotes: json['inspection_notes'] as String? ?? '',
      holdReason: json['hold_reason'] as String? ?? '',
      releaseNote: json['release_note'] as String? ?? '',
      authorisedBy: json['authorized_by'] as String? ?? '',
      authorisedAt: json['authorized_at'] as String? ?? '',
    );
  }
}
