import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

class BackupService {
  Future<String?> chooseBackupDirectory() => FilePicker.getDirectoryPath(
        dialogTitle: 'Selecciona la carpeta de copias de seguridad',
      );

  Future<File> createBackup({
    required String databasePath,
    required String destinationDirectory,
  }) async {
    final source = File(databasePath);
    if (!await source.exists()) {
      throw StateError('No se puede copiar una base de datos inexistente.');
    }
    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final destination = File(p.join(
      destinationDirectory,
      'cercano-oriente_$stamp.cercano-oriente-backup.db',
    ));
    await destination.parent.create(recursive: true);
    // La contraseña no se copia ni se guarda: permanece dentro de SQLCipher.
    return source.copy(destination.path);
  }

  Future<void> restoreBackup({
    required String backupPath,
    required String databasePath,
  }) async {
    final backup = File(backupPath);
    if (!await backup.exists()) {
      throw StateError('La copia seleccionada no existe.');
    }
    final target = File(databasePath);
    final temp = File('${target.path}.restore.tmp');
    await backup.copy(temp.path);
    await temp.rename(target.path);
  }
}
