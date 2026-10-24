/// Public application configuration supplied at build time.
class EnvConfig {
  EnvConfig._();

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://nvipwcrydrnogrbsnhud.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_2yyCD_Biu4JmoMiZqPcWag_ASc0KRXl',
  );
  static const String storageUrl = String.fromEnvironment(
    'SUPABASE_STORAGE_URL',
    defaultValue:
        'https://nvipwcrydrnogrbsnhud.storage.supabase.co/storage/v1/s3',
  );
  static const String storageBucket = String.fromEnvironment(
    'SUPABASE_STORAGE_BUCKET',
    defaultValue: 'assets',
  );
}
