import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../api/db_helper.dart';
import '../models/sale_model.dart';
import '../models/sale_item_model.dart';
import '../models/product_model.dart';
import '../models/customer_movement_model.dart'; // New import
import 'product_provider.dart'; // To update product stock

class SaleProvider with ChangeNotifier {
  final ProductProvider _productProvider;

  SaleProvider(this._productProvider);

  Future<int> recordSale({
    required List<Map<String, dynamic>> cartItems,
    required String paymentMethod,
    required double totalAmount,
    int? customerId, // New optional parameter
  }) async {
    final db = await DBHelper().database;
    int saleId = 0;
    
    await db.transaction((txn) async {
      // 1. Insert the new sale
      final newSale = Sale(
        totalAmount: totalAmount,
        paymentMethod: paymentMethod,
        saleDate: DateTime.now().toIso8601String(),
        customerId: customerId,
      );
      saleId = await txn.insert(
        'sales',
        newSale.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 2. If payment method is 'Fiado', register movement and update balance
      if (paymentMethod == 'Fiado' && customerId != null) {
        final movement = CustomerMovement(
          customerId: customerId,
          dateTime: DateTime.now().toIso8601String(),
          type: 'Cargo',
          amount: totalAmount,
          description: 'Compra fiada (Venta #$saleId)',
          saleId: saleId,
        );
        await txn.insert('customer_movements', movement.toMap());
        
        await txn.rawUpdate(
          'UPDATE customers SET total_pending_balance = total_pending_balance + ? WHERE id = ?',
          [totalAmount, customerId]
        );
      }
      
      // 2.1 Award Points (Loyalty System)
      if (customerId != null) {
        // Rule: 1 point for every 1000 units of currency
        final int earnedPoints = (totalAmount / 1000).floor();
        if (earnedPoints > 0) {
          await txn.rawUpdate(
            'UPDATE customers SET points = points + ? WHERE id = ?',
            [earnedPoints, customerId]
          );
        }
      }

      // 3. Insert sale items and update product stock (using FEFO for batches)
      for (var item in cartItems) {
        final Product product = item['product'];
        final num quantity = item['quantity'];

        final saleItem = SaleItem(
          saleId: saleId,
          productId: product.id!,
          quantity: quantity.toInt(),
          priceAtSale: product.salePrice,
        );
        await txn.insert(
          'sale_items',
          saleItem.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // --- LÓGICA FEFO PARA LOTES ---
        double remainingToSubtract = quantity.toDouble();
        
        // Obtener lotes ordenados por fecha de vencimiento (nulos al final)
        final List<Map<String, dynamic>> batchMaps = await txn.query(
          'product_batches',
          where: 'product_id = ? AND stock > 0',
          whereArgs: [product.id],
          orderBy: 'expiration_date ASC',
        );

        for (var bMap in batchMaps) {
          if (remainingToSubtract <= 0) break;

          int batchId = bMap['id'];
          double batchStock = (bMap['stock'] as num).toDouble();
          
          if (batchStock >= remainingToSubtract) {
            // Este lote cubre lo que falta
            await txn.update(
              'product_batches',
              {'stock': batchStock - remainingToSubtract},
              where: 'id = ?',
              whereArgs: [batchId],
            );
            remainingToSubtract = 0;
          } else {
            // Agotar este lote y seguir con el siguiente
            await txn.update(
              'product_batches',
              {'stock': 0},
              where: 'id = ?',
              whereArgs: [batchId],
            );
            remainingToSubtract -= batchStock;
          }
        }

        // 4. Actualizar stock denormalizado en tabla products
        await txn.rawUpdate(
          'UPDATE products SET stock = (SELECT SUM(stock) FROM product_batches WHERE product_id = ?) WHERE id = ?',
          [product.id, product.id]
        );
      }
    });
    // After transaction, reload products to reflect stock changes
    await _productProvider.loadProducts();
    notifyListeners();
    return saleId;
  }
}
