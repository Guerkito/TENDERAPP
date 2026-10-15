import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'db_helper.dart';
import 'supabase_service.dart';
import 'sync_schema.dart';

/// Lo que el motor necesita de la nube. Las pruebas lo reemplazan por una
/// versión en memoria para simular varios celulares.
abstract class SyncRemote {
  /// Registra este celular en la cuenta y devuelve su bloque de ids.
  Future<int> registerDevice(String label);

  /// Sube (o reemplaza) filas de una tabla.
  Future<void> upsertRows(String table, List<Map<String, dynamic>> rows);

  /// Filas de una tabla con `synced_at` posterior al cursor, en orden.
  /// Cada fila incluye `synced_at` (reloj del servidor) e `id`.
  Future<List<Map<String, dynamic>>> fetchRows(
      String table, String? sinceAt, int sinceId, int limit);

  /// Deja constancia de borrados hechos en este celular.
  Future<void> pushDeletions(List<Map<String, dynamic>> deletions);

  /// Borrados hechos en otros celulares después del cursor.
  Future<List<Map<String, dynamic>>> fetchDeletions(
      String? sinceAt, int sinceId, int limit);
}

/// Estado para mostrar en pantalla (Mi Tienda).
class SyncStatus {
  int? deviceIndex;
  DateTime? lastOk;
  String? error;
  bool running = false;

  String get summary {
    if (running) return 'Sincronizando...';
    if (deviceIndex == null) return 'Sin activar';
    if (error != null) return error!;
    if (lastOk == null) return 'Activado';
    final mins = DateTime.now().difference(lastOk!).inMinutes;
    if (mins < 1) return 'Al día (hace segundos)';
    if (mins < 60) return 'Al día (hace $mins min)';
    return 'Al día a las ${lastOk!.hour.toString().padLeft(2, '0')}:'
        '${lastOk!.minute.toString().padLeft(2, '0')}';
  }
}

/// Sincroniza TODAS las tablas de la tienda entre los celulares de una misma
/// cuenta. Sin relojes: cada fila lleva una marca `_dirty` que ponen los
/// triggers de SQLite cuando la app la escribe, y el servidor pone la hora
/// (`synced_at`) que ordena lo que baja. Reglas:
///  1. Se sube lo sucio y recién después se baja (si no pude subir, no acepto
///     cambios ajenos).
///  2. Una fila con cambios locales sin subir nunca se pisa.
///  3. Los borrados viajan como lápidas para que desaparezcan en todos.
class CloudSync {
  CloudSync({
    Future<Database> Function()? openDb,
    SyncRemote? remote,
    String? deviceLabel,
    bool Function()? isLoggedIn,
  })  : _openDb = openDb ?? _appDatabase,
        _remote = remote,
        _deviceLabel = deviceLabel,
        _isLoggedIn = isLoggedIn ?? _hasSession;

  /// La que usa la app.
  static final CloudSync instance = CloudSync();

  static Future<Database> _appDatabase() => DBHelper().database;

  static bool _hasSession() => SupabaseService.isLoggedIn;

  final Future<Database> Function() _openDb;
  final String? _deviceLabel;
  final bool Function() _isLoggedIn;
  SyncRemote? _remote;

  final SyncStatus status = SyncStatus();

  static const Duration _minInterval = Duration(seconds: 20);

  bool _running = false;
  DateTime? _lastAttempt;

  /// Sube y baja cambios. No lanza: los problemas quedan en [status] y el
  /// próximo intento los reintenta (los triggers marcan lo que falta).
  Future<bool> syncNow({bool force = false}) async {
    if (!_isLoggedIn()) return false;
    if (_running) return false;
    final now = DateTime.now();
    if (!force &&
        _lastAttempt != null &&
        now.difference(_lastAttempt!) < _minInterval) {
      return false;
    }
    _running = true;
    status.running = true;
    _lastAttempt = now;
    try {
      final db = await _openDb();
      final remote = _remote ??= SupabaseSyncRemote();
      await _activateIfNeeded(db, remote);
      await _push(db, remote);
      await _pushDeletions(db, remote);
      await _pull(db, remote);
      await _pullDeletions(db, remote);
      status.lastOk = DateTime.now();
      status.error = null;
      return true;
    } catch (e) {
      debugPrint('CloudSync: no se pudo sincronizar: $e');
      status.error = 'No se pudo sincronizar. Revisa tu internet.';
      return false;
    } finally {
      _running = false;
      status.running = false;
    }
  }

  // ---------------------------------------------------------------- metadatos

