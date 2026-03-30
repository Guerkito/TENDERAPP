import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart'; // Import path_provider

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
    print('DBHelper: [DEBUG] Initializing database...');
    try {
      String path;
      if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
        // Desktop platforms
        final documentsDirectory = await getApplicationDocumentsDirectory();
        path = join(documentsDirectory.path, 'tender_app.db');
      } else {
        // Mobile platforms
        path = join(await getDatabasesPath(), 'tender_app.db');
      }
      
      print('DBHelper: [DEBUG] Database path: $path');
      return await openDatabase(
        path,
        version: 12,
        onCreate: _onCreate,
        onUpgrade: (db, oldV, newV) async {
          print('DBHelper: [DEBUG] MIGRATION DETECTED: $oldV -> $newV');
          await _onUpgrade(db, oldV, newV);
        },
      );
    } catch (e) {
      print('DBHelper: [DEBUG] FATAL Error initializing database: $e');
      rethrow;
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    print('DBHelper: Creating database tables for version $version...');
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
    print('DBHelper: Products table created.');

    await db.execute('''
      CREATE TABLE categories(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      )
    ''');
    print('DBHelper: Categories table created.');

    await db.execute('''
      CREATE TABLE supplier_appointments(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        supplier_id INTEGER NOT NULL,
        appointment_date TEXT NOT NULL,
        notes TEXT,
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id) ON DELETE CASCADE
      )
    ''');
    print('DBHelper: Supplier appointments table created.');

    await db.execute('''
      CREATE TABLE sales(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        total_amount REAL NOT NULL,
        payment_method TEXT NOT NULL,
        sale_date TEXT NOT NULL,
        customer_id INTEGER
      )
    ''');
    print('DBHelper: Sales table created.');

    await db.execute('''
      CREATE TABLE sale_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        price_at_sale REAL NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
      )
    ''');
    print('DBHelper: Sale items table created.');

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
    print('DBHelper: Suppliers table created.');

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
    print('DBHelper: Customers table created.');

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
    print('DBHelper: Customer movements table created.');

    await db.execute('''
      CREATE TABLE expenses(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        description TEXT,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        category TEXT
      )
    ''');
    print('DBHelper: Expenses table created.');

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
    print('DBHelper: Purchases table created.');

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
    print('DBHelper: Purchase items table created.');

    await db.execute('''
      CREATE TABLE product_batches(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        expiration_date TEXT,
        stock REAL NOT NULL DEFAULT 0,
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
      )
    ''');
    print('DBHelper: Product batches table created.');

    await db.execute('''
      CREATE TABLE settings(
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
    print('DBHelper: Settings table created.');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('DBHelper: Upgrading database from version $oldVersion to $newVersion...');
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
        print('DBHelper: Column expiration_date might already exist: $e');
      }
    }
    if (oldVersion < 4) {
      try {
        await db.execute("ALTER TABLE products ADD COLUMN product_type TEXT NOT NULL DEFAULT 'product'");
        await db.execute('ALTER TABLE products ADD COLUMN unit TEXT');
      } catch (e) {
        print('DBHelper: Columns product_type or unit might already exist: $e');
      }
    }
    if (oldVersion < 5) {
      try {
        await db.execute('ALTER TABLE sales ADD COLUMN customer_id INTEGER');
      } catch (e) {
        print('DBHelper: Column customer_id might already exist: $e');
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
      print('DBHelper: Upgraded to version 6 (Expenses table created).');
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
      print('DBHelper: Upgraded to version 7 (Purchase tables created).');
    }
    if (oldVersion < 8) {
      try {
        await db.execute('ALTER TABLE customers ADD COLUMN points INTEGER DEFAULT 0');
        print('DBHelper: Upgraded to version 8 (Points column added to customers).');
      } catch (e) {
        print('DBHelper: Column points might already exist: $e');
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
      
      // MIGRACIÓN: Mover stock actual y vencimiento a la tabla de lotes
      await db.execute('''
        INSERT INTO product_batches (product_id, expiration_date, stock)
        SELECT id, expiration_date, stock FROM products WHERE stock > 0 OR expiration_date IS NOT NULL
      ''');
      print('DBHelper: Upgraded to version 9 (Product batches created and migrated).');
    }
    if (oldVersion < 10) {
      await db.execute('''
        CREATE TABLE settings(
          key TEXT PRIMARY KEY,
          value TEXT
        )
      ''');
      print('DBHelper: Upgraded to version 10 (Settings table created).');
    }
    if (oldVersion < 11) {
      try {
        await db.execute('ALTER TABLE products ADD COLUMN category TEXT');
      } catch (e) {
        print('DBHelper: Column category might already exist: $e');
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
      print('DBHelper: Upgraded to version 11 (Added category column and missing tables).');
    }
    if (oldVersion < 12) {
      try {
        var columns = await db.rawQuery('PRAGMA table_info(products)');
        bool hasCategory = columns.any((column) => column['name'] == 'category');
        if (!hasCategory) {
          await db.execute('ALTER TABLE products ADD COLUMN category TEXT');
          print('DBHelper: [DEBUG] Category column added in version 12.');
        } else {
          print('DBHelper: [DEBUG] Category column already exists, skipping.');
        }
      } catch (e) {
        print('DBHelper: [DEBUG] Error checking/adding category column: $e');
      }
    }
  }
}
