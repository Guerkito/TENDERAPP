import 'package:flutter/material.dart';
import '../api/db_helper.dart';
import '../constants/app_constants.dart';

class StatisticsProvider with ChangeNotifier {
  double _totalSalesAmount = 0.0;
  double _totalInventoryValue = 0.0;
  double _totalCollectedFromCustomers = 0.0;
  double _totalExpenses = 0.0;
  double _grossProfit = 0.0;
  int _dailyTransactionCount = 0;
  Map<String, double> _salesByPaymentMethod = {};
  Map<String, double> _paymentsBreakdown = {};

  Map<String, double> _dailySales = {};
  Map<int, double> _monthlySalesChartData = {};
  List<Map<String, dynamic>> _topSellingProducts = [];
  Map<String, dynamic>? _mostProfitableProduct;

  double get totalSalesAmount => _totalSalesAmount;
  double get totalInventoryValue => _totalInventoryValue;
  double get totalCollectedFromCustomers => _totalCollectedFromCustomers;
  double get totalExpenses => _totalExpenses;
  double get grossProfit => _grossProfit;
  double get netProfit => _grossProfit - _totalExpenses;
  int get dailyTransactionCount => _dailyTransactionCount;
  Map<String, double> get salesByPaymentMethod => _salesByPaymentMethod;
  // Desglose real de ingresos por método, incluyendo efectivo de ventas mixtas
  Map<String, double> get paymentsBreakdown => _paymentsBreakdown;

  Map<String, double> get dailySales => _dailySales;
  Map<int, double> get monthlySalesChartData => _monthlySalesChartData;
  List<Map<String, dynamic>> get topSellingProducts => _topSellingProducts;

  Map<String, dynamic>? get bestSellingProduct =>
      _topSellingProducts.isNotEmpty ? _topSellingProducts.first : null;
  Map<String, dynamic>? get mostProfitableProduct => _mostProfitableProduct;

