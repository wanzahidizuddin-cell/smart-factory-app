import 'package:smart_factory_qc/domain/models/inventory.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InventoryRepository {
  InventoryRepository() : _client = Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<InventoryItem>> fetchInventory() async {
    final rows = await _client.from('inventory_items').select().order('sku');

    return rows.map(_inventoryItemFromJson).toList(growable: false);
  }

  InventoryItem _inventoryItemFromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: json['id'] as String,
      sku: json['sku'] as String,
      name: json['name'] as String,
      unit: json['unit'] as String,
      reorderLevel: (json['reorder_level'] as num).toDouble(),
      targetLevel: (json['target_level'] as num).toDouble(),
      supplier: json['supplier'] as String,
      specifications: json['specifications'] as String,
    );
  }
}
