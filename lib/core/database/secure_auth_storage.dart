import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SecureAuthStorage extends LocalStorage {
  SecureAuthStorage({
    required this.persistSessionKey,
    FlutterSecureStorage? secureStorage,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final String persistSessionKey;
  final FlutterSecureStorage _secureStorage;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async {
    final session = await _secureStorage.read(key: persistSessionKey);
    return session != null && session.isNotEmpty;
  }

  @override
  Future<String?> accessToken() {
    return _secureStorage.read(key: persistSessionKey);
  }

  @override
  Future<void> persistSession(String persistSessionString) {
    return _secureStorage.write(
      key: persistSessionKey,
      value: persistSessionString,
    );
  }

  @override
  Future<void> removePersistedSession() {
    return _secureStorage.delete(key: persistSessionKey);
  }
}
