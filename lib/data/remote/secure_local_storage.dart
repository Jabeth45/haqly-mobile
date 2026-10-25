import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Secure session persistence adapter using [FlutterSecureStorage].
/// Implements docs/SECURITY.md finding S-01 (session stored in secure hardware keystore,
/// never in plain SharedPreferences).
class SecureLocalStorage extends LocalStorage {
  SecureLocalStorage({
    FlutterSecureStorage? storage,
    this.persistSessionKey = defaultSessionKey,
  }) : _storage =
           storage ??
           const FlutterSecureStorage(
             aOptions: AndroidOptions(resetOnError: true),
             iOptions: IOSOptions(
               accessibility: KeychainAccessibility.first_unlock,
             ),
           );

  /// Default secure storage key for session string.
  static const String defaultSessionKey = 'haqly_supabase_session';

  final FlutterSecureStorage _storage;
  final String persistSessionKey;

  @override
  Future<void> initialize() async {
    // No-op for FlutterSecureStorage; hardware keystore is accessed on demand.
  }

  @override
  Future<bool> hasAccessToken() async {
    final session = await _storage.read(key: persistSessionKey);
    return session != null && session.isNotEmpty;
  }

  @override
  Future<String?> accessToken() async {
    return _storage.read(key: persistSessionKey);
  }

  @override
  Future<void> removePersistedSession() async {
    await _storage.delete(key: persistSessionKey);
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    await _storage.write(key: persistSessionKey, value: persistSessionString);
  }
}

/// Secure asynchronous storage adapter for Gotrue PKCE verifier tokens.
class SecureGotrueAsyncStorage extends GotrueAsyncStorage {
  SecureGotrueAsyncStorage({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(resetOnError: true),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> getItem({required String key}) async {
    return _storage.read(key: key);
  }

  @override
  Future<void> setItem({required String key, required String value}) async {
    await _storage.write(key: key, value: value);
  }

  @override
  Future<void> removeItem({required String key}) async {
    await _storage.delete(key: key);
  }
}
