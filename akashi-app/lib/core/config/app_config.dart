/// Akashi — App Constants & Environment Configuration
library;

class AppConfig {
  AppConfig._();

  // ─── Supabase ──────────────────────────────────────────────────────────────
  static const String supabaseUrl = 'https://whaaarneyisxkphvgwco.supabase.co';
  static const String supabaseAnonKey =
      'sb_publishable_dTrT9Iwz8BEIracumgc5bg_NToZhhnP';

  // ─── Firebase ─────────────────────────────────────────────────────────────
  static const String firebaseProjectId = 'studio-3969520472-b5fd0';
  static const String firebaseAppId =
      '1:1026289113144:android:9b3d11c4bc2eee11356ecd';

  // ─── API Base URL ─────────────────────────────────────────────────────────
  // Phase 1: localhost for dev, Render.com for prod
  static const String apiBaseUrl =
      String.fromEnvironment('API_BASE_URL',
          defaultValue: 'http://10.0.2.2:8000'); // 10.0.2.2 = localhost in Android emulator

  // ─── Sentinel Hub ─────────────────────────────────────────────────────────
  static const String sentinelClientId =
      String.fromEnvironment('SENTINEL_HUB_CLIENT_ID', defaultValue: '');
  static const String sentinelClientSecret =
      String.fromEnvironment('SENTINEL_HUB_CLIENT_SECRET', defaultValue: '');

  // ─── OpenWeather ──────────────────────────────────────────────────────────
  static const String openWeatherApiKey =
      String.fromEnvironment('OPENWEATHER_API_KEY', defaultValue: '');

  // ─── App Settings ─────────────────────────────────────────────────────────
  static const String packageName = 'com.akashi.farmer';
  static const String appVersion = '1.0.0';

  // ─── NDVI Thresholds ──────────────────────────────────────────────────────
  // These are starting points — validate with agronomist before launch
  static const double ndviGreenThresholdRice = 0.50;
  static const double ndviYellowThresholdRice = 0.30;
  static const double ndviGreenThresholdGeneral = 0.45;
  static const double ndviYellowThresholdGeneral = 0.25;
  static const double cloudCoverWarningThreshold = 70.0;

  // ─── Bangladesh Geography ──────────────────────────────────────────────────
  // Center of Bangladesh — map defaults
  static const double bangladeshLat = 23.6850;
  static const double bangladeshLon = 90.3563;
  static const double defaultMapZoom = 13.0;

  // ─── Bigha Conversion ─────────────────────────────────────────────────────
  // 1 bigha = 0.33 acres in Bangladesh (local standard)
  static const double acresPerBigha = 0.33;

  static double acresToBigha(double acres) => acres / acresPerBigha;
  static double bighaToAcres(double bigha) => bigha * acresPerBigha;

  // ─── Notifications ────────────────────────────────────────────────────────
  // Never notify outside 6am–9pm Bangladesh time (GMT+6)
  static const int notificationStartHour = 6;  // 6:00 AM
  static const int notificationEndHour = 21;   // 9:00 PM
  static const String bangladeshTimezone = 'Asia/Dhaka'; // GMT+6
}
