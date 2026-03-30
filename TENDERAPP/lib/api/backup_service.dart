import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'db_helper.dart';

class BackupService {
  static Future<void> exportDatabase() async {
    try {
      String dbPath;
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final documentsDirectory = await getApplicationDocumentsDirectory();
        dbPath = join(documentsDirectory.path, 'tender_app.db');
      } else {
        dbPath = join(await getDatabasesPath(), 'tender_app.db');
      }

      final File dbFile = File(dbPath);
      if (await dbFile.exists()) {
        final String backupPath = join((await getTemporaryDirectory()).path, 'TenderApp_Backup_${DateTime.now().millisecondsSinceEpoch}.db');
        await dbFile.copy(backupPath);
        
        await Share.shareXFiles([XFile(backupPath)], text: 'Mi Copia de Seguridad de TenderApp');
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> importDatabase(String sourcePath) async {
    try {
      // First, close current database
      final db = await DBHelper().database;
      await db.close();

      String dbPath;
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final documentsDirectory = await getApplicationDocumentsDirectory();
        dbPath = join(documentsDirectory.path, 'tender_app.db');
      } else {
        dbPath = join(await getDatabasesPath(), 'tender_app.db');
      }

      final File sourceFile = File(sourcePath);
      await sourceFile.copy(dbPath);
      
      // Re-initialize database after import
    } catch (e) {
      rethrow;
    }
  }
}
