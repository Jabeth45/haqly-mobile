import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:haqly_mobile/core/config/app_config.dart';
import 'package:haqly_mobile/data/remote/secure_local_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Initializes the Supabase client using compile-time environment flags
/// and hardware-backed secure storage.
/// Follows docs/ARCHITECTURE.md Section 1, Section 11, and docs/SECURITY.md S-01.
Future<Supabase?> initializeSupabase({
  String? url,
  String? anonKey,
  FlutterSecureStorage? secureStorage,
  LocalStorage? customLocalStorage,
  GotrueAsyncStorage? customGotrueStorage,
}) async {
  final targetUrl = url ?? AppConfig.supabaseUrl;
  final targetKey = anonKey ?? AppConfig.supabaseAnonKey;

  if (targetUrl.isEmpty || targetKey.isEmpty) {
    return null;
  }

  // Avoid initializing with unconfigured dev template placeholders
  if (targetUrl.contains('YOUR-PROJECT-REF') ||
      targetKey.contains('YOUR-ANON-PUBLIC-KEY')) {
    return null;
  }

  final localStorage =
      customLocalStorage ?? SecureLocalStorage(storage: secureStorage);
  final pkceStorage =
      customGotrueStorage ?? SecureGotrueAsyncStorage(storage: secureStorage);

  return Supabase.initialize(
    url: targetUrl,
    anonKey: targetKey, // ignore: deprecated_member_use
    authOptions: FlutterAuthClientOptions(
      localStorage: localStorage,
      pkceAsyncStorage: pkceStorage,
      autoRefreshToken: true,
    ),
  );
}

/// Safe accessor for the active [SupabaseClient] if initialized.
SupabaseClient? get supabaseClient {
  try {
    return Supabase.instance.client;
  } catch (_) {
    return null;
  }
}
