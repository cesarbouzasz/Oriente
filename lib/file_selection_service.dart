import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

class FileSelectionService {
  Future<String?> chooseDatabaseFile() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['db'],
      dialogTitle: 'Selecciona la base de datos cifrada',
    );
    return file?.path;
  }

  Future<String?> chooseNewDatabasePath() async {
    final uri = await FilePicker.saveFile(
      dialogTitle: 'Crear nueva base de datos cifrada',
      fileName: 'cercano_oriente.db',
      bytes: Uint8List(0),
      type: FileType.custom,
      allowedExtensions: ['db'],
    );
    return uri?.toFilePath();
  }

  Future<String?> chooseBackupFile() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['db', 'backup'],
      dialogTitle: 'Selecciona una copia de seguridad',
    );
    return file?.path;
  }
}
