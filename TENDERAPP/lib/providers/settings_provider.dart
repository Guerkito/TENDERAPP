import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../api/db_helper.dart';

class SettingsProvider with ChangeNotifier {
  String _storeName = 'Mi Tienda';
  bool _isNameSet = false;
  String? _pinHash; // null = sin PIN
  bool _isLoaded = false;

  String get storeName => _storeName;
  bool get isNameSet => _isNameSet;
  bool get hasPinEnabled => _pinHash != null && _pinHash!.isNotEmpty;
  bool get isLoaded => _isLoaded;

  Future<void> loadSettings() async {
    final db = await DBHelper().database;
    final maps = await db.query('settings');
    final settingsMap = {for (var row in maps) row['key'] as String: row['value'] as String?};

    if (settingsMap.containsKey('store_name')) {
      _storeName = settingsMap['store_name']!;
      _isNameSet = true;
    } else {
      _isNameSet = false;
    }

    _pinHash = settingsMap['app_pin'];
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> updateStoreName(String newName) async {
    final db = await DBHelper().database;
    await db.insert('settings', {'key': 'store_name', 'value': newName},
        conflictAlgorithm: ConflictAlgorithm.replace);
    _storeName = newName;
    _isNameSet = true;
    notifyListeners();
  }

  Future<void> setPin(String rawPin) async {
    final hashed = _hashPin(rawPin);
    final db = await DBHelper().database;
    await db.insert('settings', {'key': 'app_pin', 'value': hashed},
        conflictAlgorithm: ConflictAlgorithm.replace);
    _pinHash = hashed;
    notifyListeners();
  }

  Future<void> removePin() async {
    final db = await DBHelper().database;
    await db.delete('settings', where: 'key = ?', whereArgs: ['app_pin']);
    _pinHash = null;
    notifyListeners();
  }

  bool verifyPin(String rawPin) => _hashPin(rawPin) == _pinHash;

  String _hashPin(String pin) =>
      sha256.convert(utf8.encode(pin)).toString();
}
