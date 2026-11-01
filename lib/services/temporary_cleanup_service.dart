import 'dart:io';

import 'package:path/path.dart' as p;

class TemporaryCleanupService {
  const TemporaryCleanupService();

  Future<int> cleanForDatabase(String databasePath) async {
    final parent = Directory(p.dirname(databasePath));
    if (!await parent.exists()) return 0;
    final stem = p.basename(databasePath);
    var removed = 0;
    await for (final entity in parent.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      final known = name == '$stem.restore.tmp' ||
          name == '$stem.backup.tmp' ||
          name.endsWith('.cercano-oriente.tmp') ||
          name.endsWith('.report.tmp');
      if (known) {
        try {
          await entity.delete();
          removed++;
        } on FileSystemException {
          // Un archivo bloqueado no debe impedir el arranque de la aplicación.
        }
      }
    }
    return removed;
  }
}
