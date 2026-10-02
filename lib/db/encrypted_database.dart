import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

/// Adaptador de SQLCipher para escritorio y Android.
///
/// IMPORTANTE: el binario nativo cargado por `sqlite3` debe ser SQLCipher,
/// no el SQLite de sistema. Si `cipher_version` no devuelve una versión,
/// la app se niega a trabajar para no exponer datos en claro.
class EncryptedDatabase {
  EncryptedDatabase(this.path, this.password);

  final String path;
  final String password;
  Database? _database;

  Database get database {
    final value = _database;
    if (value == null) {
      throw StateError('La base de datos aún no está abierta.');
    }
    return value;
  }

  Future<void> open({bool createIfMissing = true}) async {
    if (!createIfMissing && !File(path).existsSync()) {
      throw StateError('No existe el archivo de datos seleccionado.');
    }
    if (password.trim().length < 12) {
      throw ArgumentError('La contraseña máster debe tener al menos 12 caracteres.');
    }

    final db = sqlite3.open(path);
    try {
      final escaped = password.replaceAll("'", "''");
      db.execute("PRAGMA key = '$escaped';");
      final cipherRows = db.select('PRAGMA cipher_version;');
      if (cipherRows.isEmpty || cipherRows.first.values.isEmpty ||
          cipherRows.first.values.first == null ||
          cipherRows.first.values.first.toString().isEmpty) {
        throw StateError(
          'SQLCipher no está disponible en el binario nativo. Operación cancelada.',
        );
      }
      // SQLCipher 4 usa AES-256-CBC + HMAC-SHA512 por defecto. Estas
      // comprobaciones evitan abrir el archivo con una configuración distinta.
      final pageSize = db.select('PRAGMA cipher_page_size;');
      if (pageSize.isEmpty || pageSize.first.values.first.toString() != '4096') {
        throw StateError('Configuración SQLCipher no compatible: page size inesperado.');
      }
      db.execute('PRAGMA cipher_compatibility = 4;');
      db.execute('PRAGMA foreign_keys = ON;');
      db.execute('PRAGMA journal_mode = DELETE;');
      db.execute('PRAGMA secure_delete = ON;');
      db.execute('''
        CREATE TABLE IF NOT EXISTS app_metadata (
          key TEXT PRIMARY KEY NOT NULL,
          value TEXT NOT NULL
        );
      ''');
      db.execute('''
        INSERT OR IGNORE INTO app_metadata(key, value)
        VALUES ('schema_version', '1');
      ''');
      _database = db;
    } catch (_) {
      db.close();
      rethrow;
    }
  }

  Future<void> close() async {
    _database?.execute('PRAGMA wal_checkpoint(FULL);');
    _database?.close();
    _database = null;
  }
}
