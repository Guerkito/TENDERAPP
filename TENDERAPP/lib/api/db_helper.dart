import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import 'sync_schema.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  static Database? _database;

  /// Versión del esquema local. Sube de a uno cada vez que hay migración.
  static const int schemaVersion = 17;

  factory DBHelper() {
    return _instance;
  }

  DBHelper._internal();

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initDB();
    return _database!;
  }

  /// Cierra la conexión y la deja lista para reabrirse.
  /// Se usa al restaurar una copia de seguridad.
  static Future<void> closeAndReset() async {
    final db = _database;
    _database = null;
    if (db != null) {
      try {
        await db.close();
      } catch (e) {
        debugPrint('DBHelper: error al cerrar la base: $e');
      }
    }
  }

  /// Abre (o crea/migra) una base TenderApp en [path]. La usa la app para su
  /// base normal y las pruebas para simular varios celulares a la vez.
  static Future<Database> openAt(String path) {
    debugPrint('DBHelper: database path: $path');
    return openDatabase(
      path,
      version: schemaVersion,
      onCreate: DBHelper()._onCreate,
      onUpgrade: (db, oldV, newV) async {
        debugPrint('DBHelper: migration $oldV -> $newV');
        await DBHelper()._onUpgrade(db, oldV, newV);
      },
    );
  }

  Future<Database> _initDB() async {
    try {
      String path;
      if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
        final documentsDirectory = await getApplicationDocumentsDirectory();
        path = join(documentsDirectory.path, 'tender_app.db');
      } else {
        path = join(await getDatabasesPath(), 'tender_app.db');
      }
      return await openAt(path);
    } catch (e) {
      debugPrint('DBHelper: FATAL error initializing database: $e');
      rethrow;
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        barcode TEXT UNIQUE,
        description TEXT,
        purchase_price REAL NOT NULL,
        sale_price REAL NOT NULL,
        stock INTEGER NOT NULL DEFAULT 0,
        expiration_date TEXT,
        product_type TEXT NOT NULL DEFAULT 'product',
        unit TEXT,
        category TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE categories(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE supplier_appointments(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        supplier_id INTEGER NOT NULL,
        appointment_date TEXT NOT NULL,
        notes TEXT,
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE sales(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        total_amount REAL NOT NULL,
        payment_method TEXT NOT NULL,
        sale_date TEXT NOT NULL,
        customer_id INTEGER,
        status TEXT NOT NULL DEFAULT 'completed'
      )
    ''');

    await db.execute('''
      CREATE TABLE sale_payments(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        payment_method TEXT NOT NULL,
        amount REAL NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE sale_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        price_at_sale REAL NOT NULL,
        discount REAL NOT NULL DEFAULT 0,
        FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE suppliers(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        contact_person TEXT,
        phone TEXT,
        email TEXT,
        address TEXT,
        last_visit TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE customers(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        credit_limit REAL DEFAULT 0,
        total_pending_balance REAL DEFAULT 0,
        points INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE customer_movements(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL,
        date_time TEXT NOT NULL,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        description TEXT,
        sale_id INTEGER,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE expenses(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        description TEXT,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        category TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE purchases(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        supplier_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        total_amount REAL NOT NULL,
        notes TEXT,
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE purchase_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        purchase_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        cost_price REAL NOT NULL,
        FOREIGN KEY (purchase_id) REFERENCES purchases (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE product_batches(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        expiration_date TEXT,
        stock REAL NOT NULL DEFAULT 0,
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE settings(
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE loyalty_movements(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL,
        date_time TEXT NOT NULL,
        type TEXT NOT NULL,
        amount INTEGER NOT NULL DEFAULT 1,
        note TEXT,
        source TEXT,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE
      )
    ''');

    debugPrint('DBHelper: schema created at version $version');

    await _createSyncSchema(db);
  }

  /// Objetos que hacen posible la sincronización entre celulares (v16):
  /// - `updated_at` en cada tabla compartida (marca de cambio por fila),
  ///   la estampan los triggers, sin que las pantallas tengan que hacer nada.
  /// - `_sync_tombstones`: papelera de borrados, para que un borrado viaje.
  /// - `_sync_meta`: bloque de ids de este celular y cursores de sincronización.
  Future<void> _createSyncSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS _sync_meta(
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS _sync_tombstones(
        table_name TEXT NOT NULL,
        row_id INTEGER NOT NULL,
        deleted_at TEXT NOT NULL,
        PRIMARY KEY (table_name, row_id)
      )
    ''');

    for (final table in syncedTables) {
      try {
        await db.execute('ALTER TABLE $table ADD COLUMN updated_at TEXT');
      } catch (e) {
        // Ya existe: la migración se está repitiendo sobre una base al día.
      }
      try {
        await db.execute(
            'ALTER TABLE $table ADD COLUMN _dirty INTEGER NOT NULL DEFAULT 0');
      } catch (e) {
        // Ya existe.
      }
      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS trg_${table}_ins AFTER INSERT ON $table
        WHEN NEW.updated_at IS NULL
        BEGIN
          UPDATE $table
             SET updated_at = strftime('%Y-%m-%dT%H:%M:%fZ','now'), _dirty = 1
           WHERE id = NEW.id;
        END
      ''');
      // Estampa solo si la escritura NO trajo su propia marca: la bajada de
      // cambios remotos sí la trae (y no debe marcarse como cambio local).
      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS trg_${table}_upd AFTER UPDATE ON $table
        WHEN NEW.updated_at IS OLD.updated_at AND NEW._dirty IS OLD._dirty
        BEGIN
          UPDATE $table
             SET updated_at = strftime('%Y-%m-%dT%H:%M:%fZ','now'), _dirty = 1
           WHERE id = NEW.id;
        END
      ''');
      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS trg_${table}_del AFTER DELETE ON $table
        BEGIN
          INSERT OR REPLACE INTO _sync_tombstones(table_name, row_id, deleted_at)
          VALUES ('$table', OLD.id, strftime('%Y-%m-%dT%H:%M:%fZ','now'));
        END
      ''');
    }

    // Lo que ya existía se publica en la primera sincronización.
    for (final table in syncedTables) {
      await db.rawUpdate(
          'UPDATE $table SET updated_at = ?, _dirty = 1 WHERE updated_at IS NULL',
          [DateTime.now().toUtc().toIso8601String()]);
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE suppliers(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          contact_person TEXT,
          phone TEXT,
          email TEXT,
          address TEXT,
          last_visit TEXT
        )
      ''');
    }
    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE products ADD COLUMN expiration_date TEXT');
      } catch (e) {
        debugPrint('DBHelper: v3 - expiration_date already exists: $e');
      }
    }
    if (oldVersion < 4) {
      try {
        await db.execute("ALTER TABLE products ADD COLUMN product_type TEXT NOT NULL DEFAULT 'product'");
        await db.execute('ALTER TABLE products ADD COLUMN unit TEXT');
      } catch (e) {
        debugPrint('DBHelper: v4 - columns might already exist: $e');
      }
    }
    if (oldVersion < 5) {
      try {
        await db.execute('ALTER TABLE sales ADD COLUMN customer_id INTEGER');
      } catch (e) {
        debugPrint('DBHelper: v5 - customer_id might already exist: $e');
      }
      await db.execute('''
        CREATE TABLE customers(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          phone TEXT,
          credit_limit REAL DEFAULT 0,
          total_pending_balance REAL DEFAULT 0
        )
      ''');
      await db.execute('''
        CREATE TABLE customer_movements(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          customer_id INTEGER NOT NULL,
          date_time TEXT NOT NULL,
          type TEXT NOT NULL,
          amount REAL NOT NULL,
          description TEXT,
          sale_id INTEGER,
          FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 6) {
      await db.execute('''
        CREATE TABLE expenses(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          description TEXT,
          amount REAL NOT NULL,
          date TEXT NOT NULL,
          category TEXT
        )
      ''');
      debugPrint('DBHelper: upgraded to v6 (expenses table)');
    }
    if (oldVersion < 7) {
      await db.execute('''
        CREATE TABLE purchases(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          supplier_id INTEGER NOT NULL,
          date TEXT NOT NULL,
          total_amount REAL NOT NULL,
          notes TEXT,
          FOREIGN KEY (supplier_id) REFERENCES suppliers (id)
        )
      ''');
      await db.execute('''
        CREATE TABLE purchase_items(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          purchase_id INTEGER NOT NULL,
          product_id INTEGER NOT NULL,
          quantity INTEGER NOT NULL,
          cost_price REAL NOT NULL,
          FOREIGN KEY (purchase_id) REFERENCES purchases (id) ON DELETE CASCADE,
          FOREIGN KEY (product_id) REFERENCES products (id)
        )
      ''');
      debugPrint('DBHelper: upgraded to v7 (purchase tables)');
    }
    if (oldVersion < 8) {
      try {
        await db.execute('ALTER TABLE customers ADD COLUMN points INTEGER DEFAULT 0');
        debugPrint('DBHelper: upgraded to v8 (points column)');
      } catch (e) {
        debugPrint('DBHelper: v8 - points might already exist: $e');
      }
    }
    if (oldVersion < 9) {
      await db.execute('''
        CREATE TABLE product_batches(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          product_id INTEGER NOT NULL,
          expiration_date TEXT,
          stock REAL NOT NULL DEFAULT 0,
          FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
        )
      ''');
      await db.execute('''
        INSERT INTO product_batches (product_id, expiration_date, stock)
        SELECT id, expiration_date, stock FROM products WHERE stock > 0 OR expiration_date IS NOT NULL
      ''');
      debugPrint('DBHelper: upgraded to v9 (product batches)');
    }
    if (oldVersion < 10) {
      await db.execute('''
        CREATE TABLE settings(
          key TEXT PRIMARY KEY,
          value TEXT
        )
      ''');
      debugPrint('DBHelper: upgraded to v10 (settings table)');
    }
    if (oldVersion < 11) {
      try {
        await db.execute('ALTER TABLE products ADD COLUMN category TEXT');
      } catch (e) {
        debugPrint('DBHelper: v11 - category might already exist: $e');
      }
      await db.execute('''
        CREATE TABLE IF NOT EXISTS categories(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS supplier_appointments(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          supplier_id INTEGER NOT NULL,
          appointment_date TEXT NOT NULL,
          notes TEXT,
          FOREIGN KEY (supplier_id) REFERENCES suppliers (id) ON DELETE CASCADE
        )
      ''');
      debugPrint('DBHelper: upgraded to v11 (categories + supplier_appointments)');
    }
    if (oldVersion < 12) {
      try {
        final columns = await db.rawQuery('PRAGMA table_info(products)');
        final hasCategory = columns.any((col) => col['name'] == 'category');
        if (!hasCategory) {
          await db.execute('ALTER TABLE products ADD COLUMN category TEXT');
        }
      } catch (e) {
        debugPrint('DBHelper: v12 - error checking category: $e');
      }
      debugPrint('DBHelper: upgraded to v12');
    }
    if (oldVersion < 13) {
      try {
        await db.execute('ALTER TABLE sale_items ADD COLUMN discount REAL NOT NULL DEFAULT 0');
        debugPrint('DBHelper: upgraded to v13 (discount on sale_items)');
      } catch (e) {
        debugPrint('DBHelper: v13 - discount might already exist: $e');
      }
    }
    if (oldVersion < 14) {
      try {
        await db.execute("ALTER TABLE sales ADD COLUMN status TEXT NOT NULL DEFAULT 'completed'");
        debugPrint('DBHelper: upgraded to v14 (status on sales)');
      } catch (e) {
        debugPrint('DBHelper: v14 - status might already exist: $e');
      }
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sale_payments(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sale_id INTEGER NOT NULL,
          payment_method TEXT NOT NULL,
          amount REAL NOT NULL,
          FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE
        )
      ''');
      debugPrint('DBHelper: upgraded to v14 (sale_payments table)');
    }
    if (oldVersion < 15) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS loyalty_movements(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          customer_id INTEGER NOT NULL,
          date_time TEXT NOT NULL,
          type TEXT NOT NULL,
          amount INTEGER NOT NULL DEFAULT 1,
          note TEXT,
          source TEXT,
          FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE
        )
      ''');
      debugPrint('DBHelper: upgraded to v15 (loyalty_movements table)');
    }
    if (oldVersion < 16) {
      await _createSyncSchema(db);
      debugPrint('DBHelper: upgraded to v16 (sincronización entre celulares)');
    }
    if (oldVersion < 17) {
      // El calendario de visitas pasa a sincronizarse: se le crean sus marcas
      // de cambio y, si este celular ya está activado, sus ids entran al
      // bloque del celular (antes no se habían renumerado).
      await _createSyncSchema(db);
      final meta = await db.query('_sync_meta',
          columns: ['value'],
          where: 'key = ?',
          whereArgs: ['device_index'],
          limit: 1);
      final index =
          meta.isEmpty ? null : int.tryParse((meta.first['value'] as String?) ?? '');
      if (index != null) {
        await db.rawUpdate(
            'UPDATE supplier_appointments SET id = id + ? WHERE id < ?',
            [index * idNamespace, idNamespace]);
      }
      debugPrint('DBHelper: upgraded to v17 (calendario de visitas)');
    }
  }
}
