import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/sale_provider.dart';
import '../providers/statistics_provider.dart';
import '../api/db_helper.dart';
import '../api/currency_formatter.dart';
import '../constants/app_constants.dart';

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
    final maps = await db.rawQuery('''
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
                    final date = DateTime.parse(sale['sale_date'] as String);
                    final isCancelled =
                        (sale['status'] as String?) == SaleStatus.cancelled;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isCancelled
                              ? Colors.red.withOpacity(0.1)
                              : const Color(0xFF00DF82).withOpacity(0.1),
                          child: Icon(
                            isCancelled
                                ? Icons.cancel_outlined
                                : Icons.receipt_long,
                            color: isCancelled
                                ? Colors.red
                                : const Color(0xFF1A3C2B),
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(
                              CurrencyFormatter.format(
                                  (sale['total_amount'] as num).toDouble()),
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                decoration: isCancelled
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: isCancelled ? Colors.grey : null,
                              ),
                            ),
                            if (isCancelled) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('ANULADA',
                                    style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          '${DateFormat('dd MMM, hh:mm a').format(date)} • ${sale['payment_method']}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showSaleDetails(sale),
                      ),
                    );
                  },
                ),
    );
  }

  void _showSaleDetails(Map<String, dynamic> sale) async {
    final saleId = sale['id'] as int;
    final db = await DBHelper().database;
    final items = await db.rawQuery('''
      SELECT si.*, p.name
      FROM sale_items si
      JOIN products p ON si.product_id = p.id
      WHERE si.sale_id = ?
    ''', [saleId]);

    // Obtener pagos detallados si existen
    final payments =
        await db.query('sale_payments', where: 'sale_id = ?', whereArgs: [saleId]);

    if (!mounted) return;

    final isCancelled =
        (sale['status'] as String?) == SaleStatus.cancelled;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Detalle de Venta',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                if (isCancelled)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('ANULADA',
                        style: TextStyle(
                            color: Colors.red, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const Divider(height: 32),
            ...items.map((item) {
              final discount =
                  (item['discount'] as num?)?.toDouble() ?? 0.0;
              final unitPrice =
                  (item['price_at_sale'] as num).toDouble();
              final qty = (item['quantity'] as num).toInt();
              final lineTotal = (unitPrice - discount) * qty;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${qty}x ${item['name']}'),
                          if (discount > 0)
                            Text(
                                '-${CurrencyFormatter.format(discount)} desc.',
                                style: const TextStyle(
                                    color: Colors.red, fontSize: 12)),
                        ],
                      ),
                    ),
                    Text(CurrencyFormatter.format(lineTotal)),
                  ],
                ),
              );
            }),
            const Divider(height: 32),
            // Desglose de pagos
            if (payments.isNotEmpty) ...[
              const Text('Pagos:',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.grey)),
              ...payments.map((p) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(p['payment_method'] as String,
                            style: const TextStyle(fontSize: 13)),
                        Text(
                            CurrencyFormatter.format(
                                (p['amount'] as num).toDouble()),
                            style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  )),
              const Divider(height: 20),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('TOTAL',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  CurrencyFormatter.format(items.fold(
                      0.0,
                      (sum, item) =>
                          sum +
                          ((item['price_at_sale'] as num).toDouble() -
                                  ((item['discount'] as num?)?.toDouble() ??
                                      0.0)) *
                              (item['quantity'] as num).toInt())),
                  style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: Color(0xFF00DF82)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (!isCancelled)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _confirmCancel(context, saleId),
                  icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                  label: const Text('ANULAR VENTA',
                      style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _confirmCancel(BuildContext sheetContext, int saleId) async {
    Navigator.pop(sheetContext);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Anular venta?'),
        content: const Text(
            'Esta acción revertirá el inventario y los cobros de fiado asociados. No se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('CANCELAR')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ANULAR'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final saleProvider =
            Provider.of<SaleProvider>(context, listen: false);
        await saleProvider.cancelSale(saleId);
        Provider.of<StatisticsProvider>(context, listen: false)
            .loadStatistics();
        await _loadSales();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Venta anulada. Inventario restaurado.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error al anular: $e')));
        }
      }
    }
  }
}
