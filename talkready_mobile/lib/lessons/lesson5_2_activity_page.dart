// lib/lessons/lesson5_2_activity_page.dart
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';
import 'dart:typed_data';
import '../services/unified_progress_service.dart';
import 'package:record/record.dart';
import 'package:firebase_storage/firebase_storage.dart';

class Lesson5_2ActivityPage extends StatefulWidget {
  final String lessonId;
  final String lessonTitle;
  final Map<String, dynamic> lessonData;
  final int attemptNumber;

  const Lesson5_2ActivityPage({
    super.key,
    required this.lessonId,
    required this.lessonTitle,
    required this.lessonData,
    required this.attemptNumber,
  });

  @override
  State<Lesson5_2ActivityPage> createState() => _Lesson5_2ActivityPageState();
}

class _Lesson5_2ActivityPageState extends State<Lesson5_2ActivityPage> {
  final Logger _logger = Logger();
  final UnifiedProgressService _progressService = UnifiedProgressService();
  PermissionStatus _permissionStatus = PermissionStatus.denied;

  // Speech Recognition & TTS
  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;
  bool _isListening = false;
  bool _speechEnabled = false;
  String _currentTranscript = '';

  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;

  // Call Simulation State
  int _currentTurnIndex = 0;
  bool _isCallActive = false;
  bool _showFinalSummary = false;
  bool _isProcessingAudio = false;
  bool _isFetchingOpenAIExplanation = false;
  Timer? _callTimer;
  int _callDuration = 0;

  // Turn data structure
  Map<String, Map<String, dynamic>> _turnData = {};

  // Lesson state
  int _currentAttemptNumberForLesson = 0;
  double? _overallLessonScore;
  final int _initialTime = 900;
  int _timer = 900;
  bool _timerActive = false;
  Map<String, String> _responses = {};
  bool _reflectionSubmitted = false;
  bool _isLoadingCustomerAudio = false;
  bool _isSubmittingLesson = false;

  // HARDCODED DATA FOR LESSON 5.2 - ACTION CONFIRMATION SCENARIO
  // HARDCODED DATA FOR LESSON 5.2 - ACTION CONFIRMATION SCENARIO
  final List<Map<String, dynamic>> _simulationTurns = [
    {
      'id': 'turn1_customer',
      'text':
          'Hi, I made a payment online a little while ago, and I\'m not sure it went through. My internet connection was a bit spotty. Can you check for order TR-5839-2025?',
      'character': 'Customer',
      'voice': 'US English Female',
    },
    {
      'id': 'turn2_agent',
      'text':
          'Hello! I can certainly check on that for you. To pull up the details for order TR-5839-2025, could I please have the email address associated with the account?',
      'character': 'Agent - Your Turn',
      'callPhase': 'Information Verification',
    },
    {
      'id': 'turn3_customer',
      'text':
          'Sure, it\'s sarah.mitchell@email.com. And while you\'re checking, can you also tell me when the item is expected to ship?',
      'character': 'Customer',
      'voice': 'US English Female',
    },
    {
      'id': 'turn4_agent',
      'text':
          'Thank you, I\'ve found it. Yes, I can confirm your payment was successful. Regarding shipping, it\'s scheduled to go out by tomorrow afternoon. You\'ll receive a tracking number then.',
      'character': 'Agent - Your Turn',
      'callPhase': 'Action Confirmation',
    },
    {
      'id': 'turn5_customer',
      'text': 'Oh, that\'s all. Thank you for your help!',
      'character': 'Customer',
      'voice': 'US English Female',
    },
    {
      'id': 'turn6_agent',
      'text':
          'You\'re very welcome! Have a wonderful day, and thank you for calling.',
      'character': 'Agent - Your Turn',
      'callPhase': 'Action Completion',
    },
  ];

  final List<Map<String, dynamic>> _reflectionQuestions = [
    {
      'id': 'reflection1',
      'text':
          'How confident did you feel when making the confirmation statement? What made it feel natural or challenging?',
    },
    {
      'id': 'reflection2',
      'text':
          'Which part of the confirmation process felt the most important for customer satisfaction?',
    },
    {
      'id': 'reflection3',
      'text':
          'What would you focus on improving in your next confirmation practice session?',
    },
  ];

  @override
  void initState() {
    super.initState();
    _currentAttemptNumberForLesson = widget.attemptNumber;
    _checkPermissionsAndInitialize();
  }

  Future<void> _checkPermissionsAndInitialize() async {
    final status = await Permission.microphone.request();
    if (mounted) {
      setState(() {
        _permissionStatus = status;
      });
    }
  }

