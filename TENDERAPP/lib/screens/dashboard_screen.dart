import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../widgets/motion.dart';
import '../providers/statistics_provider.dart';
import '../providers/product_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/navigation_provider.dart';
import '../api/currency_formatter.dart';
import 'expiring_products_screen.dart';
import 'add_customer_screen.dart';
import 'expenses_screen.dart';
import 'cash_register_screen.dart';

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
    await Provider.of<StatisticsProvider>(context, listen: false)
        .loadStatistics(year: now.year, month: now.month, day: now.day);
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final stats = Provider.of<StatisticsProvider>(context);
    final storeName = Provider.of<SettingsProvider>(context).storeName;
    final productProvider = Provider.of<ProductProvider>(context);
    final navProvider =
        Provider.of<NavigationProvider>(context, listen: false);

    final dailyUtility = stats.totalSalesAmount - stats.totalExpenses;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F7EA),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 40),
              decoration: const BoxDecoration(
                color: Color(0xFF143122),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Hola de nuevo,',
                              style: TextStyle(
                                color: AppColors.lime,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              storeName,
                              style: AppText.displayOnDark.copyWith(
                                  fontSize: 27),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Tu resumen de hoy está abajo',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC6F24E).withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.storefront_rounded,
                            color: Color(0xFFC6F24E), size: 30),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                  if (productProvider.lowStockProducts.isNotEmpty ||
                      productProvider.expiringProducts.isNotEmpty)
                    _buildActiveAlertCard(productProvider),
                ],
              ),
            ),
          ),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF143122))),
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
                        Icons.shopping_bag,
                        const Color(0xFFC6F24E),
                        () => navProvider.setIndex(1),
                      ),
                      _buildQuickAction(
                        'Gastos',
                        Icons.receipt_long,
                        const Color(0xFFFF3B30),
                        () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ExpensesScreen())),
                      ),
                      _buildQuickAction(
                        'Cliente',
                        Icons.person_add,
                        const Color(0xFFC6F24E),
                        () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AddCustomerScreen())),
                      ),
                      _buildQuickAction(
                        'Stock',
                        Icons.inventory_2,
                        const Color(0xFFC6F24E),
                        () => navProvider.setIndex(2),
                      ),
                      _buildQuickAction(
                        'Caja',
                        Icons.attach_money,
                        const Color(0xFFC6F24E),
                        () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const CashRegisterScreen())),
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
                          Icons.trending_up,
                          const Color(0xFFC6F24E),
                          subtitle: '${stats.dailyTransactionCount} transacciones',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildMetricCard(
                          'Gastos',
                          stats.totalExpenses,
                          Icons.trending_down,
                          const Color(0xFFFF3B30),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildMetricCard(
                    'Utilidad Estimada',
                    dailyUtility,
                    Icons.attach_money,
                    const Color(0xFF143122),
                    isWide: true,
                    filled: true,
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
    return Row(
      children: [
        Container(
          width: 5,
          height: 20,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            color: AppColors.lime,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        Text(
          title,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w900,
            color: AppColors.ink,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAction(
      String label, IconData icon, Color color, VoidCallback onTap) {
    // Fondo suave con el color de la acción; el lima usa icono tinta para
    // no perder contraste sobre claro.
    final iconColor =
        color == AppColors.lime ? AppColors.ink : color;
    return PressScale(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color == AppColors.lime
                  ? AppColors.limeSoft
                  : color.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 25),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, double value, IconData icon, Color color,
      {bool isWide = false, String? subtitle, bool filled = false}) {
    final background =
        filled ? const Color(0xFF143122) : color.withValues(alpha: 0.10);
    final labelColor =
        filled ? const Color(0xFF9BE8C6) : const Color(0xFF5F6B63);
    final valueColor = filled ? Colors.white : const Color(0xFF0F1D14);
    final chipBg =
        filled ? const Color(0xFFC6F24E) : color.withValues(alpha: 0.18);
    final chipIcon =
        color == const Color(0xFFC6F24E) ? const Color(0xFF143122) : color;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: labelColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: chipBg, shape: BoxShape.circle),
                child: Icon(icon, color: chipIcon, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AnimatedCount(
              value: value,
              format: CurrencyFormatter.format,
              style: AppText.display.copyWith(fontSize: 24, color: valueColor),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle,
                style: TextStyle(color: labelColor, fontSize: 12)),
          ],
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
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ExpiringProductsScreen()));
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
              decoration: const BoxDecoration(
                  color: Color(0xFFC6F24E), shape: BoxShape.circle),
              child: const Icon(Icons.bolt_rounded,
                  color: Color(0xFF143122), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Acción Necesaria',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  Text(message,
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w400)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white54, size: 14),
          ],
        ),
      ),
    );
  }
}
