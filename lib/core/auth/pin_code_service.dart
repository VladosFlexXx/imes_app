import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PinCodeService {
  PinCodeService._();
  static final PinCodeService instance = PinCodeService._();

  static const _storage = FlutterSecureStorage();
  static const _keyEnabled = 'pin_code_enabled_v1';
  static const _keyHash = 'pin_code_hash_v1';
  static const _keySalt = 'pin_code_salt_v1';

  bool? _cachedEnabled;

  Future<bool> isEnabled() async {
    if (_cachedEnabled != null) return _cachedEnabled!;
    try {
      final value = await _storage.read(key: _keyEnabled);
      _cachedEnabled = value == 'true';
      return _cachedEnabled!;
    } catch (_) {
      return false;
    }
  }

  Future<bool> verify(String pin) async {
    try {
      final hash = await _storage.read(key: _keyHash);
      final salt = await _storage.read(key: _keySalt);
      if (hash == null || salt == null) return false;

      final inputHash = _hash(pin, salt);
      return inputHash == hash;
    } catch (_) {
      return false;
    }
  }

  Future<void> setPin(String pin) async {
    final salt = _generateSalt();
    final hash = _hash(pin, salt);

    await _storage.write(key: _keySalt, value: salt);
    await _storage.write(key: _keyHash, value: hash);
    await _storage.write(key: _keyEnabled, value: 'true');
    _cachedEnabled = true;
  }

  Future<void> removePin() async {
    await _storage.delete(key: _keyHash);
    await _storage.delete(key: _keySalt);
    await _storage.write(key: _keyEnabled, value: 'false');
    _cachedEnabled = false;
  }

  String _generateSalt() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return base64Url.encode(bytes);
  }

  String _hash(String pin, String salt) {
    final raw = '$salt:$pin';
    return sha256.convert(utf8.encode(raw)).toString();
  }
}

