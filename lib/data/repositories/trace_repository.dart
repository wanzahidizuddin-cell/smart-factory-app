import 'package:supabase_flutter/supabase_flutter.dart';

class TraceRepository {
  TraceRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  Future<List<Map<String, dynamic>>> searchTraceHistory(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return const [];

    final pattern = '%$normalizedQuery%';
    final results = await Future.wait<List<Map<String, dynamic>>>([
      _supabase
          .from('deliveries')
          .select(
            'id, batch_number, supplier, material, material_code, status, '
            'quantity, unit, received_at',
          )
          .ilike('batch_number', pattern)
          .order('received_at', ascending: false),
      _supabase
          .from('deliveries')
          .select(
            'id, batch_number, supplier, material, material_code, status, '
            'quantity, unit, received_at',
          )
          .ilike('supplier', pattern)
          .order('received_at', ascending: false),
      _supabase
          .from('inventory_items')
          .select(
            'id, sku, name, rack_location, current_quantity, unit, supplier',
          )
          .ilike('name', pattern)
          .order('sku'),
      _supabase
          .from('inventory_items')
          .select(
            'id, sku, name, rack_location, current_quantity, unit, supplier',
          )
          .ilike('sku', pattern)
          .order('sku'),
    ]);

    final uniqueResults = <String, Map<String, dynamic>>{};
    for (final row in [...results[0], ...results[1]]) {
      uniqueResults['Delivery:${row['id']}'] = {
        ...row,
        'type': 'Delivery',
      };
    }

    for (final row in [...results[2], ...results[3]]) {
      uniqueResults['Inventory:${row['id']}'] = {
        ...row,
        'type': 'Inventory',
      };
    }

    return uniqueResults.values.toList(growable: false);
  }
}