  Future<void> _startRecording() async {
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission is required.')),
        );
        return;
      }

      if (await _audioRecorder.isRecording()) return;

      final tempDir = await getTemporaryDirectory();
      final filePath =
          '${tempDir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';

      setState(() => _isRecording = true);

      await _audioRecorder.start(const RecordConfig(), path: filePath);
      _logger.i('Started recording to: $filePath');
    } catch (e) {
      _logger.e('Error starting recording: $e');
      if (mounted) {
        setState(() => _isRecording = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start recording: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    if (!await _audioRecorder.isRecording()) return;

    final recordingPath = await _audioRecorder.stop();
    setState(() => _isRecording = false);

    if (recordingPath != null) {
      _logger.i('Recording stopped. File at: $recordingPath');
      _processUserResponseWithAI(recordingPath);
    } else {
      _logger.w('Recording path is null after stopping.');
    }
  }

  Future<void> _playCustomerTurnAudio(String textToSpeak) async {
    if (_isLoadingCustomerAudio || textToSpeak.isEmpty) return;

    setState(() => _isLoadingCustomerAudio = true);

    try {
      final audioBytes = await _progressService.synthesizeSpeech(textToSpeak);

      if (audioBytes != null) {
        final tempDir = await getTemporaryDirectory();
        final audioFile = File(
          '${tempDir.path}/customer_audio_${DateTime.now().millisecondsSinceEpoch}.mp3',
        );
        await audioFile.writeAsBytes(audioBytes);

        final player = AudioPlayer();
        await player.play(DeviceFileSource(audioFile.path));

        player.onPlayerComplete.listen((_) {
          audioFile.delete().catchError((e) => print('Cleanup error: $e'));
          player.dispose();
        });
      } else {
        throw Exception('Failed to synthesize audio');
      }
    } catch (error) {
      _logger.e("Error playing customer audio: $error");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not play customer audio")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingCustomerAudio = false);
      }
    }
  }

  Future<void> _processUserResponseWithAI(String audioFilePath) async {
    final currentTurn = _simulationTurns[_currentTurnIndex];
    final turnId = currentTurn['id'];
    final expectedText = currentTurn['text'];

    setState(() {
      _isProcessingAudio = true;
      _turnData[turnId] = {'isAnalyzing': true};
    });

    try {
      // 1. Upload audio to get URL
      final audioUrl = await _uploadAudioFile(audioFilePath);
      if (audioUrl == null) throw Exception('Failed to upload audio file.');

      // 2. Get Azure speech analysis
      final azureResult = await _progressService.evaluateAzureSpeech(
        audioUrl,
        expectedText,
      );
      if (azureResult == null || azureResult['success'] != true) {
        throw Exception(azureResult?['error'] ?? 'Azure analysis failed.');
      }

      final recognizedText =
          azureResult['textRecognized'] ?? 'No transcription available.';
      setState(() {
        _turnData[turnId]?['transcription'] = recognizedText;
        _turnData[turnId]?['azureFeedback'] = azureResult;
        _isFetchingOpenAIExplanation = true;
      });

      // 3. Build the conversation history for AI context
      final conversationHistory = _buildConversationHistory(recognizedText);

      // 4. Build the scenario object for confirmation context
      final scenarioData = {
        'title': 'Call Center Action Confirmation',
        'briefing': {
          'role': 'Customer Service Agent',
          'company': 'TalkReady Customer Service',
          'caller': 'Customer requiring action confirmation',
          'situation':
              currentTurn['callPhase'] ?? 'Action confirmation interaction',
        },
      };

      // 5. Get AI Coach feedback with confirmation context
      final aiCoachResult = await _progressService.getAiCallFeedback(
        transcript: conversationHistory,
        scenario: scenarioData,
      );

      // 6. Update state with all the feedback
      if (mounted) {
        setState(() {
          _turnData[turnId]?['isProcessed'] = true;
          _turnData[turnId]?['isAnalyzing'] = false;
          _turnData[turnId]?['aiCoachFeedback'] = aiCoachResult;
          _turnData[turnId]?['audioUrl'] = audioUrl;
          _turnData[turnId]?['detailedFeedback'] =
              _generateEnhancedDetailedFeedback(
                azureResult,
                aiCoachResult,
                recognizedText,
              );
        });
      }
    } catch (error) {
      _logger.e('Error processing speech for turn $turnId: $error');
      if (mounted) {
        setState(() {
          _turnData[turnId]?['isProcessed'] = true;
          _turnData[turnId]?['isAnalyzing'] = false;
          _turnData[turnId]?['error'] =
              'Failed to get AI analysis. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingAudio = false;
          _isFetchingOpenAIExplanation = false;
        });
      }
    }
  }

  Future<String?> _uploadAudioFile(String filePath) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final file = File(filePath);
    if (!file.existsSync()) return null;

    final storagePath =
        'lesson_5_2_audio/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.m4a';
    final storageRef = FirebaseStorage.instance.ref().child(storagePath);

    try {
      final uploadTask = await storageRef.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      _logger.e('Error uploading audio to Firebase Storage: $e');
      return null;
    }
  }

  List<Map<String, String>> _buildConversationHistory(
    String currentTranscript,
  ) {
    final history = <Map<String, String>>[];

    for (int i = 0; i <= _currentTurnIndex; i++) {
      final turn = _simulationTurns[i];
      if (turn['character'] == 'Customer') {
        history.add({'speaker': 'Customer', 'text': turn['text']});
      } else if (turn['character'] == 'Agent - Your Turn') {
        if (i == _currentTurnIndex) {
          history.add({'speaker': 'Agent', 'text': currentTranscript});
        } else {
          final turnData = _turnData[turn['id']];
          if (turnData?['transcription'] != null) {
            history.add({
              'speaker': 'Agent',
              'text': turnData!['transcription'],
            });
          }
        }
      }
    }

    return history;
  }

  Map<String, dynamic> _generateEnhancedDetailedFeedback(
    Map<String, dynamic>? azureResult,
    Map<String, dynamic>? aiResult,
    String transcript,
  ) {
    final criteria = aiResult?['criteria'] as List<dynamic>? ?? [];
    _debugAICriteria(aiResult);

    // ✅ FIXED: Safe conversion for all metrics with proper type handling
    final serviceMetrics = <String, dynamic>{};

    serviceMetrics['clarity'] = _extractMetricScore(criteria, 'Clarity');
    serviceMetrics['accuracyVerification'] = _extractMetricScore(
      criteria,
      'Accuracy Verification',
    );
    serviceMetrics['directness'] = _extractMetricScore(criteria, 'Directness');
    serviceMetrics['professionalism'] = _extractMetricScore(
      criteria,
      'Professionalism',
    );
    serviceMetrics['completeness'] = _extractMetricScore(
      criteria,
      'Completeness',
    );

    // ✅ FIXED: Safe type conversion for Azure results
    final speechQuality = {
      'accuracyScore': _safeToDouble(azureResult?['accuracyScore']),
      'fluencyScore': _safeToDouble(azureResult?['fluencyScore']),
      'completenessScore': _safeToDouble(azureResult?['completenessScore']),
      'prosodyScore': _safeToDouble(azureResult?['prosodyScore']),
    };

    // ✅ FIXED: Safe type conversion for prosody metrics
    final enhancedProsodyMetrics = {
      'speechRate': _calculateSpeechRate(
        _safeToDouble(azureResult?['fluencyScore']),
      ),
      'pausePatterns': _calculatePausePatterns(
        _safeToDouble(azureResult?['prosodyScore']),
      ),
      'professionalTone': _calculateProfessionalTone(azureResult),
      'prosodyAnalysis': _generateProsodyAnalysis(azureResult),
    };

    // ✅ FIXED: Safe type conversion for word analysis
    final words = azureResult?['words'] as List<dynamic>? ?? [];
    final wordAnalysis = {
      'totalWords': words.length,
      'clearToCustomer': words
          .where((w) => _safeToDouble(w['accuracyScore']) >= 95)
          .map((w) => w['word'])
          .toList(),
      'practiceNeeded': words
          .where(
            (w) =>
                _safeToDouble(w['accuracyScore']) >= 82 &&
                _safeToDouble(w['accuracyScore']) < 95,
          )
          .map((w) => w['word'])
          .toList(),
      'mayConfuseCustomer': words
          .where((w) => _safeToDouble(w['accuracyScore']) < 82)
          .map((w) => w['word'])
          .toList(),
      'wordByWordDetails': words,
    };

    // ✅ FIXED: Safe type conversion for speech quality analysis
    final speechQualityAnalysis = {
      'overallScore': _calculateSpeechQualityScore(azureResult),
      'pronunciationClarity': _safeToDouble(azureResult?['accuracyScore']),
      'speechFlow': _normalizeFluencyScore(
        _safeToDouble(azureResult?['fluencyScore']),
      ),
      'assessment': _generateSpeechAssessment(
        _calculateSpeechQualityScore(azureResult),
      ),
    };

    return {
      'speechQuality': speechQuality,
      'serviceMetrics': serviceMetrics,
      'enhancedProsodyMetrics': enhancedProsodyMetrics,
      'wordAnalysis': wordAnalysis,
      'speechQualityAnalysis': speechQualityAnalysis,
      'aiCoachAnalysis': aiResult,
    };
  }

  // ✅ ADD: Helper method for safe type conversion
  double _safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed ?? 0.0;
    }
    return 0.0;
  }

  double _extractMetricScore(List<dynamic> criteria, String metricName) {
    // Create a mapping between UI metric names and actual AI criteria names
    final metricMapping = {
      'Clarity': ['Communication Clarity'],
      'Accuracy Verification': [
        'Customer Service Excellence',
        'Problem Solving Approach',
      ],
      'Directness': ['Communication Clarity', 'Problem Solving Approach'],
      'Professionalism': ['Professional Demeanor'],
      'Completeness': [
        'Customer Service Excellence',
        'Problem Solving Approach',
      ],
    };

    // Get possible AI criteria names for this UI metric
    final possibleMatches = metricMapping[metricName] ?? [metricName];

    double bestScore = 0.0;
    bool found = false;

    // Try to find a match from the possible criteria
    for (final possibleMatch in possibleMatches) {
      final metric = criteria.firstWhere(
        (c) => (c['name'] as String? ?? '').toLowerCase().contains(
          possibleMatch.toLowerCase(),
        ),
        orElse: () => null,
      );

      if (metric != null) {
        // ✅ FIXED: Safe type conversion for score
        final score = _safeToDouble(metric['score']);
        if (score > bestScore) {
          bestScore = score;
          found = true;
        }
      }
    }

    // If still no match, try partial matching with the original name
    if (!found) {
      final metric = criteria.firstWhere(
        (c) => (c['name'] as String? ?? '').toLowerCase().contains(
          metricName.toLowerCase(),
        ),
        orElse: () => null,
      );

      if (metric != null) {
        bestScore = _safeToDouble(metric['score']);
        found = true;
      }
    }

    // Add debug logging
    if (found) {
      _logger.i('✅ Mapped "$metricName" to score: $bestScore');
    } else {
      _logger.w('❌ Could not find metric: $metricName');
      _logger.w(
        'Available criteria: ${criteria.map((c) => c['name']).toList()}',
      );
    }

    return bestScore;
  }

  String _calculateSpeechRate(double fluencyScore) {
    final baseWPM = 145;
    final normalizedFluency = fluencyScore > 5
        ? fluencyScore / 20
        : fluencyScore;
    final adjustment = (normalizedFluency - 3) * 8;
    final estimatedWPM = (baseWPM + adjustment).clamp(120, 180);
    return '${estimatedWPM.round()} WPM';
  }

  double _calculatePausePatterns(double prosodyScore) {
    final normalizedProsody = prosodyScore > 5
        ? prosodyScore / 20
        : prosodyScore;
    return ((normalizedProsody / 5) * 100).clamp(0.0, 100.0);
  }

  double _calculateProfessionalTone(Map<String, dynamic>? azureResult) {
    if (azureResult == null) return 70.0;

    final accuracy = (azureResult['accuracyScore'] as num?)?.toDouble() ?? 0.0;
    final prosody = (azureResult['prosodyScore'] as num?)?.toDouble() ?? 0.0;
    final fluency = (azureResult['fluencyScore'] as num?)?.toDouble() ?? 0.0;

    final normalizedProsody = prosody > 5 ? prosody : (prosody / 5) * 100;
    final normalizedFluency = fluency > 5 ? fluency : (fluency / 5) * 100;

    return ((accuracy * 0.4) +
            (normalizedProsody * 0.3) +
            (normalizedFluency * 0.3))
        .clamp(0.0, 100.0);
  }

  String _generateProsodyAnalysis(Map<String, dynamic>? azureResult) {
    if (azureResult == null)
      return 'Continue practicing for more natural confirmation delivery.';

    final fluency = (azureResult['fluencyScore'] as num?)?.toDouble() ?? 0.0;
    final prosody = (azureResult['prosodyScore'] as num?)?.toDouble() ?? 0.0;

    final normalizedFluency = fluency > 5 ? fluency / 20 : fluency;
    final normalizedProsody = prosody > 5 ? prosody / 20 : prosody;

    List<String> insights = [];

    if (normalizedFluency >= 4) {
      insights.add('Your speech flows smoothly for clear confirmations');
    } else if (normalizedFluency >= 3) {
      insights.add('Good confirmation rhythm with room for improvement');
    } else {
      insights.add('Focus on smoother delivery for customer confidence');
    }

    if (normalizedProsody >= 4) {
      insights.add('Natural tone builds customer trust');
    } else if (normalizedProsody >= 3) {
      insights.add('Appropriate tone for confirmation calls');
    } else {
      insights.add('Work on more confident, reassuring speech patterns');
    }

    return insights.isNotEmpty
        ? insights.join('. ') + '.'
        : 'Continue practicing for more natural confirmation delivery.';
  }

  double _calculateSpeechQualityScore(Map<String, dynamic>? azureResult) {
    if (azureResult == null) return 70.0;

    final accuracy = (azureResult['accuracyScore'] as num?)?.toDouble() ?? 0.0;
    final fluency = _normalizeFluencyScore(
      (azureResult['fluencyScore'] as num?)?.toDouble() ?? 0.0,
    );
    final completeness =
        (azureResult['completenessScore'] as num?)?.toDouble() ?? 0.0;
    final prosody = _normalizeFluencyScore(
      (azureResult['prosodyScore'] as num?)?.toDouble() ?? 0.0,
    );

    return ((accuracy * 0.4) +
            (fluency * 0.3) +
            (completeness * 0.2) +
            (prosody * 0.1))
        .clamp(0.0, 100.0);
  }

  double _normalizeFluencyScore(double score) {
    return score > 5 ? score : (score / 5) * 100;
  }

  String _generateSpeechAssessment(double score) {
    if (score >= 90)
      return 'Excellent speech quality! Your pronunciation and delivery are very clear and professional.';
    if (score >= 80)
      return 'Very good speech quality. Minor improvements in pronunciation or flow could make it even better.';
    if (score >= 70)
      return 'Good speech quality. Focus on practicing pronunciation clarity and smooth delivery.';
    if (score >= 60)
      return 'Developing speech skills. Continue practicing pronunciation and speaking pace.';
    return 'Keep practicing your speech delivery. Focus on clear pronunciation and steady pace.';
  }

  void _startCallSimulation() {
    setState(() {
      _isCallActive = true;
      _currentTurnIndex = 0;
      _callDuration = 0;
      _turnData.clear();
      _showFinalSummary = false;
      _timer = _initialTime;
      _timerActive = true;
      _currentAttemptNumberForLesson = widget.attemptNumber + 1;
    });

    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _callDuration++;
        _timer--;
        if (_timer <= 0) {
          _timer = 0;
          _timerActive = false;
          _endCall();
        }
      });
    });

    if (_simulationTurns.isNotEmpty &&
        _simulationTurns[0]['character'] == 'Customer') {
      _playCustomerTurnAudio(_simulationTurns[0]['text']);
    }
  }

  void _nextTurn() {
    if (_currentTurnIndex >= _simulationTurns.length - 1) {
      _endCall();
      return;
    }

    setState(() => _currentTurnIndex++);

    final nextTurn = _simulationTurns[_currentTurnIndex];
    if (nextTurn['character'] == 'Customer') {
      _playCustomerTurnAudio(nextTurn['text']);
    }
  }

  void _endCall() {
    _callTimer?.cancel();
    setState(() {
      _isCallActive = false;
      _timerActive = false;
    });

    _calculateAndSaveLessonScore();
  }

  Future<void> _calculateAndSaveLessonScore() async {
    if (_isSubmittingLesson) return;
    setState(() => _isSubmittingLesson = true);

    double totalScore = 0;
    int agentTurnsProcessed = 0;

    _debugTurnData();

    // Calculate scores from processed turns
    for (var turn in _simulationTurns) {
      if (turn['character'] == 'Agent - Your Turn') {
        final turnData = _turnData[turn['id']];
        if (turnData?['isProcessed'] == true) {
          double turnScore = 0;

          // Try AI Coach score first (if available)
          final aiCoachFeedback =
              turnData?['aiCoachFeedback'] as Map<String, dynamic>?;
          if (aiCoachFeedback?['overallScore'] != null) {
            turnScore = (aiCoachFeedback!['overallScore'] as num).toDouble();
            _logger.i(
              'Using AI Coach score: $turnScore for turn ${turn['id']}',
            );
          } else {
            // Fallback to Azure accuracy score
            final azureFeedback =
                turnData?['azureFeedback'] as Map<String, dynamic>?;
            if (azureFeedback?['accuracyScore'] != null) {
              turnScore = (azureFeedback!['accuracyScore'] as num).toDouble();
              _logger.i(
                'Using Azure accuracy score: $turnScore for turn ${turn['id']}',
              );
            } else {
              _logger.w('No valid score found for turn ${turn['id']}');
              turnScore = 0;
            }
          }

          totalScore += turnScore;
          agentTurnsProcessed++;
          _logger.i(
            'Turn ${turn['id']}: score=$turnScore, running total=$totalScore',
          );
        } else {
          _logger.w(
            'Turn ${turn['id']} was not processed, skipping from score calculation',
          );
        }
      }
    }

    // Calculate the final average score
    final overallScore = agentTurnsProcessed > 0
        ? totalScore / agentTurnsProcessed
        : 0.0;

    _logger.i(
      'Final calculation: totalScore=$totalScore, agentTurns=$agentTurnsProcessed, average=$overallScore',
    );

    setState(() {
      _overallLessonScore = overallScore;
      _showFinalSummary = true;
    });

    try {
      await _saveProgress();
    } catch (e) {
      _logger.e('Error saving progress: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmittingLesson = false);
      }
    }
  }

  Future<void> _saveProgress() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _logger.e('No authenticated user for saving progress');
        return;
      }

      // Enhanced data structure for Lesson 5.2
      final detailedResponsesPayload = {
        'overallScore': _overallLessonScore ?? 0,
        'confirmationReadinessBreakdown': {
          'accuracy': _calculateAverageMetric('accuracyScore'),
          'fluency': _calculateAverageMetric('fluencyScore') * 20,
          'overall': _overallLessonScore ?? 0,
        },
        'timeSpent': _callDuration,
        'promptDetails': _simulationTurns.map((turn) {
          final turnData = _turnData[turn['id']];
          double? turnScore;

          if (turnData?['aiCoachFeedback']?['overallScore'] != null) {
            turnScore = (turnData!['aiCoachFeedback']['overallScore'] as num)
                .toDouble();
          } else if (turnData?['azureFeedback']?['accuracyScore'] != null) {
            turnScore = (turnData!['azureFeedback']['accuracyScore'] as num)
                .toDouble();
          }

          return {
            'id': turn['id'],
            'text': turn['text'],
            'character': turn['character'],
            'callPhase': turn['callPhase'],
            'audioUrl': turnData?['audioUrl'],
            'transcription':
                turnData?['transcription'] ?? '(No transcription available)',
            'score': turnScore,
            'azureAiFeedback': turnData?['azureFeedback'],
            'openAiDetailedFeedback': turnData?['aiCoachFeedback'],
            'enhancedMetrics': turnData?['detailedFeedback'],
          };
        }).toList(),
        'reflections': _responses,
      };

      // Save to Firebase with same structure as web
      final userProgressRef = FirebaseFirestore.instance
          .collection('userProgress')
          .doc(user.uid);

      final docSnap = await userProgressRef.get();
      Map<String, dynamic> existingData = {};
      if (docSnap.exists) {
        existingData = docSnap.data() as Map<String, dynamic>;
      }

      Map<String, dynamic> lessonAttemptsMap = Map<String, dynamic>.from(
        existingData['lessonAttempts'] ?? {},
      );

      if (lessonAttemptsMap[widget.lessonId] == null) {
        lessonAttemptsMap[widget.lessonId] = <Map<String, dynamic>>[];
      }

      List<dynamic> currentAttempts = List<dynamic>.from(
        lessonAttemptsMap[widget.lessonId],
      );

      final newAttemptData = {
        'score': _overallLessonScore ?? 0,
        'attemptNumber': currentAttempts.length + 1,
        'lessonId': widget.lessonId,
        'detailedResponses': detailedResponsesPayload,
        'attemptTimestamp': Timestamp.now(),
        'timeSpent': _callDuration,
      };

      currentAttempts.add(newAttemptData);
      lessonAttemptsMap[widget.lessonId] = currentAttempts;

      await userProgressRef.set({
        'lessonAttempts': lessonAttemptsMap,
        'lastActivityTimestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _logger.i(
        'Progress saved successfully for ${widget.lessonId}. Score: ${_overallLessonScore}',
      );
    } catch (e) {
      _logger.e('Error saving progress: $e');
      rethrow;
    }
  }

  void _debugTurnData() {
    _logger.i('=== DEBUG TURN DATA for Lesson 5.2 ===');
    for (var turn in _simulationTurns) {
      if (turn['character'] == 'Agent - Your Turn') {
        final turnData = _turnData[turn['id']];
        _logger.i('Turn ${turn['id']}:');
        _logger.i('  - isProcessed: ${turnData?['isProcessed']}');
        _logger.i(
          '  - aiCoachFeedback exists: ${turnData?['aiCoachFeedback'] != null}',
        );
        _logger.i(
          '  - aiCoachFeedback overallScore: ${turnData?['aiCoachFeedback']?['overallScore']}',
        );
        _logger.i(
          '  - azureFeedback exists: ${turnData?['azureFeedback'] != null}',
        );
        _logger.i(
          '  - azureFeedback accuracyScore: ${turnData?['azureFeedback']?['accuracyScore']}',
        );
      }
    }
    _logger.i('=== END DEBUG ===');
  }

  double _calculateAverageMetric(String metricKey) {
    double total = 0;
    int count = 0;

    for (var turn in _simulationTurns) {
      if (turn['character'] == 'Agent - Your Turn') {
        final turnData = _turnData[turn['id']];
        final azureFeedback =
            turnData?['azureFeedback'] as Map<String, dynamic>?;
        if (azureFeedback?[metricKey] != null) {
          total += (azureFeedback![metricKey] as num).toDouble();
          count++;
        }
      }
    }

    return count > 0 ? total / count : 0.0;
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5F3),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFD32F2F), Color(0xFFB71C1C)],
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Module 5: Basic Call Simulation Practice',
                    style: TextStyle(
                      fontSize: MediaQuery.of(context).size.width < 350
                          ? 20
                          : 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: const [
                        Shadow(
                          offset: Offset(1.0, 1.0),
                          blurRadius: 2.0,
                          color: Colors.black26,
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Lesson 5.2: Basic Simulation - Action Confirmation',
                    style: TextStyle(
                      fontSize: MediaQuery.of(context).size.width < 350
                          ? 16
                          : 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      shadows: const [
                        Shadow(
                          offset: Offset(1.0, 1.0),
                          blurRadius: 2.0,
                          color: Colors.black26,
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Content Area
            Expanded(child: _buildContent()),

            // Footer Link
            Container(
              padding: const EdgeInsets.all(16),
              child: TextButton(
                onPressed: () {
                  if (_isCallActive) {
                    _showExitConfirmationDialog();
                  } else {
                    Navigator.pop(context);
                  }
                },
                child: const Text(
                  'Back to Module 5 Overview',
                  style: TextStyle(color: Colors.indigo, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showExitConfirmationDialog() async {
    final bool? shouldPop = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Are you sure?'),
          content: const Text(
            'Leaving now will end your current simulation attempt. Your progress for this attempt will not be saved.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('Leave'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (shouldPop == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  Widget _buildContent() {
    if (_showFinalSummary) {
      return _buildFinalSummary();
    } else if (_isCallActive) {
      return _buildCallSimulation();
    } else {
      return _buildIntroduction();
    }
  }

  Widget _buildIntroduction() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text(
            'Welcome to Advanced Call Simulation Practice',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Scenario: Customer Action Confirmation',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'You will handle a call where you need to confirm and process a customer\'s request to update their shipping address. Practice clear confirmation techniques and professional follow-through.',
                  style: TextStyle(fontSize: 16, height: 1.4),
                ),
                SizedBox(height: 20),
                Text(
                  'Advanced Instructions:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text(
                  '• Listen carefully to each customer message\n'
                  '• Record your professional confirmation responses\n'
                  '• Ensure clarity and accuracy in your confirmations\n'
                  '• Speak with confidence and professional authority\n'
                  '• Follow natural conversation flow for action confirmations',
                  style: TextStyle(fontSize: 14, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                if (_permissionStatus.isGranted) {
                  _startCallSimulation();
                } else if (_permissionStatus.isPermanentlyDenied) {
                  openAppSettings();
                } else {
                  _checkPermissionsAndInitialize();
                }
              },
              icon: Icon(
                _permissionStatus.isGranted ? Icons.play_arrow : Icons.mic_off,
              ),
              label: Text(
                _permissionStatus.isGranted
                    ? 'Start Advanced Call Simulation'
                    : _permissionStatus.isPermanentlyDenied
                    ? 'Open Settings to Grant Permission'
                    : 'Grant Microphone Permission',
                textAlign: TextAlign.center,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _permissionStatus.isGranted
                    ? Colors.red
                    : Colors.grey[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallSimulation() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Advanced Call Simulation Attempt $_currentAttemptNumberForLesson',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        _formatDuration(_callDuration),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Current Turn Display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    _simulationTurns[_currentTurnIndex]['character'] ==
                        'Customer'
                    ? const Color(0xFFE3F2FD)
                    : const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color:
                      _simulationTurns[_currentTurnIndex]['character'] ==
                          'Customer'
                      ? Colors.blue
                      : Colors.red,
                  width: 3,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _simulationTurns[_currentTurnIndex]['character'],
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color:
                          _simulationTurns[_currentTurnIndex]['character'] ==
                              'Customer'
                          ? Colors.blue[800]
                          : Colors.red[800],
                    ),
                  ),
                  if (_simulationTurns[_currentTurnIndex]['callPhase'] !=
                      null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Text(
                        _simulationTurns[_currentTurnIndex]['callPhase'],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '"${_simulationTurns[_currentTurnIndex]['text']}"',
                    style: TextStyle(
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Controls
            if (_simulationTurns[_currentTurnIndex]['character'] == 'Customer')
              _buildCustomerTurnControls()
            else
              _buildAgentTurnControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerTurnControls() {
    return Column(
      children: [
        const SizedBox(height: 20),

        // Replay Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isLoadingCustomerAudio
                ? null
                : () => _playCustomerTurnAudio(
                    _simulationTurns[_currentTurnIndex]['text'],
                  ),
            icon: _isLoadingCustomerAudio
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.volume_up),
            label: Text(
              _isLoadingCustomerAudio ? 'Loading...' : 'Replay Customer Audio',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Next Turn Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _nextTurn,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Next Turn',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAgentTurnControls() {
    final turnData = _turnData[_simulationTurns[_currentTurnIndex]['id']] ?? {};
    final isAnalyzing = turnData['isAnalyzing'] == true;
    final isProcessed = turnData['isProcessed'] == true;
    final detailedFeedback = turnData['detailedFeedback'];
    final transcript = turnData['transcription'] as String?;

    return Column(
      children: [
        // Your Response Label
        Row(
          children: [
            const Icon(Icons.mic, color: Colors.red, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Your Response (${_currentTurnIndex ~/ 2 + 1}/${(_simulationTurns.length / 2).ceil()}):',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Analysis Processing Indicator
        if (isAnalyzing) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red[200]!),
            ),
            child: const Column(
              children: [
                CircularProgressIndicator(color: Colors.red),
                SizedBox(height: 16),
                Text(
                  'Analyzing your confirmation speech...',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Please wait a moment.',
                  style: TextStyle(color: Colors.red),
                ),
              ],
            ),
          ),
        ]
        // Enhanced Detailed Feedback Display
        else if (isProcessed && detailedFeedback != null) ...[
          _buildTranscriptionDisplay(transcript),
          _buildEnhancedDetailedFeedbackSection(detailedFeedback),
          _buildNextTurnButton(),
        ]
        // Recording Controls
        else ...[
          // Record Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isRecording ? _stopRecording : _startRecording,
              icon: Icon(_isRecording ? Icons.stop : Icons.mic),
              label: Text(
                _isRecording ? 'Stop Recording' : 'Record My Response',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isRecording ? Colors.red : Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTranscriptionDisplay(String? transcript) {
    if (transcript == null || transcript.isEmpty)
      return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What the system heard:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black54,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '"$transcript"',
            style: TextStyle(
              fontSize: 16,
              fontStyle: FontStyle.italic,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedDetailedFeedbackSection(Map<String, dynamic> feedback) {
    return DefaultTabController(
      length: 5, // Increased from 4 to 5 for the new tabs
      child: Column(
        children: [
          Container(
            height: 45,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: TabBar(
              labelColor: Colors.white,
              unselectedLabelColor: Colors.black,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: const Color(0xFFD32F2F), // Red color for Lesson 5.2
              ),
              tabs: const [
                Tab(
                  child: Text('Speech Quality', style: TextStyle(fontSize: 11)),
                ),
                Tab(child: Text('Prosody', style: TextStyle(fontSize: 11))),
                Tab(child: Text('Words', style: TextStyle(fontSize: 11))),
                Tab(child: Text('Service', style: TextStyle(fontSize: 11))),
                Tab(child: Text('AI Coach', style: TextStyle(fontSize: 11))),
              ],
            ),
          ),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: TabBarView(
              children: [
                _buildSpeechQualityTab(feedback['speechQualityAnalysis']),
                _buildEnhancedProsodyTab(feedback['enhancedProsodyMetrics']),
                _buildWordAnalysisTab(feedback['wordAnalysis']),
                _buildServiceMetricsTab(feedback['serviceMetrics']),
                _buildAICoachTab(feedback['aiCoachAnalysis']),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeechQualityTab(Map<String, dynamic>? speechQuality) {
    if (speechQuality == null) {
      return const Center(child: Text('Speech Quality data unavailable.'));
    }

    final overallScore =
        (speechQuality['overallScore'] as num?)?.toDouble() ?? 0.0;
    final pronunciationClarity =
        (speechQuality['pronunciationClarity'] as num?)?.toDouble() ?? 0.0;
    final speechFlow = (speechQuality['speechFlow'] as num?)?.toDouble() ?? 0.0;
    final assessment = speechQuality['assessment'] as String? ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Overall Speech Quality Score
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade50, Colors.blue.shade100],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              children: [
                const Text(
                  'Speech Quality Score',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.blue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${overallScore.round()}%',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: _getScoreColor(overallScore),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Based on pronunciation, fluency, and delivery',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: (overallScore / 100).clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _getScoreColor(overallScore),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Speech Assessment
          if (assessment.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Speech Assessment:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    assessment,
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 20),

          // Key Speech Metrics
          const Text(
            'Key Speech Metrics',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildKeyMetricCard(
                  'Pronunciation Clarity',
                  '${pronunciationClarity.round()}%',
                  'How clearly each word was pronounced',
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildKeyMetricCard(
                  'Speech Flow',
                  '${speechFlow.round()}%',
                  'Smoothness and naturalness of delivery',
                  Colors.blue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKeyMetricCard(
    String title,
    String value,
    String description,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: 0.9, // Adjust based on actual score
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedProsodyTab(Map<String, dynamic>? prosodyMetrics) {
    if (prosodyMetrics == null) {
      return const Center(child: Text('Enhanced Prosody data unavailable.'));
    }

    final speechRate = prosodyMetrics['speechRate'] as String? ?? '145 WPM';
    final pausePatterns =
        (prosodyMetrics['pausePatterns'] as num?)?.toDouble() ?? 0.0;
    final professionalTone =
        (prosodyMetrics['professionalTone'] as num?)?.toDouble() ?? 0.0;
    final prosodyAnalysis = prosodyMetrics['prosodyAnalysis'] as String? ?? '';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Enhanced Prosody Metrics Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.purple.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.music_note, color: Colors.purple, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Enhanced Prosody Metrics',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Three key metrics in a row
              Row(
                children: [
                  Expanded(
                    child: _buildProsodyMetricCard(
                      'Speech Rate',
                      speechRate,
                      'Excellent pace',
                      'Optimal: 140-160 WPM',
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildProsodyMetricCard(
                      'Pause Patterns',
                      '${pausePatterns.round()}%',
                      'Naturalness',
                      'Strategic pausing',
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildProsodyMetricCard(
                      'Professional Tone',
                      '${professionalTone.round()}%',
                      'Authority level',
                      'Customer confidence',
                      Colors.orange,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Prosody Analysis
        if (prosodyAnalysis.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.purple.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Prosody Analysis:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  prosodyAnalysis,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildProsodyMetricCard(
    String title,
    String value,
    String status,
    String description,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            status,
            style: TextStyle(
              fontSize: 8,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(fontSize: 8, color: Colors.grey),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildWordAnalysisTab(Map<String, dynamic>? wordAnalysis) {
    if (wordAnalysis == null) {
      return const Center(child: Text('Word Analysis data unavailable.'));
    }

    final totalWords = wordAnalysis['totalWords'] as int? ?? 0;
    final clearWords = wordAnalysis['clearToCustomer'] as List<dynamic>? ?? [];
    final practiceWords =
        wordAnalysis['practiceNeeded'] as List<dynamic>? ?? [];
    final confusingWords =
        wordAnalysis['mayConfuseCustomer'] as List<dynamic>? ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Word Analysis Summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.teal.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.teal.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.text_fields, color: Colors.teal, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    // Added Flexible here
                    child: Text(
                      'Word-by-Word Analysis',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Total Words Analyzed: $totalWords',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Clear Words Section
        if (clearWords.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      // Fixed overflow here
                      child: Text(
                        'Clear to Customer (${clearWords.length} words)',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: clearWords
                      .map(
                        (word) => Chip(
                          label: Text(
                            word.toString(),
                            style: const TextStyle(fontSize: 12),
                          ),
                          backgroundColor: Colors.green.shade100,
                          side: BorderSide(color: Colors.green.shade300),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Practice Needed Section
        if (practiceWords.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange, size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      // Fixed overflow here
                      child: Text(
                        'Practice Needed (${practiceWords.length} words)',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: practiceWords
                      .map(
                        (word) => Chip(
                          label: Text(
                            word.toString(),
                            style: const TextStyle(fontSize: 12),
                          ),
                          backgroundColor: Colors.orange.shade100,
                          side: BorderSide(color: Colors.orange.shade300),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Confusing Words Section
        if (confusingWords.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.error, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      // Fixed overflow here
                      child: Text(
                        'May Confuse Customer (${confusingWords.length} words)',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: confusingWords
                      .map(
                        (word) => Chip(
                          label: Text(
                            word.toString(),
                            style: const TextStyle(fontSize: 12),
                          ),
                          backgroundColor: Colors.red.shade100,
                          side: BorderSide(color: Colors.red.shade300),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _debugAICriteria(Map<String, dynamic>? aiResult) {
    if (aiResult != null) {
      final criteria = aiResult['criteria'] as List<dynamic>? ?? [];
      _logger.i('=== AI CRITERIA DEBUG ===');
      for (var criterion in criteria) {
        _logger.i('Criterion: ${criterion['name']} = ${criterion['score']}');
      }
      _logger.i('=== END AI CRITERIA DEBUG ===');
    }
  }

  Widget _buildServiceMetricsTab(Map<String, dynamic>? serviceMetrics) {
    if (serviceMetrics == null) {
      return const Center(child: Text('Service Metrics data unavailable.'));
    }

    final clarity = (serviceMetrics['clarity'] as num?)?.toDouble() ?? 0.0;
    final accuracyVerification =
        (serviceMetrics['accuracyVerification'] as num?)?.toDouble() ?? 0.0;
    final directness =
        (serviceMetrics['directness'] as num?)?.toDouble() ?? 0.0;
    final professionalism =
        (serviceMetrics['professionalism'] as num?)?.toDouble() ?? 0.0;
    final completeness =
        (serviceMetrics['completeness'] as num?)?.toDouble() ?? 0.0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ✅ FIXED: Service Metrics Header with proper text wrapping
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ FIXED: Wrap the Row in a Flexible layout to prevent overflow
              Row(
                children: [
                  Icon(Icons.support_agent, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  // ✅ FIXED: Use Expanded to allow text to wrap and prevent overflow
                  Expanded(
                    child: Text(
                      'Call Center Service Metrics (AI-Analyzed)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                      // ✅ ADDED: Allow text to wrap to prevent overflow
                      overflow: TextOverflow.visible,
                      softWrap: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'AI-evaluated metrics for your call performance',
                style: TextStyle(fontSize: 12, color: Colors.blue),
                // ✅ ADDED: Ensure subtitle also wraps properly
                overflow: TextOverflow.visible,
                softWrap: true,
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // All 5 Service Metrics
        Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildServiceMetricCard(
                    'Clarity',
                    clarity,
                    'How clear and unambiguous your confirmation was',
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildServiceMetricCard(
                    'Accuracy Verification',
                    accuracyVerification,
                    'How well you verified customer information',
                    Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildServiceMetricCard(
                    'Directness',
                    directness,
                    'How direct and specific your confirmation was',
                    Colors.purple,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildServiceMetricCard(
                    'Professionalism',
                    professionalism,
                    'Professional tone and delivery',
                    Colors.indigo,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Single card for Completeness
            _buildServiceMetricCard(
              'Completeness',
              completeness,
              'Whether you addressed all aspects of the confirmation',
              Colors.teal,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildServiceMetricCard(
    String title,
    double score,
    String description,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${score.round()}%',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (score / 100).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildAICoachTab(Map<String, dynamic>? aiCoachAnalysis) {
    if (aiCoachAnalysis == null) {
      return const Center(child: Text('AI Coach analysis unavailable.'));
    }

    final overallScore =
        (aiCoachAnalysis['overallScore'] as num?)?.toDouble() ?? 0.0;
    final strengths = (aiCoachAnalysis['strengths'] as List<dynamic>?) ?? [];
    final improvementAreas =
        (aiCoachAnalysis['improvementAreas'] as List<dynamic>?) ?? [];
    final specificFeedback =
        aiCoachAnalysis['specificFeedback'] as String? ?? '';
    final criteria = (aiCoachAnalysis['criteria'] as List<dynamic>?) ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // AI Coach Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.indigo.shade50, Colors.indigo.shade100],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.indigo.shade200),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.psychology, color: Colors.indigo, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'AI Coach Analysis',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '${overallScore.round()}%',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: _getScoreColor(overallScore),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Overall Performance Score',
                style: TextStyle(fontSize: 14, color: Colors.indigo),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Specific Feedback
        if (specificFeedback.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.indigo.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Detailed Feedback:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  specificFeedback,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Strengths
        if (strengths.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.star, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    const Text(
                      'Strengths:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...strengths.map(
                  (strength) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '• ',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            strength.toString(),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Improvement Areas
        if (improvementAreas.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.trending_up, color: Colors.orange, size: 16),
                    const SizedBox(width: 8),
                    const Text(
                      'Areas for Improvement:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...improvementAreas.map(
                  (area) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '• ',
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            area.toString(),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Criteria Breakdown
        if (criteria.isNotEmpty) ...[
          const Text(
            'Detailed Criteria Scores:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
            ),
          ),
          const SizedBox(height: 12),
          ...criteria.map((criterion) {
            final name = criterion['name'] as String? ?? '';
            final score = (criterion['score'] as num?)?.toDouble() ?? 0.0;
            final feedback = criterion['feedback'] as String? ?? '';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        '${score.round()}%',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _getScoreColor(score),
                        ),
                      ),
                    ],
                  ),
                  if (feedback.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      feedback,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: (score / 100).clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _getScoreColor(score),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 90) return Colors.green;
    if (score >= 80) return Colors.lightGreen;
    if (score >= 70) return Colors.orange;
    if (score >= 60) return Colors.deepOrange;
    return Colors.red;
  }

  Widget _buildNextTurnButton() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _nextTurn,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Continue to Next Turn',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(width: 8),
            Icon(Icons.arrow_forward),
          ],
        ),
      ),
    );
  }

  Widget _buildFinalSummary() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Completion Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade400, Colors.green.shade600],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 48),
                const SizedBox(height: 12),
                const Text(
                  'Action Confirmation Simulation Complete!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Attempt #$_currentAttemptNumberForLesson',
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Score Display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                const Text(
                  'Your Overall Score',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '${(_overallLessonScore ?? 0).round()}%',
                  style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.bold,
                    color: _getScoreColor(_overallLessonScore ?? 0),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: ((_overallLessonScore ?? 0) / 100).clamp(
                      0.0,
                      1.0,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _getScoreColor(_overallLessonScore ?? 0),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _getScoreDescription(_overallLessonScore ?? 0),
                  style: const TextStyle(fontSize: 16, color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Call Statistics
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Call Statistics',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text(
                          _formatDuration(_callDuration),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        const Text(
                          'Call Duration',
                          style: TextStyle(fontSize: 12, color: Colors.blue),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          '${(_simulationTurns.length / 2).ceil()}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        const Text(
                          'Your Responses',
                          style: TextStyle(fontSize: 12, color: Colors.blue),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Reflection Questions
          if (!_reflectionSubmitted) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reflection Questions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Take a moment to reflect on your confirmation experience:',
                    style: TextStyle(fontSize: 14, color: Colors.orange),
                  ),
                  const SizedBox(height: 16),

                  ..._reflectionQuestions.map((question) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            question['text'],
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText: 'Your reflection...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Colors.orange,
                                ),
                              ),
                            ),
                            onChanged: (value) {
                              setState(() {
                                _responses[question['id']] = value;
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _responses.isNotEmpty
                          ? () {
                              setState(() {
                                _reflectionSubmitted = true;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Reflection saved! Great work on completing the lesson.',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Submit Reflection',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Action Buttons
          Column(
            children: [
              if (_reflectionSubmitted) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _showFinalSummary = false;
                        _isCallActive = false;
                        _reflectionSubmitted = false;
                        _responses.clear();
                        _turnData.clear();
                        _currentTurnIndex = 0;
                        _callDuration = 0;
                        _overallLessonScore = null;
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Practice Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to Module 5 Overview'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getScoreDescription(double score) {
    if (score >= 90) {
      return 'Excellent! Your confirmation skills are professional and clear.';
    } else if (score >= 80) {
      return 'Very good! Your confirmations are mostly clear and professional.';
    } else if (score >= 70) {
      return 'Good progress! Continue practicing your confirmation techniques.';
    } else if (score >= 60) {
      return 'Keep practicing! Focus on clarity and professional delivery.';
    } else {
      return 'More practice needed. Focus on clear, confident confirmations.';
    }
  }
}
