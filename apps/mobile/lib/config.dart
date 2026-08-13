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

  /// Optional build-time Gemini key. When set, it is seeded into the local
  /// key cache so the app works even before an admin adds a key in Firestore.
  /// Prefer managing keys via the `admin_api_keys` Firestore collection (see
  /// docs/vision_setup.md) — this is only a convenience fallback.
  static const geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

  static bool get hasSupabaseConfig =>
      supabaseUrl.startsWith('https://') && supabasePublishableKey.isNotEmpty;

  /// True when Firebase (and therefore the admin_api_key_manager package) is
  /// wired up. The Gemini vision path requires this.
  static bool get hasFirebaseConfig => true;
}
