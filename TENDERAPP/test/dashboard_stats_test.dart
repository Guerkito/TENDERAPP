import 'dart:ffi';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';
import 'package:tenderapp/api/db_helper.dart';
import 'package:tenderapp/constants/app_constants.dart';
import 'package:tenderapp/providers/statistics_provider.dart';

/// El dashboard muestra las cifras del día desde SQLite. Esta prueba crea la
/// base real (con sus migraciones) y verifica ese cálculo con ventas de hoy,
/// de ayer y una anulada.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  if (Platform.isLinux) {
    open.overrideFor(
        OperatingSystem.linux, () => DynamicLibrary.open('libsqlite3.so.0'));
  }
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfiNoIsolate;

  late Directory dir;

  setUp(() async {
    await DBHelper.closeAndReset();
    dir = await Directory.systemTemp.createTemp('tender_dashboard');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => dir.path,
    );
  });

  tearDown(() async {
    await DBHelper.closeAndReset();
    await dir.delete(recursive: true);
  });

  test('las cifras del día suman solo las ventas completadas de hoy', () async {
    final db = await DBHelper().database;
    String iso(DateTime d) => d.toIso8601String();
    Future<void> sale(double total, String date, String status) {
      return db.insert('sales', {
        'total_amount': total,
        'payment_method': PaymentMethod.cash,
        'sale_date': date,
        'status': status,
      });
    }

    final now = DateTime.now();
    await sale(5000.0, iso(now), SaleStatus.completed);
    await sale(9000.0, iso(now.subtract(const Duration(days: 1))),
        SaleStatus.completed);
    await sale(7000.0, iso(now), SaleStatus.cancelled);

    final stats = StatisticsProvider();
    await stats.loadStatistics(year: now.year, month: now.month, day: now.day);

    expect(stats.totalSalesAmount, 5000.0);
    expect(stats.dailyTransactionCount, 1);
    expect(stats.totalExpenses, 0.0);
  });
}
