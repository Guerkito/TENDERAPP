import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../api/db_helper.dart';
import '../constants/app_constants.dart';
import '../models/sale_model.dart';
import '../models/sale_item_model.dart';
import '../models/product_model.dart';
import '../models/customer_movement_model.dart';
import 'product_provider.dart';

class SaleProvider with ChangeNotifier {
  final ProductProvider _productProvider;

  SaleProvider(this._productProvider);

  /// Registra una venta con uno o varios métodos de pago.
  /// [payments] es una lista de {method: String, amount: double}.
  Future<int> recordSale({
    required List<Map<String, dynamic>> cartItems,
    required List<Map<String, dynamic>> payments,
    required double totalAmount,
    int? customerId,
  }) async {
    final db = await DBHelper().database;
    int saleId = 0;

    // Determinar el método a guardar en sales (nombre único o 'Mixto')
    final paymentMethodStr = payments.length == 1
        ? payments.first['method'] as String
        : PaymentMethod.mixed;

    await db.transaction((txn) async {
      // 1. Insertar la venta
      final newSale = Sale(
        totalAmount: totalAmount,
        paymentMethod: paymentMethodStr,
        saleDate: DateTime.now().toIso8601String(),
        customerId: customerId,
      );
      saleId = await txn.insert('sales', newSale.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);

      // 2. Registrar detalle de pagos
      for (final p in payments) {
        await txn.insert('sale_payments', {
          'sale_id': saleId,
          'payment_method': p['method'],
          'amount': p['amount'],
        });
      }

      // 3. Manejo de Fiado: movimiento solo por el monto fiado
      if (customerId != null) {
        final fiadoPayment = payments.cast<Map<String, dynamic>?>().firstWhere(
              (p) => p!['method'] == PaymentMethod.credit,
              orElse: () => null,
            );
        if (fiadoPayment != null) {
          final fiadoAmount = (fiadoPayment['amount'] as num).toDouble();
          final movement = CustomerMovement(
            customerId: customerId,
            dateTime: DateTime.now().toIso8601String(),
            type: MovementType.charge,
            amount: fiadoAmount,
            description: 'Compra fiada (Venta #$saleId)',
            saleId: saleId,
          );
          await txn.insert('customer_movements', movement.toMap());
          await txn.rawUpdate(
            'UPDATE customers SET total_pending_balance = total_pending_balance + ? WHERE id = ?',
            [fiadoAmount, customerId],
          );
        }

        // 4. Sumar puntos de lealtad (1 por cada 1000)
        final int earnedPoints = (totalAmount / 1000).floor();
        if (earnedPoints > 0) {
          await txn.rawUpdate(
            'UPDATE customers SET points = points + ? WHERE id = ?',
            [earnedPoints, customerId],
          );
        }
      }

      // 5. Insertar items y descontar stock (FEFO)
      for (var item in cartItems) {
        final Product product = item['product'];
        final num quantity = item['quantity'];
        final double discount = (item['discount'] as num?)?.toDouble() ?? 0.0;

        final saleItem = SaleItem(
          saleId: saleId,
          productId: product.id!,
          quantity: quantity.toInt(),
          priceAtSale: product.salePrice,
          discount: discount,
        );
        await txn.insert('sale_items', saleItem.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);

        // FEFO: lotes con fecha primero, sin fecha al final
        double remainingToSubtract = quantity.toDouble();
        final batchMaps = await txn.query(
          'product_batches',
          where: 'product_id = ? AND stock > 0',
          whereArgs: [product.id],
          orderBy:
              'CASE WHEN expiration_date IS NULL THEN 1 ELSE 0 END ASC, expiration_date ASC',
        );

        for (var bMap in batchMaps) {
          if (remainingToSubtract <= 0) break;
          final batchId = bMap['id'] as int;
          final batchStock = (bMap['stock'] as num).toDouble();

          if (batchStock >= remainingToSubtract) {
            await txn.update('product_batches',
                {'stock': batchStock - remainingToSubtract},
                where: 'id = ?', whereArgs: [batchId]);
            remainingToSubtract = 0;
          } else {
            await txn.update('product_batches', {'stock': 0},
                where: 'id = ?', whereArgs: [batchId]);
            remainingToSubtract -= batchStock;
          }
        }

        await txn.rawUpdate(
          'UPDATE products SET stock = (SELECT SUM(stock) FROM product_batches WHERE product_id = ?) WHERE id = ?',
          [product.id, product.id],
        );
      }
    });

    await _productProvider.loadProducts();
    notifyListeners();
    return saleId;
  }

  /// Anula una venta: revierte stock, saldo de fiado y marca como cancelada.
  Future<void> cancelSale(int saleId) async {
    final db = await DBHelper().database;

    await db.transaction((txn) async {
      // Obtener datos de la venta
      final saleRows =
          await txn.query('sales', where: 'id = ?', whereArgs: [saleId]);
      if (saleRows.isEmpty) return;
      final sale = saleRows.first;

      // Restaurar stock por cada item
      final items = await txn
          .query('sale_items', where: 'sale_id = ?', whereArgs: [saleId]);
      for (var item in items) {
        final productId = item['product_id'] as int;
        final quantity = (item['quantity'] as num).toDouble();

        // Devolver al lote más reciente
        final batches = await txn.query('product_batches',
            where: 'product_id = ?',
            whereArgs: [productId],
            orderBy: 'id DESC',
            limit: 1);

        if (batches.isNotEmpty) {
          final batchId = batches.first['id'] as int;
          final batchStock = (batches.first['stock'] as num).toDouble();
          await txn.update('product_batches', {'stock': batchStock + quantity},
              where: 'id = ?', whereArgs: [batchId]);
        } else {
          await txn.insert('product_batches', {
            'product_id': productId,
            'expiration_date': null,
            'stock': quantity,
          });
        }

        await txn.rawUpdate(
          'UPDATE products SET stock = (SELECT SUM(stock) FROM product_batches WHERE product_id = ?) WHERE id = ?',
          [productId, productId],
        );
      }

      // Revertir saldo de fiado
      final salePayments = await txn
          .query('sale_payments', where: 'sale_id = ?', whereArgs: [saleId]);
      double fiadoAmount = salePayments
          .where((p) => p['payment_method'] == PaymentMethod.credit)
          .fold(0.0, (sum, p) => sum + (p['amount'] as num).toDouble());

      // Fallback para ventas anteriores a sale_payments
      if (fiadoAmount == 0 &&
          sale['payment_method'] == PaymentMethod.credit) {
        fiadoAmount = (sale['total_amount'] as num).toDouble();
      }

      if (fiadoAmount > 0 && sale['customer_id'] != null) {
        final customerId = sale['customer_id'] as int;
        await txn.insert('customer_movements', {
          'customer_id': customerId,
          'date_time': DateTime.now().toIso8601String(),
          'type': MovementType.payment,
          'amount': fiadoAmount,
          'description': 'Devolución venta #$saleId',
          'sale_id': saleId,
        });
        await txn.rawUpdate(
          'UPDATE customers SET total_pending_balance = total_pending_balance - ? WHERE id = ?',
          [fiadoAmount, customerId],
        );
      }

      // Marcar como cancelada
      await txn.update('sales', {'status': SaleStatus.cancelled},
          where: 'id = ?', whereArgs: [saleId]);
    });

    await _productProvider.loadProducts();
    notifyListeners();
  }
}
