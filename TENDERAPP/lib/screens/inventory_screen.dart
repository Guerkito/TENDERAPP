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
  String _selectedCategory = 'Todos';

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
    final categories = ['Todos', ...productProvider.categories];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Inventario / Stock', style: TextStyle(fontWeight: FontWeight.bold)),
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
            // CATEGORY TABS (PILLS)
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  final isSelected = _selectedCategory == cat;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF00DF82) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          if (!isSelected) BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
                        ],
                      ),
                      child: Center(
                        child: Text(
                          cat,
                          style: TextStyle(
                            color: isSelected ? const Color(0xFF1A3C2B) : Colors.grey[600],
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Barra de Búsqueda
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 5, 20, 10),
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
                  fillColor: Colors.white,
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
                      final matchesSearch = name.contains(_searchQuery) || barcode.contains(_searchQuery);
                      final matchesCategory = _selectedCategory == 'Todos' || product.category == _selectedCategory;
                      return matchesSearch && matchesCategory;
                    }).toList();

                    if (filteredProducts.isEmpty) {
                      return Center(
                        child: Text(
                          _searchQuery.isEmpty 
                            ? 'No hay productos en esta categoría.' 
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
        heroTag: 'inventory_fab',
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
