// lib/config/api_config.dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:logger/logger.dart';
import 'environment.dart';

class ApiConfig {
  static final Logger _logger = Logger();
  static String? _cachedBaseUrl;
  static bool _isHealthy = true;
  static DateTime? _lastHealthCheck;

  // Get the current API base URL with health checking
  static Future<String> getApiBaseUrl() async {
    // Check if we need to refresh health status (every 5 minutes)
    final now = DateTime.now();
    if (_lastHealthCheck == null ||
        now.difference(_lastHealthCheck!).inMinutes > 5) {
      await _checkApiHealth();
    }

    return _cachedBaseUrl ?? EnvironmentConfig.apiBaseUrl;
  }

  // Check if the API is healthy
  static Future<void> _checkApiHealth() async {
    final baseUrl = EnvironmentConfig.apiBaseUrl;

    try {
      _logger.i('Checking API health at: $baseUrl');

      // Longer timeout for Render cold starts
      final response = await http
          .get(
            Uri.parse('$baseUrl/health'),
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': 'TalkReady-Mobile/1.0',
            },
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        _cachedBaseUrl = baseUrl;
        _isHealthy = true;
        _lastHealthCheck = DateTime.now();
        _logger.i('✅ API health check passed: $baseUrl');
      } else {
        throw Exception('Health check failed: ${response.statusCode}');
      }
    } catch (e) {
      _logger.e('❌ API health check failed for $baseUrl: $e');
      _isHealthy = false;
      _lastHealthCheck = DateTime.now();

      // Still use the URL even if health check fails (Render might be cold starting)
      _cachedBaseUrl = baseUrl;
    }
  }

  // Reset cache (useful for retrying)
  static void resetCache() {
    _cachedBaseUrl = null;
    _isHealthy = false;
    _lastHealthCheck = null;
  }

  // Check if API is likely cold starting
  static bool get mightBeColdStarting =>
      !_isHealthy && EnvironmentConfig.isProduction;
}
