/// Inventory catalogue record, including the current Supabase stock snapshot.
class InventoryItem {
  const InventoryItem({
    required this.id,
    required this.sku,
    required this.name,
    required this.unit,
    required this.reorderLevel,
    required this.targetLevel,
    this.currentQuantity,
    this.rackLocation,
    this.supplier = 'Northworks Supply',
    this.specifications = 'Standard production material',
  });

  final String id;
  final String sku;
  final String name;
  final String unit;

  /// Low-stock when total <= reorderLevel.
  final double reorderLevel;

  /// Full-bar reference for the stock-level bar (configuration, not stock).
  final double targetLevel;
  final double? currentQuantity;
  final String? rackLocation;
  final String supplier;
  final String specifications;
}

/// Quantity of one item at one location.
class StockLevel {
  const StockLevel({
    required this.itemId,
    required this.locationId,
    required this.quantity,
  });

  final String itemId;
  final String locationId;
  final double quantity;
}

/// Append-only audit record. All fields are final and there is no copyWith.
/// Corrections are made by appending a NEW compensating movement,
/// never by editing or deleting history.
class StockMovement {
  const StockMovement({
    required this.id,
    required this.itemId,
    required this.locationId,
    required this.delta,
    required this.reason,
    required this.performedBy,
    required this.recordedAt,
    this.batchNumber,
  });

  final String id;
  final String itemId;
  final String locationId;

  /// Signed change (+ receipt, - issue).
  final double delta;
  final String reason;
  final String performedBy;
  final DateTime recordedAt;
  final String? batchNumber;
}
