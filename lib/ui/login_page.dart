import 'dart:io';

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

  Future<void> _chooseDatabase() async {
    final path = await _files.chooseDatabaseFile();
    if (path != null && mounted) setState(() => _databasePath = path);
  }

  Future<void> _open() async {
    if (_databasePath == null) {
      setState(() => _message = 'Selecciona primero el archivo .db cifrado.');
      return;
    }
    setState(() { _busy = true; _message = null; });
    try {
      String? password;
      if (_masterMode) {
        if (_master.text.length < 12) throw ArgumentError('La contraseña máster requiere al menos 12 caracteres.');
        password = _master.text;
      } else {
        password = await _pinService.unlock(_pin.text);
        if (password == null) throw ArgumentError('PIN incorrecto o no configurado en este dispositivo.');
      }
      await _temporaryCleanup.cleanForDatabase(_databasePath!);
      final database = EncryptedDatabase(_databasePath!, password);
      await database.open();
      OrientationRepository(database).logAudit(eventType: 'session_opened', entityType: 'database', details: 'Método: ${_masterMode ? 'master' : 'pin'}');
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => DashboardPage(database: database, databasePath: _databasePath!),
      ));
      await database.close();
    } catch (error) {
      if (mounted) setState(() => _message = error.toString().replaceFirst('ArgumentError: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _configurePin() async {
    final master = TextEditingController();
    final pin = TextEditingController();
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Configurar PIN local'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: master, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña máster', border: OutlineInputBorder())), const SizedBox(height: 12), TextField(controller: pin, obscureText: true, keyboardType: TextInputType.number, maxLength: 5, decoration: const InputDecoration(labelText: 'Nuevo PIN de 5 dígitos', border: OutlineInputBorder()))]), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar'))])) ?? false;
    if (!confirmed || master.text.length < 12 || !RegExp(r'^\d{5}$').hasMatch(pin.text)) {
      if (mounted) setState(() => _message = 'PIN no configurado: se requieren contraseña máster y 5 dígitos.');
      return;
    }
    await _pinService.configure(pin: pin.text, masterPassword: master.text);
    if (mounted) setState(() { _masterMode = false; _message = 'PIN local configurado. La contraseña máster sigue protegiendo SQLCipher.'; });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(fit: StackFit.expand, children: [
          RepaintBoundary(child: Image.asset('assets/images/login_cover.png', fit: BoxFit.cover, cacheWidth: 1200)),
          DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(.05), Colors.black.withOpacity(.18), Colors.black.withOpacity(.62)]))),
          SafeArea(child: Align(alignment: Alignment.bottomCenter, child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: TweenAnimationBuilder<double>(duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic, tween: Tween(begin: .94, end: 1), builder: (context, scale, child) => Transform.scale(scale: scale, child: child), child: Card(
              color: Theme.of(context).colorScheme.surface.withOpacity(.94),
              child: Padding(padding: const EdgeInsets.all(22), child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Cercano Oriente', style: Theme.of(context).textTheme.headlineMedium),
                const Text('Programa de orientación'),
                const SizedBox(height: 16),
                OutlinedButton.icon(onPressed: _chooseDatabase, icon: const Icon(Icons.folder_open), label: Text(_databasePath == null ? 'Seleccionar base cifrada' : 'Cambiar base de datos')),
                if (_databasePath != null) _DatabaseInfo(path: _databasePath!),
                const SizedBox(height: 12),
                if (!_masterMode) TextField(controller: _pin, obscureText: true, keyboardType: TextInputType.number, maxLength: 5, decoration: const InputDecoration(labelText: 'PIN local de 5 dígitos', border: OutlineInputBorder())),
                if (_masterMode) TextField(controller: _master, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña máster SQLCipher', helperText: 'Mínimo 12 caracteres; nunca viaja a la nube.', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: FilledButton(onPressed: _busy ? null : _open, child: Text(_busy ? 'Abriendo…' : 'Entrar'))),
                TextButton(onPressed: () => setState(() => _masterMode = !_masterMode), child: Text(_masterMode ? 'Usar PIN local' : 'Usar contraseña máster')),
                if (!_masterMode) TextButton(onPressed: _configurePin, child: const Text('Configurar PIN en este dispositivo')),
                if (_message != null) Text(_message!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ])),
            ))),
          ))),
        ],),
      );
}

class _DatabaseInfo extends StatelessWidget {
  const _DatabaseInfo({required this.path});
  final String path;
  @override
  Widget build(BuildContext context) {
    final file = File(path);
    final modified = file.existsSync() ? file.lastModifiedSync() : null;
    return ListTile(dense: true, leading: const Icon(Icons.lock), title: Text(path, maxLines: 2, overflow: TextOverflow.ellipsis), subtitle: Text(modified == null ? 'Archivo no encontrado' : 'Última modificación: $modified'));
  }
}
