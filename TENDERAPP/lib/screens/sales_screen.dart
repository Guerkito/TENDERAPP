import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../constants/app_constants.dart';
import '../models/product_model.dart';
import '../providers/product_provider.dart';
import '../providers/sale_provider.dart';
import '../providers/customer_provider.dart';
import '../providers/settings_provider.dart';
import '../models/customer_model.dart';
import '../models/sale_model.dart';
import '../api/currency_formatter.dart';
import '../api/pdf_generator.dart';
import '../providers/statistics_provider.dart';
class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final Map<Product, num> _cart = {};
  final Map<Product, double> _cartDiscounts = {};
  Customer? _selectedCustomer;
  final TextEditingController _searchController = TextEditingController();
  List<Product> _searchSuggestions = [];

  void _addProductToCart(Product product, {num quantity = 1}) {
    setState(() {
      _cart.update(product, (value) => value + quantity,
          ifAbsent: () => quantity);
      _searchController.clear();
      _searchSuggestions = [];
    });
  }

  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      setState(() => _searchSuggestions = []);
      return;
    }
    final productProvider =
        Provider.of<ProductProvider>(context, listen: false);
    setState(() {
      _searchSuggestions = productProvider.products
          .where((p) =>
              p.name.toLowerCase().contains(query.toLowerCase()) ||
              (p.barcode ?? '').contains(query))
          .take(5)
          .toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _removeProductFromCart(Product product) {
    setState(() {
      if (_cart.containsKey(product)) {
        if (_cart[product]! > 1) {
          _cart.update(product, (value) => value - 1);
        } else {
          _cart.remove(product);
          _cartDiscounts.remove(product);
        }
      }
    });
  }

  Future<void> _confirmClearCart() async {
    if (_cart.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Limpiar carrito?'),
        content: const Text(
            'Se eliminarán todos los productos del carrito.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('CANCELAR')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('LIMPIAR'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() {
        _cart.clear();
        _cartDiscounts.clear();
        _selectedCustomer = null;
      });
    }
  }

  void _setItemDiscount(Product product) async {
    final controller = TextEditingController(
      text: _cartDiscounts[product] != null &&
              _cartDiscounts[product]! > 0
          ? CurrencyFormatter.format(_cartDiscounts[product]!)
          : '',
    );
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Descuento para ${product.name}'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: false),
          inputFormatters: [ThousandSeparatorInputFormatter()],
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Descuento por unidad',
            prefixText: '\$ ',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, 0.0),
              child: const Text('QUITAR DESCUENTO')),
          ElevatedButton(
            onPressed: () {
              final val = CurrencyFormatter.parse(controller.text);
              Navigator.pop(ctx, val);
            },
            child: const Text('APLICAR'),
          ),
        ],
      ),
    );
    if (result != null) {
      setState(() {
        if (result <= 0) {
          _cartDiscounts.remove(product);
        } else {
          _cartDiscounts[product] = result;
        }
      });
    }
  }

  Future<void> _showProductSelectionDialog() async {
    final productProvider =
        Provider.of<ProductProvider>(context, listen: false);
    await productProvider.loadProducts();
    final allProducts = productProvider.products;
    List<Product> filteredProducts = allProducts;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 20),
                  const Text('Buscar Producto',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Nombre o código de barras',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        filteredProducts = allProducts
                            .where((p) =>
                                p.name
                                    .toLowerCase()
                                    .contains(value.toLowerCase()) ||
                                (p.barcode ?? '').contains(value))
                            .toList();
                      });
                    },
                  ),
                  const SizedBox(height: 15),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = filteredProducts[index];
                        return ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor:
                                const Color(0xFF00DF82).withOpacity(0.1),
                            child: const Icon(Icons.inventory_2,
                                color: Color(0xFF1A3C2B)),
                          ),
                          title: Text(product.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                              'Stock: ${product.stock} | ${CurrencyFormatter.format(product.salePrice)}'),
                          trailing:
                              const Icon(Icons.add_circle, color: Color(0xFF00DF82)),
                          onTap: () async {
                            if (product.stock > 0) {
                              if (product.productType == 'fruver') {
                                final quantity =
                                    await _showQuantityDialog(product);
                                if (quantity != null && quantity > 0) {
                                  _addProductToCart(product,
                                      quantity: quantity);
                                }
                              } else {
                                _addProductToCart(product);
                              }
                              Navigator.pop(context);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Producto agotado!')));
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
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
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: InputDecoration(labelText: 'Cantidad en ${product.unit}'),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar')),
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
    String barcodeScanRes = await FlutterBarcodeScanner.scanBarcode(
        '#ff6666', 'Cancelar', true, ScanMode.BARCODE);
    if (!mounted) return;
    if (barcodeScanRes != '-1') {
      final productProvider =
          Provider.of<ProductProvider>(context, listen: false);
      try {
        final scannedProduct = productProvider.products
            .firstWhere((p) => p.barcode == barcodeScanRes);
        if (scannedProduct.stock > 0) {
          _addProductToCart(scannedProduct);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Producto agotado!')));
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Producto no encontrado')));
      }
    }
  }

  double get _totalAmount {
    double total = 0;
    _cart.forEach((product, quantity) {
      final discount = _cartDiscounts[product] ?? 0.0;
      total += (product.salePrice - discount) * quantity;
    });
    return total;
  }

  // ── CHECKOUT ───────────────────────────────────────────────────────────────

  Future<void> _checkout() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('El carrito está vacío.')));
      return;
    }

    final List<Map<String, dynamic>>? payments = await _showPaymentSheet();
    if (payments == null || payments.isEmpty) return;

    // Si hay pago en Fiado, pedir cliente
    final hasFiado =
        payments.any((p) => p['method'] == PaymentMethod.credit);
    if (hasFiado && _selectedCustomer == null) {
      final customer = await _showCustomerSelectionBottomSheet();
      if (customer == null) return;
      setState(() => _selectedCustomer = customer);
    }

    // Si es solo Efectivo, mostrar diálogo de cambio
    if (payments.length == 1 &&
        payments.first['method'] == PaymentMethod.cash) {
      final success = await _showCashPaymentDialog();
      if (!success) return;
    }

    await _processSale(payments, _selectedCustomer?.id);
  }

  Future<List<Map<String, dynamic>>?> _showPaymentSheet() async {
    final total = _totalAmount;
    final Map<String, double> amounts = {};

    final methodIcons = {
      PaymentMethod.cash: Icons.payments,
      PaymentMethod.card: Icons.credit_card,
      PaymentMethod.nequi: Icons.phone_android,
      PaymentMethod.credit: Icons.book,
    };
    final methodColors = {
      PaymentMethod.cash: Colors.green,
      PaymentMethod.card: Colors.blue,
      PaymentMethod.nequi: Colors.purple,
      PaymentMethod.credit: Colors.red,
    };

    return await showModalBottomSheet<List<Map<String, dynamic>>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setS) {
            final allocated =
                amounts.values.fold(0.0, (a, b) => a + b);
            final remaining = total - allocated;

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2)),
                  ),
                  const Text('¿Cómo paga?',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total a cobrar:',
                          style: TextStyle(color: Colors.grey)),
                      Text(CurrencyFormatter.format(total),
                          style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 24,
                              color: Colors.green)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Por cobrar:',
                          style: TextStyle(color: Colors.grey)),
                      Text(
                        CurrencyFormatter.format(
                            remaining.clamp(0, double.infinity)),
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: remaining <= 0
                                ? Colors.green
                                : const Color(0xFFFF3B30)),
                      ),
                    ],
                  ),
                  const Divider(height: 28),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: PaymentMethod.all.map((method) {
                          final isSelected = amounts.containsKey(method);
                          final color = methodColors[method]!;
                          return Column(
                            children: [
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                      color: color.withOpacity(0.1),
                                      borderRadius:
                                          BorderRadius.circular(8)),
                                  child: Icon(methodIcons[method],
                                      color: color),
                                ),
                                title: Text(method,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                trailing: Switch(
                                  value: isSelected,
                                  activeColor: const Color(0xFF00DF82),
                                  onChanged: (val) => setS(() {
                                    if (val) {
                                      amounts[method] = 0.0;
                                    } else {
                                      amounts.remove(method);
                                    }
                                  }),
                                ),
                                onTap: () => setS(() {
                                  if (isSelected) {
                                    amounts.remove(method);
                                  } else {
                                    amounts[method] = 0.0;
                                  }
                                }),
                              ),
                              if (isSelected)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      0, 0, 0, 12),
                                  child: TextField(
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      ThousandSeparatorInputFormatter()
                                    ],
                                    autofocus: true,
                                    decoration: InputDecoration(
                                      labelText: 'Monto $method',
                                      prefixText: '\$ ',
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      filled: true,
                                      fillColor: Colors.grey[50],
                                    ),
                                    onChanged: (v) => setS(() {
                                      amounts[method] =
                                          CurrencyFormatter.parse(v);
                                    }),
                                  ),
                                ),
                              const Divider(height: 4),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: remaining <= 0 && amounts.isNotEmpty
                          ? () {
                              final result = amounts.entries
                                  .where((e) => e.value > 0)
                                  .map((e) => {
                                        'method': e.key,
                                        'amount': e.value,
                                      })
                                  .toList();
                              Navigator.pop(context, result);
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00DF82),
                        foregroundColor: const Color(0xFF1A3C2B),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('CONFIRMAR PAGO',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
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
                        Text('TOTAL A PAGAR',
                            style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                        Text(CurrencyFormatter.format(total),
                            style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: Colors.green)),
                        const SizedBox(height: 20),
                        TextField(
                          controller: controller,
                          keyboardType: TextInputType.number,
                          autofocus: true,
                          inputFormatters: [
                            ThousandSeparatorInputFormatter()
                          ],
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
                          children: [2000, 5000, 10000, 20000, 50000, 100000]
                              .map((amount) {
                            return ActionChip(
                              label: Text('+${amount ~/ 1000}k'),
                              onPressed: () {
                                setStateDialog(() {
                                  received += amount;
                                  final formatter =
                                      NumberFormat.decimalPattern('es_CO');
                                  controller.text =
                                      formatter.format(received);
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),
                        if (received > 0) ...[
                          Text('SU DEVUELTA (CAMBIO)',
                              style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                          Text(
                            change >= 0
                                ? CurrencyFormatter.format(change)
                                : 'Faltan ${CurrencyFormatter.format(change.abs())}',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: change >= 0 ? Colors.blue : Colors.red,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('CANCELAR')),
                    ElevatedButton(
                      onPressed: received >= total
                          ? () => Navigator.pop(context, true)
                          : null,
                      child: const Text('FINALIZAR VENTA'),
                    ),
                  ],
                );
              },
            );
          },
        ) ??
        false;
  }

  Future<void> _processSale(
      List<Map<String, dynamic>> payments, int? customerId) async {
    try {
      final double finalTotal = _totalAmount;
      final String? customerName = _selectedCustomer?.name;
      final saleProvider =
          Provider.of<SaleProvider>(context, listen: false);

      final List<Map<String, dynamic>> saleItems = _cart.entries
          .map((e) => {
                'product': e.key,
                'quantity': e.value,
                'discount': _cartDiscounts[e.key] ?? 0.0,
              })
          .toList();

      final receiptItems = _cart.entries.map((e) {
        final discount = _cartDiscounts[e.key] ?? 0.0;
        return ReceiptItem(
            name: e.key.name,
            quantity: e.value,
            price: e.key.salePrice - discount,
            unit: e.key.unit ?? '');
      }).toList();

      final int saleId = await saleProvider.recordSale(
        cartItems: saleItems,
        payments: payments,
        totalAmount: finalTotal,
        customerId: customerId,
      );

      if (mounted) {
        Provider.of<StatisticsProvider>(context, listen: false)
            .loadStatistics();
      }

      setState(() {
        _cart.clear();
        _cartDiscounts.clear();
        _selectedCustomer = null;
      });

      if (mounted) {
        _showSuccessDialog(
            saleId, finalTotal, payments, receiptItems, customerId, customerName);
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showSuccessDialog(
      int saleId,
      double total,
      List<Map<String, dynamic>> payments,
      List<ReceiptItem> items,
      int? customerId,
      String? customerName) {
    final methodLabel = payments.length == 1
        ? payments.first['method'] as String
        : PaymentMethod.mixed;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Icon(Icons.check_circle,
            color: Color(0xFF00DF82), size: 60),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('¡Venta Exitosa!',
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),
            Text('Monto: ${CurrencyFormatter.format(total)}'),
            Text('Método: $methodLabel'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CERRAR')),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              final sale = Sale(
                  id: saleId,
                  totalAmount: total,
                  paymentMethod: methodLabel,
                  saleDate: DateTime.now().toIso8601String(),
                  customerId: customerId);
              PdfGenerator.generateReceipt(sale, items, customerName,
                  storeName: Provider.of<SettingsProvider>(context,
                          listen: false)
                      .storeName);
            },
            icon: const Icon(Icons.print),
            label: const Text('RECIBO PDF'),
          ),
        ],
      ),
    );
  }

  // ── SELECCIÓN DE CLIENTE ───────────────────────────────────────────────────

  Future<Customer?> _showCustomerSelectionBottomSheet() async {
    final customerProvider =
        Provider.of<CustomerProvider>(context, listen: false);
    await customerProvider.loadCustomers();
    final allCustomers = customerProvider.customers;
    List<Customer> filteredCustomers = allCustomers;

    return await showModalBottomSheet<Customer>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Asignar Cliente',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      TextButton.icon(
                        icon: const Icon(Icons.person_add),
                        label: const Text('Nuevo'),
                        onPressed: () async {
                          final newCustomer = await _showAddCustomerDialog();
                          if (newCustomer != null && mounted) {
                            Navigator.pop(context, newCustomer);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Buscar cliente por nombre',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                    onChanged: (v) => setDialogState(() =>
                        filteredCustomers = allCustomers
                            .where((c) => c.name
                                .toLowerCase()
                                .contains(v.toLowerCase()))
                            .toList()),
                  ),
                  const SizedBox(height: 15),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredCustomers.length,
                      itemBuilder: (context, i) {
                        final c = filteredCustomers[i];
                        return ListTile(
                          title: Text(c.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                          subtitle: Text(
                              'Deuda: ${CurrencyFormatter.format(c.totalPendingBalance)}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).pop(c),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<Customer?> _showAddCustomerDialog() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    return await showDialog<Customer>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuevo Cliente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameController,
                decoration:
                    const InputDecoration(labelText: 'Nombre Completo'),
                autofocus: true),
            TextField(
                controller: phoneController,
                decoration:
                    const InputDecoration(labelText: 'Teléfono (Opcional)'),
                keyboardType: TextInputType.phone),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCELAR')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                final customer = Customer(
                    name: nameController.text, phone: phoneController.text);
                final id = await Provider.of<CustomerProvider>(context,
                        listen: false)
                    .addCustomer(customer);
                final savedCustomer = Customer(
                    id: id,
                    name: customer.name,
                    phone: customer.phone);
                Navigator.pop(context, savedCustomer);
              }
            },
            child: const Text('GUARDAR'),
          ),
        ],
      ),
    );
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Caja / POS',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        actions: [
          if (_cart.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _confirmClearCart,
              tooltip: 'Limpiar carrito',
            ),
          IconButton(
            icon: Icon(PhosphorIcons.qrCode(PhosphorIconsStyle.regular),
                size: 28),
            onPressed: _scanBarcodeAndAddToCart,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_selectedCustomer != null)
              Container(
                color: const Color(0xFF00DF82).withOpacity(0.1),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.person,
                        color: Color(0xFF1A3C2B), size: 18),
                    const SizedBox(width: 8),
                    Text('Cliente: ${_selectedCustomer!.name}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A3C2B))),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () =>
                          setState(() => _selectedCustomer = null),
                    ),
                  ],
                ),
              ),
            // Barra de búsqueda
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 15, 20, 10),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Buscar o escanear producto...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              })
                          : IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: _showProductSelectionDialog),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  if (_searchSuggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 10)
                        ],
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _searchSuggestions.length,
                        itemBuilder: (context, index) {
                          final p = _searchSuggestions[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  const Color(0xFF00DF82).withOpacity(0.1),
                              child: const Icon(Icons.inventory_2,
                                  color: Color(0xFF1A3C2B), size: 16),
                            ),
                            title: Text(p.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                            subtitle: Text(
                                'Stock: ${p.stock} | ${CurrencyFormatter.format(p.salePrice)}',
                                style: const TextStyle(fontSize: 12)),
                            trailing: const Icon(Icons.add_circle,
                                color: Color(0xFF00DF82)),
                            onTap: () {
                              if (p.stock > 0) {
                                if (p.productType == 'fruver') {
                                  _showQuantityDialog(p).then((qty) {
                                    if (qty != null && qty > 0)
                                      _addProductToCart(p, quantity: qty);
                                  });
                                } else {
                                  _addProductToCart(p);
                                }
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Sin stock')));
                              }
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            // Carrito
            Expanded(
              child: _cart.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                              PhosphorIcons.shoppingCart(
                                  PhosphorIconsStyle.thin),
                              size: 100,
                              color: Colors.grey[300]),
                          const SizedBox(height: 20),
                          const Text('Tu carrito está vacío',
                              style: TextStyle(
                                  color: Colors.grey, fontSize: 16)),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _showProductSelectionDialog,
                            child: const Text('AGREGAR PRODUCTOS'),
                          ),
                        ],
                      ))
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: _cart.length,
                      itemBuilder: (context, index) {
                        final product = _cart.keys.elementAt(index);
                        final qty = _cart[product]!;
                        final discount = _cartDiscounts[product] ?? 0.0;
                        final hasDiscount = discount > 0;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 10)
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(product.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                                    Row(
                                      children: [
                                        if (hasDiscount) ...[
                                          Text(
                                            CurrencyFormatter.format(
                                                product.salePrice),
                                            style: const TextStyle(
                                                color: Colors.grey,
                                                fontSize: 12,
                                                decoration: TextDecoration
                                                    .lineThrough),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            CurrencyFormatter.format(
                                                product.salePrice - discount),
                                            style: const TextStyle(
                                                color: Colors.red,
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ] else
                                          Text(
                                            '${CurrencyFormatter.format(product.salePrice)} c/u',
                                            style: const TextStyle(
                                                color: Colors.grey,
                                                fontSize: 13),
                                          ),
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: () =>
                                              _setItemDiscount(product),
                                          child: Icon(
                                            Icons.local_offer_outlined,
                                            size: 16,
                                            color: hasDiscount
                                                ? Colors.red
                                                : Colors.grey[400],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle,
                                        color: Color(0xFF8A8A8A)),
                                    onPressed: () =>
                                        _removeProductFromCart(product),
                                  ),
                                  Text('$qty',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18)),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle,
                                        color: Color(0xFF00DF82)),
                                    onPressed: () =>
                                        _addProductToCart(product),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            // Panel de total y cobrar
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 20,
                      offset: Offset(0, -5))
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('TOTAL',
                          style: TextStyle(
                              color: Color(0xFF8A8A8A),
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                      Text(
                        CurrencyFormatter.format(_totalAmount),
                        style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 32,
                            color: Color(0xFF1A1A1A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _checkout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00DF82),
                        foregroundColor: const Color(0xFF1A3C2B),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: const Text('COBRAR AHORA',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _cart.isEmpty
          ? null
          : FloatingActionButton(
              heroTag: 'sales_fab',
              onPressed: _showProductSelectionDialog,
              backgroundColor: const Color(0xFF1A3C2B),
              child: const Icon(Icons.add, color: Colors.white),
            ),
    );
  }
}

