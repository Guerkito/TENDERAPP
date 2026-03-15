import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/purchase_provider.dart';
import '../providers/supplier_provider.dart';
import '../api/currency_formatter.dart';
import '../widgets/info_banner.dart';
import 'add_purchase_screen.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  bool _showTutorial = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      Provider.of<PurchaseProvider>(context, listen: false).loadPurchases();
      Provider.of<SupplierProvider>(context, listen: false).loadSuppliers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final purchaseProvider = Provider.of<PurchaseProvider>(context);
    final supplierProvider = Provider.of<SupplierProvider>(context);
    final purchases = purchaseProvider.purchases;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Entradas'),
      ),
      body: Column(
        children: [
          // Banner Guía
          if (_showTutorial)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: InfoBanner(
                text: 'Revisa aquí todas las compras de mercancía que has realizado. Mira cuánto has invertido en inventario.',
                icon: Icons.history,
                color: Colors.blueGrey,
                onClose: () => setState(() => _showTutorial = false),
              ),
            ),
          Expanded(
            child: purchases.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        const Text('No hay registros de compras.', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: purchases.length,
                    itemBuilder: (ctx, index) {
                      final purchase = purchases[index];
                      // Buscamos el nombre del proveedor en la lista cargada
                      final supplier = supplierProvider.suppliers.firstWhere(
                        (s) => s.id == purchase.supplierId,
                        orElse: () => throw Exception('Proveedor no encontrado'),
                      );

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue[50],
                            child: const Icon(Icons.local_shipping, color: Colors.blue),
                          ),
                          title: Text(supplier.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(DateFormat('dd/MM/yyyy - HH:mm').format(purchase.date)),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                CurrencyFormatter.format(purchase.totalAmount),
                                style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.blue, fontSize: 16),
                              ),
                              if (purchase.notes != null && purchase.notes!.isNotEmpty)
                                const Icon(Icons.note, size: 12, color: Colors.grey),
                            ],
                          ),
                          onTap: () {
                            // Podríamos mostrar el detalle de productos comprados aquí
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddPurchaseScreen()),
          );
        },
        label: const Text('Nueva Entrada'),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.blue,
      ),
    );
  }
}
