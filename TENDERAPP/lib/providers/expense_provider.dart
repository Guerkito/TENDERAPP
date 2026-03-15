import 'package:flutter/material.dart';
import '../api/db_helper.dart';
import '../models/expense_model.dart';

class ExpenseProvider with ChangeNotifier {
  List<ExpenseModel> _expenses = [];

  List<ExpenseModel> get expenses => _expenses;

  Future<void> loadExpenses() async {
    final db = await DBHelper().database;
    final List<Map<String, dynamic>> maps = await db.query('expenses', orderBy: 'date DESC');
    _expenses = List.generate(maps.length, (i) {
      return ExpenseModel.fromMap(maps[i]);
    });
    notifyListeners();
  }

  Future<void> addExpense(ExpenseModel expense) async {
    final db = await DBHelper().database;
    await db.insert('expenses', expense.toMap());
    await loadExpenses();
  }

  Future<void> deleteExpense(int id) async {
    final db = await DBHelper().database;
    await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
    await loadExpenses();
  }

  // Calculate total expenses for a specific period (optional logic can be added here)
  double get totalExpenses {
    return _expenses.fold(0.0, (sum, item) => sum + item.amount);
  }
}
