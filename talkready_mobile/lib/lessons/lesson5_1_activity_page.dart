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
import 'package:record/record.dart'; // Add this import
import 'dart:io'; // Add this import
import 'package:firebase_storage/firebase_storage.dart'; // Add this import
import 'package:permission_handler/permission_handler.dart';

class Lesson5_1ActivityPage extends StatefulWidget {
  final String lessonId;
  final String lessonTitle;
  final Map<String, dynamic> lessonData;
  final int attemptNumber;

  const Lesson5_1ActivityPage({
    super.key,
    required this.lessonId,
    required this.lessonTitle,
    required this.lessonData,
    required this.attemptNumber,
  });

  @override
  State<Lesson5_1ActivityPage> createState() => _Lesson5_1ActivityPageState();
}

class _Lesson5_1ActivityPageState extends State<Lesson5_1ActivityPage> {
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
  bool _isRecording = false; // This will now track the recording state

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

  // HARDCODED DATA TO MATCH WEB VERSION EXACTLY
  final List<Map<String, dynamic>> _simulationTurns = [
    {
      'id': 'turn1_customer',
      'text':
          'Hi, I was just calling to check on the status of my recent order.',
      'character': 'Customer',
      'voice': 'US English Female',
    },
    {
      'id': 'turn2_agent',
      'text':
          'Good morning! Thank you for calling. I can certainly check that for you. May I have your order number, please?',
      'character': 'Agent - Your Turn',
    },
    {
      'id': 'turn3_customer',
      'text': 'Sure, my order number is 784512.',
      'character': 'Customer',
      'voice': 'US English Female',
    },
    {
      'id': 'turn4_agent',
      'text':
          'Thank you. One moment while I pull that up... Okay, I see your order. It has been shipped, and the estimated delivery date is August 25th.',
      'character': 'Agent - Your Turn',
    },
    {
      'id': 'turn5_customer',
      'text': 'Oh, great! That\'s all I needed to know. Thank you.',
      'character': 'Customer',
      'voice': 'US English Female',
    },
    {
      'id': 'turn6_agent',
      'text':
          'You\'re very welcome! Is there anything else I can assist you with today?',
      'character': 'Agent - Your Turn',
    },
  ];

  final List<Map<String, dynamic>> _reflectionQuestions = [
    {
      'id': 'reflection1',
      'text':
          'Which part of the call flow felt the most challenging for you (e.g., the opening, providing the information, closing)?',
    },
    {
      'id': 'reflection2',
      'text':
          'How confident do you feel handling a similar info-request call in a real job?',
    },
    {
      'id': 'reflection3',
      'text':
          'What is one thing you would focus on improving in your next simulation practice?',
    },
  ];

  @override
  void initState() {
    super.initState();
    _currentAttemptNumberForLesson = widget.attemptNumber;
    _checkPermissionsAndInitialize();
  }

  // --- ADD THIS NEW METHOD ---
  Future<void> _checkPermissionsAndInitialize() async {
    final status = await Permission.microphone.request();
    if (mounted) {
      setState(() {
        _permissionStatus = status;
      });
    }
  }

  Future<void> _initializeServices() async {
    // No longer need to initialize TTS or speech-to-text here for the core recording logic
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

      // --- THIS IS THE FIX ---
      // 1. Get the path to a writable temporary directory.
      final tempDir = await getTemporaryDirectory();
      // 2. Create a full, valid file path.
      final filePath =
          '${tempDir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
      // --- END OF FIX ---

      setState(() => _isRecording = true);

      // 3. Use the full filePath to start recording.
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

  // This is the new stop recording method that triggers the analysis
  Future<void> _stopRecording() async {
    if (!await _audioRecorder.isRecording()) return;

    final recordingPath = await _audioRecorder.stop();
    setState(() => _isRecording = false);

    if (recordingPath != null) {
      _logger.i('Recording stopped. File at: $recordingPath');
      // The analysis process starts here!
      _processUserResponseWithAI(recordingPath);
    } else {
      _logger.w('Recording path is null after stopping.');
    }
  }

  Future<void> _initializeSpeech() async {
    _speech = stt.SpeechToText();

    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
    }

    if (status.isGranted) {
      bool available = await _speech.initialize(
        onError: (error) => _logger.e('Speech recognition error: $error'),
        onStatus: (status) {
          _logger.d('Speech recognition status: $status');
          _logger.d(
            'Current transcript: "$_currentTranscript"',
          ); // ✅ ADD THIS LOG

          // ✅ FIXED: Process transcript when speech recognition completes
          if (status == 'done') {
            _logger.d(
              'Status is done, checking transcript...',
            ); // ✅ ADD THIS LOG
            if (_currentTranscript.isNotEmpty) {
              _logger.d(
                'Processing transcript on status $status: $_currentTranscript',
              );
              _processUserResponseWithAI(_currentTranscript);
            } else {
              _logger.d(
                'Transcript is empty, cannot process',
              ); // ✅ ADD THIS LOG
            }
          }
        },
      );

      setState(() => _speechEnabled = available);
    }
  }

