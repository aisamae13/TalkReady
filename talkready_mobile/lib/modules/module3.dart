import 'dart:async';
import 'dart:io' show Platform;
import 'dart:convert';

import 'package:flutter/material.dart' hide CarouselController;
import 'package:carousel_slider/carousel_slider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';

import '../firebase_service.dart';
import '../lessons/lesson3_1.dart';
import '../lessons/lesson3_2.dart';
import '../StudentAssessment/AiFeedbackData.dart';

class Module3Page extends StatefulWidget {
  final String? targetLessonKey;
  const Module3Page({super.key, this.targetLessonKey});

  @override
  State<Module3Page> createState() => _Module3PageState();
}

class _Module3PageState extends State<Module3Page> {
  // multiple server fallbacks - prefer your PC LAN IP first for real devices
  static const List<String> AI_BASE_URLS = [
    'http://192.168.1.2:5001', // TODO: replace with your real PC LAN IP
    'http://10.0.2.2:5001',    // Android emulator -> host
    'http://127.0.0.1:5001',   // for adb reverse on USB
    'http://localhost:5001',
  ];
  static const bool kDevelopmentMode = true; // Change to true
  static const bool kForceOfflineMode = false;

  String? _workingBaseUrl;
  String get _aiBaseUrl {
    if (_workingBaseUrl != null) return _workingBaseUrl!;
    // On mobile, prefer the first entry (your LAN IP) instead of 10.0.2.2
    if (Platform.isAndroid || Platform.isIOS) return AI_BASE_URLS.first;
    return AI_BASE_URLS[3]; // localhost on desktop
  }

  Future<bool> _isServerReachable() async {
    // In development mode, don't block initialization on server checks
    if (kDevelopmentMode) {
      _logger.i('L3: Development mode - skipping server health check during initialization');
      return false; // This will trigger mock data usage
    }
    
    if (_workingBaseUrl != null) {
      if (await _testUrl(_workingBaseUrl!)) return true;
      _logger.w('L3: Previously working server $_workingBaseUrl is no longer responsive');
      _workingBaseUrl = null;
    }
    for (final baseUrl in AI_BASE_URLS) {
      _logger.d('L3: Trying server at $baseUrl');
      if (await _testUrl(baseUrl)) {
        _workingBaseUrl = baseUrl;
        _logger.i('L3: Found working server at $baseUrl');
        return true;
      }
    }
    _logger.w('L3: No servers responded to health checks.');
    return false;
  }

  // Add a separate method for checking servers when actually needed
  Future<bool> _checkServerReachableForRequest() async {
    // In development mode, try to connect but don't block the UI for too long.
    // The calling function will decide to use mock data if this returns false.
    if (_workingBaseUrl != null) {
      if (await _testUrl(_workingBaseUrl!)) return true;
      _logger.w('L3: Previously working server $_workingBaseUrl is no longer responsive');
      _workingBaseUrl = null;
    }
    for (final baseUrl in AI_BASE_URLS) {
      _logger.d('L3: Trying server at $baseUrl');
      if (await _testUrl(baseUrl)) {
        _workingBaseUrl = baseUrl;
        _logger.i('L3: Found working server at $baseUrl');
        return true;
      }
    }
    _logger.w('L3: No servers responded to health checks.');
    return false;
  }

  // Optional: slightly longer health timeout for Wi‑Fi
  Future<bool> _testUrl(String baseUrl) async {
    final normalized =
        baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;

    final candidates = <Uri>[
      Uri.parse('$normalized/health'),
      Uri.parse(normalized),
    ];

    for (final uri in candidates) {
      try {
        _logger.d('L3: Testing server at $uri');
        final response = await http.get(uri).timeout(const Duration(seconds: 5));
        if (response.statusCode >= 200 && response.statusCode < 500) {
          _logger.i('L3: Server responsive at $uri (status: ${response.statusCode})');
          return true;
        } else {
          _logger.w('L3: Server responded at $uri but with non-success status ${response.statusCode}');
        }
      } on TimeoutException {
        _logger.w('L3: Timeout trying to reach $uri. Check IP address and firewall rules.');
      } catch (e) {
        _logger.e('L3: Failed to reach $uri with exception: $e');
      }
    }
    _logger.d('L3: All candidates for $baseUrl failed.');
    return false;
  }

