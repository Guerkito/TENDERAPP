import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../api/db_helper.dart';

class SettingsProvider with ChangeNotifier {
  String _storeName = 'Mi Tienda';
  bool _isNameSet = false;

  String get storeName => _storeName;
  bool get isNameSet => _isNameSet;

  Future<void> loadSettings() async {
    final db = await DBHelper().database;
    final List<Map<String, dynamic>> maps = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['store_name'],
    );

    if (maps.isNotEmpty) {
      _storeName = maps.first['value'];
      _isNameSet = true;
    } else {
      _isNameSet = false;
    }
    notifyListeners();
  }

  Future<void> updateStoreName(String newName) async {
    final db = await DBHelper().database;
    await db.insert(
      'settings',
      {'key': 'store_name', 'value': newName},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _storeName = newName;
    _isNameSet = true;
    notifyListeners();
  }
}
