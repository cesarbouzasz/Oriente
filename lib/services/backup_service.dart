import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

class BackupService {
  Future<String?> chooseBackupDirectory() => FilePicker.getDirectoryPath(
        dialogTitle: 'Selecciona la carpeta de copias de seguridad',
      );

  Future<File> createBackup({
    required String databasePath,
    required String destinationDirectory,
    int keepLatest = 10,
  }) async {
    final source = File(databasePath);
    if (!await source.exists()) {
      throw StateError('No se puede copiar una base de datos inexistente.');
    }
    final sourceBytes = await source.readAsBytes();
    if (sourceBytes.isEmpty) throw StateError('La base de datos está vacía.');
    final digest = sha256.convert(sourceBytes).toString();
    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final base = p.join(destinationDirectory, 'cercano-oriente_$stamp');
    final destination = File('$base.cercano-oriente-backup.db');
    final temporary = File('$base.backup.tmp');
    await destination.parent.create(recursive: true);
    await temporary.writeAsBytes(sourceBytes, flush: true);
    final copiedDigest = await _sha256File(temporary);
    if (copiedDigest != digest) {
      await _deleteIfExists(temporary);
      throw StateError('La verificación de integridad del backup ha fallado.');
    }
    await temporary.rename(destination.path);
    final manifest = File('${destination.path}.sha256.json');
    await manifest.writeAsString(jsonEncode({
      'sha256': digest,
      'sizeBytes': sourceBytes.length,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'databaseName': p.basename(databasePath),
    }), flush: true);
    await _prune(destination.parent, keepLatest);
    return destination;
  }

  Future<bool> verifyBackup(String backupPath) async {
    final backup = File(backupPath);
    final manifest = File('$backupPath.sha256.json');
    if (!await backup.exists() || !await manifest.exists()) return false;
    try {
      final data = jsonDecode(await manifest.readAsString()) as Map<String, dynamic>;
      if ((data['sizeBytes'] as num?)?.toInt() != await backup.length()) return false;
      return data['sha256'] == await _sha256File(backup);
    } catch (_) {
      return false;
    }
  }

  Future<void> restoreBackup({
    required String backupPath,
    required String databasePath,
  }) async {
    if (!await verifyBackup(backupPath)) {
      throw StateError('La copia seleccionada no supera la verificación SHA-256.');
    }
    final backup = File(backupPath);
    final target = File(databasePath);
    final temporary = File('${target.path}.restore.tmp');
    final safety = File('${target.path}.before-restore-${DateTime.now().millisecondsSinceEpoch}.db');
    if (await target.exists()) await target.copy(safety.path);
    await backup.copy(temporary.path);
    final manifest = jsonDecode(await File('$backupPath.sha256.json').readAsString()) as Map<String, dynamic>;
    if (manifest['sha256'] != await _sha256File(temporary)) {
      await _deleteIfExists(temporary);
      throw StateError('La copia temporal restaurada no es íntegra.');
    }
    await _deleteIfExists(target);
    await temporary.rename(target.path);
  }

  Future<void> _prune(Directory directory, int keepLatest) async {
    if (keepLatest < 1) return;
    final files = <File>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is File && entity.path.endsWith('.cercano-oriente-backup.db')) files.add(entity);
    }
    files.sort((a, b) => b.path.compareTo(a.path));
    for (final file in files.skip(keepLatest)) {
      await _deleteIfExists(file);
      await _deleteIfExists(File('${file.path}.sha256.json'));
    }
  }

  Future<String> _sha256File(File file) async =>
      sha256.convert(await file.readAsBytes()).toString();

  Future<void> _deleteIfExists(File file) async {
    if (await file.exists()) await file.delete();
  }
}