  int currentLesson = 1;
  bool showActivitySection = false;
  YoutubePlayerController _youtubeController = YoutubePlayerController(
    initialVideoId: '',
    flags: const YoutubePlayerFlags(autoPlay: false),
  );
  int _currentSlide = 0;
  final CarouselSliderController _carouselController = CarouselSliderController();
  final Logger _logger = Logger();
  final FirebaseService _firebaseService = FirebaseService();
  late FlutterTts flutterTts;

  final Map<int, String?> _videoIds = {1: 'qY9iPdZfOic', 2: null};

  // --- FEEDBACK state: keep both raw map (for passing to children) and parsed models (for display)
  Map<String, dynamic>? _aiFeedbackDataCurrentLesson; // raw server shape (keeps compatibility)
  Map<String, AiFeedbackDataModel>? _aiFeedbackModelsCurrentLesson; // parsed for display
  int? _overallScoreCurrentLesson;
  int? _maxScoreCurrentLesson;
  bool _shouldDisplayFeedbackCurrentLesson = false;

  String? _youtubeError;
  Map<String, bool> _lessonCompletion = {'lesson1': false, 'lesson2': false};
  late Map<String, int> _lessonAttemptCounts;
  bool _isContentLoaded = false;
  bool _isLoadingNextLesson = false;
  bool _isSubmittingToServer = false;

  Map<String, dynamic>? _lessonData;
  List<dynamic> _speakingPrompts = [];
  Map<String, PromptAttemptData> _lesson3_2PromptDataMap = {};

  final Map<int, String> _lessonNumericToFirestoreKey = {1: "Lesson 3.1", 2: "Lesson 3.2"};

  @override
  void initState() {
    super.initState();
    _logger.i('L3: Initializing Module 3 with server URLs: ${AI_BASE_URLS.join(", ")}');
    if (kDevelopmentMode) {
      _logger.i('L3: Running in development mode - will use mock data when server unavailable');
    }
    flutterTts = FlutterTts();
    _lessonAttemptCounts = {'lesson1': 0, 'lesson2': 0};
    _performAsyncInit();
  }

  Future<void> _initializeAndConfigureTts() async => _configureTts();
  Future<void> _configureTts() async {
    try {
      await flutterTts.stop();
      await flutterTts.setLanguage("en-US");
      await flutterTts.setSpeechRate(0.45);
      await flutterTts.setVolume(1.0);
      await flutterTts.setPitch(1.0);
      _logger.i("L3: Flutter TTS configured.");
    } catch (e) {
      _logger.e("L3: Error configuring TTS: $e");
    }
  }

  Future<void> _playScript(String scriptText) async {
    try {
      await flutterTts.stop();
      int result = await flutterTts.speak(scriptText);
      if (result == 1) _logger.i("L3: TTS speaking script...");
      else _logger.w("L3: TTS speak command failed.");
    } catch (e) {
      _logger.e("L3: Error during TTS speak: $e");
    }
  }

  Future<void> _performAsyncInit() async {
    setState(() => _isContentLoaded = false);
    try {
      // Don't block initialization on server checks in development mode
      if (!kDevelopmentMode) {
        await _isServerReachable();
      } else {
        _logger.i('L3: Skipping server check during initialization in development mode');
      }
      
      await _loadLessonProgress();
      _initializeYoutubeController();
      _resetUIForCurrentLesson();
      await _loadLessonSpecificData();
      if (mounted) setState(() {
        showActivitySection = _lessonCompletion['lesson$currentLesson'] ?? false;
        _isContentLoaded = true;
      });
    } catch (error) {
      _logger.e("Error during initState loading for Module 3: $error");
      if (mounted) setState(() {
        _youtubeError = "Failed to load lesson content. Please try again.";
        _isContentLoaded = true;
      });
    }
  }

  void _initializePromptAttemptDataL3_2() {
    _lesson3_2PromptDataMap.clear();
    if (_lessonData != null && currentLesson == 2) {
      final activityData = (_lessonData!['activity'] as Map<String, dynamic>?) ?? {};
      _speakingPrompts = activityData['speakingPrompts'] as List<dynamic>? ?? [];
      for (var prompt in _speakingPrompts) {
        if (prompt is Map && prompt['id'] is String) _lesson3_2PromptDataMap[prompt['id']] = PromptAttemptData();
      }
      _logger.i("L3.2: Initialized _lesson3_2PromptDataMap for ${_speakingPrompts.length} prompts.");
    } else if (currentLesson == 2) {
      _logger.w("L3.2: _lessonData is null or not for L3.2. Prompts might be empty.");
      _speakingPrompts = [];
    }
  }

