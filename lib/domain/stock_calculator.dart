import 'package:smart_factory_qc/domain/models/inventory.dart';

/// Legacy fallback for catalogue items without a Supabase stock snapshot.
double totalStock(String itemId, Iterable<StockLevel> levels) => levels
    .where((l) => l.itemId == itemId)
    .fold<double>(0, (sum, l) => sum + l.quantity);

double currentStock(InventoryItem item, Iterable<StockLevel> levels) =>
    item.currentQuantity ?? totalStock(item.id, levels);

/// "At or below" reorder level counts as low stock.
bool isLowStock(InventoryItem item, Iterable<StockLevel> levels) =>
    currentStock(item, levels) <= item.reorderLevel;
