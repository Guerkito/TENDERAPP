import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../api/db_helper.dart';
import '../api/notification_service.dart';
import '../models/product_model.dart';
import '../models/product_batch_model.dart';

class ProductProvider with ChangeNotifier {
  List<Product> _products = [];
  List<Product> _expiringProducts = [];
  List<Product> _lowStockProducts = [];
  List<String> _categories = [];

  List<Product> get products => _products;
  List<Product> get expiringProducts => _expiringProducts;
  List<Product> get lowStockProducts => _lowStockProducts;
  List<String> get categories => _categories;

  Future<void> loadProducts() async {
    final db = await DBHelper().database;

    // 1. Obtener todos los productos
    final List<Map<String, dynamic>> productMaps = await db.query('products');

    // 2. Obtener todas las categorías únicas presentes en los productos
    final List<Map<String, dynamic>> catResult = await db.rawQuery('SELECT DISTINCT category FROM products WHERE category IS NOT NULL AND category != ""');
    _categories = catResult.map((e) => e['category'] as String).toList();
    if (!_categories.contains('General')) _categories.insert(0, 'General');

    // 2. Obtener todos los lotes
    final List<Map<String, dynamic>> batchMaps = await db.query('product_batches');
    
    // Agrupar lotes por product_id
    Map<int, List<ProductBatch>> productBatches = {};
    for (var map in batchMaps) {
      final batch = ProductBatch.fromMap(map);
      productBatches.putIfAbsent(batch.productId, () => []).add(batch);
    }

    // 3. Construir lista de productos con sus lotes
    _products = productMaps.map((map) {
      final id = map['id'] as int;
      final batches = productBatches[id] ?? [];
      
      // El stock total del producto es la suma de sus lotes
      double totalStock = batches.fold(0.0, (sum, b) => sum + b.stock);
      
      // La fecha de vencimiento principal es la del lote más próximo
      String? nextExpiration;
      if (batches.isNotEmpty) {
        final sortedBatches = List<ProductBatch>.from(batches)
          ..sort((a, b) {
            if (a.expirationDate == null) return 1;
            if (b.expirationDate == null) return -1;
            return a.expirationDate!.compareTo(b.expirationDate!);
          });
        nextExpiration = sortedBatches.first.expirationDate;
      }

      // Actualizamos el stock en el objeto Product para UI (retrocompatibilidad)
      var pMap = Map<String, dynamic>.from(map);
      pMap['stock'] = totalStock;
      pMap['expiration_date'] = nextExpiration;
      
      return Product.fromMap(pMap, batches: batches);
    }).toList();

    await loadExpiringProducts();
    await loadLowStockProducts();
    
    notifyListeners();
  }

