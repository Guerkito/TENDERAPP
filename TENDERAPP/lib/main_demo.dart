// Entry temporal SOLO para capturas de pantalla (recorrido automático).
// No forma parte del producto: borrar cuando termine la revisión visual.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'demo_seed.dart';import 'providers/product_provider.dart';
import 'providers/sale_provider.dart';
import 'providers/supplier_provider.dart';
import 'providers/customer_provider.dart';
import 'providers/expense_provider.dart';
import 'providers/purchase_provider.dart';
import 'providers/statistics_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/navigation_provider.dart';
import 'providers/calendar_provider.dart';
import 'constants/app_theme.dart';
import 'screens/add_customer_screen.dart';
import 'screens/add_product_screen.dart';
import 'screens/add_purchase_screen.dart';
import 'screens/add_supplier_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/cash_register_screen.dart';
import 'screens/customer_detail_screen.dart';
import 'screens/expenses_screen.dart';
import 'screens/expiring_products_screen.dart';
import 'screens/home_screen.dart';
import 'screens/import_products_screen.dart';
import 'screens/pin_screen.dart';
import 'screens/purchases_screen.dart';
import 'screens/sales_history_screen.dart';
import 'screens/statistics_screen.dart';
import 'screens/suppliers_screen.dart';
import 'models/customer_model.dart';
import 'screens/customer_purchases_screen.dart';
import 'widgets/customer_type_sheet.dart';
import 'screens/login_screen.dart';
import 'screens/loyalty_screen.dart';
import 'screens/receipt_review_screen.dart';
import 'screens/store_profile_screen.dart';

Future<void> _seed() async {
  await seedDemoData();
}

/// Pasos del recorrido: nombre + constructor + pestaña que debe activar.
List<(String, Widget Function(), int?)> _tour() => [
      ('login', () => const LoginScreen(), null),
      ('inicio', () => const HomeScreen(), 0),
      ('caja', () => const HomeScreen(), 1),
      (
        'tipo_cliente',
        () => Scaffold(
          backgroundColor: AppColors.cream,
          body: Align(
            alignment: Alignment.bottomCenter,
            child: CustomerTypeSheet(onSelect: (_) {}),
          ),
        ),
        null
      ),
      ('stock', () => const HomeScreen(), 2),
      ('clientes', () => const HomeScreen(), 3),
      ('mas', () => const HomeScreen(), 4),
      ('tarjetas_fid', () => const LoyaltyScreen(), null),
      ('facturas_web', () => const ReceiptReviewScreen(), null),
      ('perfil_tienda', () => const StoreProfileScreen(), null),
      (
        'compras_cliente',
        () => CustomerPurchasesScreen(
            customer: Customer(
                id: 1, name: 'María Fernanda Pérez', phone: '3012001000')),
        null
      ),
      (
        'cliente_detalle',
        () => CustomerDetailScreen(
            customer: Customer(
                id: 1, name: 'María Fernanda Pérez', phone: '3012001000')),
        null
      ),
      ('estadisticas', () => const StatisticsScreen(), null),
      ('historial_ventas', () => const SalesHistoryScreen(), null),
      ('gastos', () => const ExpensesScreen(), null),
      ('proveedores', () => const SuppliersScreen(), null),
      ('proveedor_nuevo', () => const AddSupplierScreen(), null),
      ('compras_proveedor', () => const PurchasesScreen(), null),
      ('compra_nueva', () => const AddPurchaseScreen(), null),
      ('alertas', () => const AlertsScreen(), null),
      ('por_vencer', () => const ExpiringProductsScreen(), null),
      ('calendario', () => const CalendarScreen(), null),
      ('cierre_caja', () => const CashRegisterScreen(), null),
      ('importar_excel', () => const ImportProductsScreen(), null),
      ('producto_nuevo', () => const AddProductScreen(), null),
      ('cliente_nuevo', () => const AddCustomerScreen(), null),
      ('pin_config', () => const PinSetupScreen(), null),
    ];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  await initializeDateFormatting('es_ES', null);
  await _seed();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProxyProvider<ProductProvider, SaleProvider>(
          create: (context) =>
              SaleProvider(Provider.of<ProductProvider>(context, listen: false)),
          update: (context, productProvider, saleProvider) =>
              SaleProvider(productProvider),
        ),
        ChangeNotifierProxyProvider<ProductProvider, PurchaseProvider>(
          create: (context) => PurchaseProvider(
              Provider.of<ProductProvider>(context, listen: false)),
          update: (context, productProvider, purchaseProvider) =>
              PurchaseProvider(productProvider),
        ),
        ChangeNotifierProvider(create: (_) => SupplierProvider()),
        ChangeNotifierProvider(create: (_) => CustomerProvider()),
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
        ChangeNotifierProvider(create: (_) => StatisticsProvider()),
        ChangeNotifierProvider(create: (_) => CalendarProvider()),
      ],
      child: const _TourApp(),
    ),
  );
}

class _TourApp extends StatefulWidget {
  const _TourApp();

  @override
  State<_TourApp> createState() => _TourAppState();
}

class _TourAppState extends State<_TourApp> {
  int _step = 0;
  late final List<(String, Widget Function(), int?)> _steps = _tour();
  late final Timer _timer;

  void _applyStep(int step) {
    final tab = _steps[step].$3;
    if (tab != null) {
      Provider.of<NavigationProvider>(context, listen: false).setIndex(tab);
    }
    debugPrint('TOUR: ${_steps[step].$1}');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyStep(_step));
    // Cambia de pantalla cada 6 segundos para que el script capture.
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (_step + 1 >= _steps.length) {
        debugPrint('TOUR: fin');
        _timer.cancel();
        return;
      }
      _step++;
      _applyStep(_step);
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  // Se ajusta con --dart-define=TEXT_SCALE_PCT=200 (para QA de accesibilidad).
  static const double _textScale =
      int.fromEnvironment('TEXT_SCALE_PCT', defaultValue: 100) / 100.0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TenderApp (tour)',
      builder: _textScale == 1.0
          ? null
          : (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(_textScale)),
                child: child!,
              ),
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Nunito',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFC6F24E),
          primary: const Color(0xFFC6F24E),
          surfaceTint: Colors.transparent,
        ),
        scaffoldBackgroundColor: const Color(0xFFF3F7EA),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Color(0xFF0F1D14),
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Color(0xFF0F1D14),
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),
      home: _steps[_step].$2(),
    );
  }
}
