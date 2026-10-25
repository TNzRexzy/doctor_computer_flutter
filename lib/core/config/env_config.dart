/// Public application configuration supplied at build time.
///
/// No key or project URL is hardcoded here. Provide them from `.env`:
///   flutter run --dart-define-from-file=.env
///   flutter build apk --dart-define-from-file=.env
/// (copy `.env.example` to `.env` first).
///
/// The Gemini API key is NOT part of this config: it is read from the
/// Supabase table `app_config` (key = GEMINI_API_KEY) at runtime, see
/// `lib/services/app_config_service.dart`.
class EnvConfig {
  EnvConfig._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );
  static const String storageUrl = String.fromEnvironment(
    'SUPABASE_STORAGE_URL',
  );
  static const String storageBucket = String.fromEnvironment(
    'SUPABASE_STORAGE_BUCKET',
    defaultValue: 'assets',
  );

  /// Throws a clear error at startup when the build was started without
  /// `--dart-define-from-file=.env`.
  static void assertConfigured() {
    final missing = <String>[
      if (supabaseUrl.isEmpty) 'SUPABASE_URL',
      if (supabaseAnonKey.isEmpty) 'SUPABASE_ANON_KEY',
      if (storageUrl.isEmpty) 'SUPABASE_STORAGE_URL',
    ];
    if (missing.isNotEmpty) {
      throw StateError(
        'Missing build configuration: ${missing.join(', ')}. '
        'Copy .env.example to .env, fill it in, then run with '
        '--dart-define-from-file=.env',
      );
    }
  }
}
