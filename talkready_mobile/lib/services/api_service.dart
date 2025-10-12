// lib/services/api_service.dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:logger/logger.dart';
import '../config/api_config.dart';
import '../config/environment.dart';

class ApiService {
  static final Logger _logger = Logger();

  // Generic GET request
  static Future<Map<String, dynamic>?> get(String endpoint) async {
    try {
      final baseUrl = await ApiConfig.getApiBaseUrl();
      final response = await http
          .get(Uri.parse('$baseUrl$endpoint'), headers: _getHeaders())
          .timeout(EnvironmentConfig.networkTimeout);

      return _handleResponse(response, endpoint);
    } catch (e) {
      _logger.e('GET request failed for $endpoint: $e');
      return null;
    }
  }

  // Generic POST request
  static Future<Map<String, dynamic>?> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final baseUrl = await ApiConfig.getApiBaseUrl();
      final response = await http
          .post(
            Uri.parse('$baseUrl$endpoint'),
            headers: _getHeaders(),
            body: jsonEncode(body),
          )
          .timeout(EnvironmentConfig.networkTimeout);

      return _handleResponse(response, endpoint);
    } catch (e) {
      _logger.e('POST request failed for $endpoint: $e');
      return null;
    }
  }

  // Upload audio file
  static Future<String?> uploadAudio(String filePath) async {
    try {
      final baseUrl = await ApiConfig.getApiBaseUrl();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload-audio-temp'),
      );

      request.files.add(await http.MultipartFile.fromPath('audio', filePath));

      final response = await request.send().timeout(
        EnvironmentConfig.uploadTimeout,
      );
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        return data['audioUrl'];
      } else {
        _logger.e('Audio upload failed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      _logger.e('Audio upload error: $e');
      return null;
    }
  }

  // Download audio (TTS)
  static Future<Uint8List?> downloadAudio(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final baseUrl = await ApiConfig.getApiBaseUrl();
      final response = await http
          .post(
            Uri.parse('$baseUrl$endpoint'),
            headers: _getHeaders(),
            body: jsonEncode(body),
          )
          .timeout(EnvironmentConfig.networkTimeout);

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        _logger.e('Audio download failed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      _logger.e('Audio download error: $e');
      return null;
    }
  }

  // Common headers
  static Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent': 'CustomerServiceApp/1.0',
    };
  }

  // Handle HTTP response
  static Map<String, dynamic>? _handleResponse(
    http.Response response,
    String endpoint,
  ) {
    if (EnvironmentConfig.enableLogging) {
      _logger.i('$endpoint: ${response.statusCode}');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        return jsonDecode(response.body);
      } catch (e) {
        _logger.e('JSON decode error for $endpoint: $e');
        return null;
      }
    } else {
      _logger.e('HTTP error for $endpoint: ${response.statusCode}');
      if (response.statusCode >= 500) {
        // Server error - might want to retry
        ApiConfig.resetCache();
      }
      return null;
    }
  }
}
