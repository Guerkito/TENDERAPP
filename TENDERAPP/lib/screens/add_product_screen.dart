import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:intl/intl.dart';

import '../models/product_model.dart';
import '../providers/product_provider.dart';
import '../api/currency_formatter.dart';

class AddProductScreen extends StatefulWidget {
  final Product? product;

  const AddProductScreen({super.key, this.product});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _barcodeController;
  late TextEditingController _descriptionController;
  late TextEditingController _purchasePriceController;
  late TextEditingController _salePriceController;
  late TextEditingController _stockController;
  late TextEditingController _expirationDateController;
  late TextEditingController _unitController;
  String _productType = 'product';

  DateTime? _selectedExpirationDate;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _barcodeController =
        TextEditingController(text: widget.product?.barcode ?? '');
    _descriptionController =
        TextEditingController(text: widget.product?.description ?? '');
    
    // Formatear precios iniciales con separador de miles
    final formatter = NumberFormat.decimalPattern('es_CO');
    _purchasePriceController = TextEditingController(
        text: widget.product != null ? formatter.format(widget.product!.purchasePrice) : '');
    _salePriceController =
        TextEditingController(text: widget.product != null ? formatter.format(widget.product!.salePrice) : '');
    
    _stockController =
        TextEditingController(text: widget.product?.stock.toString() ?? '');
    _unitController = TextEditingController(text: widget.product?.unit ?? '');
    _productType = widget.product?.productType ?? 'product';

    if (widget.product?.expirationDate != null) {
      _selectedExpirationDate = DateTime.tryParse(widget.product!.expirationDate!);
      _expirationDateController = TextEditingController(text: _selectedExpirationDate != null ? _selectedExpirationDate!.toLocal().toString().split(' ')[0] : '');
    } else {
      _expirationDateController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _descriptionController.dispose();
    _purchasePriceController.dispose();
    _salePriceController.dispose();
    _stockController.dispose();
    _expirationDateController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    String barcodeScanRes = await FlutterBarcodeScanner.scanBarcode(
      '#ff6666',
      'Cancelar',
      true,
      ScanMode.BARCODE,
    );

    if (!mounted) return;

    if (barcodeScanRes != '-1') {
      setState(() {
        _barcodeController.text = barcodeScanRes;
      });
    }
  }

  Future<void> _selectExpirationDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedExpirationDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedExpirationDate) {
      setState(() {
        _selectedExpirationDate = picked;
        _expirationDateController.text = picked.toLocal().toString().split(' ')[0];
      });
    }
  }

  void _saveProduct() async {
    if (_formKey.currentState!.validate()) {
      try {
        final productProvider =
            Provider.of<ProductProvider>(context, listen: false);

        final newProduct = Product(
          id: widget.product?.id,
          name: _nameController.text,
          barcode: _barcodeController.text.isNotEmpty ? _barcodeController.text : null,
          description: _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
          purchasePrice: CurrencyFormatter.parse(_purchasePriceController.text),
          salePrice: CurrencyFormatter.parse(_salePriceController.text),
          stock: int.tryParse(_stockController.text) ?? 0,
          expirationDate: _selectedExpirationDate?.toIso8601String(),
          productType: _productType,
          unit: _unitController.text.isNotEmpty ? _unitController.text : null,
        );

        if (widget.product == null) {
          await productProvider.addProduct(newProduct);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Producto agregado con éxito!')),
            );
          }
        } else {
          await productProvider.updateProduct(newProduct);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Producto actualizado con éxito!')),
            );
          }
        }
        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        print('Error saving product: $e');
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Error al guardar'),
              content: Text('No se pudo guardar el producto. Detalles: $e'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cerrar'),
                ),
              ],
            ),
          );
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor revisa los campos obligatorios')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product == null ? 'Agregar Producto' : 'Editar Producto'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: <Widget>[
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Nombre del Producto'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingrese un nombre';
                    }
                    return null;
                  },
                ),
                DropdownButtonFormField<String>(
                  value: _productType,
                  decoration: const InputDecoration(labelText: 'Tipo de Producto'),
                  items: const [
                    DropdownMenuItem(value: 'product', child: Text('Producto (con código de barras)')),
                    DropdownMenuItem(value: 'fruver', child: Text('Fruver (sin código de barras)')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _productType = value!;
                    });
                  },
                ),
                if (_productType == 'fruver')
                  TextFormField(
                    controller: _unitController,
                    decoration: const InputDecoration(labelText: 'Unidad (ej. kg, lb, unidad)'),
                    validator: (value) {
                      if (_productType == 'fruver' && (value == null || value.isEmpty)) {
                        return 'Por favor ingrese una unidad';
                      }
                      return null;
                    },
                  ),
                if (_productType != 'fruver')
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _barcodeController,
                          decoration: const InputDecoration(labelText: 'Código de Barras (Opcional)'),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.qr_code_scanner),
                        onPressed: _scanBarcode,
                      ),
                    ],
                  ),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Descripción (Opcional)'),
                  maxLines: 3,
                ),
                TextFormField(
                  controller: _purchasePriceController,
                  decoration: const InputDecoration(labelText: 'Precio de Compra', prefixText: '\$ '),
                  keyboardType: TextInputType.number,
                  inputFormatters: [ThousandSeparatorInputFormatter()],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingrese el precio de compra';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _salePriceController,
                  decoration: const InputDecoration(labelText: 'Precio de Venta', prefixText: '\$ '),
                  keyboardType: TextInputType.number,
                  inputFormatters: [ThousandSeparatorInputFormatter()],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingrese el precio de venta';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _stockController,
                  decoration: const InputDecoration(labelText: 'Stock'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingrese el stock';
                    }
                    if (int.tryParse(value) == null) {
                      return 'Ingrese un número entero válido';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _expirationDateController,
                  decoration: InputDecoration(
                    labelText: 'Fecha de Vencimiento (Opcional)',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () => _selectExpirationDate(context),
                    ),
                  ),
                  readOnly: true,
                  onTap: () => _selectExpirationDate(context),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveProduct,
                    child: Text(widget.product == null ? 'Guardar Producto' : 'Actualizar Producto'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
