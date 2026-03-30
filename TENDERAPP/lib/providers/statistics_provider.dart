import 'package:flutter/material.dart';
import '../api/db_helper.dart';
import '../models/product_model.dart';

class StatisticsProvider with ChangeNotifier {
  double _totalSalesAmount = 0.0;
  double _totalInventoryValue = 0.0;
  double _totalCollectedFromCustomers = 0.0; // Money from abonos
  double _totalExpenses = 0.0; // Total expenses amount
  double _grossProfit = 0.0; // Sales - Cost of Goods Sold
  
  Map<String, double> _dailySales = {}; // Date string -> sales amount
  Map<int, double> _monthlySalesChartData = {}; // Day of month -> sales amount (for the selected month)
  
  // List of top sold products in the selected period
  List<Map<String, dynamic>> _topSellingProducts = [];
  Map<String, dynamic>? _mostProfitableProduct;

  double get totalSalesAmount => _totalSalesAmount;
  double get totalInventoryValue => _totalInventoryValue;
  double get totalCollectedFromCustomers => _totalCollectedFromCustomers;
  double get totalExpenses => _totalExpenses;
  double get grossProfit => _grossProfit;
  double get netProfit => _grossProfit - _totalExpenses;
  
  Map<String, double> get dailySales => _dailySales;
  Map<int, double> get monthlySalesChartData => _monthlySalesChartData;
  List<Map<String, dynamic>> get topSellingProducts => _topSellingProducts;
  
  Map<String, dynamic>? get bestSellingProduct => _topSellingProducts.isNotEmpty ? _topSellingProducts.first : null;
  Map<String, dynamic>? get mostProfitableProduct => _mostProfitableProduct;

