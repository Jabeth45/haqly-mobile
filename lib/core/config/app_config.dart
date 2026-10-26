/// Application environment configuration loaded via `--dart-define-from-file`.
/// Follows docs/ARCHITECTURE.md Section 11 and docs/SECURITY.md Section 4.
class AppConfig {
  const AppConfig._();

  /// Supabase project URL loaded from compile-time environment define.
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// Supabase public anonymous API key loaded from compile-time environment define.
  /// Note: Only the anon key may ship in the app. Never use service_role key.
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  /// Deployment environment: 'dev', 'staging', or 'prod'.
  static const String appEnv = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'dev',
  );

  /// Returns true if valid, non-placeholder Supabase configuration is present.
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      !supabaseUrl.contains('YOUR-PROJECT-REF') &&
      !supabaseAnonKey.contains('YOUR-ANON-PUBLIC-KEY');
}