  Future<void> loadStatistics({int? year, int? month, int? day}) async {
    final db = await DBHelper().database;

    // --- Construcción de filtros ---
    String filterWhereClause = '';
    List<String> filterWhereArgs = [];
    String expensesWhereClause = '';
    List<String> expensesWhereArgs = [];
    String movementsWhereClause = '';
    String productsWhereClause = '';

    if (year != null && month != null && day != null) {
      final dateStr =
          '${year.toString()}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
      filterWhereClause = ' WHERE DATE(sale_date) = DATE(?)';
      filterWhereArgs = [dateStr];
      expensesWhereClause = ' WHERE DATE(date) = DATE(?)';
      expensesWhereArgs = [dateStr];
      movementsWhereClause = ' WHERE DATE(date_time) = DATE(?)';
      productsWhereClause = ' WHERE DATE(s.sale_date) = DATE(?)';
    } else {
      if (year != null) {
        filterWhereClause += ' WHERE SUBSTR(sale_date, 1, 4) = ?';
        filterWhereArgs.add(year.toString());
      }
      if (month != null) {
        String c = filterWhereClause.isEmpty ? ' WHERE' : ' AND';
        filterWhereClause += '$c SUBSTR(sale_date, 6, 2) = ?';
        filterWhereArgs.add(month.toString().padLeft(2, '0'));
      }
      if (day != null) {
        String c = filterWhereClause.isEmpty ? ' WHERE' : ' AND';
        filterWhereClause += '$c SUBSTR(sale_date, 9, 2) = ?';
        filterWhereArgs.add(day.toString().padLeft(2, '0'));
      }

      if (year != null) {
        expensesWhereClause += ' WHERE SUBSTR(date, 1, 4) = ?';
        expensesWhereArgs.add(year.toString());
      }
      if (month != null) {
        String c = expensesWhereClause.isEmpty ? ' WHERE' : ' AND';
        expensesWhereClause += '$c SUBSTR(date, 6, 2) = ?';
        expensesWhereArgs.add(month.toString().padLeft(2, '0'));
      }
      if (day != null) {
        String c = expensesWhereClause.isEmpty ? ' WHERE' : ' AND';
        expensesWhereClause += '$c SUBSTR(date, 9, 2) = ?';
        expensesWhereArgs.add(day.toString().padLeft(2, '0'));
      }

      if (year != null) {
        movementsWhereClause += ' WHERE SUBSTR(date_time, 1, 4) = ?';
      }
      if (month != null) {
        String c = movementsWhereClause.isEmpty ? ' WHERE' : ' AND';
        movementsWhereClause += '$c SUBSTR(date_time, 6, 2) = ?';
      }
      if (day != null) {
        String c = movementsWhereClause.isEmpty ? ' WHERE' : ' AND';
        movementsWhereClause += '$c SUBSTR(date_time, 9, 2) = ?';
      }

      if (year != null) {
        productsWhereClause += ' WHERE SUBSTR(s.sale_date, 1, 4) = ?';
      }
      if (month != null) {
        String c = productsWhereClause.isEmpty ? ' WHERE' : ' AND';
        productsWhereClause += '$c SUBSTR(s.sale_date, 6, 2) = ?';
      }
      if (day != null) {
        String c = productsWhereClause.isEmpty ? ' WHERE' : ' AND';
        productsWhereClause += '$c SUBSTR(s.sale_date, 9, 2) = ?';
      }
    }

    // Agregar filtro de status=completed a todas las queries de ventas
    final String statusAnd = filterWhereClause.isEmpty ? ' WHERE' : ' AND';
    final String salesFilter =
        "$filterWhereClause$statusAnd status = '${SaleStatus.completed}'";
    final String salesProductsFilter = productsWhereClause.isEmpty
        ? " WHERE s.status = '${SaleStatus.completed}'"
        : "$productsWhereClause AND s.status = '${SaleStatus.completed}'";

    // Gráfico mensual
    final now = DateTime.now();
    final chartYear = year ?? now.year;
    final chartMonth = month ?? now.month;
    final chartWhereClause =
        " WHERE SUBSTR(sale_date, 1, 4) = ? AND SUBSTR(sale_date, 6, 2) = ? AND status = '${SaleStatus.completed}'";
    final chartWhereArgs = [
      chartYear.toString(),
      chartMonth.toString().padLeft(2, '0'),
    ];

    // --- Queries ---

    // 1. Total ventas
    final salesResult = await db.rawQuery(
        'SELECT SUM(total_amount) as total FROM sales $salesFilter',
        filterWhereArgs);
    _totalSalesAmount =
        (salesResult.first['total'] as num?)?.toDouble() ?? 0.0;

    // 2. Contador de transacciones del día
    final txCountResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM sales $salesFilter', filterWhereArgs);
    _dailyTransactionCount =
        (txCountResult.first['count'] as int?) ?? 0;

    // 3. Ventas por método de pago
    final byMethodResult = await db.rawQuery(
        'SELECT payment_method, SUM(total_amount) as total FROM sales $salesFilter GROUP BY payment_method',
        filterWhereArgs);
    _salesByPaymentMethod = {
      for (var row in byMethodResult)
        row['payment_method'] as String:
            (row['total'] as num?)?.toDouble() ?? 0.0
    };

    // 4. Desglose real por método de pago (desde sale_payments, incluye efectivo de ventas mixtas)
    final paymentsResult = await db.rawQuery('''
      SELECT sp.payment_method, SUM(sp.amount) as total
      FROM sale_payments sp
      JOIN sales s ON sp.sale_id = s.id
      $salesProductsFilter
      GROUP BY sp.payment_method
    ''', filterWhereArgs);
    _paymentsBreakdown = {
      for (var row in paymentsResult)
        row['payment_method'] as String:
            (row['total'] as num?)?.toDouble() ?? 0.0
    };

    // 5. Abonos de clientes
    final abonosResult = await db.rawQuery(
        "SELECT SUM(amount) as total FROM customer_movements $movementsWhereClause${movementsWhereClause.isEmpty ? ' WHERE' : ' AND'} type = '${MovementType.payment}'",
        filterWhereArgs);
    _totalCollectedFromCustomers =
        (abonosResult.first['total'] as num?)?.toDouble() ?? 0.0;

    // 5. Total gastos
    final expensesResult = await db.rawQuery(
        'SELECT SUM(amount) as total FROM expenses $expensesWhereClause',
        expensesWhereArgs);
    _totalExpenses =
        (expensesResult.first['total'] as num?)?.toDouble() ?? 0.0;

    // 6. Utilidad bruta
    final profitResult = await db.rawQuery('''
      SELECT SUM((si.price_at_sale - si.discount - p.purchase_price) * si.quantity) as totalProfit
      FROM sale_items si
      JOIN sales s ON si.sale_id = s.id
      JOIN products p ON si.product_id = p.id
      $salesProductsFilter
    ''', filterWhereArgs);
    _grossProfit =
        (profitResult.first['totalProfit'] as num?)?.toDouble() ?? 0.0;

    // 7. Ventas diarias (lista)
    final dailySalesResult = await db.rawQuery(
        "SELECT SUBSTR(sale_date, 1, 10) as saleDay, SUM(total_amount) as dailyTotal FROM sales $salesFilter GROUP BY saleDay ORDER BY saleDay DESC",
        filterWhereArgs);
    _dailySales = {
      for (var row in dailySalesResult)
        row['saleDay'] as String: (row['dailyTotal'] as double?) ?? 0.0
    };

    // 8. Gráfico mensual
    final chartResult = await db.rawQuery(
        'SELECT CAST(SUBSTR(sale_date, 9, 2) as INTEGER) as dayOfMonth, SUM(total_amount) as dailyTotal FROM sales $chartWhereClause GROUP BY dayOfMonth ORDER BY dayOfMonth ASC',
        chartWhereArgs);
    _monthlySalesChartData = {};
    final daysInMonth = DateTime(chartYear, chartMonth + 1, 0).day;
    for (int i = 1; i <= daysInMonth; i++) {
      _monthlySalesChartData[i] = 0.0;
    }
    for (var row in chartResult) {
      _monthlySalesChartData[row['dayOfMonth'] as int] =
          (row['dailyTotal'] as double?) ?? 0.0;
    }

    // 9. Productos más vendidos
    final productsResult = await db.rawQuery('''
      SELECT p.name, SUM(si.quantity) as totalQuantity, SUM(si.quantity * si.price_at_sale) as totalRevenue
      FROM sale_items si
      JOIN sales s ON si.sale_id = s.id
      JOIN products p ON si.product_id = p.id
      $salesProductsFilter
      GROUP BY p.id, p.name
      ORDER BY totalQuantity DESC
      LIMIT 10
    ''', filterWhereArgs);
    _topSellingProducts = List<Map<String, dynamic>>.from(productsResult);

    // 10. Producto más rentable
    final profitableResult = await db.rawQuery('''
      SELECT p.name, SUM(si.quantity * (si.price_at_sale - si.discount - p.purchase_price)) as totalProfit
      FROM sale_items si
      JOIN sales s ON si.sale_id = s.id
      JOIN products p ON si.product_id = p.id
      $salesProductsFilter
      GROUP BY p.id, p.name
      ORDER BY totalProfit DESC
      LIMIT 1
    ''', filterWhereArgs);
    _mostProfitableProduct =
        profitableResult.isNotEmpty ? profitableResult.first : null;

    // 11. Valor total del inventario
    final inventoryResult = await db.rawQuery(
        'SELECT SUM(stock * sale_price) as total FROM products');
    _totalInventoryValue =
        (inventoryResult.first['total'] as double?) ?? 0.0;

    notifyListeners();
  }
}
