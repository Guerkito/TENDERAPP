import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../api/db_helper.dart';
import '../models/customer_model.dart';
import '../models/customer_movement_model.dart';

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
      final adjustment = movement.type == 'Cargo' ? movement.amount : -movement.amount;
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
