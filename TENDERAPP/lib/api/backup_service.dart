import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'db_helper.dart';

/// Error con mensaje en español para mostrar tal cual al tendero.
class BackupException implements Exception {
  final String message;
  BackupException(this.message);

  @override
  String toString() => message;
}

class BackupService {
  /// Copia rodante que se guarda antes de reemplazar la base actual.
  static const String _preRestoreSuffix = '.antes_de_restaurar';

  static Future<String> _dbPath() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      return join(documentsDirectory.path, 'tender_app.db');
    }
    return join(await getDatabasesPath(), 'tender_app.db');
  }

  static Future<void> exportDatabase() async {
    try {
      final dbPath = await _dbPath();
      final File dbFile = File(dbPath);
      if (await dbFile.exists()) {
        final String backupPath = join(
            (await getTemporaryDirectory()).path,
            'TenderApp_Backup_${DateTime.now().millisecondsSinceEpoch}.db');
        await dbFile.copy(backupPath);

        await Share.shareXFiles([XFile(backupPath)],
            text: 'Mi Copia de Seguridad de TenderApp');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Verifica que [path] sea una copia de seguridad de TenderApp antes de
  /// usarla. Lanza [BackupException] con un mensaje entendible si no lo es.
  static Future<void> validateBackupFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw BackupException('No se encontró el archivo seleccionado.');
    }
    if (await file.length() < 1024) {
      throw BackupException('Ese archivo no parece una copia de TenderApp.');
    }

    Database? probe;
    try {
      probe = await openDatabase(path, readOnly: true);
      final tables = await probe
          .rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      final names = tables.map((row) => row['name'] as String).toSet();
      const required = {'products', 'sales', 'customers', 'settings'};
      if (!required.every(names.contains)) {
        throw BackupException(
            'Ese archivo no es una copia de seguridad de TenderApp.');
      }
    } on BackupException {
      rethrow;
    } catch (e) {
      throw BackupException(
          'El archivo está dañado o no es una copia de TenderApp.');
    } finally {
      await probe?.close();
    }
  }

  /// Reemplaza la base de datos actual con la copia indicada.
  /// Antes de tocar nada guarda la base actual junto a ella; si algo falla
  /// a mitad, la devuelve a su sitio. Devuelve un resumen para el usuario.
  static Future<String> importDatabase(String sourcePath) async {
    await validateBackupFile(sourcePath);
    final dbPath = await _dbPath();
    final rollingBackup = File('$dbPath$_preRestoreSuffix');

    final current = File(dbPath);
    if (await current.exists()) {
      await current.copy(rollingBackup.path);
    }

    try {
      await DBHelper.closeAndReset();
      await File(sourcePath).copy(dbPath);
      // Reabrir aquí mismo para detectar problemas ahora, no en el próximo
      // arranque de la app.
      final db = await DBHelper().database;
      final salesRows = await db.rawQuery('SELECT COUNT(*) AS n FROM sales');
      final customerRows =
          await db.rawQuery('SELECT COUNT(*) AS n FROM customers');
      final sales = (salesRows.first['n'] as num?)?.toInt() ?? 0;
      final customers = (customerRows.first['n'] as num?)?.toInt() ?? 0;
      return 'Se restauraron $sales ventas y $customers clientes.';
    } catch (e) {
      // Deja la base anterior en su sitio y reabre.
      await DBHelper.closeAndReset();
      if (await rollingBackup.exists()) {
        await rollingBackup.copy(dbPath);
      }
      await DBHelper().database;
      throw BackupException(
          'No se pudo restaurar la copia. Tus datos actuales siguen en su lugar.');
    }
  }
}
