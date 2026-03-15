import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product_model.dart';
import '../providers/product_provider.dart';
import '../providers/settings_provider.dart';
import '../api/currency_formatter.dart';
import '../api/report_generator.dart';
import '../widgets/info_banner.dart';
import 'add_product_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showTutorial = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ProductProvider>(context, listen: false).loadProducts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventario'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Exportar Inventario PDF',
            onPressed: () => ReportGenerator.generateInventoryReport(
              productProvider.products,
              storeName: Provider.of<SettingsProvider>(context, listen: false).storeName,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Banner Guía con botón de cerrar
            if (_showTutorial)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: InfoBanner(
                  text: 'Administra aquí tus productos. Puedes ver el stock disponible, actualizar precios y agregar nuevos artículos.',
                  icon: Icons.inventory_2,
                  color: Colors.blue,
                  onClose: () => setState(() => _showTutorial = false),
                ),
              ),
            
            // Barra de Búsqueda
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar producto...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty 
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[200],
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
              ),
            ),
            
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Consumer<ProductProvider>(
                  builder: (context, productProvider, child) {
                    final filteredProducts = productProvider.products.where((product) {
                      final name = product.name.toLowerCase();
                      final barcode = (product.barcode ?? '').toLowerCase();
                      return name.contains(_searchQuery) || barcode.contains(_searchQuery);
                    }).toList();

                    if (filteredProducts.isEmpty) {
                      return Center(
                        child: Text(
                          _searchQuery.isEmpty 
                            ? 'No hay productos en el inventario. Agrega uno!' 
                            : 'No se encontraron productos.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      );
                    }
                    
                    return ListView.builder(
                      itemCount: filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = filteredProducts[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8.0),
                          child: ListTile(
                            title: Text(product.name, style: Theme.of(context).textTheme.titleMedium),
                            subtitle: Text(
                                'Precio: ${CurrencyFormatter.format(product.salePrice)} | Stock: ${product.stock}', 
                                style: Theme.of(context).textTheme.bodySmall),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                await productProvider.deleteProduct(product.id!);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Producto eliminado')),
                                );
                              },
                            ),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => AddProductScreen(product: product),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const AddProductScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
