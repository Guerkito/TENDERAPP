import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/currency_formatter.dart';
import '../models/product_model.dart';
import '../providers/product_provider.dart';

class ImportProductsScreen extends StatefulWidget {
  const ImportProductsScreen({super.key});

  @override
  State<ImportProductsScreen> createState() => _ImportProductsScreenState();
}

class _ImportProductsScreenState extends State<ImportProductsScreen> {
  bool _parsing = false;
  bool _importing = false;
  String? _error;
  String? _fileName;
  List<Product> _products = [];
  List<String> _rowErrors = [];

  static const Map<String, List<String>> _fieldKeys = {
    'name': [
      'nombre del producto',
      'nombre producto',
      'nombre',
      'producto',
      'articulo',
      'descripcion',
      'name',
    ],
    'barcode': [
      'codigo de barras',
      'codigo barras',
      'barras',
      'codigo',
      'ean',
      'barcode',
    ],
    'category': ['categoria', 'linea', 'familia'],
    'purchase': [
      'precio compra',
      'precio de compra',
      'precio costo',
      'costo unitario',
      'costo',
      'compra',
    ],
    'sale': [
      'precio venta',
      'precio de venta',
      'precio publico',
      'precio al publico',
      'pvp',
      'venta',
      'precio',
    ],
    'stock': [
      'stock',
      'existencia',
      'existencias',
      'cantidad',
      'inventario',
      'unidades',
    ],
    'expiration': [
      'fecha de vencimiento',
      'fecha vencimiento',
      'vencimiento',
      'caducidad',
      'vence',
    ],
    'unit': ['unidad de medida', 'unidad', 'medida', 'um'],
  };

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      setState(() => _error = 'No se pudo leer el archivo.');
      return;
    }
    setState(() {
      _parsing = true;
      _error = null;
      _products = [];
      _rowErrors = [];
      _fileName = file.name;
    });
    try {
      _parse(bytes);
    } catch (e) {
      setState(() {
        _error = 'Error al leer el Excel: $e';
        _parsing = false;
      });
    }
  }

  void _parse(Uint8List bytes) {
    final workbook = Excel.decodeBytes(bytes);
    if (workbook.tables.isEmpty) {
      setState(() {
        _error = 'El archivo no tiene hojas.';
        _parsing = false;
      });
      return;
    }
    final table = workbook.tables[workbook.tables.keys.first]!;
    if (table.rows.isEmpty) {
      setState(() {
        _error = 'La hoja está vacía.';
        _parsing = false;
      });
      return;
    }

    final headers = table.rows.first
        .map((cell) => _normalize(_cellText(cell?.value)))
        .toList();

    final cols = <String, int>{};
    final used = <int>{};
    for (final entry in _fieldKeys.entries) {
      var found = false;
      for (final key in entry.value) {
        for (var i = 0; i < headers.length; i++) {
          if (used.contains(i) || headers[i].isEmpty) continue;
          if (headers[i] == key || headers[i].contains(key)) {
            cols[entry.key] = i;
            used.add(i);
            found = true;
            break;
          }
        }
        if (found) break;
      }
    }

    if (!cols.containsKey('name') || !cols.containsKey('sale')) {
      setState(() {
        _error =
            'No encontré las columnas "Nombre" y "Precio Venta".\nColumnas detectadas: ${headers.where((h) => h.isNotEmpty).join(", ")}';
        _parsing = false;
      });
      return;
    }

    final products = <Product>[];
    final rowErrors = <String>[];

    for (var r = 1; r < table.rows.length; r++) {
      final row = table.rows[r];
      String text(String? field) {
        final col = cols[field];
        if (col == null || col >= row.length) return '';
        return _cellText(row[col]?.value).trim();
      }

      CellValue? value(String? field) {
        final col = cols[field];
        if (col == null || col >= row.length) return null;
        return row[col]?.value;
      }

      final name = text('name');
      if (name.isEmpty) continue;

      final salePrice = _parseNumber(value('sale'));
      if (salePrice <= 0) {
        rowErrors.add('Fila ${r + 1}: "$name" sin precio de venta válido');
        continue;
      }

      final barcode = text('barcode');
      final category = text('category');
      final unit = text('unit');

      products.add(Product(
        name: name,
        barcode: barcode.isEmpty ? null : barcode,
        category: category.isEmpty ? 'General' : category,
        purchasePrice: _parseNumber(value('purchase')),
        salePrice: salePrice,
        stock: _parseNumber(value('stock')),
        expirationDate: _parseDate(value('expiration')),
        unit: unit.isEmpty ? null : unit,
      ));
    }

    setState(() {
      _products = products;
      _rowErrors = rowErrors;
      _parsing = false;
    });
  }

  Future<void> _import() async {
    final provider = Provider.of<ProductProvider>(context, listen: false);
    setState(() => _importing = true);
    try {
      final summary = await provider.importProducts(_products);
      if (!mounted) return;
      setState(() => _importing = false);
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Importación completada'),
          content: Text(
              '${summary.imported} productos importados.\n${summary.skipped} omitidos por ya existir (mismo nombre o código de barras).'),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _importing = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error al importar: $e')));
    }
  }

  String _cellText(CellValue? value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  String _normalize(String text) {
    var s = text.toLowerCase().trim();
    const accents = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ü': 'u',
      'ñ': 'n',
    };
    accents.forEach((k, v) => s = s.replaceAll(k, v));
    return s.replaceAll(RegExp(r'\s+'), ' ');
  }

  double _parseNumber(CellValue? value) {
    if (value == null) return 0;
    if (value is IntCellValue) return value.value.toDouble();
    if (value is DoubleCellValue) return value.value;
    return _parseNumberText(value.toString());
  }

  double _parseNumberText(String raw) {
    var s = raw.replaceAll(RegExp(r'[^0-9,.\-]'), '');
    if (s.isEmpty) return 0;
    if (s.contains(',')) {
      s = s.replaceAll('.', '').replaceAll(',', '.');
    } else if (s.contains('.')) {
      final parts = s.split('.');
      if (parts.length > 2 || parts.last.length == 3) {
        s = s.replaceAll('.', '');
      }
    }
    return double.tryParse(s) ?? 0;
  }

  String? _parseDate(CellValue? value) {
    if (value == null) return null;
    if (value is DateCellValue) {
      return value.asDateTimeLocal().toIso8601String();
    }
    if (value is DateTimeCellValue) {
      return DateTime(value.year, value.month, value.day).toIso8601String();
    }
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    final iso = DateTime.tryParse(text);
    if (iso != null) {
      return DateTime(iso.year, iso.month, iso.day).toIso8601String();
    }
    final match =
        RegExp(r'^(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})$').firstMatch(text);
    if (match != null) {
      var year = int.parse(match.group(3)!);
      if (year < 100) year += 2000;
      return DateTime(
              year, int.parse(match.group(2)!), int.parse(match.group(1)!))
          .toIso8601String();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F7EA),
      appBar: AppBar(
        title: const Text('Importar Productos',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_parsing) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF143122)));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.orange),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _pickFile,
                child: const Text('ELEGIR OTRO ARCHIVO'),
              ),
            ],
          ),
        ),
      );
    }

    if (_products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.upload_file, size: 64, color: Color(0xFF143122)),
              const SizedBox(height: 16),
              const Text(
                'Sube tu Excel de productos (.xlsx)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Columnas reconocidas:\n'
                'Nombre (obligatoria) · Precio Venta (obligatoria)\n'
                'Código de Barras · Categoría · Precio Compra · Stock · Vencimiento · Unidad',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.folder_open),
                label: const Text('ELEGIR ARCHIVO'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC6F24E),
                  foregroundColor: const Color(0xFF143122),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 14),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              const Icon(Icons.description, color: Color(0xFF143122)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_fileName ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      '${_products.length} productos listos para importar'
                      '${_rowErrors.isNotEmpty ? ' · ${_rowErrors.length} filas con problemas' : ''}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.swap_horiz),
                tooltip: 'Cambiar archivo',
                onPressed: _pickFile,
              ),
            ],
          ),
        ),
        if (_rowErrors.isNotEmpty)
          ExpansionTile(
            title: Text('${_rowErrors.length} filas omitidas',
                style: const TextStyle(
                    color: Colors.orange, fontWeight: FontWeight.bold)),
            children: _rowErrors
                .take(20)
                .map((e) => ListTile(
                    dense: true,
                    title: Text(e, style: const TextStyle(fontSize: 12))))
                .toList(),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: _products.length,
            itemBuilder: (context, index) {
              final p = _products[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFF3F7EA),
                  child: Text('${index + 1}',
                      style: const TextStyle(fontSize: 12)),
                ),
                title: Text(p.name),
                subtitle: Text(
                    '${p.category ?? "General"} · Stock: ${p.stock} · ${p.barcode ?? "sin código"}'),
                trailing: Text(CurrencyFormatter.format(p.salePrice),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _importing ? null : _import,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC6F24E),
                foregroundColor: const Color(0xFF143122),
              ),
              child: _importing
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('IMPORTAR ${_products.length} PRODUCTOS',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ],
    );
  }
}