  void _resetUIForCurrentLesson() {
    _aiFeedbackDataCurrentLesson = null;
    _aiFeedbackModelsCurrentLesson = null;
    _overallScoreCurrentLesson = null;
    _maxScoreCurrentLesson = null;
    _shouldDisplayFeedbackCurrentLesson = false;
    _logger.i("Resetting UI for Lesson $currentLesson");
    if (currentLesson == 2) _initializePromptAttemptDataL3_2();
  }

  Future<void> _loadLessonSpecificData() async {
    if (currentLesson == 2) {
      final Map<String, dynamic> hardcodedLesson3_2ActivityData = {
        'speakingPrompts': [
          {'id': 'd1_agent1', 'text': "Good morning! This is Anna from TechSupport. How can I assist you?", 'character': "Agent"},
          {'id': 'd1_agent2', 'text': "I'm sorry about that. Can I get your account number, please?", 'character': "Agent"},
          {'id': 'd2_agent1', 'text': "Hello! Thank you for calling. What can I help you with today?", 'character': "Agent"},
          {'id': 'd2_agent2', 'text': "Certainly. May I have your tracking number?", 'character': "Agent"},
          {'id': 'd3_agent1', 'text': "Thank you for waiting. I've confirmed your refund has been processed.", 'character': "Agent"},
          {'id': 'd3_agent2', 'text': "You're welcome! Have a great day.", 'character': "Agent"},
        ],
      };
      setState(() {
        _lessonData = {'activity': hardcodedLesson3_2ActivityData};
        _speakingPrompts = hardcodedLesson3_2ActivityData['speakingPrompts'] as List<dynamic>? ?? [];
        _initializePromptAttemptDataL3_2();
      });
    } else {
      setState(() => _lessonData = {});
    }
  }

  Future<void> _loadLessonProgress() async {
    try {
      final progress = await _firebaseService.getModuleProgress('module3');
      final lessonsData = progress['lessons'] as Map<String, dynamic>? ?? {};
      final attemptData = progress['attempts'] as Map<String, dynamic>? ?? {};
      _lessonCompletion = {'lesson1': lessonsData['lesson1'] ?? false, 'lesson2': lessonsData['lesson2'] ?? false};
      _lessonAttemptCounts = {'lesson1': attemptData['lesson1'] as int? ?? 0, 'lesson2': attemptData['lesson2'] as int? ?? 0};

      if (widget.targetLessonKey != null) {
        _logger.i("Module 3: Target lesson key provided: ${widget.targetLessonKey}");
        switch (widget.targetLessonKey) {
          case 'lesson1':
            currentLesson = 1;
            break;
          case 'lesson2':
            currentLesson = 2;
            break;
          default:
            _logger.w("Module 3: Unknown targetLessonKey: ${widget.targetLessonKey}. Defaulting.");
            if (!(_lessonCompletion['lesson1'] ?? false)) currentLesson = 1;
            else if (!(_lessonCompletion['lesson2'] ?? false)) currentLesson = 2;
            else currentLesson = 2;
        }
      } else {
        if (!(_lessonCompletion['lesson1'] ?? false)) currentLesson = 1;
        else if (!(_lessonCompletion['lesson2'] ?? false)) currentLesson = 2;
        else currentLesson = 2;
      }
      _logger.i('Module 3: Loaded lesson progress: currentLesson=$currentLesson, completion=$_lessonCompletion, attempts=$_lessonAttemptCounts');
    } catch (e) {
      _logger.e('Module 3: Error loading lesson progress: $e');
      currentLesson = 1;
      _lessonCompletion = {'lesson1': false, 'lesson2': false};
      _lessonAttemptCounts = {'lesson1': 0, 'lesson2': 0};
      rethrow;
    }
  }

