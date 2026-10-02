import 'package:flutter/material.dart';

import 'db/encrypted_database.dart';
import 'services/backup_service.dart';
import 'services/file_selection_service.dart';

void main() => runApp(const CercanoOrienteApp());

class CercanoOrienteApp extends StatelessWidget {
  const CercanoOrienteApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Cercano Oriente',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff087e8b)),
          useMaterial3: true,
        ),
        home: const LoginPage(),
      );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _password = TextEditingController();
  final _files = FileSelectionService();
  String? _databasePath;
  String? _message;
  bool _busy = false;
  EncryptedDatabase? _database;

  Future<void> _open() async {
    if (_databasePath == null || _password.text.isEmpty) {
      setState(() => _message = 'Selecciona un archivo .db e introduce la contraseña máster.');
      return;
    }
    setState(() { _busy = true; _message = null; });
    try {
      final db = EncryptedDatabase(_databasePath!, _password.text);
      await db.open();
      _database = db;
      if (mounted) {
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => HomePage(database: db, databasePath: _databasePath!),
        ));
      }
    } catch (error) {
      setState(() => _message = 'No se pudo abrir la base cifrada: $error');
    } finally {
      await _database?.close();
      _database = null;
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Image.asset('assets/images/portada_cercano_oriente.jfif', height: 220),
                    const SizedBox(height: 18),
                    Text('Cercano Oriente', style: Theme.of(context).textTheme.headlineMedium),
                    const Text('Programa de orientación · almacenamiento local'),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _busy ? null : () async {
                        final path = await _files.chooseDatabaseFile();
                        if (path != null) setState(() => _databasePath = path);
                      },
                      icon: const Icon(Icons.folder_open),
                      label: Text(_databasePath == null ? 'Elegir archivo .db' : 'Cambiar archivo .db'),
                    ),
                    if (_databasePath != null) ...[
                      const SizedBox(height: 8),
                      Text(_databasePath!, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: 16),
                    TextField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña máster',
                        helperText: 'Mínimo 12 caracteres. No se guarda ni se transmite.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(width: double.infinity, child: FilledButton(
                      onPressed: _busy ? null : _open,
                      child: Text(_busy ? 'Abriendo…' : 'Abrir espacio seguro'),
                    )),
                    if (_message != null) ...[
                      const SizedBox(height: 14),
                      Text(_message!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ],
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
}

class HomePage extends StatelessWidget {
  const HomePage({required this.database, required this.databasePath, super.key});
  final EncryptedDatabase database;
  final String databasePath;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Cercano Oriente')),
        body: Center(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.verified_user, size: 64),
            const SizedBox(height: 12),
            const Text('Base de datos abierta en modo seguro.'),
            const SizedBox(height: 8),
            Text(databasePath, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.backup),
              label: const Text('Crear copia cifrada'),
              onPressed: () async {
                final dir = await BackupService().chooseBackupDirectory();
                if (dir == null || !context.mounted) return;
                await BackupService().createBackup(databasePath: databasePath, destinationDirectory: dir);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copia cifrada creada correctamente.')),
                  );
                }
              },
            ),
          ]),
        )),
      );
}
