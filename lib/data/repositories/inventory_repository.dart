import 'dart:async';
import 'dart:io';

import 'package:smart_factory_qc/data/local/local_db_service.dart';
import 'package:smart_factory_qc/domain/models/inventory.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InventoryRepository {
  InventoryRepository() : _client = Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<InventoryItem>> fetchInventory({bool preferCache = false}) async {
    final localDatabase = await LocalDbService.open();
    if (preferCache) {
      final cachedRows = await localDatabase.readCache('inventory_items');
      if (cachedRows == null) {
        throw StateError(
          'Inventory has not been synchronized to this device yet.',
        );
      }
      return _inventoryItemsFromCache(cachedRows);
    }

    try {
      final response =
          await _client.from('inventory_items').select().order('sku');
      final rows = List<Map<String, dynamic>>.from(response);
      await localDatabase.saveCache('inventory_items', rows);
      final locations = rows
          .map((row) => row['rack_location'])
          .whereType<String>()
          .toSet()
          .toList()
        ..sort();
      await localDatabase.saveCache('inventory_locations', locations);
      return rows.map(_inventoryItemFromJson).toList(growable: false);
    } on SocketException catch (error) {
      return _readCachedInventory(localDatabase, error);
    } on TimeoutException catch (error) {
      return _readCachedInventory(localDatabase, error);
    }
  }

  Future<List<InventoryItem>> _readCachedInventory(
    LocalDbService database,
    Object networkError,
  ) async {
    final cachedRows = await database.readCache('inventory_items');
    if (cachedRows == null) {
      throw StateError(
        'Inventory request failed ($networkError), and this device has no '
        'cached inventory.',
      );
    }
    return _inventoryItemsFromCache(cachedRows);
  }

  List<InventoryItem> _inventoryItemsFromCache(Object cachedRows) =>
      (cachedRows as List<dynamic>)
          .map(
            (row) => _inventoryItemFromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false);

  InventoryItem _inventoryItemFromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: json['id'] as String,
      sku: json['sku'] as String,
      name: json['name'] as String,
      unit: json['unit'] as String,
      rackLocation: json['rack_location'] as String,
      currentQuantity: (json['current_quantity'] as num).toDouble(),
      reorderLevel: (json['reorder_level'] as num).toDouble(),
      targetLevel: (json['target_level'] as num).toDouble(),
      supplier: json['supplier'] as String,
      specifications: json['specifications'] as String,
    );
  }
}
