import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../api/db_helper.dart';
import '../models/purchase_model.dart';
import '../models/purchase_item_model.dart';
import '../models/product_model.dart';
import 'product_provider.dart';

class PurchaseProvider with ChangeNotifier {
  final ProductProvider _productProvider;
  List<PurchaseModel> _purchases = [];

  PurchaseProvider(this._productProvider);

  List<PurchaseModel> get purchases => _purchases;

  Future<void> loadPurchases() async {
    final db = await DBHelper().database;
    final List<Map<String, dynamic>> maps = await db.query('purchases', orderBy: 'date DESC');
    _purchases = List.generate(maps.length, (i) {
      return PurchaseModel.fromMap(maps[i]);
    });
    notifyListeners();
  }

  Future<void> recordPurchase({
    required int supplierId,
    required DateTime date,
    required String? notes,
    required List<Map<String, dynamic>> items, // { 'product': Product, 'quantity': num, 'cost': double, 'expiration_date': String? }
  }) async {
    final db = await DBHelper().database;
    
    await db.transaction((txn) async {
      // 1. Insert Purchase Header
      double totalAmount = items.fold(0.0, (sum, item) => sum + (item['quantity'] * item['cost']));
      
      final newPurchase = PurchaseModel(
        supplierId: supplierId,
        date: date,
        totalAmount: totalAmount,
        notes: notes,
      );
      final int purchaseId = await txn.insert('purchases', newPurchase.toMap());

      // 2. Process Items
      for (var item in items) {
        final Product product = item['product'];
        final num quantity = item['quantity'];
        final double costPrice = item['cost'];
        final String? expirationDate = item['expiration_date'];

        // Insert Purchase Item
        final purchaseItem = PurchaseItemModel(
          purchaseId: purchaseId,
          productId: product.id!,
          quantity: quantity,
          costPrice: costPrice,
        );
        await txn.insert('purchase_items', purchaseItem.toMap());

        // 3. Update Product Cost (Last purchase price)
        await txn.update(
          'products',
          {'purchase_price': costPrice},
          where: 'id = ?',
          whereArgs: [product.id],
        );

        // 4. Update Batches and Total Stock using productProvider logic but inside transaction
        // We'll reuse the logic from productProvider.addStock but adjusted for transaction
        await _addStockInTransaction(txn, product.id!, quantity.toDouble(), expirationDate);
      }
    });

    // Refresh everything
    await _productProvider.loadProducts();
    await loadPurchases();
  }

  /// Helper to handle batch logic within a transaction
  Future<void> _addStockInTransaction(Transaction txn, int productId, double quantity, String? expirationDate) async {
    final List<Map<String, dynamic>> existing = await txn.query(
      'product_batches',
      where: 'product_id = ? AND (expiration_date = ? OR (expiration_date IS NULL AND ? IS NULL))',
      whereArgs: [productId, expirationDate, expirationDate],
    );

    if (existing.isNotEmpty) {
      int batchId = existing.first['id'];
      double currentStock = (existing.first['stock'] as num).toDouble();
      await txn.update(
        'product_batches',
        {'stock': currentStock + quantity},
        where: 'id = ?',
        whereArgs: [batchId],
      );
    } else {
      await txn.insert('product_batches', {
        'product_id': productId,
        'expiration_date': expirationDate,
        'stock': quantity,
      });
    }

    // Update denormalized stock in products table
    await txn.rawUpdate(
      'UPDATE products SET stock = (SELECT SUM(stock) FROM product_batches WHERE product_id = ?) WHERE id = ?',
      [productId, productId]
    );
  }
}
