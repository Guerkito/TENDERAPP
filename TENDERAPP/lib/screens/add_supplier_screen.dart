import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/supplier_model.dart';
import '../providers/supplier_provider.dart';

class AddSupplierScreen extends StatefulWidget {
  final Supplier? supplier;

  const AddSupplierScreen({super.key, this.supplier});

  @override
  State<AddSupplierScreen> createState() => _AddSupplierScreenState();
}

class _AddSupplierScreenState extends State<AddSupplierScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _contactPersonController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _lastVisitController; // For displaying selected date

  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.supplier?.name ?? '');
    _contactPersonController = TextEditingController(text: widget.supplier?.contactPerson ?? '');
    _phoneController = TextEditingController(text: widget.supplier?.phone ?? '');
    _emailController = TextEditingController(text: widget.supplier?.email ?? '');
    _addressController = TextEditingController(text: widget.supplier?.address ?? '');

    if (widget.supplier?.lastVisit != null) {
      _selectedDate = DateTime.tryParse(widget.supplier!.lastVisit!);
      _lastVisitController = TextEditingController(text: _selectedDate != null ? _selectedDate!.toLocal().toString().split(' ')[0] : '');
    } else {
      _lastVisitController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactPersonController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _lastVisitController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _lastVisitController.text = picked.toLocal().toString().split(' ')[0];
      });
    }
  }

  void _saveSupplier() async {
    if (_formKey.currentState!.validate()) {
      final supplierProvider =
          Provider.of<SupplierProvider>(context, listen: false);

      final newSupplier = Supplier(
        id: widget.supplier?.id,
        name: _nameController.text,
        contactPerson: _contactPersonController.text.isNotEmpty ? _contactPersonController.text : null,
        phone: _phoneController.text.isNotEmpty ? _phoneController.text : null,
        email: _emailController.text.isNotEmpty ? _emailController.text : null,
        address: _addressController.text.isNotEmpty ? _addressController.text : null,
        lastVisit: _selectedDate?.toIso8601String(),
      );

      if (widget.supplier == null) {
        // Add new supplier
        await supplierProvider.addSupplier(newSupplier);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Proveedor agregado con éxito!')),
        );
      } else {
        // Update existing supplier
        await supplierProvider.updateSupplier(newSupplier);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Proveedor actualizado con éxito!')),
        );
      }
      Navigator.of(context).pop(); // Go back to calendar screen
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.supplier == null ? 'Agregar Proveedor' : 'Editar Proveedor'),
      ),
      body: SafeArea( // Apply SafeArea
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0), // 20px padding
          child: Form(
            key: _formKey,
            child: ListView(
              children: <Widget>[
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Nombre del Proveedor'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingrese un nombre';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _contactPersonController,
                  decoration: const InputDecoration(labelText: 'Persona de Contacto (Opcional)'),
                ),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'Teléfono (Opcional)'),
                  keyboardType: TextInputType.phone,
                ),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email (Opcional)'),
                  keyboardType: TextInputType.emailAddress,
                ),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(labelText: 'Dirección (Opcional)'),
                  maxLines: 2,
                ),
                TextFormField(
                  controller: _lastVisitController,
                  decoration: InputDecoration(
                    labelText: 'Última Visita (Opcional)',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () => _selectDate(context),
                    ),
                  ),
                  readOnly: true, // Make it read-only so date picker is the only input
                  onTap: () => _selectDate(context),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity, // Make button full width
                  child: ElevatedButton(
                    onPressed: _saveSupplier,
                    child: Text(widget.supplier == null ? 'Guardar Proveedor' : 'Actualizar Proveedor'),
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
