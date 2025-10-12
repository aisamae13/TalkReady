// lib/config/environment.dart
enum Environment { development, staging, production }

class EnvironmentConfig {
  static const Environment _environment =
      Environment.production; // Set to production for your hosted backend

  static Environment get environment => _environment;

  static bool get isDevelopment => _environment == Environment.development;
  static bool get isStaging => _environment == Environment.staging;
  static bool get isProduction => _environment == Environment.production;

  // API Configuration
  static String get apiBaseUrl {
    switch (_environment) {
      case Environment.development:
        return 'http://192.168.254.103:5000'; // Keep for local testing
      case Environment.staging:
        return 'https://talkready-backend.onrender.com'; // Your backend URL
      case Environment.production:
        return 'https://talkready-backend.onrender.com'; // Your backend URL
    }
  }

  // Frontend URL (if needed for any redirects or links)
  static String get frontendUrl {
    switch (_environment) {
      case Environment.development:
        return 'http://localhost:3000';
      case Environment.staging:
        return 'https://talkreadyweb.onrender.com';
      case Environment.production:
        return 'https://talkreadyweb.onrender.com';
    }
  }

  // Timeouts - increased for Render's cold start
  static Duration get networkTimeout => const Duration(seconds: 60);
  static Duration get uploadTimeout => const Duration(minutes: 3);

  // Debug settings
  static bool get enableLogging => !isProduction;
  static bool get enableCrashReporting => isProduction;
}
