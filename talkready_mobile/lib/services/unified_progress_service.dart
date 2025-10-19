// lib/services/unified_progress_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import '../config/api_config.dart';
import '../config/environment.dart';
import 'practice_activity_service.dart';


class UnifiedProgressService {
  final Logger _logger = Logger();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get userId => _auth.currentUser?.uid;

  // Web-compatible lesson structure
  static const Map<String, List<String>> webLessonStructure = {
    'module1': ['Lesson 1.1', 'Lesson 1.2', 'Lesson 1.3'],
    'module2': ['Lesson 2.1', 'Lesson 2.2', 'Lesson 2.3'],
    'module3': ['Lesson 3.1', 'Lesson 3.2'],
    'module4': ['Lesson 4.1', 'Lesson 4.2'],
    'module5': ['Lesson 5.1', 'Lesson 5.2'],
    'module6': ['Lesson-6-1'],
  };

  // Module assessment IDs (matching web structure)
  static const Map<String, String> moduleAssessments = {
    'module1': 'module_1_final',
    'module2': 'module_2_final',
    'module3': 'module_3_final',
    'module4': 'module_4_final',
    'module5': 'module_5_final',
    'module6': 'module_6_final',
  };

  // ✅ FIXED: Private method to get API base URL
  Future<String> _getApiBaseUrl() async {
    return await ApiConfig.getApiBaseUrl();
  }

  // ✅ NEW: Public method for external access
  Future<String> getApiBaseUrl() async {
    return await _getApiBaseUrl();
  }

  Duration get _networkTimeout => EnvironmentConfig.networkTimeout;

  /// Get user progress in the same format as the web app
  Future<Map<String, dynamic>> getUserProgress() async {
    final uId = userId;
    if (uId == null) {
      _logger.w('User not authenticated');
      return {
        'lessonAttempts': <String, dynamic>{},
        'moduleAssessmentAttempts': <String, dynamic>{},
        'preAssessmentsCompleted': <String, dynamic>{},
      };
    }

    try {
      final userProgressRef = _firestore.collection('userProgress').doc(uId);
      final docSnap = await userProgressRef.get();

      if (!docSnap.exists) {
        _logger.i('No progress document found for user $uId');
        return {
          'lessonAttempts': <String, dynamic>{},
          'moduleAssessmentAttempts': <String, dynamic>{},
          'preAssessmentsCompleted': <String, dynamic>{},
        };
      }

      final data = docSnap.data() as Map<String, dynamic>;

      final lessonAttempts = data['lessonAttempts'];
      final moduleAssessmentAttempts = data['moduleAssessmentAttempts'];
      final preAssessmentsCompleted = data['preAssessmentsCompleted'];

      return {
        'lessonAttempts': lessonAttempts is Map
            ? Map<String, dynamic>.from(lessonAttempts)
            : <String, dynamic>{},
        'moduleAssessmentAttempts': moduleAssessmentAttempts is Map
            ? Map<String, dynamic>.from(moduleAssessmentAttempts)
            : <String, dynamic>{},
        'preAssessmentsCompleted': preAssessmentsCompleted is Map
            ? Map<String, dynamic>.from(preAssessmentsCompleted)
            : <String, dynamic>{},
      };
    } catch (e) {
      _logger.e('Error getting user progress: $e');
      return {
        'lessonAttempts': <String, dynamic>{},
        'moduleAssessmentAttempts': <String, dynamic>{},
        'preAssessmentsCompleted': <String, dynamic>{},
      };
    }
  }

  Future<Map<String, dynamic>?> getFullLessonContent(
    String lessonDocumentId,
  ) async {
    if (lessonDocumentId.isEmpty) {
      _logger.w(
        'Lesson document ID is empty. Cannot fetch full lesson content.',
      );
      return null;
    }
    try {
      _logger.i(
        'Fetching full content for lesson document: $lessonDocumentId from "lessons" collection.',
      );
      final lessonDocRef = _firestore
          .collection('lessons')
          .doc(lessonDocumentId);
      final docSnapshot = await lessonDocRef.get();

      if (docSnapshot.exists) {
        _logger.d(
          'Full lesson content found for $lessonDocumentId: ${docSnapshot.data()}',
        );
        return docSnapshot.data();
      } else {
        _logger.w(
          'Lesson document "$lessonDocumentId" not found in "lessons" collection.',
        );
        return null;
      }
    } catch (e) {
      _logger.e(
        'Error fetching full lesson content for "$lessonDocumentId": $e',
      );
      return null;
    }
  }