  Future<void> loadExpiringProducts({int days = 30}) async {
    final db = await DBHelper().database;
    final now = DateTime.now();
    final inXDays = now.add(Duration(days: days));
    final String todayStr = now.toIso8601String().substring(0, 10);
    final String futureStr = inXDays.toIso8601String().substring(0, 10);

    // Ahora buscamos en la tabla de lotes (product_batches)
    // Un producto puede aparecer varias veces si tiene varios lotes por vencer
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT p.*, b.expiration_date as batch_expiry, b.stock as batch_stock
      FROM product_batches b
      JOIN products p ON b.product_id = p.id
      WHERE b.expiration_date IS NOT NULL 
      AND b.expiration_date >= ? 
      AND b.expiration_date <= ?
      AND b.stock > 0
      ORDER BY b.expiration_date ASC
    ''', [todayStr, futureStr]);

    _expiringProducts = maps.map((item) {
      // Creamos un producto "virtual" por cada lote para la lista de alertas
      var pMap = Map<String, dynamic>.from(item);
      pMap['expiration_date'] = item['batch_expiry'];
      pMap['stock'] = item['batch_stock'];
      return Product.fromMap(pMap);
    }).toList();

    // NOTIFICACIÓN: Si hay productos por vencer, avisar del más próximo
    if (_expiringProducts.isNotEmpty) {
      final first = _expiringProducts.first;
      NotificationService().showExpiryAlert(first.name, first.expirationDate!);
    }
    
    notifyListeners();
  }

  Future<void> loadLowStockProducts({int threshold = 5}) async {
    // Calculamos el stock bajo basándonos en la suma de lotes
    _lowStockProducts = _products.where((p) => p.stock <= threshold).toList();

    // NOTIFICACIÓN: Si hay stock crítico (ej. <= 2), avisar
    final critical = _lowStockProducts.where((p) => p.stock <= 2).toList();
    if (critical.isNotEmpty) {
      final first = critical.first;
      NotificationService().showLowStockAlert(first.name, first.stock.toDouble());
    }
    
    notifyListeners();
  }

  Future<void> addProduct(Product product) async {
    try {
      final db = await DBHelper().database;
      await db.transaction((txn) async {
        // 1. Insertar producto (sin stock, el stock viene de lotes)
        int productId = await txn.insert(
          'products',
          product.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // 2. Si tiene stock inicial o fecha, crear el primer lote
        if (product.stock > 0 || product.expirationDate != null) {
          final batch = ProductBatch(
            productId: productId,
            expirationDate: product.expirationDate,
            stock: product.stock.toDouble(),
          );
          await txn.insert('product_batches', batch.toMap());
        }
      });
      await loadProducts();
    } catch (e) {
      print('ProductProvider: Error adding product: $e');
      rethrow;
    }
  }

  Future<void> updateProduct(Product product) async {
    try {
      final db = await DBHelper().database;
      
      await db.transaction((txn) async {
        // 1. Obtener el stock actual (suma de lotes)
        final List<Map<String, dynamic>> batchResult = await txn.query(
          'product_batches',
          where: 'product_id = ?',
          whereArgs: [product.id],
        );
        double currentStock = batchResult.fold(0.0, (sum, b) => sum + (b['stock'] as num).toDouble());
        double newStock = product.stock.toDouble();

        // 2. Si el stock cambió, ajustar lotes
        if (newStock != currentStock) {
          if (newStock > currentStock) {
            // Aumento de stock: Crear un nuevo lote con la diferencia
            final diff = newStock - currentStock;
            await txn.insert('product_batches', {
              'product_id': product.id,
              'expiration_date': product.expirationDate,
              'stock': diff,
            });
          } else {
            // Disminución de stock: Ajustar lotes existentes (empezando por el más viejo/próximo a vencer)
            double toRemove = currentStock - newStock;
            final List<Map<String, dynamic>> sortedBatches = await txn.query(
              'product_batches',
              where: 'product_id = ? AND stock > 0',
              whereArgs: [product.id],
              orderBy: 'expiration_date ASC',
            );

            for (var bMap in sortedBatches) {
              if (toRemove <= 0) break;
              double bStock = (bMap['stock'] as num).toDouble();
              int bId = bMap['id'];

              if (bStock <= toRemove) {
                await txn.delete('product_batches', where: 'id = ?', whereArgs: [bId]);
                toRemove -= bStock;
              } else {
                await txn.update('product_batches', {'stock': bStock - toRemove}, where: 'id = ?', whereArgs: [bId]);
                toRemove = 0;
              }
            }
          }
        }

        // 3. Actualizar la información básica del producto
        await txn.update(
          'products',
          product.toMap(),
          where: 'id = ?',
          whereArgs: [product.id],
        );

        // 4. Asegurar que el stock denormalizado en 'products' sea correcto
        await txn.rawUpdate(
          'UPDATE products SET stock = (SELECT COALESCE(SUM(stock), 0) FROM product_batches WHERE product_id = ?) WHERE id = ?',
          [product.id, product.id]
        );
      });

      await loadProducts();
    } catch (e) {
      print('ProductProvider: Error updating product: $e');
      rethrow;
    }
  }

  Future<void> deleteProduct(int id) async {
    try {
      final db = await DBHelper().database;
      await db.delete(
        'products',
        where: 'id = ?',
        whereArgs: [id],
      );
      // Los lotes se borran por el ON DELETE CASCADE definido en SQL
      await loadProducts();
    } catch (e) {
      print('ProductProvider: Error deleting product: $e');
      rethrow;
    }
  }

  /// Registra una nueva entrada (compra) de un producto existente
  Future<void> addStock(int productId, double quantity, String? expirationDate) async {
    final db = await DBHelper().database;
    
    // Buscamos si ya existe un lote con esa misma fecha de vencimiento
    final List<Map<String, dynamic>> existing = await db.query(
      'product_batches',
      where: 'product_id = ? AND (expiration_date = ? OR (expiration_date IS NULL AND ? IS NULL))',
      whereArgs: [productId, expirationDate, expirationDate],
    );

    if (existing.isNotEmpty) {
      // Actualizar lote existente
      int batchId = existing.first['id'];
      double currentStock = (existing.first['stock'] as num).toDouble();
      await db.update(
        'product_batches',
        {'stock': currentStock + quantity},
        where: 'id = ?',
        whereArgs: [batchId],
      );
    } else {
      // Crear nuevo lote
      final batch = ProductBatch(
        productId: productId,
        expirationDate: expirationDate,
        stock: quantity,
      );
      await db.insert('product_batches', batch.toMap());
    }

    // Actualizar también el stock denormalizado en la tabla products para compatibilidad
    await db.rawUpdate(
      'UPDATE products SET stock = (SELECT SUM(stock) FROM product_batches WHERE product_id = ?) WHERE id = ?',
      [productId, productId]
    );

    await loadProducts();
  }
}
