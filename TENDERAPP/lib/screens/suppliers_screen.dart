import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/supplier_provider.dart';
import '../widgets/info_banner.dart';
import 'add_supplier_screen.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  bool _showTutorial = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SupplierProvider>(context, listen: false).loadSuppliers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final supplierProvider = Provider.of<SupplierProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Proveedores'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Banner Guía
            if (_showTutorial)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: InfoBanner(
                  text: 'Guarda aquí el contacto de tus proveedores y repartidores. Podrás ver cuándo fue su última visita.',
                  icon: Icons.business,
                  color: Colors.cyan,
                  onClose: () => setState(() => _showTutorial = false),
                ),
              ),
            
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
                child: supplierProvider.suppliers.isEmpty
                    ? const Center(child: Text('No hay proveedores registrados.'))
                    : ListView.builder(
                        itemCount: supplierProvider.suppliers.length,
                        itemBuilder: (context, index) {
                          final supplier = supplierProvider.suppliers[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8.0),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                                child: Icon(Icons.business, color: Theme.of(context).primaryColor),
                              ),
                              title: Text(supplier.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(supplier.phone ?? 'Sin teléfono'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AddSupplierScreen(supplier: supplier),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddSupplierScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