  Future<void> markPreAssessmentAsComplete(String lessonId) async {
    final uId = userId;
    if (uId == null) {
      _logger.e('User not authenticated to mark pre-assessment complete.');
      throw Exception('User not authenticated');
    }
    if (lessonId.isEmpty) {
      _logger.w('Lesson ID is empty, cannot mark pre-assessment as complete.');
      return;
    }

    try {
      final userProgressDocRef = _firestore.collection('userProgress').doc(uId);

      await userProgressDocRef.set({
        'preAssessmentsCompleted': {lessonId: true},
        'lastActivityTimestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _logger.i(
        'Successfully marked pre-assessment "$lessonId" as complete for user $uId.',
      );
    } catch (e) {
      _logger.e('Error marking pre-assessment "$lessonId" as complete: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getModuleAssessmentAttempts(
    String assessmentId,
  ) async {
    final uId = userId;
    if (uId == null) {
      _logger.w('User not authenticated for getModuleAssessmentAttempts.');
      return [];
    }
    if (assessmentId.isEmpty) {
      _logger.w('Assessment ID is empty for getModuleAssessmentAttempts.');
      return [];
    }

    try {
      final userProgressDoc = await _firestore
          .collection('userProgress')
          .doc(uId)
          .get();

      if (userProgressDoc.exists) {
        final data = userProgressDoc.data();
        if (data != null && data['moduleAssessmentAttempts'] is Map) {
          final allModuleAttempts = Map<String, dynamic>.from(
            data['moduleAssessmentAttempts'],
          );

          if (allModuleAttempts[assessmentId] is List) {
            final attemptsList = List<dynamic>.from(
              allModuleAttempts[assessmentId],
            );
            return attemptsList.map((attempt) {
              final attemptMap = Map<String, dynamic>.from(attempt as Map);
              if (attemptMap['attemptTimestamp'] is Timestamp) {
                attemptMap['attemptTimestamp'] =
                    (attemptMap['attemptTimestamp'] as Timestamp).toDate();
              }
              return attemptMap;
            }).toList();
          }
        }
      }
      return [];
    } catch (e) {
      _logger.e(
        'Error getting module assessment attempts for "$assessmentId": $e',
      );
      return [];
    }
  }

  Future<Map<String, dynamic>?> getModuleAssessmentContent(
    String assessmentId,
  ) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('moduleAssessments')
          .doc(assessmentId)
          .get();

      return doc.exists ? doc.data() : null;
    } catch (e) {
      _logger.e('Error getting assessment content: $e');
      return null;
    }
  }

  Future<void> saveModuleAssessmentAttempt({
    required String assessmentId,
    required int score,
    required int maxScore,
    Map<String, dynamic>? detailedResults,
    List<Map<String, dynamic>>? scenarioDetails,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final docRef = FirebaseFirestore.instance
          .collection('userProgress')
          .doc(user.uid);

      final attemptData = {
        'assessmentId': assessmentId,
        'score': score,
        'maxScore': maxScore,
        'attemptTimestamp': Timestamp.now(),
        'type': 'module_assessment',
        'detailedResults': detailedResults,
      };

      if (scenarioDetails != null && scenarioDetails.isNotEmpty) {
        attemptData['scenarioBreakdown'] = scenarioDetails
            .map(
              (scenario) => ({
                'scenarioId': scenario['id'],
                'scenarioTitle':
                    scenario['title'] ?? 'Scenario ${scenario['id']}',
                'individualScore': scenario['score'],
                'maxScenarioScore': scenario['maxScore'],
                'feedback': {
                  'overallFeedback': scenario['feedback']?['overallFeedback'],
                  'criteriaBreakdown':
                      scenario['feedback']?['criteriaBreakdown'] ?? [],
                  'detailedExplanation':
                      scenario['feedback']?['detailedExplanation'],
                },
                'audioData': {
                  'userRecordingUrl': scenario['audioUrl'],
                  'transcription': scenario['transcript'],
                },
                'evaluationMetadata': {
                  'evaluationType': scenario['evaluationType'] ?? 'unscripted',
                  'aiModel': 'gpt-4o-mini',
                  'evaluatedAt': DateTime.now().toIso8601String(),
                  'scoringCriteria': scenario['scoringCriteria'] ?? {},
                },
              }),
            )
            .toList();

        final totalScenarios = scenarioDetails.length;
        final averageScore =
            scenarioDetails
                .map((s) => (s['score'] as num?)?.toDouble() ?? 0.0)
                .reduce((a, b) => a + b) /
            totalScenarios;

        attemptData['summaryStats'] = {
          'totalScenarios': totalScenarios,
          'averageScenarioScore': averageScore,
          'scenariosCompleted': scenarioDetails
              .where((s) => s['score'] != null)
              .length,
          'strongestAreas': _identifyStrongestAreas(scenarioDetails),
          'improvementAreas': _identifyImprovementAreas(scenarioDetails),
        };
      }

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);

        if (!doc.exists) {
          transaction.set(docRef, {
            'moduleAssessmentAttempts': {
              assessmentId: [attemptData],
            },
            'lastActivityTimestamp': FieldValue.serverTimestamp(),
          });
        } else {
          final data = doc.data() as Map<String, dynamic>;
          final moduleAttempts =
              data['moduleAssessmentAttempts'] as Map<String, dynamic>? ?? {};
          final existingAttempts = List<Map<String, dynamic>>.from(
            moduleAttempts[assessmentId] ?? [],
          );

          existingAttempts.add(attemptData);

          transaction.update(docRef, {
            'moduleAssessmentAttempts.$assessmentId': existingAttempts,
            'lastActivityTimestamp': FieldValue.serverTimestamp(),
          });
        }
      });

