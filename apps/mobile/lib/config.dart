abstract final class AppConfig {
  static const appEnvironment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  /// Production AdMob banner unit. Empty in debug so Google sample units load.
  static const bannerAdUnitIdProd = String.fromEnvironment('ADMOB_BANNER_ID');

  static const bannerAdUnitIdTest = 'ca-app-pub-3940256099942544/6300978111';

  static const adMobTestDeviceIds = <String>[];

  static bool get isProduction => appEnvironment == 'production';

  /// Test ads unless this is a production build AND a real unit id is provided.
  static bool get useTestAds =>
      !isProduction || bannerAdUnitIdProd.trim().isEmpty;

  static String get bannerAdUnitId =>
      useTestAds ? bannerAdUnitIdTest : bannerAdUnitIdProd;

  /// Optional build-time Gemini key. When set, it is seeded into the local
  /// key cache so the app works even before an admin adds a key in Firestore.
  /// Prefer managing keys via the `admin_api_keys` Firestore collection (see
  /// docs/vision_setup.md) — this is only a convenience fallback.
  static const geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

  /// Firebase (auth + Firestore) is required; the Gemini vision path runs on
  /// device using the Firestore-backed admin API key pool.
  static bool get hasFirebaseConfig => true;
}
