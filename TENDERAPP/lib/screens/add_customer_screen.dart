import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/customer_model.dart';
import '../providers/customer_provider.dart';
import '../api/currency_formatter.dart';

class AddCustomerScreen extends StatefulWidget {
  final Customer? customer;

  const AddCustomerScreen({super.key, this.customer});

  @override
  State<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _limitController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.customer?.name ?? '');
    _phoneController = TextEditingController(text: widget.customer?.phone ?? '');
    
    final formatter = NumberFormat.decimalPattern('es_CO');
    _limitController = TextEditingController(
        text: widget.customer != null ? formatter.format(widget.customer!.creditLimit) : '0');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _limitController.dispose();
    super.dispose();
  }

  void _saveCustomer() async {
    if (_formKey.currentState!.validate()) {
      final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
      final newCustomer = Customer(
        id: widget.customer?.id,
        name: _nameController.text,
        phone: _phoneController.text,
        creditLimit: CurrencyFormatter.parse(_limitController.text),
        totalPendingBalance: widget.customer?.totalPendingBalance ?? 0.0,
      );

      if (widget.customer == null) {
        await customerProvider.addCustomer(newCustomer);
      } else {
        await customerProvider.updateCustomer(newCustomer);
      }
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cliente guardado con éxito')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.customer == null ? 'Nuevo Cliente' : 'Editar Cliente'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nombre Completo'),
                validator: (value) => value!.isEmpty ? 'Ingrese un nombre' : null,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Teléfono (WhatsApp)', hintText: 'Ej: 3001234567'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _limitController,
                decoration: const InputDecoration(labelText: 'Límite de Crédito (Opcional)', prefixText: '\$ '),
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandSeparatorInputFormatter()],
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _saveCustomer,
                child: const Text('Guardar Cliente'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