  Future<String?> _metaGet(Database db, String key) async {
    final rows = await db.query('_sync_meta',
        columns: ['value'], where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> _metaSet(DatabaseExecutor db, String key, String value) async {
    await db.insert('_sync_meta', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Deja la sincronización como recién instalada: la próxima vez pide bloque
  /// de ids nuevo y vuelve a subir/bajar todo. Se usa tras restaurar una copia
  /// de otro celular (esa copia trae bloque, cursores y lápidas del otro).
  static Future<void> resetAfterRestore(Database db) async {
    await db.delete('_sync_meta');
    await db.delete('_sync_tombstones');
    for (final table in syncedTables) {
      await db.rawUpdate('UPDATE $table SET _dirty = 1');
    }
  }

  // ---------------------------------------------------------------- activación

  /// Primer uso: pide a la cuenta un bloque de ids propio y renumera lo que ya
  /// existía dentro de ese bloque, para que nunca choque con otro celular.
  Future<void> _activateIfNeeded(Database db, SyncRemote remote) async {
    final stored = await _metaGet(db, 'device_index');
    if (stored != null) {
      status.deviceIndex = int.tryParse(stored);
      return;
    }

    final granted = await remote.registerDevice(_deviceLabel ?? 'Celular');
    if (granted <= 0 || granted > maxDeviceIndex) {
      throw StateError('La cuenta devolvió un bloque de ids inválido: $granted');
    }

    final delta = granted * idNamespace;
    await db.transaction((txn) async {
      for (final table in syncedTables) {
        await txn.rawUpdate(
            'UPDATE $table SET id = id + ? WHERE id < ?', [delta, idNamespace]);
      }
      for (final (table, column) in syncForeignKeyColumns) {
        await txn.rawUpdate(
            'UPDATE $table SET $column = $column + ? '
            'WHERE $column IS NOT NULL AND $column < ?',
            [delta, idNamespace]);
      }
      await _bumpSequences(txn, granted);
      await _metaSet(txn, 'device_index', granted.toString());
    });
    status.deviceIndex = granted;
    debugPrint('CloudSync: celular activado con bloque $granted');
  }

  /// Los registros nuevos de este celular deben nacer dentro de su bloque.
  Future<void> _bumpSequences(DatabaseExecutor db, int granted) async {
    final base = granted * idNamespace;
    final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND sql LIKE '%AUTOINCREMENT%'");
    for (final row in tables) {
      final name = row['name'] as String;
      if (name.startsWith('_sync') || name.startsWith('sqlite_')) continue;
      final current =
          await db.query('sqlite_sequence', where: 'name = ?', whereArgs: [name]);
      if (current.isEmpty) {
        try {
          await db.insert('sqlite_sequence', {'name': name, 'seq': base + 1});
        } catch (_) {
          // La tabla nunca se usó; se ajustará al insertar la primera fila.
        }
      } else {
        await db.rawUpdate(
            'UPDATE sqlite_sequence SET seq = MAX(seq, ?) WHERE name = ?',
            [base + 1, name]);
      }
    }
  }

  // --------------------------------------------------------------------- subir

  Future<void> _push(Database db, SyncRemote remote) async {
    for (final table in syncedTables) {
      while (true) {
        final rows = await db
            .query(table, where: '_dirty = 1', orderBy: 'id ASC', limit: 300);
        if (rows.isEmpty) break;
        final payload = rows
            .map((row) => Map<String, dynamic>.from(row)..remove('_dirty'))
            .toList();
        await remote.upsertRows(table, payload);
        for (final row in rows) {
          await db.update(table, {'_dirty': 0},
              where: 'id = ? AND updated_at = ?',
              whereArgs: [row['id'], row['updated_at']]);
        }
        if (rows.length < 300) break;
      }
    }
  }

  Future<void> _pushDeletions(Database db, SyncRemote remote) async {
    while (true) {
      final rows = await db.query('_sync_tombstones',
          orderBy: 'deleted_at ASC, row_id ASC', limit: 300);
      if (rows.isEmpty) break;
      await remote.pushDeletions(
          rows.map((r) => Map<String, dynamic>.from(r)).toList());
      for (final row in rows) {
        await db.delete('_sync_tombstones',
            where: 'table_name = ? AND row_id = ? AND deleted_at = ?',
            whereArgs: [row['table_name'], row['row_id'], row['deleted_at']]);
      }
      if (rows.length < 300) break;
    }
  }

  // -------------------------------------------------------------------- bajar

  Future<void> _pull(Database db, SyncRemote remote) async {
    for (final table in syncedTables) {
      var at = await _metaGet(db, 'pull_${table}_at');
      var id = int.tryParse(await _metaGet(db, 'pull_${table}_id') ?? '') ?? 0;
      while (true) {
        final rows = await remote.fetchRows(table, at, id, 500);
        if (rows.isEmpty) break;
        for (final row in rows) {
          await _applyRemoteRow(db, table, row);
        }
        final last = rows.last;
        at = last['synced_at'] as String;
        id = (last['id'] as num).toInt();
        await _metaSet(db, 'pull_${table}_at', at);
        await _metaSet(db, 'pull_${table}_id', id.toString());
        if (rows.length < 500) break;
      }
    }
  }

  Future<void> _applyRemoteRow(
      Database db, String table, Map<String, dynamic> remoteRow) async {
    final row = Map<String, dynamic>.from(remoteRow)
      ..remove('synced_at')
      ..remove('owner_id')
      ..['updated_at'] = _normalizeStamp(remoteRow['updated_at'])
      ..['_dirty'] = 0;

    final id = (row['id'] as num).toInt();
    final local = await db.query(table,
        columns: ['updated_at', '_dirty'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1);

    if (local.isEmpty) {
      await db.insert(table, row);
      return;
    }
    // Con cambios locales sin subir, manda lo local (ya se subió o se subirá).
    if ((local.first['_dirty'] as int? ?? 0) == 1) return;
    // Idéntica: no se toca (evita marcarla como cambio y reenviarla).
    if (_normalizeStamp(local.first['updated_at']) == row['updated_at']) return;
    await db.update(table, row, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> _pullDeletions(Database db, SyncRemote remote) async {
    var at = await _metaGet(db, 'pull_deletions_at');
    var id = int.tryParse(await _metaGet(db, 'pull_deletions_id') ?? '') ?? 0;
    while (true) {
      final rows = await remote.fetchDeletions(at, id, 500);
      if (rows.isEmpty) break;
      for (final deleted in rows) {
        final table = deleted['table_name'] as String;
        final rowId = (deleted['row_id'] as num).toInt();
        if (!syncedTables.contains(table)) continue;
        await db.delete(table, where: 'id = ?', whereArgs: [rowId]);
        // El borrado local deja lápida; como viene de afuera, no se reenvía.
        await db.delete('_sync_tombstones',
            where: 'table_name = ? AND row_id = ?', whereArgs: [table, rowId]);
      }
      final last = rows.last;
      at = last['synced_at'] as String;
      id = (last['row_id'] as num).toInt();
      await _metaSet(db, 'pull_deletions_at', at);
      await _metaSet(db, 'pull_deletions_id', id.toString());
      if (rows.length < 500) break;
    }
  }

  static String? _normalizeStamp(Object? value) {
    if (value == null) return null;
    final text = value is DateTime ? value.toIso8601String() : value.toString();
    final parsed = DateTime.tryParse(text);
    return parsed?.toUtc().toIso8601String();
  }
}

/// Implementación real contra Supabase (tablas `sync_*` con RLS por cuenta).
class SupabaseSyncRemote implements SyncRemote {
  SupabaseClient get _client => SupabaseService.client;

  static String _table(String table) => 'sync_$table';

  @override
  Future<int> registerDevice(String label) async {
    final result = await _client
        .rpc('register_store_device', params: {'p_label': label});
    return (result as num).toInt();
  }

  @override
  Future<void> upsertRows(
      String table, List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    final owner = SupabaseService.currentUser?.id;
    final payload = rows
        .map((row) => {...row, if (owner != null) 'owner_id': owner})
        .toList();
    await _client
        .from(_table(table))
        .upsert(payload, onConflict: 'owner_id,id');
  }

  @override
  Future<List<Map<String, dynamic>>> fetchRows(
      String table, String? sinceAt, int sinceId, int limit) async {
    var query = _client.from(_table(table)).select();
    if (sinceAt != null) {
      query = query.or(
          'synced_at.gt.$sinceAt,and(synced_at.eq.$sinceAt,id.gt.$sinceId)');
    }
    final data = await query
        .order('synced_at', ascending: true)
        .order('id', ascending: true)
        .limit(limit);
    return List<Map<String, dynamic>>.from(data);
  }

  @override
  Future<void> pushDeletions(List<Map<String, dynamic>> deletions) async {
    if (deletions.isEmpty) return;
    final owner = SupabaseService.currentUser?.id;
    final payload = deletions
        .map((row) => {
              'table_name': row['table_name'],
              'row_id': row['row_id'],
              if (owner != null) 'owner_id': owner,
            })
        .toList();
    await _client.from('sync_deletions').upsert(payload,
        onConflict: 'owner_id,table_name,row_id');
  }

  @override
  Future<List<Map<String, dynamic>>> fetchDeletions(
      String? sinceAt, int sinceId, int limit) async {
    var query = _client.from('sync_deletions').select();
    if (sinceAt != null) {
      query = query.or(
          'synced_at.gt.$sinceAt,and(synced_at.eq.$sinceAt,row_id.gt.$sinceId)');
    }
    final data = await query
        .order('synced_at', ascending: true)
        .order('row_id', ascending: true)
        .limit(limit);
    return List<Map<String, dynamic>>.from(data);
  }
}
