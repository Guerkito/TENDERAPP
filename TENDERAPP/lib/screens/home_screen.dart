import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart'; // Import Phosphor Icons
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';
import '../providers/settings_provider.dart';
import 'inventory_screen.dart';
import 'sales_screen.dart';
import 'statistics_screen.dart';
import 'calendar_screen.dart';
import 'alerts_screen.dart'; // Replaced expiring_products_screen.dart
import 'customers_screen.dart';
import 'suppliers_screen.dart'; 
import 'expenses_screen.dart';
import 'purchases_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

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
        title: const Text('¡Bienvenido a TenderApp!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Para personalizar tus recibos y reportes, dinos:'),
            const SizedBox(height: 15),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '¿Cuál es el nombre de tu tienda?',
                border: OutlineInputBorder(),
                hintText: 'Ej: Tienda de Don Pepe',
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Provider.of<SettingsProvider>(context, listen: false)
                    .updateStoreName(controller.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('EMPEZAR'),
          ),
        ],
      ),
    );
  }

  static const List<Widget> _widgetOptions = <Widget>[
    InventoryScreen(),
    SalesScreen(),
    CustomersScreen(),
    StatisticsScreen(),
    AlertsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Helper function to get the correct icon based on index and selected state
  IconData _getPhosphorIcon(int index, bool isSelected) {
    switch (index) {
      case 0: return PhosphorIcons.archive(isSelected ? PhosphorIconsStyle.fill : PhosphorIconsStyle.regular);
      case 1: return PhosphorIcons.shoppingCart(isSelected ? PhosphorIconsStyle.fill : PhosphorIconsStyle.regular);
      case 2: return PhosphorIcons.notebook(isSelected ? PhosphorIconsStyle.fill : PhosphorIconsStyle.regular);
      case 3: return PhosphorIcons.chartLine(isSelected ? PhosphorIconsStyle.fill : PhosphorIconsStyle.regular);
      case 4: return PhosphorIcons.bell(isSelected ? PhosphorIconsStyle.fill : PhosphorIconsStyle.regular);
      default: return PhosphorIcons.question(PhosphorIconsStyle.regular); // Fallback icon
    }
  }

  @override
  Widget build(BuildContext context) {
    final storeName = Provider.of<SettingsProvider>(context).storeName;

    return Scaffold(
      appBar: AppBar(
        title: Text(storeName, style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: -1)),
        centerTitle: false,
        actions: [
          Consumer<ProductProvider>(
            builder: (context, provider, child) {
              final hasAlerts = provider.lowStockProducts.isNotEmpty || provider.expiringProducts.isNotEmpty;
              return Stack(
                children: [
                  IconButton(
                    icon: Icon(
                      hasAlerts ? PhosphorIcons.bell(PhosphorIconsStyle.fill) : PhosphorIcons.bell(PhosphorIconsStyle.regular),
                      color: hasAlerts ? Colors.orange : null,
                    ),
                    onPressed: () => _onItemTapped(4), // Navega a la pestaña de Alertas
                    tooltip: 'Alertas',
                  ),
                  if (hasAlerts)
                    Positioned(
                      right: 12,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        constraints: const BoxConstraints(minWidth: 10, minHeight: 10),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
              ),
              child: const SizedBox(
                width: double.infinity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.store, color: Colors.white, size: 30),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Mi Tienda',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Gestión de negocio',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.business_center),
              title: const Text('Proveedores'),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SuppliersScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.shopping_bag),
              title: const Text('Entradas (Compras)'),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchasesScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Calendario'),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.push(context, MaterialPageRoute(builder: (_) => const CalendarScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.money_off),
              title: const Text('Gastos Operativos'),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpensesScreen()));
              },
            ),
            const Divider(),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('TenderApp v1.0', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ),
          ],
        ),
      ),
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1), // Subtle shadow
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, -3), // changes position of shadow
            ),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white, // Explicitly set background to white
          selectedItemColor: Theme.of(context).primaryColor, // Green for active
          unselectedItemColor: const Color(0xFF757575), // Medium gray for inactive
          items: <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: PhosphorIcon(_getPhosphorIcon(0, _selectedIndex == 0)),
              label: 'Inventario',
            ),
            BottomNavigationBarItem(
              icon: PhosphorIcon(_getPhosphorIcon(1, _selectedIndex == 1)),
              label: 'Ventas',
            ),
            BottomNavigationBarItem(
              icon: PhosphorIcon(_getPhosphorIcon(2, _selectedIndex == 2)),
              label: 'Fiados',
            ),
            BottomNavigationBarItem(
              icon: PhosphorIcon(_getPhosphorIcon(3, _selectedIndex == 3)),
              label: 'Estadísticas',
            ),
            BottomNavigationBarItem(
              icon: Consumer<ProductProvider>(
                builder: (context, provider, child) {
                  final hasAlerts = provider.lowStockProducts.isNotEmpty || provider.expiringProducts.isNotEmpty;
                  return Stack(
                    children: [
                      PhosphorIcon(_getPhosphorIcon(4, _selectedIndex == 4)),
                      if (hasAlerts)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 10,
                              minHeight: 10,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              label: 'Alertas',
            ),
          ],
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
        ),
      ),
    );
  }
}
