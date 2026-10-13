import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../api/currency_formatter.dart';
import '../constants/app_theme.dart';
import '../models/customer_model.dart';
import '../models/loyalty.dart';
import '../providers/customer_provider.dart';
import '../providers/sale_provider.dart';

/// Compras registradas a nombre de un cliente (se abre desde su tarjeta).
class CustomerPurchasesScreen extends StatefulWidget {
  final Customer customer;

  const CustomerPurchasesScreen({super.key, required this.customer});

  @override
  State<CustomerPurchasesScreen> createState() =>
      _CustomerPurchasesScreenState();
}

class _CustomerPurchasesScreenState extends State<CustomerPurchasesScreen> {
  late Future<List<Map<String, dynamic>>> _salesFuture;
  late Future<LoyaltySummary> _stampsFuture;

  @override
  void initState() {
    super.initState();
    _salesFuture = Provider.of<SaleProvider>(context, listen: false)
        .getCustomerSales(widget.customer.id!);
    _stampsFuture = Provider.of<CustomerProvider>(context, listen: false)
        .getLoyaltySummary(widget.customer.id!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('Compras del cliente'),
        backgroundColor: Colors.transparent,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _salesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.forest));
          }
          final sales = snapshot.data ?? [];
          final total = sales.fold<double>(
              0, (sum, sale) => sum + ((sale['total_amount'] as num).toDouble()));

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildHeader(sales.length, total),
              const SizedBox(height: 20),
              if (sales.isEmpty)
                _buildEmpty()
              else
                ...sales.map(_buildSaleTile),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(int count, double total) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.forest,
        borderRadius: BorderRadius.circular(AppRadius.big),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.customer.name,
            style: AppText.displayOnDark.copyWith(fontSize: 20),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            widget.customer.phone.isEmpty
                ? 'Sin celular registrado'
                : 'Cel: ${widget.customer.phone}',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildStat('COMPRAS', '$count'),
              ),
              Expanded(
                child: _buildStat('TOTAL', CurrencyFormatter.format(total)),
              ),
              FutureBuilder<LoyaltySummary>(
                future: _stampsFuture,
                builder: (context, snap) => Expanded(
                  child: _buildStat(
                      'SELLOS', '${snap.data?.currentStamps ?? 0}'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.lime,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value,
              style: AppText.displayOnDark.copyWith(fontSize: 18)),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.lime.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long_outlined,
                color: AppColors.ink, size: 30),
          ),
          const SizedBox(height: 12),
          const Text('Sin compras registradas',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 6),
          const Text(
            'Cuando le registres una venta a nombre de este cliente, aparecerá aquí y sus puntos se sumarán solos.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppColors.muted, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildSaleTile(Map<String, dynamic> sale) {
    final date = DateTime.tryParse(sale['sale_date'] as String? ?? '');
    final method = sale['payment_method'] as String? ?? '';
    final isFiado = method == 'Fiado';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.lime.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shopping_bag_outlined,
                color: AppColors.ink, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date == null
                      ? 'Venta'
                      : DateFormat("d 'de' MMMM · h:mm a", 'es')
                          .format(date),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 13.5),
                ),
                const SizedBox(height: 2),
                Text(
                  isFiado ? 'Fiado' : method,
                  style: TextStyle(
                      color: isFiado ? AppColors.danger : AppColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          Text(
            CurrencyFormatter.format(
                (sale['total_amount'] as num).toDouble()),
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
          ),
        ],
      ),
    );
  }
}
