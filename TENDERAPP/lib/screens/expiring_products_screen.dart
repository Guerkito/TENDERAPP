import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';
import '../widgets/info_banner.dart';
import 'add_product_screen.dart';

class ExpiringProductsScreen extends StatefulWidget {
  const ExpiringProductsScreen({super.key});

  @override
  State<ExpiringProductsScreen> createState() => _ExpiringProductsScreenState();
}

class _ExpiringProductsScreenState extends State<ExpiringProductsScreen> {
  bool _showTutorial = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ProductProvider>(context, listen: false).loadExpiringProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Productos Próximos a Vencer'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_showTutorial)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: InfoBanner(
                  text: 'Revisa aquí los productos que vencerán pronto para rotarlos o aplicar promociones.',
                  icon: Icons.timer,
                  color: Colors.deepOrange,
                  onClose: () => setState(() => _showTutorial = false),
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Consumer<ProductProvider>(
                  builder: (context, productProvider, child) {
                    if (productProvider.expiringProducts.isEmpty) {
                      return Center(
                        child: Text('No hay productos próximos a vencer.', style: Theme.of(context).textTheme.bodyMedium,),
                      );
                    }
                    return ListView.builder(
                      itemCount: productProvider.expiringProducts.length,
                      itemBuilder: (context, index) {
                        final product = productProvider.expiringProducts[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8.0),
                          child: ListTile(
                            title: Text(product.name, style: Theme.of(context).textTheme.titleMedium),
                            subtitle: Text(
                                'Vence: ${product.expirationDate != null ? product.expirationDate!.substring(0, 10) : 'N/A'} | Stock: ${product.stock}', style: Theme.of(context).textTheme.bodySmall),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      AddProductScreen(product: product),
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
    );
  }
}
