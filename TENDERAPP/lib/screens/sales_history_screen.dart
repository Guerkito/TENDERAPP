import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/sale_provider.dart';
import '../api/db_helper.dart';
import '../api/currency_formatter.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  List<Map<String, dynamic>> _sales = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  Future<void> _loadSales() async {
    final db = await DBHelper().database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT s.*, c.name as customer_name 
      FROM sales s 
      LEFT JOIN customers c ON s.customer_id = c.id 
      ORDER BY s.sale_date DESC
    ''');
    setState(() {
      _sales = maps;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Historial de Ventas'),
        backgroundColor: Colors.white,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _sales.isEmpty 
          ? const Center(child: Text('No hay ventas registradas'))
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _sales.length,
              itemBuilder: (context, index) {
                final sale = _sales[index];
                final date = DateTime.parse(sale['sale_date']);
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF00DF82).withOpacity(0.1),
                      child: const Icon(Icons.receipt_long, color: Color(0xFF1A3C2B)),
                    ),
                    title: Text(
                      CurrencyFormatter.format((sale['total_amount'] as num).toDouble()),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text(
                      '${DateFormat('dd MMM, hh:mm a').format(date)} • ${sale['payment_method']}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showSaleDetails(sale['id']),
                  ),
                );
              },
            ),
    );
  }

  void _showSaleDetails(int saleId) async {
    final db = await DBHelper().database;
    final List<Map<String, dynamic>> items = await db.rawQuery('''
      SELECT si.*, p.name 
      FROM sale_items si 
      JOIN products p ON si.product_id = p.id 
      WHERE si.sale_id = ?
    ''', [saleId]);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Detalle de Venta', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Divider(height: 32),
            ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${item['quantity']}x ${item['name']}'),
                  Text(CurrencyFormatter.format((item['price_at_sale'] * item['quantity'] as num).toDouble())),
                ],
              ),
            )).toList(),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  CurrencyFormatter.format(items.fold(0.0, (sum, item) => sum + (item['price_at_sale'] * item['quantity']))),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF00DF82)),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
