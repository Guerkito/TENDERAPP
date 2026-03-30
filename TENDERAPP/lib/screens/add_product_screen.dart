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
  late TextEditingController _categoryController;
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
    _categoryController = TextEditingController(text: widget.product?.category ?? 'General');
    
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
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    String barcodeScanRes = await FlutterBarcodeScanner.scanBarcode('#ff6666', 'Cancelar', true, ScanMode.BARCODE);
    if (!mounted) return;
    if (barcodeScanRes != '-1') {
      setState(() => _barcodeController.text = barcodeScanRes);
    }
  }

  Future<void> _selectExpirationDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedExpirationDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        _selectedExpirationDate = picked;
        _expirationDateController.text = picked.toLocal().toString().split(' ')[0];
      });
    }
  }

  void _saveProduct() async {
    if (_formKey.currentState!.validate()) {
      try {
        final productProvider = Provider.of<ProductProvider>(context, listen: false);
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
          category: _categoryController.text.isNotEmpty ? _categoryController.text : 'General',
        );

        if (widget.product == null) {
          await productProvider.addProduct(newProduct);
        } else {
          await productProvider.updateProduct(newProduct);
        }
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(widget.product == null ? 'Nuevo Producto' : 'Editar Producto'),
        backgroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: <Widget>[
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Nombre del Producto',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (v) => v!.isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _productType,
                  decoration: InputDecoration(
                    labelText: 'Tipo',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'product', child: Text('General / Abarrote')),
                    DropdownMenuItem(value: 'fruver', child: Text('Fruver / Pesable')),
                  ],
                  onChanged: (v) => setState(() => _productType = v!),
                ),
                const SizedBox(height: 16),
                Consumer<ProductProvider>(
                  builder: (context, provider, child) {
                    return Autocomplete<String>(
                      initialValue: TextEditingValue(text: _categoryController.text),
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text == '') {
                          return provider.categories;
                        }
                        return provider.categories.where((String option) {
                          return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                        });
                      },
                      onSelected: (String selection) {
                        _categoryController.text = selection;
                      },
                      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                        // Sincronizar el controlador inicial con el controlador del campo de autocompletado
                        if (controller.text.isEmpty && _categoryController.text.isNotEmpty) {
                          controller.text = _categoryController.text;
                        }
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            labelText: 'Categoría o Marca (Selecciona o escribe nueva)',
                            hintText: 'Ej: Lácteos, Coca-Cola, Aseo',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                            filled: true,
                            fillColor: Colors.white,
                            suffixIcon: const Icon(Icons.search),
                          ),
                          onChanged: (value) {
                            _categoryController.text = value;
                          },
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
                if (_productType != 'fruver')
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _barcodeController,
                          decoration: InputDecoration(
                            labelText: 'Código de Barras',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _scanBarcode,
                        icon: const Icon(Icons.qr_code_scanner),
                        style: IconButton.styleFrom(backgroundColor: const Color(0xFF1A3C2B)),
                      ),
                    ],
                  ),
                if (_productType == 'fruver')
                  TextFormField(
                    controller: _unitController,
                    decoration: InputDecoration(
                      labelText: 'Unidad (kg, lb, unidad)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _purchasePriceController,
                        decoration: InputDecoration(
                          labelText: 'Precio Compra',
                          prefixText: '\$ ',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [ThousandSeparatorInputFormatter()],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _salePriceController,
                        decoration: InputDecoration(
                          labelText: 'Precio Venta',
                          prefixText: '\$ ',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [ThousandSeparatorInputFormatter()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _stockController,
                  decoration: InputDecoration(
                    labelText: 'Stock Inicial',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _expirationDateController,
                  decoration: InputDecoration(
                    labelText: 'Vencimiento (Opcional)',
                    suffixIcon: const Icon(Icons.calendar_today),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  readOnly: true,
                  onTap: () => _selectExpirationDate(context),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _saveProduct,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00DF82),
                      foregroundColor: const Color(0xFF1A3C2B),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      widget.product == null ? 'GUARDAR PRODUCTO' : 'ACTUALIZAR',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
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
