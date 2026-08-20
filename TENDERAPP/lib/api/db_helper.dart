import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  static Database? _database;

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

  Future<Database> _initDB() async {
    try {
      String path;
      if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
        final documentsDirectory = await getApplicationDocumentsDirectory();
        path = join(documentsDirectory.path, 'tender_app.db');
      } else {
        path = join(await getDatabasesPath(), 'tender_app.db');
      }

      debugPrint('DBHelper: database path: $path');
      return await openDatabase(
        path,
        version: 14,
        onCreate: _onCreate,
        onUpgrade: (db, oldV, newV) async {
          debugPrint('DBHelper: migration $oldV -> $newV');
          await _onUpgrade(db, oldV, newV);
        },
      );
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

    debugPrint('DBHelper: schema created at version $version');
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
  }
}
