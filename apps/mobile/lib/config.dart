abstract final class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static const appEnvironment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );
  static const authCallbackUrl =
      'com.rxscanlabs.prescriptionscanner://login-callback';

  static bool get hasSupabaseConfig =>
      supabaseUrl.startsWith('https://') && supabasePublishableKey.isNotEmpty;
}
