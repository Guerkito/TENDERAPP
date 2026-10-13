import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';
import 'package:tenderapp/api/backup_service.dart';

void main() {
  // En Linux suele faltar el symlink de desarrollo libsqlite3.so; cargamos
  // la biblioteca del sistema directamente.
  if (Platform.isLinux) {
    open.overrideFor(
        OperatingSystem.linux, () => DynamicLibrary.open('libsqlite3.so.0'));
  }
  sqfliteFfiInit();
  // Sin isolate: el override de sqlite3 de arriba aplica en este mismo hilo.
  databaseFactory = databaseFactoryFfiNoIsolate;

  test('acepta una copia con las tablas de TenderApp', () async {
    final dir = await Directory.systemTemp.createTemp('tender_backup_ok');
    final path = '${dir.path}/copia.db';
    final db = await databaseFactory.openDatabase(path);
    for (final table in ['products', 'sales', 'customers', 'settings']) {
      await db.execute('CREATE TABLE $table (id INTEGER PRIMARY KEY)');
    }
    await db.close();

    await expectLater(BackupService.validateBackupFile(path), completes);
    await dir.delete(recursive: true);
  });

  test('rechaza un archivo que no es una base de datos', () async {
    final dir = await Directory.systemTemp.createTemp('tender_backup_bad');
    final path = '${dir.path}/foto.jpg';
    await File(path).writeAsBytes(List<int>.generate(2048, (i) => i % 251));

    await expectLater(
      BackupService.validateBackupFile(path),
      throwsA(isA<BackupException>()),
    );
    await dir.delete(recursive: true);
  });

  test('rechaza una base de datos sin las tablas de TenderApp', () async {
    final dir = await Directory.systemTemp.createTemp('tender_backup_other');
    final path = '${dir.path}/otra.db';
    final db = await databaseFactory.openDatabase(path);
    await db.execute('CREATE TABLE chismes (id INTEGER PRIMARY KEY)');
    await db.close();

    await expectLater(
      BackupService.validateBackupFile(path),
      throwsA(isA<BackupException>()),
    );
    await dir.delete(recursive: true);
  });

  test('rechaza un archivo pequeño antes de intentar abrirlo', () async {
    final dir = await Directory.systemTemp.createTemp('tender_backup_tiny');
    final path = '${dir.path}/vacio.db';
    await File(path).writeAsBytes(const [1, 2, 3]);

    await expectLater(
      BackupService.validateBackupFile(path),
      throwsA(isA<BackupException>()),
    );
    await dir.delete(recursive: true);
  });
}
