import 'package:cloud_functions/cloud_functions.dart';
import 'package:logger/logger.dart';

class PracticeActivityService {
  static final Logger _logger = Logger();
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Records a practice activity and updates streak
  static Future<Map<String, dynamic>?> recordPracticeActivity() async {
    try {
      _logger.i('Calling recordPracticeActivity Cloud Function');

      final HttpsCallable callable = _functions.httpsCallable(
        'recordPracticeActivity',
      );

      final result = await callable.call();

      _logger.i('Cloud Function response: ${result.data}');

      return {
        'success': result.data['success'] ?? false,
        'message': result.data['message'] ?? '',
        'currentStreak': result.data['currentStreak'] ?? 0,
        'streakFreezes': result.data['streakFreezes'] ?? 0,
      };
    } catch (e) {
      _logger.e('Error calling recordPracticeActivity: $e');
      return null;
    }
  }
}