  Future<void> loadStatistics({int? year, int? month, int? day}) async {
    final db = await DBHelper().database;

    // --- Build WHERE Clauses ---
    String filterWhereClause = '';
    List<String> filterWhereArgs = [];
    String expensesWhereClause = '';
    List<String> expensesWhereArgs = [];
    String movementsWhereClause = '';
    String productsWhereClause = '';

    if (year != null && month != null && day != null) {
      // Si tenemos la fecha completa, usamos una comparación directa de fecha
      final dateStr = '${year.toString()}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
      filterWhereClause = ' WHERE DATE(sale_date) = DATE(?)';
      filterWhereArgs = [dateStr];
      
      expensesWhereClause = ' WHERE DATE(date) = DATE(?)';
      expensesWhereArgs = [dateStr];
      
      movementsWhereClause = ' WHERE DATE(date_time) = DATE(?)';
      
      productsWhereClause = ' WHERE DATE(s.sale_date) = DATE(?)';
    } else {
      // 1. General Filter (for Total Sales, Top Products, etc.)
      if (year != null) {
        filterWhereClause += ' WHERE SUBSTR(sale_date, 1, 4) = ?';
        filterWhereArgs.add(year.toString());
      }
      if (month != null) {
        String connector = filterWhereClause.isEmpty ? ' WHERE' : ' AND';
        filterWhereClause += '$connector SUBSTR(sale_date, 6, 2) = ?';
        filterWhereArgs.add(month.toString().padLeft(2, '0'));
      }
      if (day != null) {
        String connector = filterWhereClause.isEmpty ? ' WHERE' : ' AND';
        filterWhereClause += '$connector SUBSTR(sale_date, 9, 2) = ?';
        filterWhereArgs.add(day.toString().padLeft(2, '0'));
      }

      // Filter for expenses
      if (year != null) {
        expensesWhereClause += ' WHERE SUBSTR(date, 1, 4) = ?';
        expensesWhereArgs.add(year.toString());
      }
      if (month != null) {
        String connector = expensesWhereClause.isEmpty ? ' WHERE' : ' AND';
        expensesWhereClause += '$connector SUBSTR(date, 6, 2) = ?';
        expensesWhereArgs.add(month.toString().padLeft(2, '0'));
      }
      if (day != null) {
        String connector = expensesWhereClause.isEmpty ? ' WHERE' : ' AND';
        expensesWhereClause += '$connector SUBSTR(date, 9, 2) = ?';
        expensesWhereArgs.add(day.toString().padLeft(2, '0'));
      }

      // Filter for customer movements
      if (year != null) {
        movementsWhereClause += ' WHERE SUBSTR(date_time, 1, 4) = ?';
      }
      if (month != null) {
        String connector = movementsWhereClause.isEmpty ? ' WHERE' : ' AND';
        movementsWhereClause += '$connector SUBSTR(date_time, 6, 2) = ?';
      }
      if (day != null) {
        String connector = movementsWhereClause.isEmpty ? ' WHERE' : ' AND';
        movementsWhereClause += '$connector SUBSTR(date_time, 9, 2) = ?';
      }
      
      // Alias for joined queries
      if (year != null) {
        productsWhereClause += ' WHERE SUBSTR(s.sale_date, 1, 4) = ?';
      }
      if (month != null) {
        String connector = productsWhereClause.isEmpty ? ' WHERE' : ' AND';
        productsWhereClause += '$connector SUBSTR(s.sale_date, 6, 2) = ?';
      }
      if (day != null) {
        String connector = productsWhereClause.isEmpty ? ' WHERE' : ' AND';
        productsWhereClause += '$connector SUBSTR(s.sale_date, 9, 2) = ?';
      }
    }

    // 2. Monthly Chart Filter (Always for the selected month/year, ignores day filter for the chart context)
    // If no year/month selected, defaults to current.
    final now = DateTime.now();
    final chartYear = year ?? now.year;
    final chartMonth = month ?? now.month;
    
    String chartWhereClause = ' WHERE SUBSTR(sale_date, 1, 4) = ? AND SUBSTR(sale_date, 6, 2) = ?';
    List<String> chartWhereArgs = [
      chartYear.toString(),
      chartMonth.toString().padLeft(2, '0')
    ];

    // --- Execute Queries ---

    // 1. Total Sales Amount (Filtered)
    final List<Map<String, dynamic>> salesResult =
        await db.rawQuery('SELECT SUM(total_amount) as total FROM sales $filterWhereClause', filterWhereArgs);
    _totalSalesAmount = (salesResult.first['total'] as num?)?.toDouble() ?? 0.0;

    // 2. Total Collected from Customers (Abonos)
    final List<Map<String, dynamic>> abonosResult = await db.rawQuery(
        "SELECT SUM(amount) as total FROM customer_movements $movementsWhereClause ${movementsWhereClause.isEmpty ? 'WHERE' : 'AND'} type = 'Abono'", filterWhereArgs);
    _totalCollectedFromCustomers = (abonosResult.first['total'] as num?)?.toDouble() ?? 0.0;
    
    // 3. Total Expenses
    final List<Map<String, dynamic>> expensesResult = await db.rawQuery(
        "SELECT SUM(amount) as total FROM expenses $expensesWhereClause", expensesWhereArgs);
    _totalExpenses = (expensesResult.first['total'] as num?)?.toDouble() ?? 0.0;

    // 4. Gross Profit (Sales - Cost)
    // We calculate profit per item: (sale_price - purchase_price) * quantity
    // Note: This uses the CURRENT purchase_price of the product.
    final List<Map<String, dynamic>> profitResult = await db.rawQuery('''
      SELECT SUM((si.price_at_sale - p.purchase_price) * si.quantity) as totalProfit
      FROM sale_items si
      JOIN sales s ON si.sale_id = s.id
      JOIN products p ON si.product_id = p.id
      $productsWhereClause
    ''', filterWhereArgs);
    _grossProfit = (profitResult.first['totalProfit'] as num?)?.toDouble() ?? 0.0;

    // 5. Daily Sales List (Filtered)
    // If a specific day is selected, this will return just that day. 
    // If month is selected, returns days of that month.
    final List<Map<String, dynamic>> dailySalesResult = await db.rawQuery(
        'SELECT SUBSTR(sale_date, 1, 10) as saleDay, SUM(total_amount) as dailyTotal FROM sales $filterWhereClause GROUP BY saleDay ORDER BY saleDay DESC', filterWhereArgs);
    _dailySales = {
      for (var row in dailySalesResult) row['saleDay']: (row['dailyTotal'] as double?) ?? 0.0
    };

    // 3. Monthly Chart Data (For the graph of the month)
    final List<Map<String, dynamic>> chartResult = await db.rawQuery(
        'SELECT CAST(SUBSTR(sale_date, 9, 2) as INTEGER) as dayOfMonth, SUM(total_amount) as dailyTotal FROM sales $chartWhereClause GROUP BY dayOfMonth ORDER BY dayOfMonth ASC', chartWhereArgs);
    
    _monthlySalesChartData = {};
    // Initialize all days of the month with 0
    int daysInMonth = DateTime(chartYear, chartMonth + 1, 0).day;
    for (int i = 1; i <= daysInMonth; i++) {
      _monthlySalesChartData[i] = 0.0;
    }
    // Fill with actual data
    for (var row in chartResult) {
      _monthlySalesChartData[row['dayOfMonth']] = (row['dailyTotal'] as double?) ?? 0.0;
    }

    // 4. Top Selling Products (Filtered by the selected period)
    // We need to join sale_items with sales to apply the date filter
    String productsQuery = '''
      SELECT p.name, SUM(si.quantity) as totalQuantity, SUM(si.quantity * si.price_at_sale) as totalRevenue
      FROM sale_items si
      JOIN sales s ON si.sale_id = s.id
      JOIN products p ON si.product_id = p.id
      $filterWhereClause
      GROUP BY p.id, p.name
      ORDER BY totalQuantity DESC
      LIMIT 10
    ''';
    // Note: The WHERE clause for productsQuery needs to be adapted because 'sale_date' is in 'sales' table (aliased as 's')
    // The constructed filterWhereClause uses 'sale_date', so we might need to prefix it if ambiguous, 
    // but here 'sale_date' is only in 'sales', so it should be fine. 
    // However, to be safe and correct SQL, let's replace "sale_date" with "s.sale_date" in the clause if we reused the string.
    // Actually, simply using the clause string might be risky if we have joins.
    // Let's rebuild the clause for the join query to be safe with alias 's'.
    
    // Re-construct the query with the specific alias clause
    productsQuery = '''
      SELECT p.name, SUM(si.quantity) as totalQuantity, SUM(si.quantity * si.price_at_sale) as totalRevenue
      FROM sale_items si
      JOIN sales s ON si.sale_id = s.id
      JOIN products p ON si.product_id = p.id
      $productsWhereClause
      GROUP BY p.id, p.name
      ORDER BY totalQuantity DESC
      LIMIT 10
    ''';

    final List<Map<String, dynamic>> productsResult = await db.rawQuery(productsQuery, filterWhereArgs);
    _topSellingProducts = List<Map<String, dynamic>>.from(productsResult);
    
    // 5. Most Profitable Product (Filtered)
    // Profit = (price_at_sale - purchase_price) * quantity
    String profitableQuery = '''
      SELECT p.name, SUM(si.quantity * (si.price_at_sale - p.purchase_price)) as totalProfit
      FROM sale_items si
      JOIN sales s ON si.sale_id = s.id
      JOIN products p ON si.product_id = p.id
      $productsWhereClause
      GROUP BY p.id, p.name
      ORDER BY totalProfit DESC
      LIMIT 1
    ''';
    final List<Map<String, dynamic>> profitableResult = await db.rawQuery(profitableQuery, filterWhereArgs);
    if (profitableResult.isNotEmpty) {
      _mostProfitableProduct = profitableResult.first;
    } else {
      _mostProfitableProduct = null;
    }


    // 6. Total Inventory Value (Always current state, not filtered by sales date)
    final List<Map<String, dynamic>> inventoryResult = await db.rawQuery(
        'SELECT SUM(stock * sale_price) as total FROM products');
    _totalInventoryValue = (inventoryResult.first['total'] as double?) ?? 0.0;

    notifyListeners();
  }
}
