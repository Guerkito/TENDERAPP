import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';
import '../widgets/info_banner.dart';
import 'add_product_screen.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _showTutorial = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ProductProvider>(context, listen: false).loadExpiringProducts();
      Provider.of<ProductProvider>(context, listen: false).loadLowStockProducts();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alertas'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).primaryColor,
          tabs: const [
            Tab(text: 'Por Vencer', icon: Icon(Icons.timer)),
            Tab(text: 'Stock Bajo', icon: Icon(Icons.warning)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Banner Guía
          if (_showTutorial)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: InfoBanner(
                text: '¡Atención necesaria! Revisa aquí los productos que se están agotando o están por vencer pronto.',
                icon: Icons.priority_high,
                color: Colors.orange,
                onClose: () => setState(() => _showTutorial = false),
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildExpiringList(),
                _buildLowStockList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiringList() {
    return Consumer<ProductProvider>(
      builder: (context, productProvider, child) {
        if (productProvider.expiringProducts.isEmpty) {
          return const Center(child: Text('No hay productos próximos a vencer.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: productProvider.expiringProducts.length,
          itemBuilder: (context, index) {
            final product = productProvider.expiringProducts[index];
            return Card(
              child: ListTile(
                leading: const Icon(Icons.timer, color: Colors.orange),
                title: Text(product.name),
                subtitle: Text('Vence: ${product.expirationDate?.substring(0, 10)}'),
                trailing: Text('Stock: ${product.stock}'),
                onTap: () => _editProduct(product),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLowStockList() {
    return Consumer<ProductProvider>(
      builder: (context, productProvider, child) {
        if (productProvider.lowStockProducts.isEmpty) {
          return const Center(child: Text('No hay productos con stock bajo.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: productProvider.lowStockProducts.length,
          itemBuilder: (context, index) {
            final product = productProvider.lowStockProducts[index];
            return Card(
              child: ListTile(
                leading: const Icon(Icons.warning, color: Colors.red),
                title: Text(product.name),
                subtitle: Text('Stock crítico'),
                trailing: Text(
                  '${product.stock} ${product.unit ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                ),
                onTap: () => _editProduct(product),
              ),
            );
          },
        );
      },
    );
  }

  void _editProduct(dynamic product) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddProductScreen(product: product),
      ),
    );
  }
}
