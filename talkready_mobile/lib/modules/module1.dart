import 'dart:async'; // For Timer
import 'dart:math'; // For Random (shuffling)

import 'package:flutter/material.dart' hide CarouselController;
import 'package:carousel_slider/carousel_slider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:logger/logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../firebase_service.dart';
import '../lessons/lesson1_1.dart';
import '../lessons/lesson1_2.dart';
import '../lessons/lesson1_3.dart';

class Module1Page extends StatefulWidget {
  final String? targetLessonKey;

  const Module1Page({super.key, this.targetLessonKey});

  @override
  State<Module1Page> createState() => _Module1PageState();
}

class _Module1PageState extends State<Module1Page> {
  int currentLesson = 1;
  bool showActivity = false;
  late YoutubePlayerController _youtubeController;
  int _currentSlide = 0;
  final CarouselSliderController _carouselController =
      CarouselSliderController();
  final Logger _logger = Logger();
  final FirebaseService _firebaseService = FirebaseService();
  bool _isContentLoaded = false;
  Map<String, dynamic>? _currentLessonData;
  List<Map<String, dynamic>> _activityQuestions = [];
  List<Map<String, dynamic>> _shuffledActivityQuestions = [];
  int _currentQuestionIndex = 0;
  Map<String, String> _mcqAnswers = {};
  Map<String, bool> _flaggedQuestions = {};
  bool _showResults = false;
  int _userScore = 0;
  bool _isActivitySubmitting = false;
  bool _attemptInitialized = false;

  Timer? _activityTimerInstance;
  int _activityTimerValue = 0;
  bool _isActivityTimerActive = false;

  late List<bool?> _isCorrectStates;
  late List<String?> _errorMessages;

  String? _youtubeError;
  Map<String, bool> _lessonCompletion = {
    'lesson1': false,
    'lesson2': false,
    'lesson3': false
  };
  late Map<String, int> _lessonSpecificAttemptCounts;
  late Map<String, int> _moduleLevelLessonAttemptCounts;

  final Map<int, String> _firestoreLessonKeys = {
    1: "Lesson 1.1",
    2: "Lesson 1.2",
    3: "Lesson 1.3"
  };
  final Map<int, String> _firestoreDocumentKeys = {
    1: "lesson_1_1",
    2: "lesson_1_2",
    3: "lesson_1_3"
  };

  @override
  void initState() {
    super.initState();
    _logger.i(
        "Module1Page initState: targetLessonKey = ${widget.targetLessonKey}");
    // Initialize maps, controllers, etc.
    _lessonSpecificAttemptCounts = {
      'Lesson 1.1': 0,
      'Lesson 1.2': 0,
      'Lesson 1.3': 0,
    };
    _moduleLevelLessonAttemptCounts = {
      'lesson1': 0,
      'lesson2': 0,
      'lesson3': 0,
    };
    _youtubeController = YoutubePlayerController(
        initialVideoId: ''); // Initialize with a blank or placeholder
    _isCorrectStates = [];
    _errorMessages = [];

    // Kick off the initial loading sequence
    _initializeModule();
  }

  Future<void> _initializeModule() async {
    _logger.i("Starting _initializeModule. Target: ${widget.targetLessonKey}");
    if (!mounted) return;
    setState(() {
      _isContentLoaded = false;
    }); // Show loading indicator

    await _updateProgressDataForAllLessons(); // Load all progress/completion states first

    // Now that _lessonCompletion is populated, determine the correct initial lesson
    _determineCurrentLessonFromProgress(); // This sets the initial `currentLesson`

    _logger.i(
        "_initializeModule: initial currentLesson decided as $currentLesson. Proceeding to load its content.");
    await _loadContentForCurrentLesson(); // Load and display content for this lesson
  }

  Future<void> _navigateToLesson(int lessonNumber) async {
    if (!mounted) return;
    _logger.i("Navigating to lesson $lessonNumber");

    currentLesson = lessonNumber; // Directly set the target lesson

    // Set loading state and reset lesson-specific UI states
    setState(() {
      _isContentLoaded = false; // Show loading for new lesson content
      _currentSlide = 0; // Reset carousel slide for the new lesson
      _showResults = false; // Don't show results from a previous lesson
      _attemptInitialized =
          false; // Activity for the new lesson needs to be initialized
      // `showActivity` will be determined in _loadContentForCurrentLesson
    });

    // Fetch the latest progress for all lessons to ensure `_lessonCompletion` is up-to-date
    await _updateProgressDataForAllLessons();

    // Load and display content for the new currentLesson
    await _loadContentForCurrentLesson();
  }

