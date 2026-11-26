/// Konfigurasi environment Supabase yang disuntikkan melalui `--dart-define`
/// atau `--dart-define-from-file=env.json`.
class AppEnv {
  AppEnv._();

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      !supabaseUrl.contains('YOUR_PROJECT_ID') &&
      !supabaseUrl.contains('placeholder.supabase.co') &&
      !supabaseAnonKey.contains('YOUR_SUPABASE_ANON_KEY') &&
      !supabaseAnonKey.contains('placeholder-anon-key');
}
