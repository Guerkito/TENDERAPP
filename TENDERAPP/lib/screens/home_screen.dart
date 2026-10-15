import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../api/cloud_sync.dart';
import '../api/supabase_service.dart';
import '../constants/app_theme.dart';
import '../widgets/motion.dart';
import '../providers/settings_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/product_provider.dart';
import '../providers/statistics_provider.dart';
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
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });
    // Cada 2 minutos trae lo de los otros celulares y publica lo de este.
    _syncTimer = Timer.periodic(
        const Duration(minutes: 2), (_) => _syncWithOtherDevices());
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Sincroniza y, si algo cambió, refresca lo que muestran las pantallas.
  Future<void> _syncWithOtherDevices() async {
    final done = await CloudSync.instance.syncNow();
    if (!done || !mounted) return;
    await Provider.of<ProductProvider>(context, listen: false).loadProducts();
    if (!mounted) return;
    final now = DateTime.now();
    await Provider.of<StatisticsProvider>(context, listen: false)
        .loadStatistics(year: now.year, month: now.month, day: now.day);
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

    // Registra la tienda en el sistema de fidelización al iniciar sesión,
    // para que el QR de los clientes funcione sin abrir otras pantallas.
    if (SupabaseService.isLoggedIn) {
      try {
        final remoteId = await SupabaseService.syncStore(
            settings.storeId, null);
        if (remoteId != settings.storeId) {
          await settings.updateStoreId(remoteId);
        }
      } catch (e) {
        debugPrint('HomeScreen: no se pudo sincronizar la tienda: $e');
      }
    }

    if (!settings.hasPinEnabled) {
      setState(() => _isUnlocked = true);
    }
    // Si tiene PIN, _isUnlocked permanece false → PinScreen se muestra

    if (!settings.isNameSet || !settings.isBusinessTypeSet) {
      _showOnboardingDialog(needsName: !settings.isNameSet);
    }

    // Publica lo de este celular y trae lo de los demás (no bloquea la UI).
    unawaited(_syncWithOtherDevices());
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
                      color: Color(0xFF143122))),
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
        backgroundColor: Color(0xFF143122),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFC6F24E)),
        ),
      );
    }

    // El PIN se muestra como capa encima para no desmontar la app:
    // así una venta a medio cobrar sobrevive a una interrupción.
    final showPin = settings.hasPinEnabled && !_isUnlocked;

    final navProvider = Provider.of<NavigationProvider>(context);

    return Stack(
      children: [
        ExcludeSemantics(
          excluding: showPin,
          child: Scaffold(
          body: IndexedStack(
            index: navProvider.selectedIndex,
            children: _widgetOptions,
          ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.forest,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: List.generate(_navItems.length, (index) {
                  final item = _navItems[index];
                  final selected = index == navProvider.selectedIndex;
                  return Expanded(
                    child: PressScale(
                      scale: 0.94,
                      onTap: () => navProvider.setIndex(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 12),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.lime : Colors.transparent,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                selected ? item.selectedIcon : item.icon,
                                size: 21,
                                color:
                                    selected ? AppColors.ink : Colors.white70,
                              ),
                              if (selected) ...[
                                const SizedBox(width: 7),
                                Text(
                                  item.label,
                                  style: const TextStyle(
                                    color: AppColors.ink,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          ),
        ),
        if (showPin)
          Positioned.fill(
            child:
                PinScreen(onSuccess: () => setState(() => _isUnlocked = true)),
          ),
      ],
    );
  }

  static const List<({IconData icon, IconData selectedIcon, String label})>
      _navItems = [
    (icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: 'Inicio'),
    (
      icon: Icons.shopping_bag_outlined,
      selectedIcon: Icons.shopping_bag_rounded,
      label: 'Caja'
    ),
    (
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2_rounded,
      label: 'Stock'
    ),
    (
      icon: Icons.people_outline_rounded,
      selectedIcon: Icons.people_rounded,
      label: 'Clientes'
    ),
    (
      icon: Icons.grid_view_rounded,
      selectedIcon: Icons.grid_view_rounded,
      label: 'Más'
    ),
  ];
}