  Future<void> _initializeTts() async {
    _flutterTts = FlutterTts();
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
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

  void _startListening() {
    if (!_speechEnabled || _isListening) return;

    final currentTurn = _simulationTurns[_currentTurnIndex];
    if (currentTurn['character'] != 'Agent - Your Turn') return;

    setState(() {
      _isListening = true;
      _currentTranscript = '';
    });

    _logger.d('Starting to listen...');

    _speech.listen(
      onResult: (result) {
        _logger.d(
          '🎤 Speech result received: "${result.recognizedWords}"',
        ); // ✅ ADD THIS LOG
        _logger.d('🎤 Is final: ${result.finalResult}'); // ✅ ADD THIS LOG

        setState(() {
          _currentTranscript = result.recognizedWords;
        });

        // ✅ Process immediately when we get a final result
        if (result.finalResult && result.recognizedWords.isNotEmpty) {
          _logger.d('Final result received, processing...');
          _processUserResponseWithAI(result.recognizedWords);
        }
      },
      listenFor: const Duration(seconds: 30), // ✅ INCREASED back to 30 seconds
      pauseFor: const Duration(seconds: 5), // ✅ INCREASED to 5 seconds
      partialResults: true,
      localeId: "en_US",
      cancelOnError: false, // ✅ CHANGED to false
      // listenMode: stt.ListenMode.confirmation, // ✅ REMOVE this line
    );
  }

  IconData _getIconForMetric(String metricName) {
    switch (metricName.toLowerCase()) {
      case 'accuracy':
        return Icons.gps_fixed;
      case 'fluency':
        return Icons.speed;
      case 'completeness':
        return Icons.rule_sharp;
      case 'prosody':
        return Icons.multitrack_audio;
      case 'politeness':
        return Icons.handshake;
      case 'clarity':
        return Icons.search_sharp;
      case 'professionalism':
        return Icons.business_center;
      case 'helpfulness':
        return Icons.lightbulb_outline;
      case 'engagement':
        return Icons.group_work;
      case 'opening':
        return Icons.call;
      case 'information gathering':
        return Icons.playlist_add_check;
      case 'solution offering':
        return Icons.construction;
      case 'professional closure':
        return Icons.check_circle_outline;
      default:
        return Icons.bar_chart;
    }
  }

  IconData _getIconForAICoachCriterion(String criterionName) {
    final name = criterionName.toLowerCase();
    if (name.contains('excellence')) return Icons.emoji_events;
    if (name.contains('clarity')) return Icons.remove_red_eye;
    if (name.contains('demeanor')) return Icons.person_pin;
    if (name.contains('problem solving')) return Icons.extension;
    return Icons.school;
  }

  // ✅ ADD THIS TEST METHOD
  void _testSpeechRecognition() async {
    _logger.d('🧪 Testing speech recognition...');

    if (!_speechEnabled) {
      _logger.d('🧪 Speech not enabled');
      return;
    }

    setState(() {
      _isListening = true;
      _currentTranscript = 'Testing...';
    });

    try {
      final result = await _speech.listen(
        onResult: (result) {
          _logger.d('🧪 TEST result: "${result.recognizedWords}"');
          setState(() {
            _currentTranscript = result.recognizedWords;
          });
        },
        listenFor: const Duration(seconds: 10),
        partialResults: true,
        localeId: "en_US",
      );

      _logger.d('🧪 Listen call result: $result');
    } catch (e) {
      _logger.e('🧪 Speech test error: $e');
    }

    // Stop after 10 seconds
    Future.delayed(const Duration(seconds: 10), () {
      if (_isListening) {
        _speech.stop();
        setState(() => _isListening = false);
      }
    });
  }

  void _stopListening() {
    if (!_isListening) return;

    _logger.d('Manually stopping listening...');
    _logger.d(
      'Current transcript before stop: "$_currentTranscript"',
    ); // ✅ ADD THIS LOG

    _speech.stop();
    setState(() => _isListening = false);

    // ✅ FIXED: Process AFTER setting _isListening to false, with better logging
    if (_currentTranscript.isNotEmpty) {
      _logger.d('Processing transcript on manual stop: $_currentTranscript');
      _processUserResponseWithAI(_currentTranscript);
    } else {
      _logger.d('No transcript to process on manual stop'); // ✅ ADD THIS LOG
    }
  }

  // ✅ ADD THIS NEW METHOD FOR TESTING
  void _testProcessing() {
    if (_currentTranscript.isNotEmpty) {
      _logger.d(
        'TEST: Calling _processUserResponseWithAI with: $_currentTranscript',
      );
      _logger.d('TEST: _isProcessingAudio = $_isProcessingAudio');
      _processUserResponseWithAI(_currentTranscript);
    } else {
      _logger.d('TEST: No transcript to process');
    }
  }

  // REPLACE your entire _processUserResponseWithAI method with this one.
  Future<void> _processUserResponseWithAI(String audioFilePath) async {
    final currentTurn = _simulationTurns[_currentTurnIndex];
    final turnId = currentTurn['id'];
    final expectedText = currentTurn['text'];

    setState(() {
      _isProcessingAudio = true;
      _turnData[turnId] = {'isAnalyzing': true};
    });

    try {
      // 1. Upload audio to get URL (this part is correct)
      final audioUrl = await _uploadAudioFile(audioFilePath);
      if (audioUrl == null) throw Exception('Failed to upload audio file.');

      // 2. Get Azure speech analysis (this part is correct)
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

      // --- THIS IS THE FIX ---
      // 3. Build the payload and call the NEW service method for AI Coach feedback.

      // a. Build the conversation history, just like the web app
      final conversationHistory = _buildConversationHistory(recognizedText);

      // b. Build the scenario object, just like the web app
      final scenarioData = {
        'title':
            widget.lessonData['activity']?['scenario'] ??
            'Call Center Customer Service',
        'briefing': {
          'role': 'Customer Service Agent',
          'company': 'TalkReady Customer Service',
          'caller': 'Customer with inquiry',
          'situation':
              currentTurn['callPhase'] ??
              'General customer service interaction',
        },
      };

      // c. Call the new, correct endpoint via the service
      final aiCoachResult = await _progressService.getAiCallFeedback(
        transcript: conversationHistory,
        scenario: scenarioData,
      );
      // --- END OF FIX ---

      // 4. Update state with all the feedback
      if (mounted) {
        setState(() {
          _turnData[turnId]?['isProcessed'] = true;
          _turnData[turnId]?['isAnalyzing'] = false;
          _turnData[turnId]?['aiCoachFeedback'] =
              aiCoachResult; // Store the new result
          _turnData[turnId]?['aiCoachFeedback'] =
              aiCoachResult; // Make sure this is set
          _turnData[turnId]?['audioUrl'] = audioUrl;
          _turnData[turnId]?['detailedFeedback'] = _generateDetailedFeedback(
            azureResult,
            aiCoachResult, // Pass the new result
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
        'lesson_5_1_audio/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.m4a';
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

  // ✅ Build conversation history for AI context
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

  // ✅ Create audio bytes from transcript (demo implementation)
  Future<Uint8List> _createAudioFromTranscript(String transcript) async {
    // In a real implementation, you would capture actual audio during recording
    // For demo purposes, we'll create a simple audio representation
    return Uint8List.fromList(transcript.codeUnits);
  }

  Map<String, dynamic> _generateDetailedFeedback(
    Map<String, dynamic>? azureResult,
    Map<String, dynamic>? aiResult,
    String transcript,
  ) {
    // This function now PARSES real data instead of creating mock data.
    // It matches the structure of your web version's feedback.

    final speechQuality = {
      'accuracyScore': azureResult?['accuracyScore'] ?? 0.0,
      'fluencyScore': azureResult?['fluencyScore'] ?? 0.0,
      'completenessScore': azureResult?['completenessScore'] ?? 0.0,
      'prosodyScore': azureResult?['prosodyScore'] ?? 0.0,
    };

    // --- Call Center Service Metrics (Derived from AI Coach criteria) ---
    final serviceMetrics = <String, dynamic>{};
    final criteria = aiResult?['criteria'] as List<dynamic>? ?? [];

    final politeness = criteria.firstWhere(
      (c) => (c['name'] as String).contains('Service Excellence'),
      orElse: () => {'score': 0},
    )['score'];
    final clarity = criteria.firstWhere(
      (c) => (c['name'] as String).contains('Clarity'),
      orElse: () => {'score': 0},
    )['score'];
    final professionalism = criteria.firstWhere(
      (c) => (c['name'] as String).contains('Demeanor'),
      orElse: () => {'score': 0},
    )['score'];

    serviceMetrics['politeness'] = politeness;
    serviceMetrics['clarity'] = clarity;
    serviceMetrics['professionalism'] = professionalism;
    // These can be derived for a more complete picture
    serviceMetrics['helpfulness'] =
        (criteria.firstWhere(
                  (c) => (c['name'] as String).contains('Problem Solving'),
                  orElse: () => {'score': 0},
                )['score']
                as num?)
            ?.toDouble() ??
        0.0;
    serviceMetrics['engagement'] = ((azureResult?['fluencyScore'] ?? 0.0) * 20)
        .clamp(0, 100); // Fluency is a good proxy for engagement

    // --- Conversation Flow Analysis ---
    final conversationFlow = {
      'opening':
          (transcript.toLowerCase().contains("good morning") ||
              transcript.toLowerCase().contains("thank you for calling"))
          ? 90.0
          : 65.0,
      'informationGathering':
          (transcript.toLowerCase().contains("order number") ||
              transcript.toLowerCase().contains("may i have"))
          ? 85.0
          : 70.0,
      'solutionOffering':
          (transcript.toLowerCase().contains("i can check") ||
              transcript.toLowerCase().contains("i see your order"))
          ? 88.0
          : 75.0,
      'professionalClosure':
          (transcript.toLowerCase().contains("anything else") ||
              transcript.toLowerCase().contains("you're welcome"))
          ? 92.0
          : 80.0,
    };

    // --- Word Pronunciation Analysis ---
    final words = azureResult?['words'] as List<dynamic>? ?? [];
    final wordAnalysis = {
      'clearWords': words
          .where((w) => (w['accuracyScore'] as num? ?? 0) >= 90)
          .map((w) => w['word'] as String)
          .toList(),
      'practiceNeeded': words
          .where(
            (w) =>
                (w['accuracyScore'] as num? ?? 0) >= 70 &&
                (w['accuracyScore'] as num? ?? 0) < 90,
          )
          .map((w) => w['word'] as String)
          .toList(),
      'confusing': words
          .where((w) => (w['accuracyScore'] as num? ?? 0) < 70)
          .map((w) => w['word'] as String)
          .toList(),
    };

    // --- AI Coach Analysis ---
    // The aiResult is already in the correct format from the server

    return {
      'speechQuality': speechQuality,
      'serviceMetrics': serviceMetrics,
      'conversationFlow': conversationFlow,
      'wordAnalysis': wordAnalysis,
      'aiCoachAnalysis': aiResult,
    };
  }

  // ✅ Enhanced mock feedback for demo when API fails
  Map<String, dynamic> _generateEnhancedMockFeedback(String transcript) {
    final words = transcript.split(' ');
    final baseAccuracy = (words.length * 10 + 60).clamp(70, 95).toDouble();

    return _generateDetailedFeedback(
      {
        'accuracyScore': baseAccuracy,
        'fluencyScore': 4.0 + (words.length / 20).clamp(0, 1),
        'completenessScore': words.length >= 8 ? 90.0 : words.length * 10.0,
        'prosodyScore': 3.5 + (transcript.contains('!') ? 0.5 : 0),
      },
      {
        'summary': 'Good professional response with clear communication.',
        'strengths': ['Professional tone', 'Clear articulation'],
        'improvements': ['Add more engagement', 'Vary speech pace'],
      },
      transcript,
    );
  }

  Future<String?> _uploadAudioToCloudinary(Uint8List audioData) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final audioFile = File(
        '${tempDir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.webm',
      );
      await audioFile.writeAsBytes(audioData);
      return audioFile.path;
    } catch (e) {
      _logger.e('Error saving audio file: $e');
      return null;
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

  // REPLACE your existing _calculateAndSaveLessonScore method with this one.
  Future<void> _calculateAndSaveLessonScore() async {
    if (_isSubmittingLesson) return;
    setState(() => _isSubmittingLesson = true);

    double totalScore = 0;
    int agentTurnsProcessed = 0;

    _debugTurnData();

    // --- THIS IS THE FIX for the 0% score ---
    // Match the web version's scoring logic exactly
    for (var turn in _simulationTurns) {
      if (turn['character'] == 'Agent - Your Turn') {
        final turnData = _turnData[turn['id']];
        if (turnData?['isProcessed'] == true) {
          // Try AI Coach score first (if available)
          final aiCoachFeedback =
              turnData?['aiCoachFeedback'] as Map<String, dynamic>?;
          double turnScore = 0;

          if (aiCoachFeedback?['overallScore'] != null) {
            // Use AI Coach overall score
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

      // --- THIS MATCHES THE WEB VERSION'S DATA STRUCTURE ---
      final detailedResponsesPayload = {
        'overallScore': _overallLessonScore ?? 0,
        'callCenterReadinessBreakdown': {
          'accuracy': _calculateAverageMetric('accuracyScore'),
          'fluency':
              _calculateAverageMetric('fluencyScore') *
              20, // Convert 0-5 to 0-100
          'overall': _overallLessonScore ?? 0,
        },
        'timeSpent': _callDuration,
        'promptDetails': _simulationTurns.map((turn) {
          final turnData = _turnData[turn['id']];
          double? turnScore;

          // Extract turn score using the same logic as overall calculation
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
            'audioUrl': turnData?['audioUrl'],
            'transcription':
                turnData?['transcription'] ?? '(No transcription available)',
            'score': turnScore,
            'azureAiFeedback': turnData?['azureFeedback'],
            'openAiDetailedFeedback': turnData?['aiCoachFeedback'],
            'callCenterMetrics': turnData?['callCenterMetrics'],
          };
        }).toList(),
        'reflections': _responses,
      };

      // --- USE THE SAME FIRESTORE STRUCTURE AS WEB ---
      final userProgressRef = FirebaseFirestore.instance
          .collection('userProgress')
          .doc(user.uid);

      // Get existing data
      final docSnap = await userProgressRef.get();
      Map<String, dynamic> existingData = {};
      if (docSnap.exists) {
        existingData = docSnap.data() as Map<String, dynamic>;
      }

      // Get existing lesson attempts
      Map<String, dynamic> lessonAttemptsMap = Map<String, dynamic>.from(
        existingData['lessonAttempts'] ?? {},
      );

      // Initialize lesson attempts array if it doesn't exist
      if (lessonAttemptsMap[widget.lessonId] == null) {
        lessonAttemptsMap[widget.lessonId] = <Map<String, dynamic>>[];
      }

      List<dynamic> currentAttempts = List<dynamic>.from(
        lessonAttemptsMap[widget.lessonId],
      );

      // Create new attempt data matching web structure
      final newAttemptData = {
        'score': _overallLessonScore ?? 0,
        'attemptNumber': currentAttempts.length + 1,
        'lessonId': widget.lessonId,
        'detailedResponses': detailedResponsesPayload,
        'attemptTimestamp':
            Timestamp.now(), // Use Timestamp.now() instead of FieldValue
        'timeSpent': _callDuration,
      };

      // Add the new attempt
      currentAttempts.add(newAttemptData);
      lessonAttemptsMap[widget.lessonId] = currentAttempts;

      // Update the document with the same structure as web
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
    _logger.i('=== DEBUG TURN DATA ===');
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

  // Add this helper method to calculate average metrics
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
    _speech.cancel();
    _flutterTts.stop();
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
                  colors: [Color(0xFF20B2AA), Color(0xFF008B8B)],
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
                    'Lesson 5.1: Basic Simulation - Info Request',
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
                // --- THIS IS THE FIX ---
                onPressed: () {
                  // Only show the warning if a call is currently active
                  if (_isCallActive) {
                    _showExitConfirmationDialog();
                  } else {
                    // If not in an active call, just go back normally
                    Navigator.pop(context);
                  }
                },
                // --- END OF FIX ---
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

  // ADD THIS ENTIRE NEW METHOD
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
                Navigator.of(context).pop(false); // User does not want to leave
              },
            ),
            TextButton(
              child: const Text('Leave'),
              onPressed: () {
                Navigator.of(
                  context,
                ).pop(true); // User confirms they want to leave
              },
            ),
          ],
        );
      },
    );

    // If the user tapped "Leave", shouldPop will be true.
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
            'Welcome to Call Simulation Practice',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
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
                  'Scenario: Customer Order Status Inquiry',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'You will handle a call from a customer asking about their order status. Practice professional communication and follow the call flow naturally.',
                  style: TextStyle(fontSize: 16, height: 1.4),
                ),
                SizedBox(height: 20),
                Text(
                  'Instructions:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text(
                  '• Listen to each customer message\n'
                  '• Record your professional response\n'
                  '• Follow natural conversation flow\n'
                  '• Speak clearly and professionally',
                  style: TextStyle(fontSize: 14, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              // The button's action and text now depend on the permission status
              onPressed: () {
                if (_permissionStatus.isGranted) {
                  // If permission is granted, start the simulation
                  _startCallSimulation();
                } else if (_permissionStatus.isPermanentlyDenied) {
                  // If denied forever, guide user to settings
                  openAppSettings();
                } else {
                  // Otherwise, ask for permission again
                  _checkPermissionsAndInitialize();
                }
              },
              icon: Icon(
                _permissionStatus.isGranted ? Icons.play_arrow : Icons.mic_off,
              ),
              label: Text(
                _permissionStatus.isGranted
                    ? 'Start Call Simulation'
                    : _permissionStatus.isPermanentlyDenied
                    ? 'Open Settings to Grant Permission'
                    : 'Grant Microphone Permission',
                textAlign: TextAlign.center,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _permissionStatus.isGranted
                    ? Colors.green
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
          border: Border.all(color: Colors.green, width: 3),
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
                  'Call Simulation Attempt $_currentAttemptNumberForLesson',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
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
                    : const Color(0xFFE8F5E8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color:
                      _simulationTurns[_currentTurnIndex]['character'] ==
                          'Customer'
                      ? Colors.blue
                      : Colors.green,
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
                          : Colors.green[800],
                    ),
                  ),
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
              backgroundColor: Colors.indigo,
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

  // ADD THIS ENTIRE NEW METHOD
  Widget _buildNextTurnButton() {
    // Determine if it's the last turn in the simulation
    final isLastTurn = _currentTurnIndex >= _simulationTurns.length - 1;

    return Padding(
      padding: const EdgeInsets.only(top: 24.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _nextTurn,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isLastTurn ? 'End Call & View Summary' : 'Next Turn',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ UPDATED: Agent turn controls with better processing flow
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
            const Icon(Icons.mic, color: Colors.blue, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Your Response (${_currentTurnIndex ~/ 2 + 1}/${(_simulationTurns.length / 2).ceil()}):',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // ✅ Analysis Processing Indicator
        if (isAnalyzing) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: const Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Analyzing your speech...',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Please wait a moment.',
                  style: TextStyle(color: Colors.blue),
                ),
              ],
            ),
          ),
        ]
        // ✅ Detailed Feedback Display
        else if (isProcessed && detailedFeedback != null) ...[
          _buildTranscriptionDisplay(transcript),
          _buildDetailedFeedbackSection(detailedFeedback),
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

          // ✅ Added manual processing button when transcript is available
          if (_currentTranscript.isNotEmpty && !_isListening) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _testSpeechRecognition,
                icon: const Icon(Icons.science),
                label: const Text('Test Speech Recognition'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.purple,
                  side: const BorderSide(color: Colors.purple),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],

          // Transcript Display
          if (_currentTranscript.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'You said:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _currentTranscript,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildDetailedFeedbackSection(Map<String, dynamic> feedback) {
    return DefaultTabController(
      length: 4,
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
                color: const Color(0xFF20B2AA), // Teal color
              ),
              tabs: const [
                Tab(child: Text('AI Coach', style: TextStyle(fontSize: 12))),
                Tab(child: Text('Quality', style: TextStyle(fontSize: 12))),
                Tab(child: Text('Metrics', style: TextStyle(fontSize: 12))),
                Tab(child: Text('Flow', style: TextStyle(fontSize: 12))),
              ],
            ),
          ),
          SizedBox(
            // Give it a constrained height to prevent layout errors
            height: MediaQuery.of(context).size.height * 0.5,
            child: TabBarView(
              children: [
                _buildAICoachTab(feedback['aiCoachAnalysis']),
                _buildSpeechQualityTab(feedback['speechQuality']),
                _buildServiceMetricsTab(feedback['serviceMetrics']),
                _buildConversationFlowTab(feedback['conversationFlow']),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Tabbed feedback sections
  Widget _buildFeedbackTabs(Map<String, dynamic> feedback) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const TabBar(
              labelColor: Colors.indigo,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.indigo,
              tabs: [
                Tab(text: 'Quality'),
                Tab(text: 'Service'),
                Tab(text: 'Flow'),
                Tab(text: 'AI Coach'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 300,
            child: TabBarView(
              children: [
                _buildSpeechQualityTab(feedback['speechQuality']),
                _buildServiceMetricsTab(feedback['serviceMetrics']),
                _buildConversationFlowTab(feedback['conversationFlow']),
                _buildAICoachTab(feedback['aiCoachAnalysis']),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // REPLACE your existing _buildSpeechQualityTab method with this one.
  Widget _buildSpeechQualityTab(Map<String, dynamic>? quality) {
    if (quality == null)
      return const Center(child: Text('Speech Quality data unavailable.'));

    // --- THIS IS THE FIX ---
    // Read from the map using the correct, full key names from the server.
    final accuracy = (quality['accuracyScore'] as num?)?.toDouble() ?? 0.0;
    final fluency =
        (quality['fluencyScore'] as num?)?.toDouble() ??
        0.0; // Use 'fluencyScore'
    final completeness =
        (quality['completenessScore'] as num?)?.toDouble() ?? 0.0;
    final prosody =
        (quality['prosodyScore'] as num?)?.toDouble() ??
        0.0; // Use 'prosodyScore'
    // --- END OF FIX ---

    // Normalize fluency and prosody scores from 0-5 scale to 0-100 for display
    final fluencyPercent = (fluency * 20).clamp(0.0, 100.0);
    final prosodyPercent = (prosody * 20).clamp(0.0, 100.0);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      children: [
        _buildMetricCard(
          'Accuracy',
          accuracy,
          Colors.green,
          _getIconForMetric('Accuracy'),
        ),
        _buildMetricCard(
          'Fluency',
          fluencyPercent,
          Colors.blue,
          _getIconForMetric('Fluency'),
        ),
        _buildMetricCard(
          'Completeness',
          completeness,
          Colors.orange,
          _getIconForMetric('Completeness'),
        ),
        _buildMetricCard(
          'Prosody',
          prosodyPercent,
          Colors.purple,
          _getIconForMetric('Prosody'),
        ),
      ],
    );
  }

  Widget _buildServiceMetricsTab(Map<String, dynamic>? service) {
    if (service == null)
      return const Center(child: Text('Service Metrics unavailable.'));

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      children: [
        _buildMetricCard(
          'Politeness',
          (service['politeness'] as num?)?.toDouble() ?? 0.0,
          Colors.green,
          _getIconForMetric('Politeness'),
        ),
        _buildMetricCard(
          'Clarity',
          (service['clarity'] as num?)?.toDouble() ?? 0.0,
          Colors.blue,
          _getIconForMetric('Clarity'),
        ),
        _buildMetricCard(
          'Professionalism',
          (service['professionalism'] as num?)?.toDouble() ?? 0.0,
          Colors.purple,
          _getIconForMetric('Professionalism'),
        ),
        _buildMetricCard(
          'Helpfulness',
          (service['helpfulness'] as num?)?.toDouble() ?? 0.0,
          Colors.orange,
          _getIconForMetric('Helpfulness'),
        ),
        _buildMetricCard(
          'Engagement',
          (service['engagement'] as num?)?.toDouble() ?? 0.0,
          Colors.teal,
          _getIconForMetric('Engagement'),
        ),
      ],
    );
  }

  // REPLACE your _buildConversationFlowTab method
  Widget _buildConversationFlowTab(Map<String, dynamic>? flow) {
    if (flow == null)
      return const Center(child: Text('Conversation Flow data unavailable.'));

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      children: [
        _buildMetricCard(
          'Opening',
          (flow['opening'] as num?)?.toDouble() ?? 0.0,
          Colors.amber,
          _getIconForMetric('Opening'),
        ),
        _buildMetricCard(
          'Information Gathering',
          (flow['informationGathering'] as num?)?.toDouble() ?? 0.0,
          Colors.red,
          _getIconForMetric('Information Gathering'),
        ),
        _buildMetricCard(
          'Solution Offering',
          (flow['solutionOffering'] as num?)?.toDouble() ?? 0.0,
          Colors.yellow,
          _getIconForMetric('Solution Offering'),
        ),
        _buildMetricCard(
          'Professional Closure',
          (flow['professionalClosure'] as num?)?.toDouble() ?? 0.0,
          Colors.green,
          _getIconForMetric('Professional Closure'),
        ),
      ],
    );
  }

  // AI Coach Tab - This now shows the detailed criteria breakdown
  Widget _buildAICoachTab(Map<String, dynamic>? aiCoach) {
    if (aiCoach == null)
      return const Center(child: Text('AI Coach analysis unavailable.'));

    final overallScore = (aiCoach['overallScore'] as num?)?.toDouble() ?? 0.0;
    final summary = aiCoach['summary'] as String? ?? 'No summary available.';
    final criteria =
        (aiCoach['criteria'] as List<dynamic>?)
            ?.map((c) => c as Map<String, dynamic>)
            .toList() ??
        [];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        children: [
          // Overall Score and Summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F7FA), // Light cyan
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  'AI Call Center Readiness: ${overallScore.toInt()}%',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00796B),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  summary,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF004D40),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Detailed Criteria List
          ...criteria.map((item) {
            final name = item['name'] as String? ?? 'Criterion';
            final score = (item['score'] as num?)?.toDouble() ?? 0.0;
            final feedback = item['feedback'] as String? ?? 'No feedback.';
            return Card(
              elevation: 1,
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(
                          _getIconForAICoachCriterion(name),
                          color: Colors.indigo,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Text(
                          '${score.toInt()}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _getScoreColor(score),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 28.0,
                      ), // Indent feedback
                      child: Text(
                        feedback,
                        style: TextStyle(color: Colors.grey[700], height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  // Helper to determine score color - keep this as it is
  Color _getScoreColor(double score) {
    if (score >= 85) return Colors.green;
    if (score >= 70) return Colors.blue;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }

  Widget _buildMetricCard(
    String title,
    double value,
    Color color,
    IconData icon,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 5)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24), // Icon is now displayed here
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Colors.grey[800],
              ),
            ),
          ),
          Text(
            '${value.toInt()}%',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ADD this new widget to display the transcription
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

  Widget _buildFinalSummary() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Success Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _getScoreColor((_overallLessonScore ?? 0)).withOpacity(0.8),
                  _getScoreColor((_overallLessonScore ?? 0)),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Icon(Icons.military_tech, size: 48, color: Colors.white),
                const SizedBox(height: 16),
                Text(
                  '${(_overallLessonScore ?? 0).toInt()}%',
                  style: const TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  'Overall Call Performance Score',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // --- NEW: Turn-by-Turn Performance Review Section ---
          const Text(
            'Turn-by-Turn Performance Review',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _simulationTurns.length,
              itemBuilder: (context, index) {
                final turn = _simulationTurns[index];
                final turnData = _turnData[turn['id']] ?? {};

                // Only show agent turns with processed data
                if (turn['character'] != 'Agent - Your Turn' ||
                    turnData['isProcessed'] != true) {
                  return const SizedBox.shrink();
                }

                return ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  title: Text(
                    'Your Response (${index ~/ 2 + 1}/${(_simulationTurns.length / 2).ceil()})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(
                    turn['text'],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          _buildTranscriptionDisplay(turnData['transcription']),
                          _buildDetailedFeedbackSection(
                            turnData['detailedFeedback'] ?? {},
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          // --- END OF NEW SECTION ---
          const SizedBox(height: 24),

          // Reflection Questions
          if (_reflectionQuestions.isNotEmpty) ...[
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reflection Questions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!_reflectionSubmitted) ...[
                    ..._reflectionQuestions.map((question) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            question['text'] ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            onChanged: (value) {
                              _responses[question['id']] = value;
                            },
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText: 'Your thoughts...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.all(12),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      );
                    }).toList(),
                    Center(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _reflectionSubmitted = true;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: const Text('Submit Reflection'),
                      ),
                    ),
                  ] else ...[
                    const Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 48,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Thank you for your reflection!',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _showFinalSummary = false;
                      _isCallActive = false;
                      _currentTurnIndex = 0;
                      _turnData.clear();
                      _overallLessonScore = null;
                      _callDuration = 0;
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.indigo,
                    side: const BorderSide(color: Colors.indigo),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.home),
                  label: const Text('Complete'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
