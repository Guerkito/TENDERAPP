import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'currency_formatter.dart';
import '../providers/statistics_provider.dart';
import '../models/product_model.dart';
import '../models/expense_model.dart';

class ReportGenerator {
  static Future<void> generateFinancialReport(StatisticsProvider stats, {int? year, int? month, int? day, String storeName = 'TenderApp'}) async {
    final pdf = pw.Document();
    final period = _getPeriodString(year, month, day);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) => _buildHeader('Reporte Financiero', period, storeName),
        footer: (pw.Context context) => _buildFooter(context),
        build: (pw.Context context) => [
          _buildSummarySection(stats),
          pw.SizedBox(height: 20),
          _buildRankingSection(stats.topSellingProducts),
          pw.SizedBox(height: 20),
          _buildDailySalesSection(stats.dailySales),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Reporte_Financiero_$period',
    );
  }

  static Future<void> generateInventoryReport(List<Product> products, {String storeName = 'TenderApp'}) async {
    final pdf = pw.Document();
    final date = DateFormat('dd/MM/yyyy').format(DateTime.now());
    double totalValue = products.fold(0, (sum, p) => sum + (p.stock * p.salePrice));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) => _buildHeader('Reporte de Inventario', date, storeName),
        footer: (pw.Context context) => _buildFooter(context),
        build: (pw.Context context) => [
          pw.Text('Resumen de Inventario', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.Text('Total de productos: ${products.length}'),
          pw.Text('Valor total de mercancía: ${CurrencyFormatter.format(totalValue)}'),
          pw.SizedBox(height: 20),
          _buildInventoryTable(products),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Reporte_Inventario_$date',
    );
  }

  static Future<void> generateExpensesReport(List<ExpenseModel> expenses, {String storeName = 'TenderApp'}) async {
    final pdf = pw.Document();
    final date = DateFormat('dd/MM/yyyy').format(DateTime.now());
    double total = expenses.fold(0, (sum, e) => sum + e.amount);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) => _buildHeader('Reporte de Gastos', date, storeName),
        footer: (pw.Context context) => _buildFooter(context),
        build: (pw.Context context) => [
          pw.Text('Resumen de Egresos', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.Text('Cantidad de registros: ${expenses.length}'),
          pw.Text('Total egresos: ${CurrencyFormatter.format(total)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
          pw.SizedBox(height: 20),
          _buildExpensesTable(expenses),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Reporte_Gastos_$date',
    );
  }

  static pw.Widget _buildHeader(String title, String subtitle, String storeName) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(title, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
            pw.Text(storeName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
          ],
        ),
        pw.SizedBox(height: 5),
        pw.Text('Periodo/Fecha: $subtitle', style: const pw.TextStyle(color: PdfColors.grey700)),
        pw.Divider(thickness: 2, color: PdfColors.blue900),
        pw.SizedBox(height: 20),
      ],
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Text(
        'Página ${context.pageNumber} de ${context.pagesCount}',
        style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 10),
      ),
    );
  }

  static pw.Widget _buildSummarySection(StatisticsProvider stats) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Resumen Ejecutivo', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        _buildSummaryRow('Ventas Totales', CurrencyFormatter.format(stats.totalSalesAmount)),
        _buildSummaryRow('Gastos Operativos', CurrencyFormatter.format(stats.totalExpenses), color: PdfColors.red900),
        _buildSummaryRow('Utilidad Bruta', CurrencyFormatter.format(stats.grossProfit)),
        _buildSummaryRow('Utilidad Neta', CurrencyFormatter.format(stats.netProfit), isBold: true, color: stats.netProfit >= 0 ? PdfColors.green900 : PdfColors.red900),
      ],
    );
  }

  static pw.Widget _buildSummaryRow(String label, String value, {bool isBold = false, PdfColor color = PdfColors.black}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  static pw.Widget _buildRankingSection(List<Map<String, dynamic>> topProducts) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Top 10 Productos Más Vendidos', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          headers: ['Producto', 'Cantidad', 'Ingresos'],
          data: topProducts.map((p) => [
            p['name'],
            p['totalQuantity'].toString(),
            CurrencyFormatter.format(p['totalRevenue'] as double),
          ]).toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
          cellAlignment: pw.Alignment.centerLeft,
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(2),
          },
        ),
      ],
    );
  }

  static pw.Widget _buildDailySalesSection(Map<String, double> dailySales) {
    if (dailySales.isEmpty) return pw.SizedBox();
    
    final sortedDates = dailySales.keys.toList()..sort((a, b) => b.compareTo(a));

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Detalle de Ventas por Día', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          headers: ['Fecha', 'Total Vendido'],
          data: sortedDates.map((date) => [
            date,
            CurrencyFormatter.format(dailySales[date]!),
          ]).toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey800),
          cellAlignment: pw.Alignment.centerLeft,
        ),
      ],
    );
  }

  static pw.Widget _buildInventoryTable(List<Product> products) {
    return pw.TableHelper.fromTextArray(
      headers: ['Producto', 'Stock', 'Precio Compra', 'Precio Venta', 'Valor Total'],
      data: products.map((p) => [
        p.name,
        '${p.stock} ${p.unit ?? ""}',
        CurrencyFormatter.format(p.purchasePrice),
        CurrencyFormatter.format(p.salePrice),
        CurrencyFormatter.format(p.stock * p.salePrice),
      ]).toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
      cellAlignment: pw.Alignment.centerLeft,
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(2),
        4: const pw.FlexColumnWidth(2),
      },
    );
  }

  static pw.Widget _buildExpensesTable(List<ExpenseModel> expenses) {
    return pw.TableHelper.fromTextArray(
      headers: ['Fecha', 'Descripción', 'Categoría', 'Monto'],
      data: expenses.map((e) => [
        DateFormat('dd/MM/yyyy').format(e.date),
        e.description,
        e.category,
        CurrencyFormatter.format(e.amount),
      ]).toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.red900),
      cellAlignment: pw.Alignment.centerLeft,
    );
  }

  static String _getPeriodString(int? year, int? month, int? day) {
    if (day != null && month != null && year != null) return '$day/$month/$year';
    if (month != null && year != null) return '$month/$year';
    if (year != null) return '$year';
    return 'Total Histórico';
  }
}
