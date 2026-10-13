// Sembrador de datos demo (SOLO para capturas/pruebas visuales).
// No forma parte del producto.
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import 'api/db_helper.dart';

Future<String> seedDemoData() async {
  final db = await DBHelper().database;

  // Solo siembra un dispositivo vacío: no pisa datos reales.
  final count = await db.rawQuery('SELECT COUNT(*) n FROM products');
  if (((count.first['n'] as num?) ?? 0) > 0) {
    return 'Este dispositivo ya tiene productos registrados; no se cargó nada.';
  }

  for (final entry in {
    'store_name': 'Licorera Punto de Encuentro',
    'business_type': 'liquor',
    'loyalty_goal': '6',
    'loyalty_reward': '1 cerveza Águila gratis',
  }.entries) {
    await db.insert('settings', {'key': entry.key, 'value': entry.value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  final rnd = Random(7);

  // ---------------------------------------------------------------- catálogo
  // (nombre, categoría, precio venta, precio compra, stock, días para vencer)
  final catalog = <(String, String, double, double, int, int?)>[
    ('Cerveza Águila Original Lata 330ml', 'Cervezas', 4000, 3100, 48, 150),
    ('Cerveza Águila Light Lata 330ml', 'Cervezas', 4000, 3100, 36, 150),
    ('Cerveza Águila 0.0 Lata 330ml', 'Cervezas', 4200, 3300, 18, 150),
    ('Cerveza Águila Botella 330ml', 'Cervezas', 4500, 3400, 24, 150),
    ('Cerveza Poker Lata 330ml', 'Cervezas', 3500, 2700, 42, 150),
    ('Cerveza Pilsen Lata 330ml', 'Cervezas', 3800, 2900, 30, 150),
    ('Cerveza Club Colombia Roja Botella 330ml', 'Cervezas', 5300, 4100, 24, 150),
    ('Cerveza Club Colombia Dorada Botella 330ml', 'Cervezas', 5500, 4300, 18, 150),
    ('Cerveza Club Colombia Negra Botella 330ml', 'Cervezas', 5500, 4300, 12, 150),
    ('Cerveza Costeñita Lata 330ml', 'Cervezas', 3500, 2700, 24, 150),
    ('Cerveza Corona Extra Botella 355ml', 'Cervezas', 9000, 7200, 12, 200),
    ('Cerveza Heineken Botella 330ml', 'Cervezas', 8500, 6800, 12, 200),
    ('Cerveza Stella Artois Botella 330ml', 'Cervezas', 8000, 6300, 12, 200),
    ('Cerveza BBC Cajicá Botella 330ml', 'Cervezas', 7500, 5800, 9, 90),
    ('Pack Águila Original x6 Lata', 'Cervezas', 22500, 18500, 10, 150),
    ('Pack Club Colombia Dorada x6 Botella', 'Cervezas', 31000, 25000, 6, 150),
    ('Aguardiente Antioqueño Tapa Roja Media 375ml', 'Aguardiente', 32500, 25500, 24, 540),
    ('Aguardiente Antioqueño Tapa Azul Media 375ml', 'Aguardiente', 32500, 25700, 18, 540),
    ('Aguardiente Antioqueño Tapa Verde Media 375ml', 'Aguardiente', 29000, 22000, 18, 540),
    ('Aguardiente Antioqueño Tapa Roja Botella 750ml', 'Aguardiente', 58000, 46850, 12, 540),
    ('Aguardiente Antioqueño Sin Azúcar 750ml', 'Aguardiente', 50000, 39500, 9, 540),
    ('Aguardiente Cristal Tradicional Botella 750ml', 'Aguardiente', 44000, 34680, 9, 540),
    ('Aguardiente Cristal XS Media 375ml', 'Aguardiente', 24000, 18070, 12, 540),
    ('Aguardiente Néctar Rojo Botella 750ml', 'Aguardiente', 48000, 38890, 8, 540),
    ('Aguardiente Néctar Club Litro 1000ml', 'Aguardiente', 56000, 45720, 6, 540),
    ('Aguardiente Líder Verde Tercio PET 175ml', 'Aguardiente', 12000, 8940, 36, 540),
    ('Aguardiente Líder Azul Tercio PET 175ml', 'Aguardiente', 13500, 10490, 24, 540),
    ('Amarillo de Manzanares Media 375ml', 'Aguardiente', 33000, 25200, 12, 540),
    ('Ron Medellín Clásico Botella 750ml', 'Rones', 47000, 37500, 10, 720),
    ('Ron Medellín Añejo Botella 750ml', 'Rones', 65000, 52000, 6, 720),
    ('Ron Viejo de Caldas 8 Años 750ml', 'Rones', 54500, 46000, 6, 720),
    ('Ron Santa Fe Botella 750ml', 'Rones', 42000, 33000, 8, 720),
    ('Whisky Old Parr 12 Años 750ml', 'Whisky', 92000, 75000, 6, 900),
    ("Whisky Buchanan's Deluxe 12 750ml", 'Whisky', 95000, 78000, 6, 900),
    ("Whisky Buchanan's Deluxe 375ml", 'Whisky', 52000, 42000, 6, 900),
    ('Whisky Something Special 750ml', 'Whisky', 72000, 60000, 6, 900),
    ('Whisky Johnnie Walker Red 750ml', 'Whisky', 88000, 72000, 4, 900),
    ('Whisky J&B 750ml', 'Whisky', 82000, 68000, 4, 900),
    ('Vodka Smirnoff 750ml', 'Vodka', 56000, 45000, 6, 900),
    ('Vodka Absolut 750ml', 'Vodka', 110000, 90000, 4, 900),
    ('Tequila José Cuervo Especial 750ml', 'Tequila', 118000, 95000, 4, 900),
    ('Vino Gato Negro Cabernet 750ml', 'Vinos', 29000, 22000, 9, 720),
    ('Vino Casillero del Diablo 750ml', 'Vinos', 48000, 38000, 6, 720),
    ('Coca-Cola 1.5L', 'Pasabocas y mezcladores', 7000, 5500, 24, 200),
    ('Maní La Especial 45g', 'Pasabocas y mezcladores', 2500, 1900, 20, 120),
    ('Papas Margarita 105g', 'Pasabocas y mezcladores', 5500, 4200, 18, 90),
    ('Hielo Bolsa 2kg', 'Pasabocas y mezcladores', 5000, 3500, 15, 30),
  ];

  final productIds = <int>[];
  final salePrices = <double>[];
  final names = <String>[];
  var barcode = 7702000100000;
  for (var i = 0; i < catalog.length; i++) {
    final (name, category, sell, buy, stock, expiryDays) = catalog[i];
    final id = await db.insert('products', {
      'name': name,
      'barcode': '${barcode + i}',
      'purchase_price': buy,
      'sale_price': sell,
      'stock': stock,
      'product_type': 'product',
      'unit': 'Unidad',
      'category': category,
    });
    productIds.add(id);
    salePrices.add(sell);
    names.add(name);
    await db.insert('product_batches', {
      'product_id': id,
      'expiration_date': expiryDays == null
          ? null
          : DateTime.now()
              .add(Duration(days: expiryDays))
              .toIso8601String(),
      'stock': stock,
    });
  }
  // Dos lotes por vencer pronto (alerta real en Inicio).
  for (final i in [13, 7]) {
    await db.update('product_batches', {
      'expiration_date':
          DateTime.now().add(const Duration(days: 16)).toIso8601String(),
    }, where: 'product_id = ?', whereArgs: [productIds[i]]);
  }

  // ------------------------------------------------------------- proveedores
  final suppliers = <(String, String, String, String, String)>[
    ('Dislicores S.A.S.', 'Andrés Ramírez', '310 555 2233', 'ventas@dislicores.com', 'Bodega Itagüí'),
    ('Bavaria S.A.', 'Carolina Gómez', '320 444 1100', 'pedidos.bavaria@bavaria.co', 'Planta Medellín'),
    ('Fábrica de Licores de Antioquia', 'Jorge Villa', '311 222 8899', 'distribucion@fla.gov.co', 'Envigado'),
    ('Diageo Colombia', 'Paula Restrepo', '315 678 3322', 'pedidos@diageo.co', 'Bogotá D.C.'),
    ('Coca-Cola FEMSA', 'Diana Osorio', '314 220 7788', 'servicio@coca-colafemsa.com', 'Rionegro'),
    ('Postobón S.A.', 'Sandra Mejía', '322 445 6677', 'distribucion@postobon.com', 'Bello'),
    ('Distribuidora El Cóndor', 'Mauricio Ruiz', '300 998 1122', 'elcondor.licores@gmail.com', 'Centro de Medellín'),
  ];
  final supplierIds = <int>[];
  for (var i = 0; i < suppliers.length; i++) {
    final (name, contact, phone, email, address) = suppliers[i];
    supplierIds.add(await db.insert('suppliers', {
      'name': name,
      'contact_person': contact,
      'phone': phone,
      'email': email,
      'address': address,
      'last_visit': DateTime.now()
          .subtract(Duration(days: 3 + i * 2))
          .toIso8601String(),
    }));
  }

  // ----------------------------------------------------------------- compras
  final purchases = <(int, int, List<(int, int, double)>)>[
    // (día-hace, proveedor, [(producto, cantidad, costo unitario)])
    (12, 0, [(16, 12, 25500), (17, 12, 25700), (28, 10, 37500)]),
    (9, 1, [(0, 48, 3100), (4, 48, 2700), (8, 18, 4100)]),
    (5, 6, [(25, 36, 8940), (42, 12, 22000), (43, 10, 1900)]),
    (2, 3, [(32, 6, 75000), (33, 6, 78000), (38, 6, 45000)]),
  ];
  for (final (daysAgo, supIdx, items) in purchases) {
    final date = DateTime.now().subtract(Duration(days: daysAgo));
    var total = 0.0;
    for (final (_, qty, cost) in items) {
      total += qty * cost;
    }
    final purchaseId = await db.insert('purchases', {
      'supplier_id': supplierIds[supIdx],
      'date': date.toIso8601String(),
      'total_amount': total,
      'notes': 'Entrada de mercancía',
    });
    for (final (prodIdx, qty, cost) in items) {
      await db.insert('purchase_items', {
        'purchase_id': purchaseId,
        'product_id': productIds[prodIdx],
        'quantity': qty,
        'cost_price': cost,
      });
    }
  }

  // ------------------------------------------------------------------ gastos
  final expenses = <(int, String, double, String)>[
    (13, 'Arriendo del local', 1400000, 'Alquiler'),
    (12, 'Luz EPM', 185400, 'Servicios'),
    (12, 'Agua y acueducto', 48700, 'Servicios'),
    (11, 'Internet Claro', 95000, 'Servicios'),
    (10, 'Pago empleada (quincena)', 650000, 'Sueldos'),
    (9, 'Domicilios y moto', 90000, 'Otros'),
    (8, 'Mantenimiento nevera exhibidora', 120000, 'Mantenimiento'),
    (7, 'Hielo y bolsas', 60000, 'Otros'),
    (6, 'Cambio de canastillas', 80000, 'Mantenimiento'),
    (5, 'Volantes y publicidad', 80000, 'Otros'),
    (4, 'Aseo del local', 55000, 'Otros'),
    (3, 'Parqueadero moto', 30000, 'Otros'),
    (2, 'Recarga celular negocio', 20000, 'Otros'),
    (1, 'Pago empleada (quincena)', 650000, 'Sueldos'),
  ];
  for (final (daysAgo, desc, amount, category) in expenses) {
    await db.insert('expenses', {
      'description': desc,
      'amount': amount,
      'date': DateTime.now().subtract(Duration(days: daysAgo)).toIso8601String(),
      'category': category,
    });
  }

  // ------------------------------------------- 30 clientes con tarjeta digital
  final customerNames = [
    'María Fernanda Pérez', 'Juan Carlos Ríos', 'Diana Marcela Torres',
    'Andrés Felipe Gómez', 'Luz Elena Zapata', 'Carlos Mario Agudelo',
    'Sandra Milena Patiño', 'Jhon Freddy Quintero', 'Natalia Andrea Ruiz',
    'Sebastián Betancur', 'Alba Lucía Cárdenas', 'Wilmar Alexánder Muñoz',
    'Estefanía Vélez', 'Óscar Iván Ramírez', 'Paula Andrea Correa',
    'Robinson Gil', 'Yenny Alexandra Henao', 'Diego Alejandro Mesa',
    'Carolina Uribe', 'Jhonatan Ospina', 'Maira Alejandra Chavarría',
    'Santiago Zapata', 'Laura Vanesa Pulgarín', 'Édison Alberto Marín',
    'Valentina Restrepo', 'Óscar Javier Arango', 'Sara Sofía Montoya',
    'Juan Pablo Echeverri', 'Marleny Villada', 'Yeison Sánchez',
  ];
  // Marcaciones: la mayoría con 5 sellos.
  final stamps = [
    5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5,
    4, 4, 4, 4, 4, 3, 3, 3, 2, 2, 1, 1, 6, 6,
  ];
  final customerIds = <int>[];
  for (var i = 0; i < customerNames.length; i++) {
    final phone = '3${10 + (i % 8)} ${200 + i} ${1000 + i * 7}'.replaceAll(' ', '');
    final owes = i < 6; // seis clientes con fiado
    final id = await db.insert('customers', {
      'name': customerNames[i],
      'phone': phone,
      'credit_limit': owes ? 100000.0 : 50000.0,
      'total_pending_balance': owes ? [38500.0, 21000.0, 55000.0, 12800.0, 42000.0, 9700.0][i] : 0.0,
      'points': 40 + rnd.nextInt(260),
    });
    customerIds.add(id);

    final stampCount = stamps[i];
    for (var s = 0; s < stampCount; s++) {
      await db.insert('loyalty_movements', {
        'customer_id': id,
        'date_time': DateTime.now()
            .subtract(Duration(days: 1 + rnd.nextInt(13), hours: rnd.nextInt(10)))
            .toIso8601String(),
        'type': 'stamp',
        'amount': 1,
        'note': rnd.nextBool() ? 'Factura validada' : 'Compra en tienda',
        'source': rnd.nextBool() ? 'web' : 'manual',
      });
    }
    if (owes) {
      await db.insert('customer_movements', {
        'customer_id': id,
        'date_time': DateTime.now()
            .subtract(Duration(days: 2 + rnd.nextInt(10)))
            .toIso8601String(),
        'type': 'Cargo',
        'amount': [38500.0, 21000.0, 55000.0, 12800.0, 42000.0, 9700.0][i],
        'description': 'Venta fiada',
      });
    }
  }

  // ------------------------------------------------- 2 semanas de ventas
  // Distribución realista: viernes/sábado son los días fuertes.
  final beers = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15];
  final popular = [...beers, 16, 17, 18, 25, 26, 43, 44];
  var saleCount = 0;
  for (var daysAgo = 13; daysAgo >= 0; daysAgo--) {
    final dow = DateTime.now().subtract(Duration(days: daysAgo)).weekday;
    final busy = dow == DateTime.friday || dow == DateTime.saturday;
    final nSales = busy ? 6 + rnd.nextInt(4) : 3 + rnd.nextInt(4);
    for (var s = 0; s < nSales; s++) {
      final hour = 10 + rnd.nextInt(12);
      final minute = rnd.nextInt(60);
      final date = DateTime.now()
          .subtract(Duration(days: daysAgo))
          .copyWith(hour: hour, minute: minute, second: 0, millisecond: 0);

      final rolls = rnd.nextDouble();
      final String method = rolls < 0.55
          ? 'Efectivo'
          : rolls < 0.75
              ? 'Nequi / Daviplata'
              : rolls < 0.87
                  ? 'Tarjeta'
                  : 'Fiado';
      final withCustomer = method == 'Fiado'
          ? true
          : rnd.nextDouble() < 0.6;
      final customerId =
          withCustomer ? customerIds[rnd.nextInt(customerIds.length)] : null;

      final itemCount = 1 + rnd.nextInt(4);
      var total = 0.0;
      final items = <(int, int)>[];
      for (var it = 0; it < itemCount; it++) {
        final idx = rnd.nextDouble() < 0.7
            ? popular[rnd.nextInt(popular.length)]
            : rnd.nextInt(productIds.length);
        final qty = idx < 16 ? 1 + rnd.nextInt(6) : 1 + rnd.nextInt(2);
        items.add((idx, qty));
        total += salePrices[idx] * qty;
      }

      final saleId = await db.insert('sales', {
        'total_amount': total,
        'payment_method': method,
        'sale_date': date.toIso8601String(),
        'customer_id': customerId,
        'status': 'completed',
      });
      for (final (idx, qty) in items) {
        await db.insert('sale_items', {
          'sale_id': saleId,
          'product_id': productIds[idx],
          'quantity': qty,
          'price_at_sale': salePrices[idx],
          'discount': 0,
        });
      }
      await db.insert('sale_payments', {
        'sale_id': saleId,
        'payment_method': method,
        'amount': total,
      });
      saleCount++;
    }
  }

  // Fiados: lo vendido a crédito genera cargo en el cliente.
  final creditSales = await db.query('sales',
      where: 'payment_method = ? AND customer_id IS NOT NULL',
      whereArgs: ['Fiado']);
  for (final sale in creditSales) {
    await db.insert('customer_movements', {
      'customer_id': sale['customer_id'],
      'date_time': sale['sale_date'],
      'type': 'Cargo',
      'amount': sale['total_amount'],
      'description': 'Venta fiada',
      'sale_id': sale['id'],
    });
  }

  final summary =
      'Datos demo cargados: ${productIds.length} productos · '
      '${customerNames.length} clientes con tarjeta · $saleCount ventas · '
      '${expenses.length} gastos · ${suppliers.length} proveedores.';
  debugPrint('SEED OK: $summary');
  return summary;
}
