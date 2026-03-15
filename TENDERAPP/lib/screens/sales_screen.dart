import 'package:flutter/material.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/product_model.dart';
import '../providers/product_provider.dart';
import '../providers/sale_provider.dart';
import '../providers/customer_provider.dart';
import '../providers/settings_provider.dart';
import '../models/customer_model.dart';
import '../models/sale_model.dart';
import '../api/currency_formatter.dart';
import '../api/pdf_generator.dart';
import '../widgets/info_banner.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final Map<Product, num> _cart = {}; 
  bool _showTutorial = true;

  void _addProductToCart(Product product, {num quantity = 1}) {
    setState(() {
      _cart.update(product, (value) => value + quantity, ifAbsent: () => quantity);
    });
  }

  void _removeProductFromCart(Product product) {
    setState(() {
      if (_cart.containsKey(product)) {
        if (_cart[product]! > 1) {
          _cart.update(product, (value) => value - 1);
        } else {
          _cart.remove(product);
        }
      }
    });
  }

  Future<void> _showProductSelectionDialog() async {
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    await productProvider.loadProducts();
    final allProducts = productProvider.products;
    List<Product> filteredProducts = allProducts;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Seleccionar Producto'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Buscar producto',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          filteredProducts = allProducts
                              .where((p) => p.name.toLowerCase().contains(value.toLowerCase()))
                              .toList();
                        });
                      },
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredProducts.length,
                        itemBuilder: (context, index) {
                          final product = filteredProducts[index];
                          return ListTile(
                            title: Text(product.name),
                            subtitle: Text('Precio: ${CurrencyFormatter.format(product.salePrice)} | Stock: ${product.stock}'),
                            onTap: () async {
                              Navigator.of(context).pop();
                              if (product.stock > 0) {
                                if (product.productType == 'fruver') {
                                  final quantity = await _showQuantityDialog(product);
                                  if (quantity != null && quantity > 0) {
                                    _addProductToCart(product, quantity: quantity);
                                  }
                                } else {
                                  _addProductToCart(product);
                                }
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Producto agotado!')),
                                );
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cerrar'),
                )
              ],
            );
          },
        );
      },
    );
  }

  Future<double?> _showQuantityDialog(Product product) async {
    final controller = TextEditingController();
    return await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Cantidad para ${product.name} (${product.unit})'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Cantidad en ${product.unit}',
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                final quantity = double.tryParse(controller.text);
                if (quantity != null && quantity > 0) {
                  Navigator.of(context).pop(quantity);
                }
              },
              child: const Text('Aceptar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _scanBarcodeAndAddToCart() async {
    String barcodeScanRes = await FlutterBarcodeScanner.scanBarcode('#ff6666', 'Cancelar', true, ScanMode.BARCODE);
    if (!mounted) return;
    if (barcodeScanRes != '-1') {
      final productProvider = Provider.of<ProductProvider>(context, listen: false);
      try {
        final scannedProduct = productProvider.products.firstWhere((p) => p.barcode == barcodeScanRes);
        if (scannedProduct.stock > 0) {
          _addProductToCart(scannedProduct);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Producto agotado!')));
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Producto no encontrado')));
      }
    }
  }

  double get _totalAmount {
    double total = 0;
    _cart.forEach((product, quantity) => total += product.salePrice * quantity);
    return total;
  }

  Future<void> _checkout() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El carrito está vacío.')));
      return;
    }

    final String? paymentMethod = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Método de Pago'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _buildPaymentOption(context, 'Efectivo', Icons.payments, Colors.green),
              _buildPaymentOption(context, 'Tarjeta', Icons.credit_card, Colors.blue),
              _buildPaymentOption(context, 'Nequi / Daviplata', Icons.phone_android, Colors.purple),
              _buildPaymentOption(context, 'Fiar (Crédito)', Icons.book, Colors.red),
            ],
          ),
        );
      },
    );

    if (paymentMethod != null) {
      if (paymentMethod == 'Efectivo') {
        final success = await _showCashPaymentDialog();
        if (!success) return;
      }

      int? selectedCustomerId;
      if (paymentMethod == 'Fiar (Crédito)') {
        selectedCustomerId = await _showCustomerSelectionDialog();
        if (selectedCustomerId == null) return;
      }

      await _processSale(paymentMethod == 'Fiar (Crédito)' ? 'Fiado' : paymentMethod, selectedCustomerId);
    }
  }

  Widget _buildPaymentOption(BuildContext context, String title, IconData icon, Color color) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      onTap: () => Navigator.of(context).pop(title),
    );
  }

  Future<bool> _showCashPaymentDialog() async {
    double total = _totalAmount;
    double received = 0;
    final controller = TextEditingController();

    return await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            double change = received - total;
            return AlertDialog(
              title: const Text('Pago en Efectivo'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('TOTAL A PAGAR', style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.bold)),
                    Text(CurrencyFormatter.format(total), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.green)),
                    const SizedBox(height: 20),
                    TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      inputFormatters: [ThousandSeparatorInputFormatter()],
                      decoration: const InputDecoration(
                        labelText: '¿Cuánto recibes?',
                        prefixText: '\$ ',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setStateDialog(() {
                          received = CurrencyFormatter.parse(value);
                        });
                      },
                    ),
                    const SizedBox(height: 15),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [2000, 5000, 10000, 20000, 50000, 100000].map((amount) {
                        return ActionChip(
                          label: Text('+${amount ~/ 1000}k'),
                          onPressed: () {
                            setStateDialog(() {
                              received += amount;
                              final formatter = NumberFormat.decimalPattern('es_CO');
                              controller.text = formatter.format(received);
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    if (received > 0) ...[
                      Text('SU DEVUELTA (CAMBIO)', style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.bold)),
                      Text(
                        change >= 0 ? CurrencyFormatter.format(change) : 'Faltan ${CurrencyFormatter.format(change.abs())}',
                        style: TextStyle(
                          fontSize: 28, 
                          fontWeight: FontWeight.w900, 
                          color: change >= 0 ? Colors.blue : Colors.red
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCELAR')),
                ElevatedButton(
                  onPressed: received >= total ? () => Navigator.pop(context, true) : null,
                  child: const Text('FINALIZAR VENTA'),
                ),
              ],
            );
          },
        );
      },
    ) ?? false;
  }

  Future<void> _processSale(String paymentMethod, int? customerId) async {
    try {
      final double finalTotal = _totalAmount;
      final saleProvider = Provider.of<SaleProvider>(context, listen: false);
      
      final List<Map<String, dynamic>> saleItems = _cart.entries.map((e) => {'product': e.key, 'quantity': e.value}).toList();
      final receiptItems = _cart.entries.map((e) => ReceiptItem(name: e.key.name, quantity: e.value, price: e.key.salePrice, unit: e.key.unit ?? '')).toList();

      final int saleId = await saleProvider.recordSale(
        cartItems: saleItems,
        paymentMethod: paymentMethod,
        totalAmount: finalTotal,
        customerId: customerId,
      );

      setState(() => _cart.clear());

      if (mounted) {
        _showSuccessDialog(saleId, finalTotal, paymentMethod, receiptItems, customerId);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showSuccessDialog(int saleId, double total, String method, List<ReceiptItem> items, int? customerId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Icon(Icons.check_circle, color: Colors.green, size: 60),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('¡Venta Exitosa!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),
            Text('Monto: ${CurrencyFormatter.format(total)}'),
            Text('Método: $method'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CERRAR')),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              final sale = Sale(id: saleId, totalAmount: total, paymentMethod: method, saleDate: DateTime.now().toIso8601String(), customerId: customerId);
              PdfGenerator.generateReceipt(
                sale, 
                items, 
                null, 
                storeName: Provider.of<SettingsProvider>(context, listen: false).storeName
              );
            },
            icon: const Icon(Icons.print),
            label: const Text('RECIBO PDF'),
          ),
        ],
      ),
    );
  }

  Future<int?> _showCustomerSelectionDialog() async {
    final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
    await customerProvider.loadCustomers();
    final allCustomers = customerProvider.customers;
    List<Customer> filteredCustomers = allCustomers;

    return await showDialog<int>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Seleccionar Cliente'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: const InputDecoration(labelText: 'Buscar cliente', prefixIcon: Icon(Icons.search)),
                      onChanged: (v) => setDialogState(() => filteredCustomers = allCustomers.where((c) => c.name.toLowerCase().contains(v.toLowerCase())).toList()),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredCustomers.length,
                        itemBuilder: (context, i) {
                          final c = filteredCustomers[i];
                          return ListTile(
                            title: Text(c.name),
                            subtitle: Text('Deuda: ${CurrencyFormatter.format(c.totalPendingBalance)}'),
                            onTap: () => Navigator.of(context).pop(c.id),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar'))],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Caja / Ventas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _scanBarcodeAndAddToCart,
            tooltip: 'Escanear Código',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            children: [
              // Banner Guía con botón de cerrar
              if (_showTutorial)
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 8),
                  child: InfoBanner(
                    text: 'Agrega productos al carrito usando el buscador o el escáner. Al cobrar, el stock se descuenta automáticamente.',
                    icon: Icons.shopping_cart_checkout,
                    color: Colors.green,
                    onClose: () => setState(() => _showTutorial = false),
                  ),
                ),
              Expanded(
                child: _cart.isEmpty
                    ? Center(child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          const Text('Carrito vacío', style: TextStyle(color: Colors.grey)),
                        ],
                      ))
                    : ListView.builder(
                        itemCount: _cart.length,
                        itemBuilder: (context, index) {
                          final product = _cart.keys.elementAt(index);
                          final qty = _cart[product]!;
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8.0),
                            child: ListTile(
                              title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('$qty ${product.unit ?? ""} x ${CurrencyFormatter.format(product.salePrice)}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => _removeProductFromCart(product)),
                                  Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => _addProductToCart(product)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    const Text('TOTAL A COBRAR', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
                    Text(
                      CurrencyFormatter.format(_totalAmount),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 40, color: Colors.black),
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        onPressed: _checkout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        child: const Text('COBRAR AHORA', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _scanBarcodeAndAddToCart,
            heroTag: 'scan_fab',
            child: const Icon(Icons.qr_code_scanner),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            onPressed: _showProductSelectionDialog,
            heroTag: 'search_fab',
            label: const Text('Buscar'),
            icon: const Icon(Icons.search),
          ),
        ],
      ),
    );
  }
}
