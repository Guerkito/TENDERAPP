import 'package:flutter/material.dart';
import '../api/db_helper.dart';
import '../constants/app_constants.dart';
import '../models/customer_model.dart';
import '../models/customer_movement_model.dart';
import '../models/loyalty.dart';

class CustomerProvider with ChangeNotifier {
  List<Customer> _customers = [];
  double _totalDebtInStreet = 0.0;

  List<Customer> get customers => _customers;
  double get totalDebtInStreet => _totalDebtInStreet;

  Future<void> loadCustomers() async {
    final db = await DBHelper().database;
    final List<Map<String, dynamic>> maps = await db.query('customers', orderBy: 'total_pending_balance DESC');
    _customers = maps.map((item) => Customer.fromMap(item)).toList();
    
    // Calcular el dinero total en la calle
    final result = await db.rawQuery('SELECT SUM(total_pending_balance) as total FROM customers');
    _totalDebtInStreet = (result.first['total'] as num?)?.toDouble() ?? 0.0;
    
    notifyListeners();
  }

  Future<int> addCustomer(Customer customer) async {
    final db = await DBHelper().database;
    final id = await db.insert('customers', customer.toMap());
    await loadCustomers();
    return id;
  }

  Future<void> registerMovement(CustomerMovement movement) async {
    final db = await DBHelper().database;
    await db.transaction((txn) async {
      // 1. Insertar el movimiento
      await txn.insert('customer_movements', movement.toMap());

      // 2. Actualizar el saldo del cliente
      final adjustment = movement.type == MovementType.charge ? movement.amount : -movement.amount;
      await txn.rawUpdate(
        'UPDATE customers SET total_pending_balance = total_pending_balance + ? WHERE id = ?',
        [adjustment, movement.customerId]
      );
    });
    await loadCustomers();
  }

  Future<List<CustomerMovement>> getCustomerHistory(int customerId) async {
    final db = await DBHelper().database;
    final List<Map<String, dynamic>> maps = await db.query(
      'customer_movements',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'date_time DESC'
    );
    return maps.map((item) => CustomerMovement.fromMap(item)).toList();
  }
  
  Future<void> updateCustomer(Customer customer) async {
    final db = await DBHelper().database;
    await db.update(
      'customers',
      customer.toMap(),
      where: 'id = ?',
      whereArgs: [customer.id],
    );
    await loadCustomers();
  }

  Future<int> _loyaltyGoal() async {
    final db = await DBHelper().database;
    final rows = await db.query('settings',
        where: 'key = ?', whereArgs: ['loyalty_goal']);
    if (rows.isEmpty) return 6;
    return int.tryParse(rows.first['value'] as String? ?? '') ?? 6;
  }

  Future<LoyaltySummary> getLoyaltySummary(int customerId) async {
    final db = await DBHelper().database;
    final goal = await _loyaltyGoal();
    final result = await db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE WHEN type = ? THEN amount ELSE 0 END), 0) AS total_stamps,
        COALESCE(SUM(CASE WHEN type = ? THEN amount ELSE 0 END), 0) AS redeemed
      FROM loyalty_movements WHERE customer_id = ?
    ''', [LoyaltyType.stamp, LoyaltyType.redeem, customerId]);
    final row = result.first;
    return LoyaltySummary.fromTotals(
      totalStamps: (row['total_stamps'] as num).toInt(),
      rewardsRedeemed: (row['redeemed'] as num).toInt(),
      goal: goal,
    );
  }

  Future<List<LoyaltyBoardRow>> getLoyaltyBoard() async {
    final db = await DBHelper().database;
    final goal = await _loyaltyGoal();
    final rows = await db.rawQuery('''
      SELECT c.id AS customer_id, c.name AS name, c.phone AS phone,
        COALESCE(SUM(CASE WHEN m.type = ? THEN m.amount ELSE 0 END), 0) AS total_stamps,
        COALESCE(SUM(CASE WHEN m.type = ? THEN m.amount ELSE 0 END), 0) AS redeemed
      FROM customers c
      LEFT JOIN loyalty_movements m ON m.customer_id = c.id
      GROUP BY c.id
      ORDER BY c.name ASC
    ''', [LoyaltyType.stamp, LoyaltyType.redeem]);
    return rows
        .map((row) => LoyaltyBoardRow(
              customerId: row['customer_id'] as int,
              name: row['name'] as String,
              phone: row['phone'] as String?,
              summary: LoyaltySummary.fromTotals(
                totalStamps: (row['total_stamps'] as num).toInt(),
                rewardsRedeemed: (row['redeemed'] as num).toInt(),
                goal: goal,
              ),
            ))
        .toList();
  }

  Future<void> addLoyaltyStamp(int customerId,
      {String? note, String source = LoyaltySource.manual}) async {
    final db = await DBHelper().database;
    await db.insert('loyalty_movements', {
      'customer_id': customerId,
      'date_time': DateTime.now().toIso8601String(),
      'type': LoyaltyType.stamp,
      'amount': 1,
      'note': note,
      'source': source,
    });
    notifyListeners();
  }

  Future<bool> redeemLoyaltyReward(int customerId) async {
    final summary = await getLoyaltySummary(customerId);
    if (summary.rewardsAvailable <= 0) return false;
    final db = await DBHelper().database;
    await db.insert('loyalty_movements', {
      'customer_id': customerId,
      'date_time': DateTime.now().toIso8601String(),
      'type': LoyaltyType.redeem,
      'amount': 1,
      'note': null,
      'source': LoyaltySource.manual,
    });
    notifyListeners();
    return true;
  }

  Future<void> redeemPoints(int customerId, int pointsToRedeem, {double? cashValue}) async {
    final db = await DBHelper().database;
    await db.transaction((txn) async {
      // 1. Descontar puntos
      await txn.rawUpdate(
        'UPDATE customers SET points = points - ? WHERE id = ?',
        [pointsToRedeem, customerId]
      );

      // 2. Si el canje tiene un valor en dinero (descuento), registrar como abono
      if (cashValue != null && cashValue > 0) {
        final movement = CustomerMovement(
          customerId: customerId,
          dateTime: DateTime.now().toIso8601String(),
          type: 'Abono',
          amount: cashValue,
          description: 'Canje de $pointsToRedeem puntos por descuento',
        );
        await txn.insert('customer_movements', movement.toMap());
        
        // Actualizar saldo del cliente
        await txn.rawUpdate(
          'UPDATE customers SET total_pending_balance = total_pending_balance - ? WHERE id = ?',
          [cashValue, customerId]
        );
      }
    });
    await loadCustomers();
  }
}
