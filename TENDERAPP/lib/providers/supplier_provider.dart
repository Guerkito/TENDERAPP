import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../api/db_helper.dart';
import '../models/supplier_model.dart';

class SupplierProvider with ChangeNotifier {
  List<Supplier> _suppliers = [];

  List<Supplier> get suppliers => _suppliers;

  Future<void> loadSuppliers() async {
    final db = await DBHelper().database;
    final List<Map<String, dynamic>> maps = await db.query('suppliers');
    _suppliers = List.generate(maps.length, (i) {
      return Supplier.fromMap(maps[i]);
    });
    notifyListeners();
  }

  Future<void> addSupplier(Supplier supplier) async {
    final db = await DBHelper().database;
    supplier.id = await db.insert(
      'suppliers',
      supplier.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _suppliers.add(supplier);
    notifyListeners();
  }

  Future<void> updateSupplier(Supplier supplier) async {
    final db = await DBHelper().database;
    await db.update(
      'suppliers',
      supplier.toMap(),
      where: 'id = ?',
      whereArgs: [supplier.id],
    );
    int index = _suppliers.indexWhere((s) => s.id == supplier.id);
    if (index != -1) {
      _suppliers[index] = supplier;
    }
    notifyListeners();
  }

  Future<void> deleteSupplier(int id) async {
    final db = await DBHelper().database;
    await db.delete(
      'suppliers',
      where: 'id = ?',
      whereArgs: [id],
    );
    _suppliers.removeWhere((supplier) => supplier.id == id);
    notifyListeners();
  }
}
