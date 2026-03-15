import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import '../providers/supplier_provider.dart';
import '../providers/product_provider.dart';
import '../providers/purchase_provider.dart';
import '../models/supplier_model.dart';
import '../models/product_model.dart';
import '../api/currency_formatter.dart';

class AddPurchaseScreen extends StatefulWidget {
  const AddPurchaseScreen({super.key});

  @override
  State<AddPurchaseScreen> createState() => _AddPurchaseScreenState();
}

class _AddPurchaseScreenState extends State<AddPurchaseScreen> {
  int? _selectedSupplierId;
  DateTime _selectedDate = DateTime.now();
  final _notesController = TextEditingController();
  
  // List of items in the purchase cart
  // Each item is { 'product': Product, 'quantity': num, 'cost': double }
  final List<Map<String, dynamic>> _purchaseItems = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      Provider.of<SupplierProvider>(context, listen: false).loadSuppliers();
      Provider.of<ProductProvider>(context, listen: false).loadProducts();
    });
  }

  Future<void> _scanBarcode() async {
    String barcodeScanRes = await FlutterBarcodeScanner.scanBarcode('#ff6666', 'Cancelar', true, ScanMode.BARCODE);
    if (!mounted) return;

    if (barcodeScanRes != '-1') {
      final productProvider = Provider.of<ProductProvider>(context, listen: false);
      try {
        final product = productProvider.products.firstWhere((p) => p.barcode == barcodeScanRes);
        _showAddProductDialog(product);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Producto no encontrado')));
      }
    }
  }

  void _showProductSearch() async {
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final allProducts = productProvider.products;
    List<Product> filtered = allProducts;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Buscar Producto'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: const InputDecoration(labelText: 'Nombre o Código', prefixIcon: Icon(Icons.search)),
                    onChanged: (v) => setDialogState(() => filtered = allProducts.where((p) => p.name.toLowerCase().contains(v.toLowerCase()) || (p.barcode ?? "").contains(v)).toList()),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final p = filtered[i];
                        return ListTile(
                          title: Text(p.name),
                          subtitle: Text('Stock actual: ${p.stock}'),
                          onTap: () {
                            Navigator.pop(ctx);
                            _showAddProductDialog(p);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddProductDialog(Product product) async {
    final qtyController = TextEditingController(text: "1");
    final costController = TextEditingController(text: product.purchasePrice.toString());
    final expiryController = TextEditingController();
    DateTime? selectedExpiry;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('Entrada: ${product.name}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: qtyController,
                  decoration: const InputDecoration(labelText: 'Cantidad Recibida'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  autofocus: true,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: costController,
                  decoration: const InputDecoration(labelText: 'Nuevo Costo Unitario', prefixText: '\$ '),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: expiryController,
                  decoration: InputDecoration(
                    labelText: 'Vencimiento (Opcional)',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().add(const Duration(days: 30)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2030),
                        );
                        if (d != null) {
                          setDialogState(() {
                            selectedExpiry = d;
                            expiryController.text = DateFormat('yyyy-MM-dd').format(d);
                          });
                        }
                      },
                    ),
                  ),
                  readOnly: true,
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCELAR')),
              ElevatedButton(
                onPressed: () {
                  final q = double.tryParse(qtyController.text);
                  final c = double.tryParse(costController.text);
                  if (q != null && c != null && q > 0) {
                    setState(() {
                      _purchaseItems.add({
                        'product': product, 
                        'quantity': q, 
                        'cost': c,
                        'expiration_date': selectedExpiry != null ? DateFormat('yyyy-MM-dd').format(selectedExpiry!) : null,
                      });
                    });
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('AGREGAR'),
              ),
            ],
          );
        }
      ),
    );
  }

  double get _totalAmount => _purchaseItems.fold(0.0, (sum, item) => sum + (item['quantity'] * item['cost']));

  void _savePurchase() async {
    if (_selectedSupplierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seleccione un proveedor')));
      return;
    }
    if (_purchaseItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Agregue productos')));
      return;
    }

    try {
      await Provider.of<PurchaseProvider>(context, listen: false).recordPurchase(
        supplierId: _selectedSupplierId!,
        date: _selectedDate,
        notes: _notesController.text,
        items: _purchaseItems,
      );
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Compra registrada con éxito')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final suppliers = Provider.of<SupplierProvider>(context).suppliers;

    return Scaffold(
      appBar: AppBar(title: const Text('Nueva Compra (Entrada)')),
      body: Column(
        children: [
          // Banner Informativo Intuitivo
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[100]!),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Registra aquí lo que te trajo el proveedor. El inventario y el costo de compra se actualizarán automáticamente al finalizar.',
                    style: TextStyle(color: Colors.blue[800], fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    DropdownButtonFormField<int>(
                      decoration: const InputDecoration(labelText: 'Proveedor / Repartidor', prefixIcon: Icon(Icons.local_shipping)),
                      value: _selectedSupplierId,
                      items: suppliers.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                      onChanged: (val) => setState(() => _selectedSupplierId = val),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
                        const SizedBox(width: 10),
                        Expanded(child: Text('Fecha factura: ${DateFormat('dd/MM/yyyy').format(_selectedDate)}', style: const TextStyle(fontWeight: FontWeight.bold))),
                        TextButton(
                          onPressed: () async {
                            final p = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now());
                            if (p != null) setState(() => _selectedDate = p);
                          },
                          child: const Text('Cambiar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(children: [Text('PRODUCTOS RECIBIDOS', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12))]),
          ),
          
          Expanded(
            child: _purchaseItems.isEmpty
                ? Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      const Text('No has agregado productos aún', style: TextStyle(color: Colors.grey)),
                    ],
                  ))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _purchaseItems.length,
                    itemBuilder: (ctx, i) {
                      final item = _purchaseItems[i];
                      final Product p = item['product'];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${item['quantity']} x ${CurrencyFormatter.format(item['cost'])}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(CurrencyFormatter.format(item['quantity'] * item['cost']), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                              IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => setState(() => _purchaseItems.removeAt(i))),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          
          // Footer
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TOTAL FACTURA', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    Text(CurrencyFormatter.format(_totalAmount), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.blue)),
                  ],
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _savePurchase,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: const Text('FINALIZAR ENTRADA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _scanBarcode,
            heroTag: 'purchase_scan',
            backgroundColor: Colors.blue,
            child: const Icon(Icons.qr_code_scanner, color: Colors.white),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            onPressed: _showProductSearch,
            heroTag: 'purchase_search',
            backgroundColor: Colors.blue,
            child: const Icon(Icons.search, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
