import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../providers/statistics_provider.dart';
import '../providers/product_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/navigation_provider.dart';
import '../api/currency_formatter.dart';
import 'expiring_products_screen.dart';
import 'inventory_screen.dart';
import 'add_customer_screen.dart';
import 'expenses_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final now = DateTime.now();
    await Provider.of<StatisticsProvider>(context, listen: false).loadStatistics(
      year: now.year,
      month: now.month,
      day: now.day,
    );
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = Provider.of<StatisticsProvider>(context);
    final storeName = Provider.of<SettingsProvider>(context).storeName;
    final productProvider = Provider.of<ProductProvider>(context);
    final navProvider = Provider.of<NavigationProvider>(context, listen: false);

    // Utilidad según brief: Ventas - Gastos
    final dailyUtility = stats.totalSalesAmount - stats.totalExpenses;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Header del Home
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 40),
              decoration: const BoxDecoration(
                color: Color(0xFF1A3C2B),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hola, $storeName',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Resumen operativo de hoy',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00DF82).withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.storefront_rounded, color: Color(0xFF00DF82), size: 28),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                  // Alerta activa (si existe)
                  if (productProvider.lowStockProducts.isNotEmpty || productProvider.expiringProducts.isNotEmpty)
                    _buildActiveAlertCard(productProvider),
                ],
              ),
            ),
          ),

          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: Color(0xFF00DF82))),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildSectionTitle('Acciones Rápidas'),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildQuickAction(
                        'Vender',
                        PhosphorIcons.shoppingBag(PhosphorIconsStyle.bold),
                        const Color(0xFF00DF82),
                        () => navProvider.setIndex(1),
                      ),
                      _buildQuickAction(
                        'Gastos',
                        PhosphorIcons.receipt(PhosphorIconsStyle.bold),
                        const Color(0xFFFF3B30),
                        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpensesScreen())),
                      ),
                      _buildQuickAction(
                        'Cliente',
                        PhosphorIcons.userPlus(PhosphorIconsStyle.bold),
                        const Color(0xFF007AFF),
                        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddCustomerScreen())),
                      ),
                      _buildQuickAction(
                        'Stock',
                        PhosphorIcons.package(PhosphorIconsStyle.bold),
                        const Color(0xFF5856D6),
                        () => navProvider.setIndex(2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _buildSectionTitle('Finanzas del día'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          'Ventas',
                          stats.totalSalesAmount,
                          PhosphorIcons.trendUp(PhosphorIconsStyle.bold),
                          const Color(0xFF00DF82),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildMetricCard(
                          'Gastos',
                          stats.totalExpenses,
                          PhosphorIcons.trendDown(PhosphorIconsStyle.bold),
                          const Color(0xFFFF3B30),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildMetricCard(
                    'Utilidad Estimada',
                    dailyUtility,
                    PhosphorIcons.currencyDollar(PhosphorIconsStyle.bold),
                    const Color(0xFF1A3C2B),
                    isWide: true,
                  ),
                  const SizedBox(height: 32),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: Color(0xFF1A1A1A),
        letterSpacing: -0.5,
      ),
    );
  }

  Widget _buildQuickAction(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.12),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A)),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, double value, IconData icon, Color color, {bool isWide = false}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF8A8A8A),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            CurrencyFormatter.format(value),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1A1A),
              letterSpacing: -1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveAlertCard(ProductProvider provider) {
    final int lowStockCount = provider.lowStockProducts.length;
    final int expiringCount = provider.expiringProducts.length;

    String message = '';
    if (lowStockCount > 0 && expiringCount > 0) {
      message = '$lowStockCount en stock bajo y $expiringCount por vencer';
    } else if (lowStockCount > 0) {
      message = '$lowStockCount productos agotándose';
    } else {
      message = '$expiringCount productos por vencer pronto';
    }

    return InkWell(
      onTap: () {
        if (expiringCount > 0) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpiringProductsScreen()));
        } else {
          Provider.of<NavigationProvider>(context, listen: false).setIndex(2);
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: Color(0xFF00DF82), shape: BoxShape.circle),
              child: const Icon(Icons.bolt_rounded, color: Color(0xFF1A3C2B), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Acción Necesaria',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    message,
                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w400),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 14),
          ],
        ),
      ),
    );
  }
}
