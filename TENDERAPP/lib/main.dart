import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:async';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'providers/product_provider.dart';
import 'providers/sale_provider.dart';
import 'providers/supplier_provider.dart';
import 'providers/customer_provider.dart';
import 'providers/expense_provider.dart';
import 'providers/purchase_provider.dart';
import 'providers/statistics_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/navigation_provider.dart';
import 'providers/calendar_provider.dart';
import 'api/notification_service.dart';
import 'api/supabase_service.dart';
import 'constants/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize FFI for desktop databases
  if (!kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await NotificationService().init();
  await initializeDateFormatting('es_ES', null);
  try {
    await SupabaseService.init();
  } catch (e) {
    debugPrint('main: Supabase no disponible por ahora: $e');
  }
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProxyProvider<ProductProvider, SaleProvider>(
          create: (context) => SaleProvider(Provider.of<ProductProvider>(context, listen: false)),
          update: (context, productProvider, saleProvider) => SaleProvider(productProvider),
        ),
        ChangeNotifierProxyProvider<ProductProvider, PurchaseProvider>(
          create: (context) => PurchaseProvider(Provider.of<ProductProvider>(context, listen: false)),
          update: (context, productProvider, purchaseProvider) => PurchaseProvider(productProvider),
        ),
        ChangeNotifierProvider(create: (_) => SupplierProvider()),
        ChangeNotifierProvider(create: (_) => CustomerProvider()),
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
        ChangeNotifierProvider(create: (_) => StatisticsProvider()),
        ChangeNotifierProvider(create: (_) => CalendarProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TenderApp',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Nunito',
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.lime,
          primary: AppColors.lime,
          surfaceTint: Colors.transparent,
        ),
        scaffoldBackgroundColor: AppColors.cream,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.ink,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: 'Nunito',
            color: AppColors.ink,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

/// Decide qué mostrar al abrir la app: el login (obligatorio para conectar la
/// tienda con la fidelización) o la app ya iniciada sesión.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _loggedIn = SupabaseService.isLoggedIn;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _listenAuthChanges();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  /// Escucha cambios de sesión (cerrar sesión, expiración). Se activa también
  /// si el cliente de Supabase recién queda listo tras un arranque sin red.
  void _listenAuthChanges() {
    if (_authSub != null || !SupabaseService.isReady) return;
    _authSub = SupabaseService.authStateChanges.listen((state) {
      final loggedIn = state.session != null;
      if (!loggedIn && mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      if (mounted) setState(() => _loggedIn = loggedIn);
    });
  }

  void _onLoggedIn() {
    _listenAuthChanges();
    setState(() => _loggedIn = true);
  }

  @override
  Widget build(BuildContext context) {
    return _loggedIn ? const HomeScreen() : LoginScreen(onLoggedIn: _onLoggedIn);
  }
}
