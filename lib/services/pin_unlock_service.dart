import 'package:crypto/crypto.dart';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PinUnlockService {
  PinUnlockService({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  static const _pinHashKey = 'cercano_oriente.pin_hash';
  static const _masterKey = 'cercano_oriente.master_password';

  Future<bool> isConfigured() async => await _storage.read(key: _pinHashKey) != null;

  Future<void> configure({required String pin, required String masterPassword}) async {
    _validate(pin);
    final hash = sha256.convert(utf8.encode(pin)).toString();
    await _storage.write(key: _pinHashKey, value: hash);
    // Solo se guarda en el almacén seguro del dispositivo para el desbloqueo rápido.
    // Nunca se copia al backup ni se escribe en la base portable.
    await _storage.write(key: _masterKey, value: masterPassword);
  }

  Future<String?> unlock(String pin) async {
    _validate(pin);
    final expected = await _storage.read(key: _pinHashKey);
    if (expected == null || expected != sha256.convert(utf8.encode(pin)).toString()) return null;
    return _storage.read(key: _masterKey);
  }

  void _validate(String pin) {
    if (!RegExp(r'^\d{5}$').hasMatch(pin)) {
      throw ArgumentError('El PIN debe contener exactamente 5 dígitos.');
    }
  }
}
