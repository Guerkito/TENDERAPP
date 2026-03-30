import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/navigation_provider.dart';
import 'dashboard_screen.dart';
import 'sales_screen.dart';
import 'inventory_screen.dart';
import 'customers_screen.dart';
import 'more_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkStoreName();
    });
  }

  Future<void> _checkStoreName() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    await settings.loadSettings();
    if (!settings.isNameSet) {
      _showStoreNameDialog();
    }
  }

  void _showStoreNameDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('¡Bienvenido!', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Personaliza tus recibos y reportes. ¿Cómo se llama tu tienda?'),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Nombre de tu tienda',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                hintText: 'Ej: Tienda de Don Pepe',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Provider.of<SettingsProvider>(context, listen: false)
                    .updateStoreName(controller.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('EMPEZAR', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00DF82))),
          ),
        ],
      ),
    );
  }

  static const List<Widget> _widgetOptions = <Widget>[
    DashboardScreen(),
    SalesScreen(),
    InventoryScreen(),
    CustomersScreen(),
    MoreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final navProvider = Provider.of<NavigationProvider>(context);

    return Scaffold(
      body: IndexedStack(
        index: navProvider.selectedIndex,
        children: _widgetOptions,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A3C2B),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: NavigationBarTheme(
              data: NavigationBarThemeData(
                backgroundColor: Colors.transparent,
                indicatorColor: const Color(0xFF00DF82),
                labelTextStyle: MaterialStateProperty.all(
                  const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                ),
                iconTheme: MaterialStateProperty.resolveWith((states) {
                  if (states.contains(MaterialState.selected)) {
                    return const IconThemeData(color: Color(0xFF1A3C2B), size: 24);
                  }
                  return const IconThemeData(color: Colors.white70, size: 24);
                }),
              ),
              child: NavigationBar(
                height: 64,
                elevation: 0,
                selectedIndex: navProvider.selectedIndex,
                onDestinationSelected: (index) {
                  navProvider.setIndex(index);
                },
                destinations: [
                  _buildDestination(
                    PhosphorIcons.house(PhosphorIconsStyle.regular),
                    PhosphorIcons.house(PhosphorIconsStyle.fill),
                    'Inicio',
                  ),
                  _buildDestination(
                    PhosphorIcons.shoppingBag(PhosphorIconsStyle.regular),
                    PhosphorIcons.shoppingBag(PhosphorIconsStyle.fill),
                    'Caja',
                  ),
                  _buildDestination(
                    PhosphorIcons.package(PhosphorIconsStyle.regular),
                    PhosphorIcons.package(PhosphorIconsStyle.fill),
                    'Stock',
                  ),
                  _buildDestination(
                    PhosphorIcons.users(PhosphorIconsStyle.regular),
                    PhosphorIcons.users(PhosphorIconsStyle.fill),
                    'Clientes',
                  ),
                  _buildDestination(
                    PhosphorIcons.dotsThreeCircle(PhosphorIconsStyle.regular),
                    PhosphorIcons.dotsThreeCircle(PhosphorIconsStyle.fill),
                    'Más',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  NavigationDestination _buildDestination(IconData icon, IconData selectedIcon, String label) {
    return NavigationDestination(
      icon: Icon(icon),
      selectedIcon: Icon(selectedIcon),
      label: label,
    );
  }
}