  void _initializeYoutubeController() {
    String? videoId = _videoIds[currentLesson];
    _logger.i('Module 3: Initializing YouTube controller for Lesson $currentLesson: videoId=$videoId');
    if (videoId != null && videoId.isNotEmpty) {
      if (mounted && _youtubeController.initialVideoId == videoId && _youtubeController.value.isReady) {
        _logger.i('Module 3: YouTube controller already initialized for $videoId.');
        return;
      }
      _youtubeController = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(autoPlay: false, mute: false, enableCaption: true, captionLanguage: 'en', hideControls: false),
      );
      _youtubeController.addListener(() {
        if (_youtubeController.value.errorCode != 0 && mounted) setState(() => _youtubeError = 'YT Error: ${_youtubeController.value.errorCode}');
      });
      if (mounted) setState(() => _youtubeError = null);
    } else {
      _logger.w('Module 3: No video ID for Lesson $currentLesson. Creating controller with empty ID.');
      _youtubeController = YoutubePlayerController(initialVideoId: '', flags: const YoutubePlayerFlags(autoPlay: false));
      if (mounted) setState(() => _youtubeError = null);
    }
  }

  // Updated mock submission: produce raw map + parsed AiFeedbackDataModel map
  void _handleMockSubmission(Map<String, String> userTextAnswers, int timeSpent, int attemptNumber) {
    _logger.i("L3.1: Using mock submission for development");
    final Map<String, dynamic> rawFeedback = {};
    final Map<String, AiFeedbackDataModel> parsed = {};
    double totalScore = 0;
    userTextAnswers.forEach((key, value) {
      final score = (value.length > 10) ? 4.0 : 3.0;
      final raw = {
        'score': score,
        'text': "**Mock Development Feedback for $key:**\n\n"
            "Your answer shows good understanding of the concept. Consider adding more specific details to enhance your response.\n\n"
            "Suggestions:\n• Be more specific in your examples\n• Use clearer language\n• Structure your response better"
      };
      rawFeedback[key] = raw;
      parsed[key] = AiFeedbackDataModel.fromMap(raw);
      totalScore += score;
    });

    if (mounted) {
      setState(() {
        _aiFeedbackDataCurrentLesson = rawFeedback;
        _aiFeedbackModelsCurrentLesson = parsed;
        _overallScoreCurrentLesson = totalScore.round();
        _maxScoreCurrentLesson = rawFeedback.length * 5;
        _shouldDisplayFeedbackCurrentLesson = true;
        showActivitySection = true;
        _isSubmittingToServer = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Development mode: Using mock feedback'), backgroundColor: Colors.blue));
      unawaited(_saveLessonProgressStatus(1));
    }
  }

  Future<void> _handleSubmitLesson3_1(Map<String, String> userTextAnswers, int timeSpent, int attemptNumber) async {
    setState(() => _isSubmittingToServer = true);
    _logger.i("L3.1: Starting submission attempt $attemptNumber");
    final serverReachable = await _checkServerReachableForRequest();
    if (!serverReachable && kDevelopmentMode) {
      _handleMockSubmission(userTextAnswers, timeSpent, attemptNumber);
      return;
    }
    if (!serverReachable) {
      _logger.e("L3.1: No servers are reachable");
      if (mounted) {
        setState(() => _isSubmittingToServer = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Server not available. Please check your connection.'), backgroundColor: Colors.red, duration: Duration(seconds: 5)));
      }
      return;
    }

    final baseUrl = _workingBaseUrl ?? _aiBaseUrl;
    _logger.i("L3.1: Posting to $baseUrl/evaluate-scenario");

    try {
      final requestBody = {
        'answers': userTextAnswers,
        'attemptNumber': attemptNumber,
        'timeSpent': timeSpent,
      };
      final response = await http
          .post(
            Uri.parse('$baseUrl/evaluate-scenario'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 30));
      if (!mounted) return;

      if (response.statusCode == 200) {
        if (_workingBaseUrl != baseUrl) {
          _workingBaseUrl = baseUrl;
          _logger.i("L3.1: Confirmed working server: $baseUrl");
        }

        final result = jsonDecode(response.body) as Map<String, dynamic>;
        final feedbackMap = result['feedback'] as Map<String, dynamic>?;

        Map<String, dynamic>? convertedRaw;
        Map<String, AiFeedbackDataModel>? convertedModels;
        double calculatedScore = 0;
        int maxScore = 0;

        if (feedbackMap != null) {
          convertedRaw = {};
          convertedModels = {};
          feedbackMap.forEach((key, value) {
            // keep raw
            convertedRaw![key] = value;
            // try parse to model
            if (value is Map<String, dynamic>) {
              try {
                final model = AiFeedbackDataModel.fromMap(value);
                convertedModels![key] = model;
                calculatedScore += model.score;
              } catch (e) {
                convertedModels![key] = AiFeedbackDataModel(score: (value['score'] is num) ? (value['score'] as num).toDouble() : 0.0, sections: null, text: value['text']?.toString());
                if (value['score'] is num) calculatedScore += (value['score'] as num).toDouble();
              }
            } else {
              convertedModels![key] = AiFeedbackDataModel(score: 0.0, sections: null, text: value?.toString());
            }
            maxScore += 5;
          });
        }

        if (mounted) {
          setState(() {
            _aiFeedbackDataCurrentLesson = convertedRaw;
            _aiFeedbackModelsCurrentLesson = convertedModels;
            _overallScoreCurrentLesson = calculatedScore.round();
            _maxScoreCurrentLesson = maxScore;
            _shouldDisplayFeedbackCurrentLesson = true;
            showActivitySection = true;
          });
        }

        // save to firebase (fire-and-forget)
        unawaited(_firebaseService
            .saveSpecificLessonAttempt(
              lessonIdKey: "Lesson 3.1",
              score: calculatedScore.round(),
              attemptNumberToSave: attemptNumber,
              timeSpent: timeSpent,
              detailedResponsesPayload: {'feedbackForAnswers': feedbackMap},
            )
            .timeout(const Duration(seconds: 20))
            .then((_) => _logger.i("L3.1: Attempt saved to Firebase"))
            .catchError((e) => _logger.w("L3.1: Firebase save failed: $e")));

        unawaited(_saveLessonProgressStatus(1)
            .timeout(const Duration(seconds: 10))
            .then((_) => _logger.i("L3.1: Progress status saved"))
            .catchError((e) => _logger.w("L3.1: Progress save failed: $e")));
      } else {
        _logger.e("L3.1: Server error ${response.statusCode}: ${response.body}");
        if (_tryNextServerUrl()) {
          _logger.i("L3.1: Retrying with next server URL");
          return _handleSubmitLesson3_1(userTextAnswers, timeSpent, attemptNumber);
        }
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Server error: ${response.statusCode}")));
      }
    } catch (e) {
      _logger.e("L3.1: Exception during submission: $e");
      if (_tryNextServerUrl()) {
        _logger.i("L3.1: Retrying with next server URL after exception");
        return _handleSubmitLesson3_1(userTextAnswers, timeSpent, attemptNumber);
      }
      if (mounted) {
        String message = "Submission failed: Connection error";
        if (e is TimeoutException) message = "Request timed out. Check your connection.";
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSubmittingToServer = false);
    }
  }

  bool _tryNextServerUrl() {
    final currentUrl = _workingBaseUrl ?? _aiBaseUrl;
    final currentIndex = AI_BASE_URLS.indexOf(currentUrl);
    if (currentIndex >= 0 && currentIndex < AI_BASE_URLS.length - 1) {
      _workingBaseUrl = AI_BASE_URLS[currentIndex + 1];
      _logger.i("L3.1: Switching to next server: $_workingBaseUrl");
      return true;
    }
    return false;
  }

  void _showServerErrorDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Server Connection Error'),
          content: const Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Unable to connect to the AI evaluation servers.'),
            SizedBox(height: 8),
            Text('Please check your network connection and try again.'),
          ]),
          actions: [
            TextButton(child: const Text('OK'), onPressed: () => Navigator.of(context).pop()),
            TextButton(child: const Text('Retry'), onPressed: () {
              Navigator.of(context).pop();
              _checkServerReachableForRequest();
            }),
          ],
        );
      },
    );
  }

  Future<Map<String, dynamic>?> _handleProcessAudioPromptL3_2(String localAudioPath, String originalText, String promptId) async {
    setState(() => _isSubmittingToServer = true);
    _logger.i("L3.2 Module: Processing audio for prompt '$promptId': $localAudioPath");

    final String lessonKeyForFirebase = _lessonNumericToFirestoreKey[2] ?? "Lesson 3.2";
    String? firebaseStorageUrl = await _firebaseService.uploadLessonAudio(localAudioPath, lessonKeyForFirebase, promptId);

    if (firebaseStorageUrl == null || firebaseStorageUrl.isEmpty) {
      _logger.e("L3.2 Module: Firebase Storage upload failed for prompt '$promptId'.");
      if (mounted) setState(() => _isSubmittingToServer = false);
      return {'success': false, 'error': 'Audio upload to Firebase Storage failed.', 'audioStorageUrlFromModule': null};
    }

    _logger.i("L3.2 Module: Uploaded to Firebase Storage: $firebaseStorageUrl");

    // *** SIMULA NG PAGBABAGO ***

    // 1. Unang suriin kung reachable ang server
    final serverReachable = await _checkServerReachableForRequest();

    // 2. Kung hindi reachable AT nasa development mode, gamitin ang mock data
    if (!serverReachable && kDevelopmentMode) {
      _logger.w("L3.2 Module: Server not reachable in dev mode, falling back to mock data.");
      final mockResponse = _generateMockFeedback(originalText, firebaseStorageUrl);
      if (mounted) setState(() => _isSubmittingToServer = false);
      return mockResponse;
    }

    // 3. Kung hindi reachable at HINDI nasa dev mode, magpakita ng error
    if (!serverReachable) {
      _logger.e("L3.2 Module: No servers are reachable. Cannot process audio.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Server not available. Please check your connection.'),
          backgroundColor: Colors.red,
        ));
        setState(() => _isSubmittingToServer = false);
      }
      return {'success': false, 'error': 'Server not available', 'audioStorageUrlFromModule': firebaseStorageUrl};
    }

    // 4. Kung reachable, ituloy ang request gamit ang nahanap na _workingBaseUrl
    final baseUrl = _workingBaseUrl!; // Siguradong may value ito dahil sa check sa taas
    _logger.i("L3.2 Module: Server is reachable. Posting to $baseUrl/evaluate-speech-with-azure");

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/evaluate-speech-with-azure'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'audioUrl': firebaseStorageUrl,
              'originalText': originalText,
              'language': 'en-US',
              'promptId': promptId,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (!mounted) return null;

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body) as Map<String, dynamic>;
        _logger.i("L3.2 Module: Real Azure Feedback for '$promptId' received successfully");
        return {...result, 'audioStorageUrlFromModule': firebaseStorageUrl};
      } else {
        _logger.e("L3.2 Module: Server Error for '$promptId': ${response.statusCode} - ${response.body}");
        // Kung pumalya pa rin, bumalik sa mock data kung nasa dev mode
        if (kDevelopmentMode) {
          return _generateMockFeedback(originalText, firebaseStorageUrl);
        }
        return {'success': false, 'error': 'Server error: ${response.statusCode}', 'audioStorageUrlFromModule': firebaseStorageUrl};
      }
    } on TimeoutException catch (e) {
      _logger.e("L3.2 Module: Request timeout for '$promptId': $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Request timed out. Check your connection.'),
          backgroundColor: Colors.red,
        ));
      }
      // Kung nag-timeout, bumalik sa mock data kung nasa dev mode
      if (kDevelopmentMode) {
        return _generateMockFeedback(originalText, firebaseStorageUrl);
      }
      return {'success': false, 'error': 'Request timed out', 'audioStorageUrlFromModule': firebaseStorageUrl};
    } catch (e) {
      _logger.e("L3.2 Module: Exception during Azure eval for '$promptId': $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('An error occurred: $e')));
      }
      return {'success': false, 'error': e.toString(), 'audioStorageUrlFromModule': firebaseStorageUrl};
    } finally {
      if (mounted) setState(() => _isSubmittingToServer = false);
    }
    // *** WAKAS NG PAGBABAGO ***
  }

  // Add a separate method to generate mock feedback
  Map<String, dynamic> _generateMockFeedback(String originalText, String firebaseStorageUrl) {
    final mockWords = <Map<String, dynamic>>[];
    for (final w in originalText.split(RegExp(r'\s+'))) {
      mockWords.add({'word': w, 'accuracyScore': 85.0 + (w.length % 10), 'errorType': 'None'});
    }
    
    // Generate varied mock scores based on text length to make it more realistic
    final textLength = originalText.length;
    final accuracyScore = 85.0 + (textLength % 15);
    final fluencyScore = 80.0 + (textLength % 20);
    final prosodyScore = 75.0 + (textLength % 25);
    
    return {
      'success': true,
      'textRecognized': originalText,
      'accuracyScore': accuracyScore,
      'fluencyScore': fluencyScore,
      'completenessScore': 90.0,
      'prosodyScore': prosodyScore,
      'words': mockWords,
      'audioStorageUrlFromModule': firebaseStorageUrl,
      'isDevelopmentMock': true,
      // Add pre-generated explanation to avoid server call
      'mockExplanation': _generateMockExplanation(originalText, accuracyScore, fluencyScore, prosodyScore),
    };
  }

  // Add this new method to generate mock explanations
  String _generateMockExplanation(String originalText, double accuracy, double fluency, double prosody) {
    return '''
<p><strong>Coach (Offline Mode):</strong></p>
<p>I heard you say: "<em>$originalText</em>"</p>
<p><strong>Performance Analysis:</strong></p>
<ul>
<li><strong>Accuracy:</strong> ${accuracy.toStringAsFixed(1)}/100 - Good pronunciation overall</li>
<li><strong>Fluency:</strong> ${fluency.toStringAsFixed(1)}/100 - Natural speech rhythm</li>
<li><strong>Prosody:</strong> ${prosody.toStringAsFixed(1)}/100 - Nice intonation patterns</li>
</ul>
<p><strong>Tips for improvement:</strong></p>
<ul>
<li>Continue practicing clear articulation</li>
<li>Focus on natural pauses between phrases</li>
<li>Maintain consistent volume throughout</li>
</ul>
<p><em>Note: This is offline analysis. Connect to the server for detailed AI feedback.</em></p>
''';
}

  Future<String?> _handleExplainAzureFeedbackL3_2(Map<String, dynamic> azureResult, String originalText) async {
  // Check if this is mock data first
  if (azureResult['isDevelopmentMock'] == true) {
    _logger.i("L3.2: Using pre-generated mock explanation");
    if (mounted) setState(() => _isSubmittingToServer = false);
    return azureResult['mockExplanation'] ?? _localFallbackExplanation(azureResult);
  }

  setState(() => _isSubmittingToServer = true);
  _logger.i("L3.2: Requesting explanation for Azure feedback (OpenAI).");
  try {
    final healthy = await _checkServerReachableForRequest();
    if (!healthy) {
      if (mounted) setState(() => _isSubmittingToServer = false);
      return _localFallbackExplanation(azureResult);
    }
    final baseUrl = _workingBaseUrl ?? _aiBaseUrl;
    final uri = Uri.parse('$baseUrl/explain-azure-feedback-with-openai');
    try {
      final resp = await http.post(uri, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'azureFeedback': azureResult, 'originalText': originalText})).timeout(const Duration(seconds: 15)); // Reduced timeout for explanations
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final explanation = (body['detailedFeedback'] ?? body['explanation'])?.toString();
        if (explanation != null && explanation.trim().isNotEmpty) {
          return explanation;
        }
      } else {
        _logger.w('L3.2: explain endpoint returned ${resp.statusCode}: ${resp.body}');
      }
    } catch (e) {
      _logger.w('L3.2: explain request failed: $e');
    }
  } catch (e) {
    _logger.e('L3.2: Unexpected error while getting explanation: $e');
  } finally {
    if (mounted) setState(() => _isSubmittingToServer = false);
  }
  return _localFallbackExplanation(azureResult);
}

  String _localFallbackExplanation(Map<String, dynamic> azureResult) {
    final heard = (azureResult['textRecognized'] ?? '').toString().trim();
    final acc = azureResult['accuracyScore'] != null ? azureResult['accuracyScore'].toString() : 'N/A';
    final flu = azureResult['fluencyScore'] != null ? azureResult['fluencyScore'].toString() : 'N/A';
    final pros = azureResult['prosodyScore'] != null ? azureResult['prosodyScore'].toString() : 'N/A';
    final buffer = StringBuffer();
    buffer.writeln('<p><strong>Coach (offline):</strong></p>');
    if (heard.isNotEmpty) buffer.writeln('<p>Recognized text: "<em>${const HtmlEscape().convert(heard)}</em>".</p>');
    else buffer.writeln('<p>No clear speech detected.</p>');
    buffer.writeln('<p>Accuracy: $acc, Fluency: $flu, Prosody: $pros.</p>');
    buffer.writeln('<p>Tips:</p><ul>');
    buffer.writeln('<li>Speak slowly and clearly. Pronounce each word fully.</li>');
    buffer.writeln('<li>Pause between phrases to improve clarity.</li>');
    buffer.writeln('<li>If recording was very short, try a longer take.</li>');
    buffer.writeln('</ul>');
    buffer.writeln('<p><em>This is an offline summary. Connect to the server for detailed AI coach feedback.</em></p>');
    return buffer.toString();
  }

  Future<void> _handleSubmitLessonL3_2(List<Map<String, dynamic>> submittedPromptData, Map<String, String> reflections, double overallScore, int timeSpent, int attemptNumber) async {
    setState(() => _isSubmittingToServer = true);
    _logger.i("L3.2 Submitting Full Lesson: Attempt $attemptNumber, Overall Score $overallScore, Time $timeSpent");
    try {
      await _firebaseService.saveSpecificLessonAttempt(
        lessonIdKey: "Lesson 3.2",
        score: overallScore.round(),
        attemptNumberToSave: attemptNumber,
        timeSpent: timeSpent,
        detailedResponsesPayload: {'overallScore': overallScore, 'reflections': reflections, 'promptDetails': submittedPromptData},
      );
      if (!mounted) return;
      setState(() => showActivitySection = true);
      await _saveLessonProgressStatus(2);
      _logger.i("L3.2 Lesson submission successful for attempt $attemptNumber.");
    } catch (e) {
      _logger.e("L3.2 Error submitting full lesson: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to submit lesson: $e")));
    } finally {
      if (mounted) setState(() => _isSubmittingToServer = false);
    }
  }

  Future<void> _saveLessonProgressStatus(int lessonNumberInModule) async {
    final lessonFirebaseKey = 'lesson$lessonNumberInModule';
    final currentAttempts = Map<String, int>.from(_lessonAttemptCounts);
    currentAttempts[lessonFirebaseKey] = (currentAttempts[lessonFirebaseKey] ?? 0) + 1;
    await _firebaseService.updateLessonProgress('module3', lessonFirebaseKey, true, attempts: currentAttempts);
    if (mounted) setState(() {
      _lessonCompletion[lessonFirebaseKey] = true;
      _lessonAttemptCounts = currentAttempts;
    });
  }

  @override
  void dispose() {
    if (mounted) {
      _youtubeController.pause();
      _youtubeController.dispose();
    }
    flutterTts.stop();
    super.dispose();
    _logger.i('Disposed Module3Page');
  }

  @override
  Widget build(BuildContext context) {
    if (!_isContentLoaded) return Scaffold(appBar: AppBar(title: const Text('Module 3')), body: const Center(child: CircularProgressIndicator()));
    int initialAttemptForChild = _lessonAttemptCounts['lesson$currentLesson'] ?? 0;
    return Scaffold(
      appBar: AppBar(title: Text(currentLesson == 1 ? 'Module 3: Listening Comprehension' : 'Module 3: Speaking Practice'), leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(child: _buildLessonContentWidget(initialAttemptForChild)),
            if (_isSubmittingToServer) Container(color: Colors.black54, child: const Center(child: CircularProgressIndicator())),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonContentWidget(int initialAttemptNumberForLesson) {
    VoidCallback onShowActivityCallback = () {
      if (mounted) {
        setState(() {
          showActivitySection = true;
          _shouldDisplayFeedbackCurrentLesson = false;
          _aiFeedbackDataCurrentLesson = null;
          _aiFeedbackModelsCurrentLesson = null;
          _overallScoreCurrentLesson = null;
          _maxScoreCurrentLesson = null;
          _resetUIForCurrentLesson();
        });
      }
    };

    switch (currentLesson) {
      case 1:
        return BuildLesson3_1(
          parentContext: context,
          currentSlide: _currentSlide,
          carouselController: _carouselController,
          youtubeController: _youtubeController,
          youtubePlayerKey: ValueKey('yt_m3_l1_${_videoIds[1]}'),
          showActivitySectionInitially: showActivitySection,
          onShowActivitySection: onShowActivityCallback,
          onSubmitAnswers: _handleSubmitLesson3_1,
          onSlideChanged: (index) => setState(() => _currentSlide = index),
          initialAttemptNumber: initialAttemptNumberForLesson,
          displayFeedback: _shouldDisplayFeedbackCurrentLesson,
          aiFeedbackData: _aiFeedbackDataCurrentLesson,
          overallAIScoreForDisplay: _overallScoreCurrentLesson,
          maxPossibleAIScoreForDisplay: _maxScoreCurrentLesson,
        );
      case 2:
        return buildLesson3_2(
          parentContext: context,
          showActivitySectionInitially: showActivitySection,
          onShowActivitySection: onShowActivityCallback,
          initialAttemptNumber: initialAttemptNumberForLesson,
          displayFeedback: _shouldDisplayFeedbackCurrentLesson,
          onProcessAudioPrompt: _handleProcessAudioPromptL3_2,
          onExplainAzureFeedback: _handleExplainAzureFeedbackL3_2,
          onSubmitLesson: _handleSubmitLessonL3_2,
        );
      default:
        _logger.w('Module 3: Invalid lesson number: $currentLesson');
        return Center(child: Text('Error: Invalid lesson $currentLesson'));
    }
  }
}