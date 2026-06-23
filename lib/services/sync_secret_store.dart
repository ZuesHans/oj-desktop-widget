import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class SyncSecretStore {
  Future<String> readToken();
  Future<void> saveToken(String token);
}

class SecureSyncSecretStore implements SyncSecretStore {
  SecureSyncSecretStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'oj_float_sync_token_v1';

  final FlutterSecureStorage _storage;

  @override
  Future<String> readToken() async {
    return (await _storage.read(key: _tokenKey)) ?? '';
  }

  @override
  Future<void> saveToken(String token) async {
    final normalized = token.trim();
    if (normalized.isEmpty) {
      await _storage.delete(key: _tokenKey);
      return;
    }
    await _storage.write(key: _tokenKey, value: normalized);
  }
}

class MemorySyncSecretStore implements SyncSecretStore {
  MemorySyncSecretStore([this._token = '']);

  String _token;

  @override
  Future<String> readToken() async => _token;

  @override
  Future<void> saveToken(String token) async {
    _token = token.trim();
  }
}
