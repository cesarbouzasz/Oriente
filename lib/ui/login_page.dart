import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../db/encrypted_database.dart';
import '../db/orientation_repository.dart';
import '../services/file_selection_service.dart';
import '../services/pin_unlock_service.dart';
import '../services/temporary_cleanup_service.dart';
import 'dashboard_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _pin = TextEditingController();
  final _master = TextEditingController();
  final _files = FileSelectionService();
  final _pinService = PinUnlockService();
  final _temporaryCleanup = const TemporaryCleanupService();
  String? _databasePath;
  String? _message;
  bool _masterMode = false;
  bool _busy = false;

  @override
  void dispose() {
    _pin.dispose();
    _master.dispose();
    super.dispose();
  }

  Future<void> _chooseDatabase() async {
    final path = await _files.chooseDatabaseFile();
    if (path != null && mounted) setState(() => _databasePath = path);
  }

  Future<void> _createDatabase() async {
    final master = TextEditingController();
    final confirmation = TextEditingController();
    final accepted = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Crear base cifrada'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Se creará una base SQLCipher local. La contraseña máster no se envía a ningún servidor.'),
                const SizedBox(height: 16),
                TextField(controller: master, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña máster', helperText: 'Mínimo 12 caracteres', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: confirmation, obscureText: true, decoration: const InputDecoration(labelText: 'Repetir contraseña', border: OutlineInputBorder())),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continuar')),
            ],
          ),
        ) ??
        false;
    if (!accepted) {
      master.dispose();
      confirmation.dispose();
      return;
    }
    if (master.text.length < 12 || master.text != confirmation.text) {
      master.dispose();
      confirmation.dispose();
      if (mounted) setState(() => _message = 'La contraseña debe tener 12 caracteres como mínimo y coincidir en ambos campos.');
      return;
    }
    final path = await _files.chooseNewDatabasePath();
    if (path == null || path.isEmpty) {
      master.dispose();
      confirmation.dispose();
      return;
    }
    final password = master.text;
    master.dispose();
    confirmation.dispose();
    await _openDatabase(path: path, password: password, created: true);
  }

  Future<void> _open() async {
    if (_databasePath == null) {
      setState(() => _message = 'Selecciona primero el archivo .db cifrado o crea una base nueva.');
      return;
    }
    String? password;
    if (_masterMode) {
      if (_master.text.length < 12) {
        setState(() => _message = 'La contraseña máster requiere al menos 12 caracteres.');
        return;
      }
      password = _master.text;
    } else {
      password = await _pinService.unlock(_pin.text);
      if (password == null) {
        setState(() => _message = 'PIN incorrecto o no configurado en este dispositivo.');
        return;
      }
    }
    await _openDatabase(path: _databasePath!, password: password);
  }

  Future<void> _openDatabase({required String path, required String password, bool created = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await _temporaryCleanup.cleanForDatabase(path);
      final database = EncryptedDatabase(path, password);
      await database.open();
      OrientationRepository(database).logAudit(eventType: created ? 'database_created' : 'session_opened', entityType: 'database', details: 'Método: master');
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => DashboardPage(database: database, databasePath: path)));
      await database.close();
    } catch (error) {
      if (mounted) setState(() => _message = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendlyError(Object error) {
    final text = error.toString().replaceFirst('ArgumentError: ', '');
    if (text.contains('file is encrypted') || text.contains('not a database')) return 'No se pudo abrir la base. Comprueba la contraseña máster y que sea una base SQLCipher válida.';
    return text;
  }

  Future<void> _configurePin() async {
    final master = TextEditingController();
    final pin = TextEditingController();
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Configurar PIN local'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: master, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña máster', border: OutlineInputBorder())), const SizedBox(height: 12), TextField(controller: pin, obscureText: true, keyboardType: TextInputType.number, maxLength: 5, decoration: const InputDecoration(labelText: 'Nuevo PIN de 5 dígitos', border: OutlineInputBorder()))]), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar'))])) ?? false;
    if (!confirmed || master.text.length < 12 || !RegExp(r'^\d{5}$').hasMatch(pin.text)) {
      if (mounted) setState(() => _message = 'PIN no configurado: se requieren contraseña máster y 5 dígitos.');
      master.dispose();
      pin.dispose();
      return;
    }
    await _pinService.configure(pin: pin.text, masterPassword: master.text);
    master.dispose();
    pin.dispose();
    if (mounted) setState(() { _masterMode = false; _message = 'PIN local configurado. La contraseña máster sigue protegiendo SQLCipher.'; });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(child: Image.asset('assets/images/login_cover.png', fit: BoxFit.cover, cacheWidth: 1400)),
            DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(.12), Colors.black.withOpacity(.20), Colors.black.withOpacity(.72)]))),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Align(alignment: Alignment.topLeft, child: _FloatingBrand()),
                        const SizedBox(height: 100),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: _FloatingLoginPanel(
                            busy: _busy,
                            databasePath: _databasePath,
                            masterMode: _masterMode,
                            pin: _pin,
                            master: _master,
                            message: _message,
                            onChoose: _chooseDatabase,
                            onCreate: _createDatabase,
                            onOpen: _open,
                            onToggleMode: () => setState(() => _masterMode = !_masterMode),
                            onConfigurePin: _configurePin,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

class _FloatingBrand extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ClipRRect(borderRadius: BorderRadius.circular(22), child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: Container(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12), color: Colors.black.withOpacity(.24), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('CERCANO ORIENTE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 2)), Text('Orientación educativa · local · privada', style: TextStyle(color: Colors.white70))])));
}

class _FloatingLoginPanel extends StatelessWidget {
  const _FloatingLoginPanel({required this.busy, required this.databasePath, required this.masterMode, required this.pin, required this.master, required this.message, required this.onChoose, required this.onCreate, required this.onOpen, required this.onToggleMode, required this.onConfigurePin});
  final bool busy;
  final String? databasePath;
  final bool masterMode;
  final TextEditingController pin;
  final TextEditingController master;
  final String? message;
  final VoidCallback onChoose;
  final VoidCallback onCreate;
  final VoidCallback onOpen;
  final VoidCallback onToggleMode;
  final VoidCallback onConfigurePin;

  @override
  Widget build(BuildContext context) => ClipRRect(borderRadius: BorderRadius.circular(28), child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14), child: Container(color: Theme.of(context).colorScheme.surface.withOpacity(.86), padding: const EdgeInsets.all(22), child: Column(mainAxisSize: MainAxisSize.min, children: [Text('Acceso seguro', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 4), const Text('Tus datos permanecen cifrados en este dispositivo.'), const SizedBox(height: 18), Row(children: [Expanded(child: OutlinedButton.icon(onPressed: onChoose, icon: const Icon(Icons.folder_open), label: Text(databasePath == null ? 'Abrir .db' : 'Cambiar .db'))), const SizedBox(width: 10), Expanded(child: FilledButton.tonalIcon(onPressed: busy ? null : onCreate, icon: const Icon(Icons.add_circle_outline), label: const Text('Crear nueva')))]), if (databasePath != null) _DatabaseInfo(path: databasePath!), const SizedBox(height: 12), if (!masterMode) TextField(controller: pin, obscureText: true, keyboardType: TextInputType.number, maxLength: 5, decoration: const InputDecoration(labelText: 'PIN local de 5 dígitos', border: OutlineInputBorder())), if (masterMode) TextField(controller: master, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña máster SQLCipher', helperText: 'Mínimo 12 caracteres; nunca viaja a la nube.', border: OutlineInputBorder())), const SizedBox(height: 12), SizedBox(width: double.infinity, child: FilledButton(onPressed: busy ? null : onOpen, child: Text(busy ? 'Abriendo…' : 'Abrir espacio seguro'))), TextButton(onPressed: onToggleMode, child: Text(masterMode ? 'Usar PIN local' : 'Usar contraseña máster')), if (!masterMode) TextButton(onPressed: onConfigurePin, child: const Text('Configurar PIN en este dispositivo')), if (message != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(message!, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w600)))])));
}

class _DatabaseInfo extends StatelessWidget {
  const _DatabaseInfo({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    final modified = file.existsSync() ? file.lastModifiedSync() : null;
    return ListTile(dense: true, leading: const Icon(Icons.lock_outline), title: Text(path, maxLines: 2, overflow: TextOverflow.ellipsis), subtitle: Text(modified == null ? 'Se creará al confirmar' : 'Última modificación: $modified'));
  }
}
