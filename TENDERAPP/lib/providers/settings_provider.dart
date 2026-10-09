import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../api/db_helper.dart';

class SettingsProvider with ChangeNotifier {
  String _storeName = 'Mi Tienda';
  bool _isNameSet = false;
  String _storeId = '';
  String _businessType = 'generic';
  bool _isBusinessTypeSet = false;
  int _loyaltyGoal = 6;
  String _loyaltyReward = 'Premio gratis';
  String? _pinHash; // null = sin PIN
  bool _isLoaded = false;

  String get storeName => _storeName;
  bool get isNameSet => _isNameSet;
  String get storeId => _storeId;
  String get businessType => _businessType;
  bool get isBusinessTypeSet => _isBusinessTypeSet;
  int get loyaltyGoal => _loyaltyGoal;
  String get loyaltyReward => _loyaltyReward;
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

    if (settingsMap.containsKey('business_type')) {
      _businessType = settingsMap['business_type']!;
      _isBusinessTypeSet = true;
    } else {
      _isBusinessTypeSet = false;
    }

    _loyaltyGoal = int.tryParse(settingsMap['loyalty_goal'] ?? '') ?? 6;
    _loyaltyReward = settingsMap['loyalty_reward'] ?? 'Premio gratis';

    _storeId = settingsMap['store_id'] ?? '';
    if (_storeId.isEmpty) {
      _storeId = _generateStoreId();
      await db.insert('settings', {'key': 'store_id', 'value': _storeId},
          conflictAlgorithm: ConflictAlgorithm.replace);
    }

    _pinHash = settingsMap['app_pin'];
    _isLoaded = true;
    notifyListeners();
  }

  String _generateStoreId() {
    final random = Random();
    final suffix =
        random.nextInt(46656).toRadixString(36).padLeft(3, '0');
    return 't${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}$suffix';
  }

  Future<void> updateStoreName(String newName) async {
    final db = await DBHelper().database;
    await db.insert('settings', {'key': 'store_name', 'value': newName},
        conflictAlgorithm: ConflictAlgorithm.replace);
    _storeName = newName;
    _isNameSet = true;
    notifyListeners();
  }

  Future<void> updateStoreId(String newId) async {
    final db = await DBHelper().database;
    await db.insert('settings', {'key': 'store_id', 'value': newId},
        conflictAlgorithm: ConflictAlgorithm.replace);
    _storeId = newId;
    notifyListeners();
  }

  Future<void> updateBusinessType(String typeId) async {
    final db = await DBHelper().database;
    await db.insert('settings', {'key': 'business_type', 'value': typeId},
        conflictAlgorithm: ConflictAlgorithm.replace);
    _businessType = typeId;
    _isBusinessTypeSet = true;
    notifyListeners();
  }

  Future<void> updateLoyaltyConfig({required int goal, required String reward}) async {
    final db = await DBHelper().database;
    await db.insert('settings', {'key': 'loyalty_goal', 'value': goal.toString()},
        conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('settings', {'key': 'loyalty_reward', 'value': reward},
        conflictAlgorithm: ConflictAlgorithm.replace);
    _loyaltyGoal = goal;
    _loyaltyReward = reward;
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