      _logger.i(
        'Successfully saved enhanced assessment attempt for $assessmentId',
      );
    } catch (e) {
      _logger.e('Error saving assessment attempt: $e');
      rethrow;
    }
  }

  List<String> _identifyStrongestAreas(List<Map<String, dynamic>> scenarios) {
    final Map<String, List<bool>> criteriaPerformance = {};

    for (var scenario in scenarios) {
      final criteriaBreakdown =
          scenario['feedback']?['criteriaBreakdown'] as List<dynamic>? ?? [];
      for (var criterion in criteriaBreakdown) {
        final name = criterion['criterion'] as String?;
        final met = criterion['met'] as bool? ?? false;
        if (name != null) {
          criteriaPerformance[name] = (criteriaPerformance[name] ?? [])
            ..add(met);
        }
      }
    }

    return criteriaPerformance.entries
        .where(
          (entry) =>
              entry.value.where((met) => met).length / entry.value.length >=
              0.8,
        )
        .map((entry) => entry.key)
        .toList();
  }

  List<String> _identifyImprovementAreas(List<Map<String, dynamic>> scenarios) {
    final Map<String, List<bool>> criteriaPerformance = {};

    for (var scenario in scenarios) {
      final criteriaBreakdown =
          scenario['feedback']?['criteriaBreakdown'] as List<dynamic>? ?? [];
      for (var criterion in criteriaBreakdown) {
        final name = criterion['criterion'] as String?;
        final met = criterion['met'] as bool? ?? false;
        if (name != null) {
          criteriaPerformance[name] = (criteriaPerformance[name] ?? [])
            ..add(met);
        }
      }
    }

    return criteriaPerformance.entries
        .where(
          (entry) =>
              entry.value.where((met) => met).length / entry.value.length < 0.6,
        )
        .map((entry) => entry.key)
        .toList();
  }

  // ✅ FIXED: Updated evaluateUnscriptedSimulation
  Future<Map<String, dynamic>?> evaluateUnscriptedSimulation({
    required String audioUrl,
    required Map<String, dynamic> scoringCriteria,
  }) async {
    final baseUrl = await _getApiBaseUrl();

    try {
      final requestBody = {
        'audioUrl': audioUrl,
        'scoringCriteria': scoringCriteria,
      };

      _logger.i(
        'Sending unscripted evaluation request to: $baseUrl/evaluate-unscripted-simulation',
      );

      final response = await http
          .post(
            Uri.parse('$baseUrl/evaluate-unscripted-simulation'),
            headers: {
              'Content-Type': 'application/json',
              'Connection': 'close',
              'User-Agent': 'TalkReady-Mobile/1.0',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(_networkTimeout);

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        _logger.i('Unscripted evaluation successful');

        if (result['success'] == true) {
          return result;
        } else {
          _logger.e('API returned success=false: ${result['error']}');
        }
      } else {
        _logger.e('API HTTP error ${response.statusCode}: ${response.body}');
      }
      return null;
    } catch (e) {
      _logger.e('Error in unscripted evaluation: $e');
      return null;
    }
  }

  Future<void> saveLessonAttempt({
  required String lessonId,
  required int score,
  required int maxScore,
  required int timeSpent,
  required Map<String, dynamic> detailedResponses,
}) async {
  final uId = userId;
  if (uId == null) {
    _logger.e('User not authenticated. Cannot save lesson attempt.');
    throw Exception('User not authenticated');
  }

  final userProgressRef = _firestore.collection('userProgress').doc(uId);

  try {
    final existingAttempts = await getLessonAttempts(lessonId);
    final newAttemptNumber = existingAttempts.length + 1;

    final newAttemptData = {
      'score': score,
      'totalPossiblePoints': maxScore,
      'attemptNumber': newAttemptNumber,
      'lessonId': lessonId,
      'timeSpent': timeSpent,
      'attemptTimestamp': Timestamp.now(),
      'detailedResponses': detailedResponses,
    };

    await userProgressRef.set({
      'lessonAttempts': {
        lessonId: FieldValue.arrayUnion([newAttemptData]),
      },
      'lastActivityTimestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _logger.i(
      'Successfully saved attempt #$newAttemptNumber for lesson $lessonId for user $uId.',
    );

    // 🆕 NEW: Call Cloud Function to update streak
    try {
      final streakResult = await PracticeActivityService.recordPracticeActivity();

      if (streakResult != null && streakResult['success'] == true) {
        _logger.i('Streak updated: ${streakResult['message']}');

        // Log if streak freeze was used
        if (streakResult['message'].toString().contains('Streak Freeze')) {
          _logger.i('Streak Freeze used! Remaining: ${streakResult['streakFreezes']}');
        }
      }
    } catch (streakError) {
      // Don't fail the lesson save if streak update fails
      _logger.e('Failed to update streak, but lesson was saved: $streakError');
    }

  } catch (e) {
    _logger.e('Error saving lesson attempt for "$lessonId": $e');
    rethrow;
  }
}

  Future<Map<String, dynamic>> getModuleProgress(String moduleId) async {
    final progress = await getUserProgress();
    final lessonAttempts =
        progress['lessonAttempts'] as Map<String, dynamic>? ?? {};
    final assessmentAttempts =
        progress['moduleAssessmentAttempts'] as Map<String, dynamic>? ?? {};

    final moduleLessons = webLessonStructure[moduleId] ?? [];
    final assessmentId = moduleAssessments[moduleId];

    Map<String, bool> lessonCompletion = {};
    int totalCompleted = 0;

    for (String lessonId in moduleLessons) {
      final attempts = lessonAttempts[lessonId] as List<dynamic>? ?? [];
      final isCompleted = attempts.isNotEmpty;
      lessonCompletion[lessonId] = isCompleted;
      if (isCompleted) totalCompleted++;
    }

    bool assessmentTaken = false;
    if (assessmentId != null) {
      final attempts = assessmentAttempts[assessmentId] as List<dynamic>? ?? [];
      assessmentTaken = attempts.isNotEmpty;
    }

    bool allLessonsComplete = totalCompleted == moduleLessons.length;
    bool isModuleCompleted =
        allLessonsComplete && (assessmentTaken || assessmentId == null);

    return {
      'moduleId': moduleId,
      'lessons': lessonCompletion,
      'totalLessons': moduleLessons.length,
      'completedLessons': totalCompleted,
      'allLessonsComplete': allLessonsComplete,
      'assessmentTaken': assessmentTaken,
      'isCompleted': isModuleCompleted,
      'isUnlocked': _isModuleUnlocked(
        moduleId,
        lessonAttempts,
        assessmentAttempts,
      ),
    };
  }

  Future<Map<String, dynamic>> getScenarioFeedback(
    String lessonId,
    Map<String, String> answers, [
    Map<String, dynamic>? scripts,
  ]) async {
    final baseUrl = await _getApiBaseUrl();

    final body = jsonEncode({
      'lesson': lessonId,
      'answers': answers,
      'scripts': scripts ?? {},
    });

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/evaluate-scenario'),
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': 'TalkReady-Mobile/1.0',
            },
            body: body,
          )
          .timeout(_networkTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _logger.i('Received AI feedback successfully for lesson $lessonId.');
        return data['feedback'] as Map<String, dynamic>? ?? {};
      } else {
        _logger.e(
          'AI server returned an error: ${response.statusCode} ${response.body}',
        );
        throw Exception('Failed to get feedback from AI server.');
      }
    } catch (e) {
      _logger.e('Error calling AI feedback service: $e');
      rethrow;
    }
  }

  Future<Uint8List?> synthesizeSpeech(String text) async {
    final baseUrl = await _getApiBaseUrl();

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/synthesize-speech'),
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': 'TalkReady-Mobile/1.0',
            },
            body: jsonEncode({'text': text}),
          )
          .timeout(_networkTimeout);

      if (response.statusCode == 200) {
        _logger.i('Successfully fetched synthesized audio.');
        return response.bodyBytes;
      } else {
        _logger.e('TTS error: ${response.statusCode} ${response.body}');
        return null;
      }
    } catch (e) {
      _logger.e('Error calling synthesize speech service: $e');
      return null;
    }
  }

  Future<Uint8List?> synthesizeSpeechFromTurns(List<dynamic> turns) async {
    final baseUrl = await _getApiBaseUrl();

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/synthesize-speech'),
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': 'TalkReady-Mobile/1.0',
            },
            body: jsonEncode({'parts': turns}),
          )
          .timeout(_networkTimeout);

      if (response.statusCode == 200) {
        _logger.i('Successfully fetched synthesized audio for script.');
        return response.bodyBytes;
      } else {
        _logger.e('TTS error: ${response.statusCode} ${response.body}');
        return null;
      }
    } catch (e) {
      _logger.e('Error calling script synthesis service: $e');
      return null;
    }
  }

  // ✅ FIXED: Updated evaluateUnscriptedSimulationEnhanced
  Future<Map<String, dynamic>?> evaluateUnscriptedSimulationEnhanced({
    required String audioUrl,
    required Map<String, dynamic> scoringCriteria,
    Map<String, dynamic>? scenarioData,
  }) async {
    final baseUrl = await _getApiBaseUrl();

    try {
      final requestBody = {
        'audioUrl': audioUrl,
        'scoringCriteria': scoringCriteria,
        'evaluationType': 'enhanced_roleplay',
        'assessmentType': 'module_final',
        'platform': 'mobile',
        'requestDetailedBreakdown': true,
      };

      if (scenarioData != null) {
        requestBody['scenarioData'] = scenarioData;
      }

      _logger.i(
        'Sending enhanced roleplay evaluation request to: $baseUrl/evaluate-unscripted-simulation',
      );

      final response = await http
          .post(
            Uri.parse('$baseUrl/evaluate-unscripted-simulation'),
            headers: {
              'Content-Type': 'application/json',
              'Connection': 'keep-alive',
              'Accept': 'application/json',
              'User-Agent': 'TalkReady-Mobile/1.0',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 90));

      _logger.i('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        try {
          final result = jsonDecode(response.body);

          if (result is Map<String, dynamic>) {
            _logger.i('Successfully parsed JSON response');
            _logger.i('Response keys: ${result.keys.toList()}');

            if (result['success'] == true) {
              return result;
            } else {
              _logger.e('Backend returned success=false: ${result['error']}');
              return null;
            }
          }
        } catch (jsonError) {
          _logger.e('JSON parsing error: $jsonError');
          return null;
        }
      } else {
        _logger.e('HTTP error ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e) {
      _logger.e('Network error in enhanced roleplay evaluation: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> evaluateAzureSpeech(
    String audioUrl,
    String originalText,
  ) async {
    final baseUrl = await _getApiBaseUrl();

    try {
      final requestBody = {
        'audioUrl': audioUrl,
        'originalText': originalText,
        'language': 'en-US',
        'assessmentType': 'script_reading',
      };

      final response = await http
          .post(
            Uri.parse('$baseUrl/evaluate-speech-with-azure'),
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': 'TalkReady-Mobile/1.0',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(_networkTimeout);

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          return result;
        } else {
          _logger.e('Azure API returned success=false: ${result['error']}');
        }
      } else {
        _logger.e(
          'Azure API HTTP error ${response.statusCode}: ${response.body}',
        );
      }
      return null;
    } catch (e) {
      _logger.e('Error calling Azure speech evaluation: $e');
      return null;
    }
  }

  // ✅ FIXED: Updated evaluateClarificationScenario
  Future<Map<String, dynamic>> evaluateClarificationScenario(
    Map<String, String> answers,
    String lesson,
  ) async {
    final baseUrl = await _getApiBaseUrl();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/evaluate-clarification'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'TalkReady-Mobile/1.0',
        },
        body: jsonEncode({'answers': answers, 'lesson': lesson}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'Failed to evaluate clarification: ${response.statusCode}',
        );
      }
    } catch (e) {
      _logger.e('Error evaluating clarification scenario: $e');
      throw Exception('Error evaluating clarification: $e');
    }
  }

  // ✅ FIXED: Updated evaluateSolutions
  Future<Map<String, dynamic>> evaluateSolutions(
    Map<String, String> solutions,
    String lessonId,
  ) async {
    final baseUrl = await _getApiBaseUrl();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/evaluate-solutions'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'TalkReady-Mobile/1.0',
        },
        body: json.encode({'solutions': solutions, 'lesson': lessonId}),
      );

      _logger.i('Backend response status: ${response.statusCode}');
      _logger.i('Backend response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return {'success': true, 'feedback': responseData['feedback']};
      } else {
        _logger.e('Backend error: ${response.statusCode} - ${response.body}');
        return {
          'success': false,
          'error': 'HTTP ${response.statusCode}: ${response.body}',
        };
      }
    } catch (e) {
      _logger.e('Network error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ✅ FIXED: Updated testBackendConnection
  Future<void> testBackendConnection() async {
    try {
      final baseUrl = await _getApiBaseUrl();
      final response = await http
          .get(
            Uri.parse('$baseUrl/health'),
            headers: {
              'Connection': 'keep-alive',
              'User-Agent': 'TalkReady-Mobile/1.0',
            },
          )
          .timeout(const Duration(seconds: 10));

      _logger.i('Backend health check: ${response.statusCode}');
      _logger.i('Backend response: ${response.body}');
    } catch (e) {
      _logger.e('Backend connection test failed: $e');
    }
  }

  // ✅ FIXED: Updated synthesizeSpeechFromParts
  Future<Uint8List?> synthesizeSpeechFromParts(List<dynamic> parts) async {
    final baseUrl = await _getApiBaseUrl();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/synthesize-speech'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'TalkReady-Mobile/1.0',
        },
        body: json.encode({'parts': parts}),
      );

      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ✅ FIXED: Updated evaluateTypingPreAssessment
  Future<String?> evaluateTypingPreAssessment({
    required String answer,
    required String customerStatement,
    required String lessonKey,
  }) async {
    final baseUrl = await _getApiBaseUrl();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/evaluate-preassessment-typing'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'TalkReady-Mobile/1.0',
        },
        body: jsonEncode({
          'answer': answer,
          'customerStatement': customerStatement,
          'lessonKey': lessonKey,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['feedback'] as String?;
      } else {
        _logger.e(
          'Error from backend: ${response.statusCode} ${response.body}',
        );
        return null;
      }
    } catch (e, s) {
      _logger.e('Error calling evaluateTypingPreAssessment: $e\n$s');
      return null;
    }
  }

  // ✅ FIXED: Updated getOpenAICoachExplanation
  Future<Map<String, dynamic>?> getOpenAICoachExplanation(
    Map<String, dynamic> azureFeedback,
    String originalText,
  ) async {
    final baseUrl = await _getApiBaseUrl();

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/explain-azure-feedback-with-openai'),
            headers: {
              'Content-Type': 'application/json',
              'Connection': 'close',
              'User-Agent': 'TalkReady-Mobile/1.0',
            },
            body: jsonEncode({
              'azureFeedback': azureFeedback,
              'originalText': originalText,
            }),
          )
          .timeout(const Duration(seconds: 40));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          return result['detailedFeedback'];
        } else {
          _logger.e(
            'OpenAI explanation returned success=false: ${result['error'] ?? 'Unknown error'}',
          );
        }
      } else {
        _logger.e(
          'OpenAI coach explanation HTTP ${response.statusCode} body=${response.body}',
        );
      }
      return null;
    } catch (e) {
      _logger.e('Error getting OpenAI explanation: $e');
      return null;
    }
  }

  Future<void> saveLessonActivity(
    String lessonId,
    Map<String, dynamic> attemptData,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final db = FirebaseFirestore.instance;

      attemptData['userId'] = user.uid;
      attemptData['timestamp'] = FieldValue.serverTimestamp();

      await db
          .collection('users')
          .doc(user.uid)
          .collection('lessonAttempts')
          .doc(lessonId)
          .collection('attempts')
          .add(attemptData);

      _logger.d('Lesson activity saved for $lessonId');
    } catch (e) {
      _logger.e('Error saving lesson activity: $e');
      rethrow;
    }
  }

  // ✅ FIXED: Updated synthesizeSpeechEnhanced
  Future<Uint8List?> synthesizeSpeechEnhanced({
    required String text,
    String voice = 'female',
    List<Map<String, dynamic>>? parts,
  }) async {
    final baseUrl = await _getApiBaseUrl();

    try {
      Map<String, dynamic> requestBody;

      if (parts != null && parts.isNotEmpty) {
        requestBody = {'parts': parts, 'voice': voice};
      } else {
        requestBody = {'text': text, 'voice': voice};
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/synthesize-speech'),
            headers: {
              'Content-Type': 'application/json',
              'Connection': 'close',
              'User-Agent': 'TalkReady-Mobile/1.0',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        _logger.i('Successfully synthesized speech');
        return response.bodyBytes;
      } else {
        _logger.e('TTS error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      _logger.e('Error in TTS service: $e');
      return null;
    }
  }

  // ✅ FIXED: Updated getAiCallFeedback
  Future<Map<String, dynamic>?> getAiCallFeedback({
    required List<Map<String, String>> transcript,
    required Map<String, dynamic> scenario,
  }) async {
    final baseUrl = await _getApiBaseUrl();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/ai-call-feedback'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'TalkReady-Mobile/1.0',
        },
        body: jsonEncode({'transcript': transcript, 'scenario': scenario}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _logger.i('Successfully received AI Call Feedback.');
        return data;
      } else {
        _logger.e(
          'Backend server returned an error for AI Call Feedback: ${response.statusCode} ${response.body}',
        );
        return {'error': 'Failed to get AI coach feedback.'};
      }
    } catch (e) {
      _logger.e('Error calling AI Call Feedback service: $e');
      return {'error': 'Could not connect to AI coach service.'};
    }
  }

  // ✅ FIXED: Updated evaluateAzureSpeechEnhanced
  Future<Map<String, dynamic>?> evaluateAzureSpeechEnhanced({
    required String audioUrl,
    required String originalText,
    String language = 'en-US',
    String assessmentType = 'script_reading',
    Map<String, dynamic>? metadata,
  }) async {
    final baseUrl = await _getApiBaseUrl();

    try {
      final requestBody = {
        'audioUrl': audioUrl,
        'originalText': originalText,
        'language': language,
        'assessmentType': assessmentType,
        if (metadata != null) 'metadata': metadata,
      };

      _logger.i('Sending enhanced Azure request: $requestBody');

      final response = await http
          .post(
            Uri.parse('$baseUrl/evaluate-speech-with-azure'),
            headers: {
              'Content-Type': 'application/json',
              'Connection': 'close',
              'User-Agent': 'TalkReady-Mobile/1.0',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        _logger.i('Enhanced Azure evaluation complete');

        if (result['success'] == true) {
          return result;
        } else {
          _logger.e('Azure API returned success=false: ${result['error']}');
        }
      } else {
        _logger.e(
          'Azure API HTTP error ${response.statusCode}: ${response.body}',
        );
      }
      return null;
    } catch (e) {
      _logger.e('Error in enhanced Azure evaluation: $e');
      return null;
    }
  }

  bool _isModuleUnlocked(
    String moduleId,
    Map<String, dynamic> lessonAttempts,
    Map<String, dynamic> assessmentAttempts,
  ) {
    if (moduleId == 'module1') return true;

    int moduleNum = int.tryParse(moduleId.replaceAll('module', '')) ?? 1;
    String prevModuleId = 'module${moduleNum - 1}';

    final prevModuleLessons = webLessonStructure[prevModuleId] ?? [];
    bool prevLessonsComplete = prevModuleLessons.every((lessonId) {
      final attempts = lessonAttempts[lessonId] as List<dynamic>? ?? [];
      return attempts.isNotEmpty;
    });

    bool prevAssessmentTaken = true;
    final prevAssessmentId = moduleAssessments[prevModuleId];
    if (prevAssessmentId != null) {
      final attempts =
          assessmentAttempts[prevAssessmentId] as List<dynamic>? ?? [];
      prevAssessmentTaken = attempts.isNotEmpty;
    }

    return prevLessonsComplete && prevAssessmentTaken;
  }

  Future<List<Map<String, dynamic>>> getLessonAttempts(String lessonId) async {
    final progress = await getUserProgress();
    final lessonAttempts =
        progress['lessonAttempts'] as Map<String, dynamic>? ?? {};

    final attempts = lessonAttempts[lessonId] as List<dynamic>? ?? [];

    return attempts.map((attempt) {
      if (attempt is Map<String, dynamic>) {
        final result = Map<String, dynamic>.from(attempt);
        if (result['attemptTimestamp'] is Timestamp) {
          result['attemptTimestamp'] = (result['attemptTimestamp'] as Timestamp)
              .toDate();
        }
        return result;
      }
      return <String, dynamic>{};
    }).toList();
  }

  Future<bool> isPreAssessmentCompleted(String lessonId) async {
    final progress = await getUserProgress();
    final preAssessments =
        progress['preAssessmentsCompleted'] as Map<String, dynamic>? ?? {};
    return preAssessments[lessonId] == true;
  }

  Future<bool> testConnection() async {
    try {
      final baseUrl = await _getApiBaseUrl();
      final response = await http
          .get(
            Uri.parse('$baseUrl/health'),
            headers: {'User-Agent': 'TalkReady-Mobile/1.0'},
          )
          .timeout(const Duration(seconds: 30));

      _logger.i('Connection test: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      _logger.e('Connection test failed: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> getCourseProgress() async {
    Map<String, dynamic> courseProgress = {};

    for (String moduleId in webLessonStructure.keys) {
      final moduleProgress = await getModuleProgress(moduleId);
      courseProgress[moduleId] = moduleProgress;
    }

    return courseProgress;
  }
}
