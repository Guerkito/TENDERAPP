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
    final daysInMonth = _getDaysInMonth(_selectedYear, _selectedMonth);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              decoration: const InputDecoration(labelText: 'Año', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)),
              value: _selectedYear,
              items: List.generate(5, (index) => DropdownMenuItem(value: DateTime.now().year - 2 + index, child: Text((DateTime.now().year - 2 + index).toString()))),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedYear = value);
                  _loadData();
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<int>(
              decoration: const InputDecoration(labelText: 'Mes', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)),
              value: _selectedMonth,
              items: List.generate(12, (index) => DropdownMenuItem(value: index + 1, child: Text(_getMonthName(index + 1)))),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedMonth = value);
                  _loadData();
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<int?>(
              decoration: const InputDecoration(labelText: 'Día', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)),
              value: _selectedDay,
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('Todos')),
                ...List.generate(daysInMonth, (index) => DropdownMenuItem(value: index + 1, child: Text((index + 1).toString()))),
              ],
              onChanged: (value) {
                setState(() => _selectedDay = value);
                _loadData();
              },
            ),
          ),
        ],
      ),
    );
  }

  int _getDaysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

  Widget _buildSummaryCard(BuildContext context, String title, String value, Color color, {IconData? icon, double? width}) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.1), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(color: color.withOpacity(0.8), fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 24)),
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    return months[month - 1];
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