  Future<void> _updateProgressDataForAllLessons() async {
    if (_firebaseService.userId == null) {
      _logger.w("User not logged in, cannot load progress. Using defaults.");
      // Initialize default completion and attempt counts if necessary
      _lessonCompletion = {
        'lesson1': false,
        'lesson2': false,
        'lesson3': false
      };
      _lessonSpecificAttemptCounts = {
        'Lesson 1.1': 0,
        'Lesson 1.2': 0,
        'Lesson 1.3': 0
      };
      _moduleLevelLessonAttemptCounts = {
        'lesson1': 0,
        'lesson2': 0,
        'lesson3': 0
      };
      return;
    }

    try {
      final moduleProgressData =
          await _firebaseService.getModuleProgress('module1');
      final lessonsCompletionData =
          moduleProgressData['lessons'] as Map<String, dynamic>? ?? {};
      final moduleAttemptsData =
          moduleProgressData['attempts'] as Map<String, dynamic>? ?? {};

      if (!mounted) return;
      setState(() {
        // Update state if these maps are directly used in build, or just update members
        _lessonCompletion = {
          'lesson1': lessonsCompletionData['lesson1'] ?? false,
          'lesson2': lessonsCompletionData['lesson2'] ?? false,
          'lesson3': lessonsCompletionData['lesson3'] ?? false,
        };
        _moduleLevelLessonAttemptCounts = {
          'lesson1': moduleAttemptsData['lesson1'] as int? ?? 0,
          'lesson2': moduleAttemptsData['lesson2'] as int? ?? 0,
          'lesson3': moduleAttemptsData['lesson3'] as int? ?? 0,
        };
      });

      final userProgressDoc = await FirebaseFirestore.instance
          .collection('userProgress')
          .doc(_firebaseService.userId)
          .get();

      Map<String, int> specificAttempts = {};
      if (userProgressDoc.exists) {
        final data = userProgressDoc.data();
        final lessonAttemptsMap =
            data?['lessonAttempts'] as Map<String, dynamic>?;
        _firestoreLessonKeys.forEach((_, keyString) {
          if (lessonAttemptsMap != null &&
              lessonAttemptsMap.containsKey(keyString)) {
            final attemptsArray =
                lessonAttemptsMap[keyString] as List<dynamic>?;
            specificAttempts[keyString] = attemptsArray?.length ?? 0;
          } else {
            specificAttempts[keyString] = 0;
          }
        });
      } else {
        _firestoreLessonKeys.forEach((_, keyString) {
          specificAttempts[keyString] = 0;
        });
      }
      if (!mounted) return;
      setState(() {
        // Update state if this map is directly used in build, or just update member
        _lessonSpecificAttemptCounts = specificAttempts;
      });

      _logger.i(
          'Updated all progress data. Completion: $_lessonCompletion, SpecificAttempts: $_lessonSpecificAttemptCounts');
    } catch (e) {
      _logger.e('Error loading all progress data: $e');
      // Handle error, perhaps by setting default states or showing an error message
    }
  }

// This function focuses on loading content for the already set `currentLesson`
  Future<void> _loadContentForCurrentLesson() async {
    if (!mounted) return;
    _logger.i("_loadContentForCurrentLesson: Loading for $currentLesson");

    // Set loading state and reset states specific to a lesson's activity
    setState(() {
      _isContentLoaded = false;
      _youtubeError = null;
      _currentLessonData = null;
      _activityQuestions = [];
      _mcqAnswers = {};
      _shuffledActivityQuestions = [];
      _currentQuestionIndex = 0;
      _flaggedQuestions = {};
      // _showResults and _attemptInitialized should have been handled by the caller (_initializeModule or _navigateToLesson)
      // Reset YouTube Player if it's already initialized for a different video
      if (_youtubeController.initialVideoId.isNotEmpty ||
          _youtubeController.value.isReady) {
        // If loading a new lesson, you might want to load a new video or clear the old one.
        // For simplicity, _initializeYoutubeController will handle loading the correct video.
        // Pausing here is a good practice.
        _youtubeController.pause();
      }
    });
    _stopActivityTimer(); // Stop any active timer for the previous lesson's activity

    try {
      final String lessonDocIdToFetch =
          _firestoreDocumentKeys[currentLesson] ?? "";
      _logger.i(
          "Attempting to fetch document ID: '$lessonDocIdToFetch' for currentLesson: $currentLesson");

      if (lessonDocIdToFetch.isNotEmpty) {
        _currentLessonData =
            await _firebaseService.getFullLessonContent(lessonDocIdToFetch);
        _logger.i(
            "Fetched for Lesson $currentLesson ($lessonDocIdToFetch). Title: ${_currentLessonData?['title']}");
      } else {
        throw Exception(
            "Lesson configuration error: No document key for lesson $currentLesson.");
      }

      if (_currentLessonData != null &&
          _currentLessonData!['activity'] is Map &&
          _currentLessonData!['activity']['questions'] is List) {
        _activityQuestions = List<Map<String, dynamic>>.from(
            _currentLessonData!['activity']['questions']);
        _logger.i(
            "Parsed ${_activityQuestions.length} questions for Lesson $currentLesson.");

        // For Lesson 1.3, which manages its own questions internally for display,
        // but _isCorrectStates and _errorMessages are managed by module1 for feedback.
        if (currentLesson == 3) {
          _isCorrectStates =
              List<bool?>.filled(_activityQuestions.length, null);
          _errorMessages =
              List<String?>.filled(_activityQuestions.length, null);
        }
      } else {
        _activityQuestions = [];
        if (currentLesson == 3) {
          // Also clear for lesson 1.3 if no questions
          _isCorrectStates = [];
          _errorMessages = [];
        }
        _youtubeError =
            "Activity content for Lesson $currentLesson is currently unavailable.";
        _logger.w(
            "Activity questions missing or malformed for $lessonDocIdToFetch. Data: $_currentLessonData");
      }

      _initializeYoutubeController(); // Setup YouTube player for the currentLesson

      if (mounted) {
        setState(() {
          final String lessonKey = 'lesson$currentLesson';
          // Determine if the activity should be shown based on the *freshly loaded* completion status
          showActivity = _lessonCompletion[lessonKey] ?? false;
          _logger.i(
              "LoadContent End: Lesson $currentLesson ($lessonKey). showActivity: $showActivity. Questions: ${_activityQuestions.length}");
          _isContentLoaded = true; // Content is loaded, update UI
        });
      }
    } catch (error, stackTrace) {
      _logger.e(
          "Error in _loadContentForCurrentLesson (Lesson $currentLesson): $error",
          error: error,
          stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _youtubeError = "Failed to load content for Lesson $currentLesson.";
          _isContentLoaded = true; // Stop loading, error will be displayed
        });
      }
    }
  }

  Future<void> _performAsyncInit() async {
    _logger.i(
        "Top of _performAsyncInit: currentLesson = $currentLesson, targetLessonKey = ${widget.targetLessonKey}, _isContentLoaded = $_isContentLoaded");
    if (!mounted) return;
    setState(() {
      _isContentLoaded = false; // Show loading
      _youtubeError = null;
      // Don't reset _currentLessonData and _activityQuestions here if _loadLessonProgressAndAttempts might change currentLesson
      // _currentLessonData = null;
      // _activityQuestions = [];
      _mcqAnswers = {}; // Reset answers for any new activity
      _shuffledActivityQuestions = [];
      _currentQuestionIndex = 0;
      _flaggedQuestions = {};
      _showResults = false;
      _userScore = 0;
      _attemptInitialized = false;
      _stopActivityTimer();
    });

    try {
      await _loadLessonProgressAndAttempts(); // This sets/confirms `currentLesson`

      _logger.i(
          "_performAsyncInit: currentLesson is now $currentLesson after _loadLessonProgressAndAttempts.");

      final String lessonDocIdToFetch =
          _firestoreDocumentKeys[currentLesson] ?? "";
      _logger.i(
          "Attempting to fetch document ID: '$lessonDocIdToFetch' for currentLesson: $currentLesson");

      if (lessonDocIdToFetch.isNotEmpty) {
        _currentLessonData =
            await _firebaseService.getFullLessonContent(lessonDocIdToFetch);
        _logger.i(
            "Fetched for Lesson $currentLesson ($lessonDocIdToFetch). Title from data: ${_currentLessonData?['title']}");
      } else {
        throw Exception(
            "Lesson configuration error: No document key for lesson $currentLesson.");
      }

      if (_currentLessonData != null &&
          _currentLessonData!['activity'] is Map &&
          _currentLessonData!['activity']['questions'] is List) {
        _activityQuestions = List<Map<String, dynamic>>.from(
            _currentLessonData!['activity']['questions']);
        _logger.i(
            "Parsed ${_activityQuestions.length} questions for Lesson $currentLesson. First q prompt: ${_activityQuestions.isNotEmpty ? (_activityQuestions[0]['text'] ?? _activityQuestions[0]['promptText']) : 'N/A'}");
      } else {
        _activityQuestions = [];
        _youtubeError =
            "Activity content for Lesson $currentLesson is currently unavailable.";
        _logger.w(
            "Activity questions missing or malformed for $lessonDocIdToFetch. Data: $_currentLessonData");
      }

      _initializeYoutubeController();

      if (mounted) {
        setState(() {
          final String lessonKey = 'lesson$currentLesson';
          showActivity = _lessonCompletion[lessonKey] ?? false;
          _logger.i(
              "AsyncInit End: Lesson $currentLesson ($lessonKey). Fetched ${_activityQuestions.length} questions. showActivity (from completion): $showActivity");
          _isContentLoaded = true;
        });
      }
    } catch (error, stackTrace) {
      _logger.e("Error in _performAsyncInit (Lesson $currentLesson): $error",
          error: error, stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _youtubeError = "Failed to load content for Lesson $currentLesson.";
          _isContentLoaded = true;
        });
      }
    }
  }

  Future<void> _loadLessonProgressAndAttempts() async {
    // ... (Keep your existing implementation)
    // This method calls _determineCurrentLessonFromProgress which sets `currentLesson`
    if (_firebaseService.userId == null) {
      _logger.w("User not logged in, cannot load progress. Using defaults.");
      _lessonCompletion = {
        'lesson1': false,
        'lesson2': false,
        'lesson3': false
      };
      _lessonSpecificAttemptCounts = {
        'Lesson 1.1': 0,
        'Lesson 1.2': 0,
        'Lesson 1.3': 0
      };
      _moduleLevelLessonAttemptCounts = {
        'lesson1': 0,
        'lesson2': 0,
        'lesson3': 0
      };
      _determineCurrentLessonFromProgress();
      return;
    }

    try {
      final moduleProgressData =
          await _firebaseService.getModuleProgress('module1');
      final lessonsCompletionData =
          moduleProgressData['lessons'] as Map<String, dynamic>? ?? {};
      final moduleAttemptsData =
          moduleProgressData['attempts'] as Map<String, dynamic>? ?? {};

      _lessonCompletion = {
        'lesson1': lessonsCompletionData['lesson1'] ?? false,
        'lesson2': lessonsCompletionData['lesson2'] ?? false,
        'lesson3': lessonsCompletionData['lesson3'] ?? false,
      };
      _moduleLevelLessonAttemptCounts = {
        'lesson1': moduleAttemptsData['lesson1'] as int? ?? 0,
        'lesson2': moduleAttemptsData['lesson2'] as int? ?? 0,
        'lesson3': moduleAttemptsData['lesson3'] as int? ?? 0,
      };

      final userProgressDoc = await FirebaseFirestore.instance
          .collection('userProgress')
          .doc(_firebaseService.userId)
          .get();

      if (userProgressDoc.exists) {
        final data = userProgressDoc.data();
        final lessonAttemptsMap =
            data?['lessonAttempts'] as Map<String, dynamic>?;
        _firestoreLessonKeys.forEach((lessonNum, keyString) {
          if (lessonAttemptsMap != null &&
              lessonAttemptsMap.containsKey(keyString)) {
            final attemptsArray =
                lessonAttemptsMap[keyString] as List<dynamic>?;
            _lessonSpecificAttemptCounts[keyString] =
                attemptsArray?.length ?? 0;
          } else {
            _lessonSpecificAttemptCounts[keyString] = 0;
          }
        });
      } else {
        _firestoreLessonKeys.forEach((_, keyString) {
          _lessonSpecificAttemptCounts[keyString] = 0;
        });
      }

      _determineCurrentLessonFromProgress();

      _logger.i(
          'Loaded Progress for Module 1: currentLesson=$currentLesson, completion=$_lessonCompletion, specificAttempts=$_lessonSpecificAttemptCounts, moduleAttempts=$_moduleLevelLessonAttemptCounts, targetKey=${widget.targetLessonKey}');
    } catch (e) {
      _logger.e('Error loading all progress for module1: $e');
      _determineCurrentLessonFromProgress();
      rethrow;
    }
  }

  void _determineCurrentLessonFromProgress() {
    // ... (Keep existing implementation)
    if (widget.targetLessonKey != null) {
      _logger.i("Target lesson key provided: ${widget.targetLessonKey}");
      switch (widget.targetLessonKey) {
        case 'lesson1':
          currentLesson = 1;
          break;
        case 'lesson2':
          currentLesson = 2;
          break;
        case 'lesson3':
          currentLesson = 3;
          break;
        default:
          _logger.w(
              "Unknown targetLessonKey: ${widget.targetLessonKey}. Defaulting.");
          _setLessonBySequentialProgress();
      }
    } else {
      _logger.i(
          "No target lesson key. Determining current lesson by sequential progress.");
      _setLessonBySequentialProgress();
    }
  }

  void _setLessonBySequentialProgress() {
    // ... (Keep existing implementation)
    if (!(_lessonCompletion['lesson1'] ?? false))
      currentLesson = 1;
    else if (!(_lessonCompletion['lesson2'] ?? false))
      currentLesson = 2;
    else if (!(_lessonCompletion['lesson3'] ?? false))
      currentLesson = 3;
    else
      currentLesson = 3;
    _logger.i(
        "_setLessonBySequentialProgress determined currentLesson = $currentLesson");
  }

  void _initializeYoutubeController() {
    // ... (Keep implementation from your last working version that uses _currentLessonData)
    String videoId = "";
    String? errorMsg;

    if (_currentLessonData != null && _currentLessonData!['video'] is Map) {
      final videoMap = _currentLessonData!['video'] as Map;
      if (videoMap['url'] is String && (videoMap['url'] as String).isNotEmpty) {
        String fullUrl = videoMap['url'];
        videoId = YoutubePlayer.convertUrlToId(fullUrl) ?? "";
        if (videoId.isEmpty) {
          errorMsg =
              "Invalid YouTube URL format for Lesson $currentLesson: $fullUrl";
        }
      } else {
        errorMsg = "Video URL is missing or empty for Lesson $currentLesson.";
      }
    } else {
      errorMsg =
          "Video data is missing or not a map for Lesson $currentLesson.";
    }
    _logger.i(
        'Initializing YT for Lesson $currentLesson: videoId="$videoId", errorMsg: $errorMsg');

    if (_youtubeController.initialVideoId.isNotEmpty &&
        _youtubeController.initialVideoId != videoId) {
      _youtubeController
          .dispose(); // Dispose old one IF it was for a different video
      _youtubeController = YoutubePlayerController(
          initialVideoId: videoId.isNotEmpty ? videoId : 'LXb3EKWsInQ',
          flags: const YoutubePlayerFlags(autoPlay: false))
        ..addListener(_youtubePlayerListener);
    } else if (_youtubeController.initialVideoId.isEmpty &&
        videoId.isNotEmpty) {
      _youtubeController = YoutubePlayerController(
          initialVideoId: videoId,
          flags: const YoutubePlayerFlags(autoPlay: false))
        ..addListener(_youtubePlayerListener);
    } else if (videoId.isEmpty) {
      // Handle case where new lesson might have no video
      _youtubeController
          .load('LXb3EKWsInQ'); // Load placeholder or handle UI differently
    }
    // If controller exists and videoId is the same, just ensure it's reset if needed
    // _youtubeController.seekTo(Duration.zero); _youtubeController.pause();

    if (mounted)
      setState(() {
        _youtubeError = errorMsg;
      });
  }

  void _youtubePlayerListener() {
    // ... (Keep implementation from your last working version)
    if (!mounted) return;
    if (_youtubeController.value.hasError) {
      _logger.e(
          'YT Error (L$currentLesson): Code ${_youtubeController.value.errorCode}');
      if (mounted &&
          (_youtubeError == null ||
              !_youtubeError!.contains('Error playing video'))) {
        setState(() => _youtubeError =
            'Error playing video: Code ${_youtubeController.value.errorCode}.');
      }
    } else if (_youtubeError != null &&
        _youtubeError!.contains('Error playing video') &&
        !_youtubeController.value.hasError) {
      if (mounted) setState(() => _youtubeError = null);
    }
  }

  List<T> _shuffleArray<T>(List<T> array) {
    // ... (Keep implementation)
    if (array.isEmpty) return [];
    final newArray = List<T>.from(array);
    final random = Random();
    for (int i = newArray.length - 1; i > 0; i--) {
      int j = random.nextInt(i + 1);
      T temp = newArray[i];
      newArray[i] = newArray[j];
      newArray[j] = temp;
    }
    return newArray;
  }

  void _startActivityAttempt() {
    // ... (Keep implementation from your last working version)
    _logger.i("Starting new activity attempt for Lesson $currentLesson.");
    if (_currentLessonData == null || _activityQuestions.isEmpty) {
      _logger.w(
          "Cannot start activity: Original lesson data or questions not loaded for Lesson $currentLesson.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Activity content not available.")));
      }
      return;
    }

    List<Map<String, dynamic>> questionsToShuffle =
        List.from(_activityQuestions);
    _shuffledActivityQuestions = _shuffleArray(questionsToShuffle).map((q) {
      List<dynamic> options = q['options'] as List<dynamic>? ?? [];
      return {
        ...q,
        'options':
            _shuffleArray(List<String>.from(options.map((o) => o.toString())))
      };
    }).toList();
    _logger.i(
        "Lesson $currentLesson: Shuffled ${_shuffledActivityQuestions.length} questions. First new shuffled Q: ${_shuffledActivityQuestions.isNotEmpty ? (_shuffledActivityQuestions[0]['text'] ?? _shuffledActivityQuestions[0]['promptText']) : 'N/A'}");

    _mcqAnswers = {
      for (var q in _shuffledActivityQuestions)
        if (q['id'] != null) q['id'].toString(): ""
    };
    _currentQuestionIndex = 0;
    _flaggedQuestions = {};
    _showResults = false;
    _userScore = 0;
    _isActivitySubmitting = false;

    int timerDuration =
        _currentLessonData!['activity']?['timerDuration'] as int? ?? 300;
    _activityTimerValue = timerDuration;

    _isCorrectStates =
        List<bool?>.filled(_shuffledActivityQuestions.length, null);
    _errorMessages =
        List<String?>.filled(_shuffledActivityQuestions.length, null);

    _attemptInitialized = true;
    _startActivityTimer();

    if (mounted) setState(() {});
  }

  void _startActivityTimer() {
    /* ... Keep ... */
    _activityTimerInstance?.cancel();
    _isActivityTimerActive = true;
    if (mounted) setState(() {});

    _activityTimerInstance =
        Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isActivityTimerActive || !mounted) {
        timer.cancel();
        return;
      }
      if (_activityTimerValue > 0) {
        setState(() => _activityTimerValue--);
      } else {
        timer.cancel();
        _isActivityTimerActive = false;
        if (!_showResults) {
          _logger.i("Timer ended (L$currentLesson). Auto-submitting.");
          _handleFinalSubmit();
        }
      }
    });
  }

  void _stopActivityTimer() {
    /* ... Keep ... */
    _activityTimerInstance?.cancel();
    _isActivityTimerActive = false;
    _logger.i("Activity timer stopped (L$currentLesson).");
    if (mounted) setState(() {});
  }

  void _handleOptionSelected(String questionId, String selectedOption) {
    /* ... Keep ... */
    if (_showResults || !_isActivityTimerActive) return;
    if (mounted) setState(() => _mcqAnswers[questionId] = selectedOption);
  }

  void _handleNextQuestion() {
    /* ... Keep ... */
    if (_currentQuestionIndex < _shuffledActivityQuestions.length - 1) {
      if (mounted) setState(() => _currentQuestionIndex++);
    }
  }

  void _handlePreviousQuestion() {
    /* ... Keep ... */
    if (_currentQuestionIndex > 0) {
      if (mounted) setState(() => _currentQuestionIndex--);
    }
  }

  void _handleToggleFlag(String questionId) {
    /* ... Keep ... */
    if (_showResults) return;
    if (mounted)
      setState(() => _flaggedQuestions[questionId] =
          !(_flaggedQuestions[questionId] ?? false));
  }

  void _handleGoToNextFlagged() {
    /* ... Keep ... */
    if (_showResults ||
        _flaggedQuestions.isEmpty ||
        _shuffledActivityQuestions.isEmpty) return;
    int searchStartIndex = _currentQuestionIndex + 1;
    for (int i = 0; i < _shuffledActivityQuestions.length; i++) {
      int actualIndex =
          (searchStartIndex + i) % _shuffledActivityQuestions.length;
      String? qId = _shuffledActivityQuestions[actualIndex]['id']?.toString();
      if (qId != null &&
          (_flaggedQuestions[qId] ?? false) &&
          actualIndex != _currentQuestionIndex) {
        if (mounted) setState(() => _currentQuestionIndex = actualIndex);
        return;
      }
    }
    String? currentQId = _shuffledActivityQuestions.isNotEmpty
        ? _shuffledActivityQuestions[_currentQuestionIndex]['id']?.toString()
        : null;
    if (currentQId != null &&
        (_flaggedQuestions[currentQId] ?? false) &&
        _flaggedQuestions.values.where((f) => f).length == 1) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("This is the only flagged question.")));
    } else if (_flaggedQuestions.values.where((f) => f).isNotEmpty) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Cycled through flagged questions.")));
    }
  }

  Future<void> _handleFinalSubmit() async {
    // ... (Keep implementation from your last working version which calls _handleLessonSubmission)
    if (_isActivitySubmitting || _showResults) return;
    _logger.i("Final submit for Lesson $currentLesson.");
    _stopActivityTimer();
    if (mounted) setState(() => _isActivitySubmitting = true);

    int score = 0;
    int totalQs = _shuffledActivityQuestions.length;
    List<bool?> newIsCorrectStates =
        List<bool?>.filled(totalQs, null, growable: true);
    List<String?> newErrorMessages =
        List<String?>.filled(totalQs, null, growable: true);

    for (int i = 0; i < totalQs; i++) {
      Map<String, dynamic> question = _shuffledActivityQuestions[i];
      String qId = question['id'].toString();
      String? userAnswer = _mcqAnswers[qId];
      String correctAnswer = question['correctAnswer'].toString();
      if (userAnswer != null &&
          userAnswer.isNotEmpty &&
          userAnswer == correctAnswer) {
        score++;
        if (i < newIsCorrectStates.length) newIsCorrectStates[i] = true;
        if (i < newErrorMessages.length)
          newErrorMessages[i] =
              question['explanation']?.toString() ?? "Correct!";
      } else {
        if (i < newIsCorrectStates.length) newIsCorrectStates[i] = false;
        if (i < newErrorMessages.length)
          newErrorMessages[i] = question['explanation']?.toString() ??
              "Incorrect. Correct: $correctAnswer";
      }
    }
    _userScore = score;
    _isCorrectStates = newIsCorrectStates;
    _errorMessages = newErrorMessages;
    final String firestoreLessonKey = _firestoreLessonKeys[currentLesson]!;
    int currentSpecificAttempts =
        _lessonSpecificAttemptCounts[firestoreLessonKey] ?? 0;
    int timeSpent =
        (_currentLessonData!['activity']?['timerDuration'] as int? ??
                _activityTimerValue) -
            _activityTimerValue;

    await _handleLessonSubmission(
        questionsData: _shuffledActivityQuestions,
        userMCQAnswers: _mcqAnswers,
        timeSpentFromLesson: timeSpent,
        attemptNumberFromLessonWidget: currentSpecificAttempts,
        preCalculatedScore: _userScore);
    if (mounted)
      setState(() {
        _showResults = true;
        _isActivitySubmitting = false;
        _attemptInitialized = false;
      });
  }

  void _handleTryAgain() {
    // ... (Keep implementation from your last working version)
    _logger.i("Try Again for Lesson $currentLesson.");
    if (mounted) {
      setState(() {
        // showActivity should already be true if Try Again is visible
        _attemptInitialized = false; // This will trigger re-initialization
        _showResults = false; // Hide previous results
        // _currentQuestionIndex = 0; // _startActivityAttempt will do this
        // _mcqAnswers.clear(); // _startActivityAttempt will do this
        // _flaggedQuestions.clear(); // _startActivityAttempt will do this
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Ensure build cycle completes before starting attempt
        if (mounted &&
            showActivity &&
            !_attemptInitialized &&
            _activityQuestions.isNotEmpty &&
            !_showResults) {
          _startActivityAttempt();
        }
      });
    }
  }

  Future<void> _handleLessonSubmission({
    /* ... keep existing parameters ... */
    required List<Map<String, dynamic>> questionsData,
    Map<String, String>? userMCQAnswers,
    List<String>? userAnswersFromLesson1_3,
    required int timeSpentFromLesson,
    required int attemptNumberFromLessonWidget,
    int? preCalculatedScore,
  }) async {
    // ... (Keep implementation from your last working version, ensure finalDetailedResponsesPayload uses 'text' or 'promptText')
    final String lessonKeyForModuleProgress = 'lesson$currentLesson';
    final String firestoreLessonKey = _firestoreLessonKeys[currentLesson]!;

    int calculatedScore;
    int totalQuestions = questionsData.length;
    if (preCalculatedScore != null)
      calculatedScore = preCalculatedScore;
    else {
      /* fallback scoring if needed, though _handleFinalSubmit should provide it */ calculatedScore =
          0;
    }

    int attemptNumberToSave = attemptNumberFromLessonWidget + 1;

    List<Map<String, dynamic>> individualQuestionResponses = [];
    if (currentLesson == 3 && userAnswersFromLesson1_3 != null) {
      individualQuestionResponses = questionsData.asMap().entries.map((entry) {
        // questionsData is from L1.3 here
        int idx = entry.key;
        Map<String, dynamic> qData = entry.value;
        String qId = qData['id']?.toString() ?? "l3_q_${idx + 1}";
        String uAnswer = userAnswersFromLesson1_3[idx];
        bool isCorrect = (uAnswer.trim().toLowerCase() ==
            (qData['correctAnswer']?.toString() ?? '').toLowerCase());
        return {
          'questionId': qId,
          'promptText':
              qData['question'] ?? 'N/A', // L1.3 uses 'question' for its prompt
          'userAnswer': uAnswer,
          'correctAnswer': qData['correctAnswer'] ?? 'N/A',
          'isCorrect': isCorrect,
          // 'explanation': qData['explanation'], // Already handled by errorMessages for display
        };
      }).toList();
    } else if (userMCQAnswers != null) {
      // For Lessons 1.1 and 1.2
      individualQuestionResponses = questionsData.asMap().entries.map((entry) {
        // questionsData is _shuffledActivityQuestions here
        Map<String, dynamic> qData = entry.value;
        String qId = qData['id'].toString();
        String? uAnswer = userMCQAnswers[qId];
        return {
          'questionId': qId,
          'promptText': qData['text'] ?? qData['promptText'] ?? 'N/A',
          'userAnswer': uAnswer,
          'correctAnswer': qData['correctAnswer'].toString(),
          'isCorrect': (uAnswer != null &&
              uAnswer.isNotEmpty &&
              uAnswer == qData['correctAnswer'].toString()),
          'options': qData['options'] ?? [],
        };
      }).toList();
    }
    final Map<String, dynamic> finalDetailedResponsesPayload = {
      'overallScore': calculatedScore,
      'totalQuestions': totalQuestions,
      'timeSpent': timeSpentFromLesson,
      'attemptDetails': individualQuestionResponses,
    };

    try {
      await _firebaseService.saveSpecificLessonAttempt(
        lessonIdKey: firestoreLessonKey,
        score: calculatedScore,
        attemptNumberToSave: attemptNumberToSave,
        timeSpent: timeSpentFromLesson,
        detailedResponsesPayload: finalDetailedResponsesPayload,
      );
      if (mounted) {
        setState(() {
          _lessonSpecificAttemptCounts[firestoreLessonKey] =
              attemptNumberToSave;
          _lessonCompletion[lessonKeyForModuleProgress] = true;
          int newModuleLevelAttemptCount =
              (_moduleLevelLessonAttemptCounts[lessonKeyForModuleProgress] ??
                      0) +
                  1;
          _moduleLevelLessonAttemptCounts[lessonKeyForModuleProgress] =
              newModuleLevelAttemptCount;
        });
        await _saveModuleLessonProgress(currentLesson);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                '$firestoreLessonKey saved! Score: $calculatedScore/$totalQuestions')));
      }
    } catch (e) {
      /* error handling */
      _logger.e("Failed to save attempt for $firestoreLessonKey: $e");
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error saving attempt for $firestoreLessonKey: $e')));
    }
  }

  Future<bool> _saveModuleLessonProgress(int lessonNumberInModule) async {
    // ... (Keep implementation)
    try {
      final lessonFirebaseKey = 'lesson$lessonNumberInModule';
      Map<String, int> updatedModuleAttempts = Map.from(
          _moduleLevelLessonAttemptCounts); // Use the already updated count

      await _firebaseService.updateLessonProgress(
          'module1', lessonFirebaseKey, true,
          attempts: updatedModuleAttempts);
      _logger.i(
          'Saved $lessonFirebaseKey as completed (module-level). Attempts: $updatedModuleAttempts');
      return true;
    } catch (e) {
      _logger.e(
          'Error saving module-level progress for L$lessonNumberInModule: $e');
      return false;
    }
  }

  @override
  void dispose() {
    // ... (Keep implementation)
    _logger.i('Disposing Module1Page. Current Lesson: $currentLesson');
    _activityTimerInstance?.cancel();
    try {
      _youtubeController.removeListener(_youtubePlayerListener);
      _youtubeController.dispose();
    } catch (e) {
      _logger.w("Error disposing YT controller: $e");
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ... (Keep implementation, including the crucial "Next Lesson" button logic and _buildLessonContent)
    // Make sure the "Proceed to Activity" button logic correctly triggers _startActivityAttempt
    // And the "Next Lesson" button correctly calls _performAsyncInit after state changes.

    if (!_isContentLoaded) {
      return Scaffold(
          appBar: AppBar(title: const Text('Module 1')),
          body: const Center(child: CircularProgressIndicator()));
    }

    bool isModuleCompleted =
        _lessonCompletion.values.every((completed) => completed);
    bool currentLessonIsCompletedForUI =
        _lessonCompletion['lesson$currentLesson'] ?? false;
    int initialAttemptNumberForLessonWidget =
        _lessonSpecificAttemptCounts[_firestoreLessonKeys[currentLesson]!] ?? 0;

    if (showActivity &&
        !_attemptInitialized &&
        _activityQuestions.isNotEmpty &&
        !_showResults) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            showActivity &&
            !_attemptInitialized &&
            _activityQuestions.isNotEmpty &&
            !_showResults) {
          _logger.i(
              "Build method: Triggering _startActivityAttempt for Lesson $currentLesson");
          _startActivityAttempt();
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentLessonData?['title'] ?? 'Module 1 Lesson',
            style: const TextStyle(fontSize: 18)),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context)),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16.0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Text('Lesson $currentLesson of 3',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: Colors.grey)),
                  const SizedBox(height: 16),

                  if (!showActivity && _currentLessonData != null) ...[
                    // Study Phase
                    if (_currentLessonData!['objectiveText'] != null)
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Card(
                              elevation: 1,
                              child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text("Objective",
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                    color: Theme.of(context)
                                                        .primaryColorDark,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                        const SizedBox(height: 8),
                                        Text(
                                            _currentLessonData!['objectiveText']
                                                .toString(),
                                            style: const TextStyle(
                                                fontSize: 15, height: 1.4)),
                                      ])))),
                    if (_currentLessonData!['introduction'] is Map &&
                        _currentLessonData!['introduction']['paragraph1'] !=
                            null)
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Card(
                              elevation: 1,
                              child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            (_currentLessonData!['introduction']
                                                        ['heading'] ??
                                                    "Introduction")
                                                .toString(),
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                    color: Theme.of(context)
                                                        .primaryColorDark,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                        const SizedBox(height: 8),
                                        Text(
                                            _currentLessonData!['introduction']
                                                    ['paragraph1']
                                                .toString(),
                                            style: const TextStyle(
                                                fontSize: 15, height: 1.4)),
                                      ])))),

                    if (_youtubeError != null)
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(_youtubeError!,
                              style: const TextStyle(
                                  color: Colors.red, fontSize: 16),
                              textAlign: TextAlign.center)),
                    if (_youtubeError == null &&
                        _currentLessonData?['video']?['url'] != null &&
                        (_currentLessonData!['video']['url'] as String)
                            .isNotEmpty)
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: YoutubePlayer(
                              controller: _youtubeController,
                              showVideoProgressIndicator: true)),

                    ElevatedButton(
                      onPressed: () {
                        if (mounted) {
                          setState(() {
                            showActivity = true;
                            _attemptInitialized = false;
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white),
                      child: const Text('Proceed to Activity'),
                    ),
                  ] else if (showActivity) ...[
                    // Activity or Results Phase
                    if (_youtubeError == null && _activityQuestions.isNotEmpty)
                      _buildLessonContent(initialAttemptNumberForLessonWidget)
                    else if (_activityQuestions.isEmpty &&
                        _youtubeError == null)
                      const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text("No activity questions available.",
                              textAlign: TextAlign.center)),

                    if (_showResults) // "Try Again" button is only shown after results
                      Padding(
                        padding: const EdgeInsets.only(top: 20.0),
                        child: ElevatedButton(
                          onPressed: _handleTryAgain,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white),
                          child: const Text('Try Again'),
                        ),
                      ),
                  ],

                  // Navigation to Next Lesson or Finish Module (only if results are shown for current lesson)
                  if (showActivity &&
                      _showResults &&
                      currentLessonIsCompletedForUI) ...[
                    if (currentLesson < 3)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: ElevatedButton(
                          onPressed: () {
                            if (mounted) {
                              int nextLessonNumber = currentLesson + 1;
                              _logger.i(
                                  "Next Lesson button clicked: planning to navigate to $nextLessonNumber");
                              _navigateToLesson(nextLessonNumber);
                            }
                          },
                          child: const Text('Next Lesson'),
                        ),
                      )
                    else if (isModuleCompleted) // Last lesson and module is complete
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green),
                          child: const Text('Module Completed - Return'),
                        ),
                      )
                    else // Last lesson but module not yet fully complete (e.g. if logic allows this state)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Finish Module & Return'),
                        ),
                      )
                  ]
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonContent(int initialAttemptNumberForLessonUi) {
    // ... (Keep implementation from your last working version that passes new props)
    Map<String, dynamic>? currentQData;
    String? currentQId;
    if (showActivity &&
        _shuffledActivityQuestions.isNotEmpty &&
        _currentQuestionIndex < _shuffledActivityQuestions.length) {
      currentQData = _shuffledActivityQuestions[_currentQuestionIndex];
      currentQId = currentQData['id']?.toString();
    } else if (showActivity &&
        _attemptInitialized &&
        _shuffledActivityQuestions.isEmpty &&
        _activityQuestions.isNotEmpty) {
      return const Center(child: Text("Preparing questions..."));
    } else if (showActivity &&
        !_attemptInitialized &&
        _activityQuestions.isNotEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // Props common to all MCQ lessons
    final String? selectedAnswerForCurrentQ =
        currentQId != null ? _mcqAnswers[currentQId] : null;
    final bool isCurrentQFlagged =
        currentQId != null ? (_flaggedQuestions[currentQId] ?? false) : false;
    bool? shouldShowResultsForCurrentQDisplay;
    String? errorMessageForCurrentQDisplay;

    if (_showResults &&
        currentQData != null && // Ensure currentQData is not null
        _currentQuestionIndex <
            _isCorrectStates.length && // Check bounds for _isCorrectStates
        _currentQuestionIndex < _errorMessages.length) {
      // Check bounds for _errorMessages
      shouldShowResultsForCurrentQDisplay =
          _isCorrectStates[_currentQuestionIndex];
      errorMessageForCurrentQDisplay = _errorMessages[_currentQuestionIndex];
    }

    // Dynamic study material props from _currentLessonData
    final List<Map<String, String>>? currentStudySlides =
        _currentLessonData?['slides'] is List
            ? List<Map<String, String>>.from(
                (_currentLessonData!['slides'] as List)
                    .map((slide) => Map<String, String>.from(slide as Map)))
            : null; // Or pass an empty list: [];
    final String? currentLessonTitle = _currentLessonData?['title'] as String?;

    switch (currentLesson) {
      case 1:
        return buildLesson1_1(
          currentSlide: _currentSlide,
          carouselController: _carouselController,
          youtubeController: _youtubeController,
          showActivity: showActivity,
          onShowActivity: () => setState(() {
            showActivity = true;
            _attemptInitialized = false;
          }),
          onSlideChanged: (index) => setState(() => _currentSlide = index),
          currentQuestionData: currentQData,
          selectedAnswerForCurrentQuestion: selectedAnswerForCurrentQ,
          isFlagged: isCurrentQFlagged,
          showResultsForCurrentQuestion: shouldShowResultsForCurrentQDisplay,
          errorMessageForCurrentQuestion: errorMessageForCurrentQDisplay,
          questionIndex: _currentQuestionIndex,
          totalQuestions: _shuffledActivityQuestions.length,
          onOptionSelected: _handleOptionSelected,
          onToggleFlag: _handleToggleFlag,
          onPreviousQuestion: _handlePreviousQuestion,
          onNextQuestion: _handleNextQuestion,
          onSubmitAnswersFromLesson: _handleFinalSubmit,
          isSubmitting: _isActivitySubmitting,
          isFirstQuestion: _currentQuestionIndex == 0,
          isLastQuestion: _shuffledActivityQuestions.isNotEmpty &&
              _currentQuestionIndex == _shuffledActivityQuestions.length - 1,
          secondsElapsed: _activityTimerValue,
          initialAttemptNumber: initialAttemptNumberForLessonUi,
          context: context,
        );
      case 2:
        return buildLesson1_2(
          // Now uses the refactored lesson1_2.dart
          currentSlide: _currentSlide, carouselController: _carouselController,
          youtubeController: _youtubeController,
          showActivity: showActivity,
          onShowActivity: () => setState(() {
            showActivity = true;
            _attemptInitialized = false;
          }),
          onSlideChanged: (index) => setState(() => _currentSlide = index),
          currentQuestionData: currentQData,
          selectedAnswerForCurrentQuestion: selectedAnswerForCurrentQ,
          isFlagged: isCurrentQFlagged,
          showResultsForCurrentQuestion: shouldShowResultsForCurrentQDisplay,
          errorMessageForCurrentQuestion: errorMessageForCurrentQDisplay,
          questionIndex: _currentQuestionIndex,
          totalQuestions: _shuffledActivityQuestions.length,
          onOptionSelected: _handleOptionSelected,
          onToggleFlag: _handleToggleFlag,
          onPreviousQuestion: _handlePreviousQuestion,
          onNextQuestion: _handleNextQuestion,
          onSubmitAnswersFromLesson: _handleFinalSubmit,
          isSubmitting: _isActivitySubmitting,
          isFirstQuestion: _currentQuestionIndex == 0,
          isLastQuestion: _shuffledActivityQuestions.isNotEmpty &&
              _currentQuestionIndex == _shuffledActivityQuestions.length - 1,
          secondsElapsed: _activityTimerValue,
          initialAttemptNumber: initialAttemptNumberForLessonUi,
        );
      case 3: // Updated case for Lesson 1.3 as MCQ
        return buildLesson1_3(
          currentSlide: _currentSlide,
          carouselController: _carouselController,
          youtubeController: _youtubeController,
          showActivity: showActivity,
          onShowActivity: () => setState(() {
            showActivity = true;
            _attemptInitialized = false;
          }),
          onSlideChanged: (index) => setState(() => _currentSlide = index),
          studySlides:
              currentStudySlides, // Pass dynamic slides from _currentLessonData
          lessonTitle:
              currentLessonTitle, // Pass dynamic title from _currentLessonData
          // MCQ Activity Props:
          currentQuestionData: currentQData,
          selectedAnswerForCurrentQuestion: selectedAnswerForCurrentQ,
          isFlagged: isCurrentQFlagged,
          showResultsForCurrentQuestion: shouldShowResultsForCurrentQDisplay,
          errorMessageForCurrentQuestion: errorMessageForCurrentQDisplay,
          questionIndex: _currentQuestionIndex,
          totalQuestions: _shuffledActivityQuestions.length,
          onOptionSelected: _handleOptionSelected, // Use the common MCQ handler
          onToggleFlag: _handleToggleFlag,
          onPreviousQuestion: _handlePreviousQuestion,
          onNextQuestion: _handleNextQuestion,
          onSubmitAnswersFromLesson:
              _handleFinalSubmit, // Use the common submission trigger
          isSubmitting: _isActivitySubmitting,
          isFirstQuestion: _currentQuestionIndex == 0,
          isLastQuestion: _shuffledActivityQuestions.isNotEmpty &&
              _currentQuestionIndex == _shuffledActivityQuestions.length - 1,
          secondsElapsed: _activityTimerValue,
          initialAttemptNumber: initialAttemptNumberForLessonUi,
          // No 'context' prop needed for buildLesson1_3 as per the refactored version.
          // No 'isCorrectStates' or 'errorMessages' lists needed directly by buildLesson1_3.
          // No 'onSubmitAnswers' with the old fill-in-the-blank signature.
        );
      default:
        return const Center(
            child: Text("Lesson content loading or unavailable."));
    }
  }
}
