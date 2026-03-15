import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/sale_model.dart';
import 'currency_formatter.dart';

class ReceiptItem {
  final String name;
  final num quantity;
  final double price;
  final String unit;

  ReceiptItem({
    required this.name,
    required this.quantity,
    required this.price,
    this.unit = '',
  });
}

class PdfGenerator {
  static Future<void> generateReceipt(Sale sale, List<ReceiptItem> items, String? customerName, {String storeName = 'TenderApp Store'}) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(5), // Minimal margin for thermal printer
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(storeName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
              ),
              pw.SizedBox(height: 5),
              pw.Center(child: pw.Text('Comprobante de Venta', style: const pw.TextStyle(fontSize: 10))),
              pw.Divider(),
              pw.Text('Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(sale.saleDate))}', style: const pw.TextStyle(fontSize: 10)),
              if (customerName != null) pw.Text('Cliente: $customerName', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('Pago: ${sale.paymentMethod}', style: const pw.TextStyle(fontSize: 10)),
              pw.Divider(),
              
              // Items Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(child: pw.Text('Prod.', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                  pw.Text('Cant.', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  pw.SizedBox(width: 10),
                  pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                ],
              ),
              pw.Divider(thickness: 0.5),

              // Items List
              ...items.map((item) {
                return pw.Container(
                  margin: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          item.name,
                          style: const pw.TextStyle(fontSize: 10),
                          maxLines: 2,
                          overflow: pw.TextOverflow.clip,
                        ),
                      ),
                      pw.Text('${item.quantity} ${item.unit}', style: const pw.TextStyle(fontSize: 10)),
                      pw.SizedBox(width: 10),
                      pw.Text(
                        CurrencyFormatter.format(item.price * item.quantity),
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                );
              }).toList(),

              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                  pw.Text(
                    CurrencyFormatter.format(sale.totalAmount),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Center(child: pw.Text('¡Gracias por su compra!', style: const pw.TextStyle(fontSize: 10))),
              pw.SizedBox(height: 10),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Recibo-${sale.id}',
    );
  }
}
