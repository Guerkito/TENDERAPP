import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/navigation_provider.dart';
import '../widgets/business_type_picker.dart';
import 'dashboard_screen.dart';
import 'sales_screen.dart';
import 'inventory_screen.dart';
import 'customers_screen.dart';
import 'more_screen.dart';
import 'pin_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _isUnlocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final settings =
          Provider.of<SettingsProvider>(context, listen: false);
      if (settings.hasPinEnabled) {
        setState(() => _isUnlocked = false);
      }
    }
  }

  Future<void> _initialize() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    await settings.loadSettings();

    if (!settings.hasPinEnabled) {
      setState(() => _isUnlocked = true);
    }
    // Si tiene PIN, _isUnlocked permanece false → PinScreen se muestra

    if (!settings.isNameSet || !settings.isBusinessTypeSet) {
      _showOnboardingDialog(needsName: !settings.isNameSet);
    }
  }

  void _showOnboardingDialog({required bool needsName}) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final nameController = TextEditingController();
    String? selectedType;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('¡Bienvenido!',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    'Configura tu negocio para personalizar la aplicación.'),
                if (needsName) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Nombre del negocio',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16)),
                      hintText: 'Ej: Licorera El Buen Trago',
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                const Text('¿Qué tipo de negocio tienes?',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                BusinessTypePicker(
                  selectedId: selectedType,
                  onSelected: (id) =>
                      setDialogState(() => selectedType = id),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: (selectedType != null &&
                      (!needsName || nameController.text.trim().isNotEmpty))
                  ? () async {
                      if (needsName) {
                        await settings
                            .updateStoreName(nameController.text.trim());
                      }
                      await settings.updateBusinessType(selectedType!);
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                    }
                  : null,
              child: const Text('EMPEZAR',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00DF82))),
            ),
          ],
        ),
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
    final settings = Provider.of<SettingsProvider>(context);

    // Mostrar pantalla de carga mientras settings no está listo
    if (!settings.isLoaded) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A3C2B),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF00DF82)),
        ),
      );
    }

    // Mostrar PIN si está activado y aún no desbloqueado
    if (settings.hasPinEnabled && !_isUnlocked) {
      return PinScreen(onSuccess: () => setState(() => _isUnlocked = true));
    }

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
                  const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500),
                ),
                iconTheme: MaterialStateProperty.resolveWith((states) {
                  if (states.contains(MaterialState.selected)) {
                    return const IconThemeData(
                        color: Color(0xFF1A3C2B), size: 24);
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
                    Icons.home_outlined,
                    Icons.home,
                    'Inicio',
                  ),
                  _buildDestination(
                    Icons.shopping_bag_outlined,
                    Icons.shopping_bag,
                    'Caja',
                  ),
                  _buildDestination(
                    Icons.inventory_2_outlined,
                    Icons.inventory_2,
                    'Stock',
                  ),
                  _buildDestination(
                    Icons.people_outline,
                    Icons.people,
                    'Clientes',
                  ),
                  _buildDestination(
                    Icons.more_horiz,
                    Icons.more_horiz,
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

  NavigationDestination _buildDestination(
      IconData icon, IconData selectedIcon, String label) {
    return NavigationDestination(
      icon: Icon(icon),
      selectedIcon: Icon(selectedIcon),
      label: label,
    );
  }
}
