import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/statistics_provider.dart';
import '../api/currency_formatter.dart';
import '../constants/app_constants.dart';

class CashRegisterScreen extends StatefulWidget {
  const CashRegisterScreen({super.key});

  @override
  State<CashRegisterScreen> createState() => _CashRegisterScreenState();
}

class _CashRegisterScreenState extends State<CashRegisterScreen> {
  bool _isLoading = true;
  final Map<int, int> _denominations = {
    100000: 0,
    50000: 0,
    20000: 0,
    10000: 0,
    5000: 0,
    2000: 0,
    1000: 0,
    500: 0,
    200: 0,
    100: 0,
    50: 0,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    await Provider.of<StatisticsProvider>(context, listen: false)
        .loadStatistics(year: now.year, month: now.month, day: now.day);
    if (mounted) setState(() => _isLoading = false);
  }

  double get _countedCash {
    return _denominations.entries
        .fold(0.0, (sum, e) => sum + e.key * e.value);
  }

  @override
  Widget build(BuildContext context) {
    final stats = Provider.of<StatisticsProvider>(context);
    final cashSales =
        stats.paymentsBreakdown[PaymentMethod.cash] ?? 0.0;
    final difference = _countedCash - cashSales;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Cierre de Caja',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00DF82)))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildSectionTitle('Resumen de hoy'),
                const SizedBox(height: 12),
                _buildSummaryCard(stats),
                const SizedBox(height: 24),
                _buildSectionTitle('Arqueo de efectivo'),
                const SizedBox(height: 12),
                _buildDenominationsCard(),
                const SizedBox(height: 24),
                _buildDifferenceCard(cashSales, difference),
                const SizedBox(height: 40),
              ],
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: Color(0xFF1A1A1A),
          letterSpacing: -0.5),
    );
  }

  Widget _buildSummaryCard(StatisticsProvider stats) {
    final methodIcons = {
      PaymentMethod.cash: Icons.payments,
      PaymentMethod.card: Icons.credit_card,
      PaymentMethod.nequi: Icons.phone_android,
      PaymentMethod.credit: Icons.book,
      PaymentMethod.mixed: Icons.compare_arrows,
    };
    final methodColors = {
      PaymentMethod.cash: Colors.green,
      PaymentMethod.card: Colors.blue,
      PaymentMethod.nequi: Colors.purple,
      PaymentMethod.credit: Colors.red,
      PaymentMethod.mixed: Colors.orange,
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        children: [
          _buildSummaryRow('Total Ventas', stats.totalSalesAmount,
              Icons.trending_up, const Color(0xFF00DF82)),
          const Divider(height: 20),
          ...stats.salesByPaymentMethod.entries
              .where((e) => e.value > 0)
              .map((e) => _buildSummaryRow(
                    e.key,
                    e.value,
                    methodIcons[e.key] ?? Icons.payments,
                    methodColors[e.key] ?? Colors.grey,
                    indent: true,
                  )),
          if (stats.salesByPaymentMethod.isNotEmpty) const Divider(height: 20),
          _buildSummaryRow('Total Gastos', stats.totalExpenses,
              Icons.receipt_long, Colors.red),
          const Divider(height: 20),
          _buildSummaryRow(
            'Utilidad Estimada',
            stats.totalSalesAmount - stats.totalExpenses,
            Icons.account_balance_wallet,
            const Color(0xFF1A3C2B),
            bold: true,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '${stats.dailyTransactionCount} transacciones',
                style:
                    const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double value, IconData icon, Color color,
      {bool indent = false, bool bold = false}) {
    return Padding(
      padding: EdgeInsets.only(left: indent ? 16 : 0, bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                      fontSize: indent ? 13 : 14,
                      color: indent ? Colors.grey[600] : const Color(0xFF1A1A1A),
                      fontWeight: bold ? FontWeight.w800 : FontWeight.normal)),
            ],
          ),
          Text(
            CurrencyFormatter.format(value),
            style: TextStyle(
                fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
                fontSize: indent ? 13 : 14,
                color: bold ? color : const Color(0xFF1A1A1A)),
          ),
        ],
      ),
    );
  }

  Widget _buildDenominationsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        children: [
          ..._denominations.keys.map((denom) => _buildDenomRow(denom)),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total contado',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              Text(
                CurrencyFormatter.format(_countedCash),
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1A3C2B)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDenomRow(int denom) {
    final count = _denominations[denom]!;
    final label = denom >= 1000
        ? '\$${(denom ~/ 1000)}k'
        : '\$$denom';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 56,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
                color: const Color(0xFF00DF82).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
            alignment: Alignment.center,
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF1A3C2B))),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline,
                color: Colors.grey, size: 22),
            onPressed: count > 0
                ? () => setState(() => _denominations[denom] = count - 1)
                : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 36,
            child: Text(
              '$count',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.add_circle_outline,
                color: Color(0xFF00DF82), size: 22),
            onPressed: () =>
                setState(() => _denominations[denom] = count + 1),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const Spacer(),
          Text(
            count > 0 ? CurrencyFormatter.format((denom * count).toDouble()) : '',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildDifferenceCard(double expected, double difference) {
    final isExact = difference.abs() < 1;
    final isSurplus = difference > 0;
    final color = isExact
        ? Colors.green
        : isSurplus
            ? Colors.blue
            : const Color(0xFFFF3B30);
    final label = isExact
        ? 'Cuadre exacto'
        : isSurplus
            ? 'Sobrante'
            : 'Faltante';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color)),
          const SizedBox(height: 8),
          Text(
            CurrencyFormatter.format(difference.abs()),
            style: TextStyle(
                fontSize: 32, fontWeight: FontWeight.w900, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            'Efectivo esperado: ${CurrencyFormatter.format(expected)}',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          Text(
            'Efectivo contado: ${CurrencyFormatter.format(_countedCash)}',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
