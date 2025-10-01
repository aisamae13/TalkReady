import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

class DailyContentService {
  static const String baseUrl =
      'http://192.168.254.103:5000'; // Update this to your server URL
  static final Logger _logger = Logger();

  static Future<Map<String, dynamic>?> fetchLearningTip({
    Map<String, dynamic>? userProgress,
    int currentStreak = 0,
    int? timeOfDay,
    double? averageScore,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/generate-learning-tip'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userProgress': userProgress,
          'currentStreak': currentStreak,
          'timeOfDay': timeOfDay ?? DateTime.now().hour,
          'averageScore': averageScore ?? 0,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['tipData'];
        }
      }

      _logger.w('Failed to fetch learning tip: ${response.statusCode}');
      return null;
    } catch (error) {
      _logger.e('Error fetching learning tip: $error');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> fetchDailyMotivation({
    int currentStreak = 0,
    double? averageScore,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/generate-daily-motivation'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'currentStreak': currentStreak,
          'averageScore': averageScore ?? 0,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['motivationData'];
        }
      }

      _logger.w('Failed to fetch daily motivation: ${response.statusCode}');
      return null;
    } catch (error) {
      _logger.e('Error fetching daily motivation: $error');
      return null;
    }
  }

  static Map<String, dynamic> getFallbackTip() {
    return {
      'tip':
          'Practice speaking English for 10 minutes today - consistency builds confidence!',
      'category': 'fluency',
      'estimatedTime': '10 minutes',
      'difficulty': 'beginner',
      'motivation': 'Every small step forward is progress worth celebrating!',
    };
  }

  static Map<String, dynamic> getFallbackMotivation() {
    return {
      'message': 'Your English skills are growing stronger every day!',
      'emoji': '🌟',
      'theme': 'progress',
    };
  }
}
