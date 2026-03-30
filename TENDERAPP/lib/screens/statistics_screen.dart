import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/statistics_provider.dart';
import '../providers/settings_provider.dart';
import '../api/currency_formatter.dart';
import '../api/report_generator.dart';
import '../widgets/info_banner.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  bool _showTutorial = true;
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  int? _selectedDay;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    Provider.of<StatisticsProvider>(context, listen: false).loadStatistics(
      year: _selectedYear,
      month: _selectedMonth,
      day: _selectedDay,
    );
  }

  @override
  Widget build(BuildContext context) {
    final statsProvider = Provider.of<StatisticsProvider>(context);
    final chartData = statsProvider.monthlySalesChartData;

    // Prepare spots for the chart
    final List<FlSpot> spots = [];
    if (chartData.isNotEmpty) {
      final sortedDays = chartData.keys.toList()..sort();
      for (var day in sortedDays) {
        spots.add(FlSpot(day.toDouble(), chartData[day]!));
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estadísticas Financieras'),
        actions: [
          IconButton(
            icon: const Icon(Icons.table_chart),
            tooltip: 'Exportar Excel',
            onPressed: () => ReportGenerator.generateExcelReport(
              statsProvider,
              year: _selectedYear,
              month: _selectedMonth,
              day: _selectedDay,
              storeName: Provider.of<SettingsProvider>(context, listen: false).storeName,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Exportar Reporte PDF',
            onPressed: () => ReportGenerator.generateFinancialReport(
              statsProvider,
              year: _selectedYear,
              month: _selectedMonth,
              day: _selectedDay,
              storeName: Provider.of<SettingsProvider>(context, listen: false).storeName,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildFilters(context),
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Banner Guía
                    if (_showTutorial)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: InfoBanner(
                          text: 'Analiza la salud de tu negocio. Revisa tus ventas diarias, gastos operativos y la ganancia neta real del periodo.',
                          icon: Icons.auto_graph,
                          color: Colors.deepPurple,
                          onClose: () => setState(() => _showTutorial = false),
                        ),
                      ),

                    // Financial Summary Section
                    Text(
                      'Resumen del Periodo',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 15),
                    
                    // Sustituimos GridView por Wrap para evitar errores de layout
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildSummaryCard(
                          context,
                          'Ventas',
                          CurrencyFormatter.format(statsProvider.totalSalesAmount),
                          Colors.blue,
                          icon: Icons.shopping_cart,
                          width: (MediaQuery.of(context).size.width - 44) / 2,
                        ),
                        _buildSummaryCard(
                          context,
                          'Gastos',
                          CurrencyFormatter.format(statsProvider.totalExpenses),
                          Colors.red,
                          icon: Icons.money_off,
                          width: (MediaQuery.of(context).size.width - 44) / 2,
                        ),
                        _buildSummaryCard(
                          context,
                          'Ganancia Bruta',
                          CurrencyFormatter.format(statsProvider.grossProfit),
                          Colors.orange,
                          icon: Icons.trending_up,
                          width: (MediaQuery.of(context).size.width - 44) / 2,
                        ),
                        _buildSummaryCard(
                          context,
                          'Ganancia Neta',
                          CurrencyFormatter.format(statsProvider.netProfit),
                          statsProvider.netProfit >= 0 ? Colors.green : Colors.redAccent,
                          icon: Icons.attach_money,
                          width: (MediaQuery.of(context).size.width - 44) / 2,
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),

                    // Chart Section
                    Text(
                      'Ventas Diarias (Este Mes)',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 15),
                    Container(
                      height: 250,
                      padding: const EdgeInsets.only(right: 20, top: 20, bottom: 10, left: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: spots.isEmpty 
                        ? const Center(child: Text('Sin datos para el gráfico'))
                        : LineChart(
                          LineChartData(
                            lineTouchData: LineTouchData(
                              touchTooltipData: LineTouchTooltipData(
                                getTooltipColor: (touchedSpot) => Colors.blueGrey.withOpacity(0.8),
                                getTooltipItems: (List<LineBarSpot> touchedSpots) {
                                  return touchedSpots.map((spot) {
                                    return LineTooltipItem(
                                      'Día ${spot.x.toInt()}\n',
                                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      children: [
                                        TextSpan(
                                          text: CurrencyFormatter.format(spot.y),
                                          style: const TextStyle(color: Color(0xFF00DF82), fontWeight: FontWeight.w900),
                                        ),
                                      ],
                                    );
                                  }).toList();
                                },
                              ),
                            ),
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              horizontalInterval: _calculateInterval(spots),
                              getDrawingHorizontalLine: (value) => FlLine(
                                color: Colors.grey.withOpacity(0.1),
                                strokeWidth: 1,
                              ),
                            ),
                            titlesData: FlTitlesData(
                              show: true,
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 30,
                                  interval: 5, 
                                  getTitlesWidget: (value, meta) {
                                    if (value < 1 || value > 31) return const SizedBox.shrink();
                                    return Text(value.toInt().toString(), style: const TextStyle(color: Colors.grey, fontSize: 10));
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) => Text(compactNumber(value), style: const TextStyle(color: Colors.grey, fontSize: 10)),
                                  reservedSize: 45,
                                ),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: spots,
                                isCurved: true,
                                color: Theme.of(context).primaryColor,
                                barWidth: 4,
                                isStrokeCapRound: true,
                                dotData: const FlDotData(show: false),
                                belowBarData: BarAreaData(
                                  show: true,
                                  gradient: LinearGradient(
                                    colors: [
                                      Theme.of(context).primaryColor.withOpacity(0.3),
                                      Theme.of(context).primaryColor.withOpacity(0),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                            ],
                            minX: 1,
                            maxX: 31, 
                            minY: 0,
                          ),
                        ),
                    ),

                    const SizedBox(height: 30),

                    // Top Products Section
                    Text(
                      'Ranking de Productos',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 15),
                    statsProvider.topSellingProducts.isEmpty
                        ? const Center(child: Padding(
                            padding: EdgeInsets.all(30.0),
                            child: Text('No hay ventas para mostrar en el ranking.'),
                          ))
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: statsProvider.topSellingProducts.length,
                            itemBuilder: (context, index) {
                              final product = statsProvider.topSellingProducts[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                                    child: Text('${index + 1}', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
                                  ),
                                  title: Text(product['name'] ?? 'Desconocido', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('Vendidos: ${product['totalQuantity']} unidades'),
                                  trailing: Text(
                                    CurrencyFormatter.format(product['totalRevenue'] as double),
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                                  ),
                                ),
                              );
                            },
                          ),
                    
                    const SizedBox(height: 30),

                    // Highlights Section
                    if (statsProvider.bestSellingProduct != null || statsProvider.mostProfitableProduct != null) ...[
                      Text(
                        'Desempeño Destacado',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 15),
                      if (statsProvider.bestSellingProduct != null)
                        _buildProductHighlightCard(
                          context,
                          'Líder en Ventas',
                          statsProvider.bestSellingProduct!['name'] ?? 'N/A',
                          'Volumen: ${statsProvider.bestSellingProduct!['totalQuantity']} unidades',
                          Icons.workspace_premium,
                          Colors.amber,
                        ),
                      const SizedBox(height: 12),
                      if (statsProvider.mostProfitableProduct != null)
                        _buildProductHighlightCard(
                          context,
                          'Más Rentable',
                          statsProvider.mostProfitableProduct!['name'] ?? 'N/A',
                          'Margen: ${CurrencyFormatter.format((statsProvider.mostProfitableProduct!['totalProfit'] as num).toDouble())}',
                          Icons.trending_up,
                          Colors.green,
                        ),
                       const SizedBox(height: 30),
                    ],
                    
                    // Inventory Value
                    _buildSummaryCard(
                      context,
                      'Valor Total de Mercancía',
                      CurrencyFormatter.format(statsProvider.totalInventoryValue),
                      Colors.blueGrey,
                      icon: Icons.inventory_2,
                      width: double.infinity,
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductHighlightCard(BuildContext context, String title, String productName, String subtitle, IconData icon, Color color) {
    return Card(
      elevation: 0,
      color: color.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: color.withOpacity(0.2))),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Icon(icon, color: color, size: 40),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title.toUpperCase(), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                  const SizedBox(height: 6),
                  Text(productName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Year and Day Selectors (Horizontal Chips)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _buildFilterChip(
                  label: 'Año: $_selectedYear',
                  icon: Icons.calendar_today_rounded,
                  onTap: () => _showYearPicker(),
                ),
                const SizedBox(width: 12),
                _buildFilterChip(
                  label: _selectedDay == null ? 'Todo el mes' : 'Día: $_selectedDay',
                  icon: Icons.today_rounded,
                  onTap: () => _showDayPicker(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Month Selector (Horizontal Scroll)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: List.generate(12, (index) {
                final month = index + 1;
                final isSelected = _selectedMonth == month;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedMonth = month);
                    _loadData();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF00DF82) : const Color(0xFFF5F7FA),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getMonthName(month, full: true),
                      style: TextStyle(
                        color: isSelected ? const Color(0xFF1A3C2B) : Colors.grey[600],
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({required String label, required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1A3C2B).withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF1A3C2B)),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF1A3C2B),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showYearPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Seleccionar Año', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              children: List.generate(5, (index) {
                final year = DateTime.now().year - 2 + index;
                return ChoiceChip(
                  label: Text(year.toString()),
                  selected: _selectedYear == year,
                  onSelected: (val) {
                    setState(() => _selectedYear = year);
                    _loadData();
                    Navigator.pop(context);
                  },
                );
              }),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showDayPicker() {
    final daysInMonth = _getDaysInMonth(_selectedYear, _selectedMonth);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text('Seleccionar Día', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, mainAxisSpacing: 10, crossAxisSpacing: 10),
                itemCount: daysInMonth + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildDayItem(null, 'Todo');
                  }
                  return _buildDayItem(index, index.toString());
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayItem(int? day, String label) {
    final isSelected = _selectedDay == day;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedDay = day);
        _loadData();
        Navigator.pop(context);
      },
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00DF82) : const Color(0xFFF5F7FA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF1A3C2B) : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  int _getDaysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

  Widget _buildSummaryCard(BuildContext context, String title, String value, Color color, {IconData? icon, double? width}) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) 
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 20),
            ),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: const TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w900, fontSize: 26, letterSpacing: -1)),
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month, {bool full = false}) {
    const months = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    const shortMonths = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    return full ? months[month - 1] : shortMonths[month - 1];
  }

  double _calculateInterval(List<FlSpot> spots) {
    if (spots.isEmpty) return 1.0;
    double maxVal = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    return maxVal == 0 ? 1.0 : maxVal / 5;
  }
  
  String compactNumber(double number) {
    if (number >= 1000000) return '\$ ${(number / 1000000).toStringAsFixed(1)}M';
    if (number >= 1000) return '\$ ${(number / 1000).toStringAsFixed(0)}K';
    return '\$ ${number.toInt()}';
  }
}
