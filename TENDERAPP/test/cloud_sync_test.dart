import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';
import 'package:tenderapp/api/cloud_sync.dart';
import 'package:tenderapp/api/db_helper.dart';

/// Nube de mentira con su propio "reloj de servidor" (contador), para probar
/// que dos celulares terminan con los mismos datos.
class FakeRemote implements SyncRemote {
  int _clock = 0;
  int _devices = 0;
  bool failNextUpsert = false;

  final Map<String, Map<int, Map<String, dynamic>>> rows = {};
  final Map<String, Map<int, Map<String, dynamic>>> deletions = {};

  String _stamp() => (++_clock).toString().padLeft(12, '0');

  bool _after(String stamp, int id, String? sinceAt, int sinceId) {
    if (sinceAt == null) return true;
    if (stamp != sinceAt) return stamp.compareTo(sinceAt) > 0;
    return id > sinceId;
  }

  int _cmp(String atA, int idA, String atB, int idB) {
    final byStamp = atA.compareTo(atB);
    return byStamp != 0 ? byStamp : idA.compareTo(idB);
  }

  @override
  Future<int> registerDevice(String label) async => ++_devices;

  @override
  Future<void> upsertRows(
      String table, List<Map<String, dynamic>> data) async {
    if (failNextUpsert) {
      failNextUpsert = false;
      throw Exception('sin internet (prueba)');
    }
    final target = rows.putIfAbsent(table, () => {});
    for (final row in data) {
      target[(row['id'] as num).toInt()] = {
        ...row,
        'synced_at': _stamp(),
      };
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchRows(
      String table, String? sinceAt, int sinceId, int limit) async {
    final all = (rows[table] ?? {}).values.toList()
      ..sort((a, b) => _cmp(a['synced_at'] as String, (a['id'] as num).toInt(),
          b['synced_at'] as String, (b['id'] as num).toInt()));
    return all
        .where((r) => _after(r['synced_at'] as String, (r['id'] as num).toInt(),
            sinceAt, sinceId))
        .take(limit)
        .toList();
  }

  @override
  Future<void> pushDeletions(List<Map<String, dynamic>> data) async {
    for (final row in data) {
      final table = row['table_name'] as String;
      final rowId = (row['row_id'] as num).toInt();
      deletions.putIfAbsent(table, () => {})[rowId] = {
        'table_name': table,
        'row_id': rowId,
        'synced_at': _stamp(),
      };
      rows[table]?.remove(rowId);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchDeletions(
      String? sinceAt, int sinceId, int limit) async {
    final all = deletions.values.expand((m) => m.values).toList()
      ..sort((a, b) => _cmp(a['synced_at'] as String, (a['row_id'] as num).toInt(),
          b['synced_at'] as String, (b['row_id'] as num).toInt()));
    return all
        .where((r) => _after(r['synced_at'] as String,
            (r['row_id'] as num).toInt(), sinceAt, sinceId))
        .take(limit)
        .toList();
  }
}

/// Un celular de prueba: su base SQLite y su motor de sincronización.
class FakeDevice {
  FakeDevice(this.name, this.db, this.sync);

  final String name;
  final Database db;
  final CloudSync sync;

  Future<List<Map<String, dynamic>>> all(String table) =>
      db.query(table, orderBy: 'id ASC');

  Future<int> insert(String table, Map<String, dynamic> values) =>
      db.insert(table, values);

  Future<void> update(String table, Map<String, dynamic> values, int id) =>
      db.update(table, values, where: 'id = ?', whereArgs: [id]);

  Future<void> remove(String table, int id) =>
      db.delete(table, where: 'id = ?', whereArgs: [id]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  if (Platform.isLinux) {
    open.overrideFor(
        OperatingSystem.linux, () => DynamicLibrary.open('libsqlite3.so.0'));
  }
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfiNoIsolate;

  late Directory dir;
  late FakeRemote cloud;
  late FakeDevice a;
  late FakeDevice b;

  Future<FakeDevice> openDevice(String name) async {
    final db = await DBHelper.openAt('${dir.path}/$name.db');
    final sync = CloudSync(
      openDb: () async => db,
      remote: cloud,
      deviceLabel: name,
      isLoggedIn: () => true,
    );
    return FakeDevice(name, db, sync);
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('tender_sync');
    cloud = FakeRemote();
    a = await openDevice('celular_a');
    b = await openDevice('celular_b');
  });

  tearDown(() async {
    await DBHelper.closeAndReset();
    await dir.delete(recursive: true);
  });

  test('los dos celulares ven las mismas ventas y productos, sin chocar ids',
      () async {
    await a.insert('products', {
      'name': 'Coca-Cola 400ml',
      'purchase_price': 2000.0,
      'sale_price': 3500.0,
      'stock': 10,
    });
    await a.insert('sales', {
      'total_amount': 3500.0,
      'payment_method': 'Efectivo',
      'sale_date': DateTime.now().toIso8601String(),
      'status': 'completed',
    });

    await a.sync.syncNow(force: true);

    await b.insert('products', {
      'name': 'Papas Margarita',
      'purchase_price': 1500.0,
      'sale_price': 2500.0,
      'stock': 8,
    });
    await b.insert('sales', {
      'total_amount': 2500.0,
      'payment_method': 'Nequi / Daviplata',
      'sale_date': DateTime.now().toIso8601String(),
      'status': 'completed',
    });

    await b.sync.syncNow(force: true);
    await a.sync.syncNow(force: true);
    await b.sync.syncNow(force: true);

    // Los dos ven los dos productos y las dos ventas.
    for (final device in [a, b]) {
      final products = await device.all('products');
      final sales = await device.all('sales');
      expect(products.map((p) => p['name']), containsAll(
          ['Coca-Cola 400ml', 'Papas Margarita']),
          reason: '${device.name} no ve los productos de los dos celulares');
      expect(sales.map((s) => s['total_amount']), containsAll([3500.0, 2500.0]),
          reason: '${device.name} no ve las ventas de los dos celulares');
      expect(products.length, 2);
      expect(sales.length, 2);
    }

    // Cada uno guarda lo suyo en su propio bloque de ids: no hay choques.
    final productsA = await a.all('products');
    final productsB = await b.all('products');
    expect(productsA.map((p) => p['id']).toSet(), productsB.map((p) => p['id']).toSet());
    final ids = productsA.map((p) => p['id'] as int).toList();
    expect(ids.where((id) => id >= 1000000000000 && id < 2000000000000).length,
        1,
        reason: 'el producto creado en A debe vivir en el bloque de A');
    expect(ids.where((id) => id >= 2000000000000 && id < 3000000000000).length,
        1,
        reason: 'el producto creado en B debe vivir en el bloque de B');

    // Un registro nuevo después de activar también nace en el bloque propio.
    final lateProduct = await a.insert('products', {
      'name': 'Chicle',
      'purchase_price': 200.0,
      'sale_price': 500.0,
      'stock': 20,
    });
    expect(lateProduct, greaterThan(1000000000000));
  });

  test('editar en un celular llega al otro sin duplicar', () async {
    await a.insert('products', {
      'name': 'Coca-Cola 400ml',
      'purchase_price': 2000.0,
      'sale_price': 3500.0,
      'stock': 10,
    });
    await a.sync.syncNow(force: true);
    await b.sync.syncNow(force: true);
    expect((await b.all('products')).length, 1);
    // Tras activarse, el id cambia de bloque: se lee el actual.
    final product = (await b.all('products')).first['id'] as int;

    // B (que ve el producto espejo de A) le cambia el precio.
    await b.update('products', {'sale_price': 4000.0}, product);
    await b.sync.syncNow(force: true);
    await a.sync.syncNow(force: true);

    final inA = await a.all('products');
    final inB = await b.all('products');
    expect(inA.length, 1, reason: 'no debe duplicarse el producto');
    expect(inB.length, 1);
    expect(inA.first['sale_price'], 4000.0);
    expect(inB.first['sale_price'], 4000.0);
  });

  test('borrar en un celular borra en el otro', () async {
    await a.insert('products', {
      'name': 'Producto perdido',
      'purchase_price': 100.0,
      'sale_price': 200.0,
      'stock': 3,
    });
    await a.sync.syncNow(force: true);
    await b.sync.syncNow(force: true);
    expect((await b.all('products')).length, 1);
    final product = (await b.all('products')).first['id'] as int;

    // Se borra desde B (espejo) y debe desaparecer también en A.
    await b.remove('products', product);
    await b.sync.syncNow(force: true);
    await a.sync.syncNow(force: true);

    expect(await a.all('products'), isEmpty);
    expect(await b.all('products'), isEmpty);
  });

  test('si no se puede subir, no se pisa lo local ni se baja nada', () async {
    await a.insert('products', {
      'name': 'Arroz 1kg',
      'purchase_price': 3000.0,
      'sale_price': 4500.0,
      'stock': 5,
    });
    await a.sync.syncNow(force: true);
    await b.sync.syncNow(force: true);
    final product = (await b.all('products')).first['id'] as int;

    // El otro celular cambia el nombre y sube bien.
    await b.update('products', {'name': 'Arroz premium'}, product);
    await b.sync.syncNow(force: true);

    // A edita lo mismo pero se queda sin internet: no debe perder su cambio.
    await a.update('products', {'name': 'Arroz de la casa'}, product);
    cloud.failNextUpsert = true;
    final ok = await a.sync.syncNow(force: true);

    expect(ok, isFalse);
    expect((await a.all('products')).first['name'], 'Arroz de la casa');
    expect(a.sync.status.error, isNotNull);

    // Cuando vuelve el internet, gana el último que subió (A).
    await a.sync.syncNow(force: true);
    await b.sync.syncNow(force: true);
    expect((await a.all('products')).first['name'], 'Arroz de la casa');
    expect((await b.all('products')).first['name'], 'Arroz de la casa');
  });

  test('sincronizar dos veces no reenvía lo que ya está al día', () async {
    await a.insert('products', {
      'name': 'Pan tajado',
      'purchase_price': 1000.0,
      'sale_price': 1800.0,
      'stock': 6,
    });
    await a.sync.syncNow(force: true);
    await b.sync.syncNow(force: true);

    final before = cloud.rows['products']!.values.first['synced_at'];
    await a.sync.syncNow(force: true);
    await b.sync.syncNow(force: true);
    final after = cloud.rows['products']!.values.first['synced_at'];

    expect(after, before,
        reason: 'nada cambió: no debe volver a subirse la misma fila');
    expect(cloud.rows['products']!.length, 1);
  });
}
