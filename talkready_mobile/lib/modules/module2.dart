// module2.dart

import 'package:flutter/material.dart' hide CarouselController;
import 'package:carousel_slider/carousel_slider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:logger/logger.dart';
import 'dart:convert'; // For jsonEncode and jsonDecode
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart'; // For Timestamp, FieldValue

import '../firebase_service.dart';
// Import your TEXT-INPUT BASED lesson widgets for Module 2
import '../lessons/lesson2_1.dart';
import '../lessons/lesson2_2.dart';
import '../lessons/lesson2_3.dart';

class Module2Page extends StatefulWidget {
  final String? targetLessonKey;

  const Module2Page({super.key, this.targetLessonKey});

  @override
  State<Module2Page> createState() => _Module2PageState();
}

class _Module2PageState extends State<Module2Page> {
  final Logger _logger = Logger();
  final FirebaseService _firebaseService = FirebaseService();

  int currentLesson = 1;
  bool showActivitySectionForLesson = false;

  late YoutubePlayerController _youtubeController;
  int _currentSlide = 0;
  final CarouselSliderController _carouselController =
      CarouselSliderController();

  String? _youtubeError;
  bool _isContentLoaded = false;
  bool _isSubmittingLesson = false;

  Map<String, dynamic>? _currentLessonFullData;
  Map<String, dynamic>? _aiFeedbackForCurrentLessonAttempt;
  int? _overallAIScoreForCurrentAttempt;
  int? _maxPossibleAIScoreForCurrentLesson;
  bool _shouldDisplayFeedbackForCurrentLesson = false;

  Map<String, bool> _module2LessonCompletion = {
    'lesson1': false,
    'lesson2': false,
    'lesson3': false
  };
  Map<String, int> _lessonSpecificAttemptCounts = {};
  Map<String, int> _moduleLevelLessonAttemptCounts = {};

  final Map<int, String> _lessonNumericToFirestoreKey = {
    1: "Lesson 2.1",
    2: "Lesson 2.2",
    3: "Lesson 2.3",
  };
  final Map<int, String> _lessonNumericToContentDocId = {
    1: "lesson_2_1",
    2: "lesson_2_2",
    3: "lesson_2_3",
  };
  final Map<int, String> _lessonNumericToModuleKey = {
    1: "lesson1",
    2: "lesson2",
    3: "lesson3",
  };

  final Map<int, String> _hardcodedVideoIdsM2 = {
    1: 'LRJXMKZ4wOw', // Video ID for Lesson 2.1
    2: 'bQ90ZCNFuq0', // Video ID for Lesson 2.2
    3: 'ug-xjtExqKA', // << REPLACE WITH ACTUAL 11-char ID for Lesson 2.3
  };

  // This map is NOT used if video URLs are fetched from Firestore. Kept for reference if needed as fallback.
  // final Map<int, String> _videoIdsM2 = { /* ... */ };
  final Map<String, Map<String, dynamic>> _loadedLessonData = {};

  @override
  void initState() {
    super.initState();
    _logger
        .i("Module2Page initState. TargetLessonKey: ${widget.targetLessonKey}");
    // Initialize with a dummy/default valid ID. It will be updated in _performAsyncInit.
    _youtubeController = YoutubePlayerController(
      initialVideoId: 'LRJXMKZ4wOw', // Placeholder, will be updated
      flags: const YoutubePlayerFlags(
          autoPlay: false, mute: false, enableCaption: true),
    );
    _youtubeController.addListener(_youtubePlayerListener);
    _performAsyncInit();
  }

  void _youtubePlayerListener() {
    if (_youtubeController.value.errorCode != 0 && mounted) {
      setStateIfMounted(() {
        _youtubeError =
            'YouTube Player Error: ${_youtubeController.value.errorCode}';
        _logger.e('Module 2 YT Error: ${_youtubeController.value.errorCode}');
      });
    }
  }

  Future<void> _performAsyncInit() async {
    if (!mounted) return;
    setStateIfMounted(() {
      _isContentLoaded = false;
      _youtubeError = null;
    });

    try {
      await _loadOverallModuleProgress(); // Determines currentLesson
      // This still loads other lesson content (slides, prompts) from Firebase if configured,
      // or the lesson files use their own internal hardcoded data for that.
      await _loadFullLessonContentForCurrent();

      // Directly use the hardcoded video ID for the current lesson
      String? videoIdToUse = _hardcodedVideoIdsM2[currentLesson];
      _logger.i(
          "Module 2 _performAsyncInit: Using hardcoded video ID for lesson $currentLesson: $videoIdToUse");

      _updateYoutubeControllerWithVideoId(videoIdToUse); // Use the new method

      if (mounted) {
        setStateIfMounted(() {
          final currentLessonModuleKey =
              _lessonNumericToModuleKey[currentLesson]!;
          showActivitySectionForLesson =
              _module2LessonCompletion[currentLessonModuleKey] ?? false;
          _shouldDisplayFeedbackForCurrentLesson = false;
          _aiFeedbackForCurrentLessonAttempt = null;
          _overallAIScoreForCurrentAttempt = null;
          _isContentLoaded = true;
        });
      }
    } catch (error, stackTrace) {
      _logger.e("Error during Module 2 performAsyncInit: $error",
          error: error, stackTrace: stackTrace);
      if (mounted) {
        setStateIfMounted(() {
          _youtubeError = "Failed to load lesson. Please try again.";
          _isContentLoaded = true;
        });
      }
    }
  }

  void _updateYoutubeControllerWithVideoId(String? videoId) {
    _logger.i(
        "Module 2 _updateYoutubeControllerWithVideoId received ID: '$videoId'");

    String videoIdToLoad = videoId ?? '';

    if (videoIdToLoad.isEmpty) {
      _logger.w(
          'Module 2: videoIdToLoad is empty. An error will be shown or player will be blank.');
      if (mounted) {
        final oldController = _youtubeController;
        oldController.removeListener(_youtubePlayerListener);
        oldController.pause();

        _youtubeController = YoutubePlayerController(
          initialVideoId: '', // Load empty to show error or clear player
          flags: const YoutubePlayerFlags(
              autoPlay: false,
              mute: false,
              hideControls: false,
              enableCaption: true),
        );
        _youtubeController.addListener(_youtubePlayerListener);

        setStateIfMounted(() {
          _youtubeError =
              'Video not available or video ID is invalid for this lesson.';
        });

        // Dispose the very old controller after a short delay.
        Future.delayed(
            const Duration(milliseconds: 100), () => oldController.dispose());
      }
      return; // Exit if no valid ID.
    }

    // Proceed only if videoIdToLoad is available and different, or if there was an error previously
    if (_youtubeController.metadata.videoId == videoIdToLoad &&
        _youtubeError == null) {
      _logger.i(
          'Module 2: VideoId "$videoIdToLoad" is already loaded and no error. No change needed.');
      return;
    }

    _logger.i(
        'Module 2: Creating new YoutubePlayerController for videoId: "$videoIdToLoad"');
    final oldController = _youtubeController;
    oldController.removeListener(_youtubePlayerListener);
    oldController.pause();

    _youtubeController = YoutubePlayerController(
      initialVideoId: videoIdToLoad,
      flags: const YoutubePlayerFlags(
        autoPlay: false,
        mute: false,
        enableCaption: true,
        hideControls: false,
      ),
    );
    _youtubeController.addListener(_youtubePlayerListener);

    if (mounted) {
      setStateIfMounted(() {
        _youtubeError = null; // Clear any previous error
      });
    }
    Future.delayed(
        const Duration(milliseconds: 100), () => oldController.dispose());
  }

  // --- Methods related to fetching and saving progress (mostly from your last version) ---
  Future<void> _loadOverallModuleProgress() async {
    if (_firebaseService.userId == null) {
      _logger.w("Module 2: User not logged in, using defaults for progress.");
      _setDefaultProgressStates();
      // This call is okay here for initial setup or if user is not logged in.
      _determineCurrentLessonFromProgressFlags();
      return;
    }
    try {
      final moduleProgressData =
          await _firebaseService.getModuleProgress('module2');
      final lessonsCompletionData =
          moduleProgressData['lessons'] as Map<String, dynamic>? ?? {};
      final moduleAttemptsData =
          moduleProgressData['attempts'] as Map<String, dynamic>? ?? {};

      _module2LessonCompletion = {
        _lessonNumericToModuleKey[1]!:
            lessonsCompletionData[_lessonNumericToModuleKey[1]!] ?? false,
        _lessonNumericToModuleKey[2]!:
            lessonsCompletionData[_lessonNumericToModuleKey[2]!] ?? false,
        _lessonNumericToModuleKey[3]!:
            lessonsCompletionData[_lessonNumericToModuleKey[3]!] ?? false,
      };
      _moduleLevelLessonAttemptCounts = {
        _lessonNumericToModuleKey[1]!:
            moduleAttemptsData[_lessonNumericToModuleKey[1]!] as int? ?? 0,
        _lessonNumericToModuleKey[2]!:
            moduleAttemptsData[_lessonNumericToModuleKey[2]!] as int? ?? 0,
        _lessonNumericToModuleKey[3]!:
            moduleAttemptsData[_lessonNumericToModuleKey[3]!] as int? ?? 0,
      };

      final userProgressDoc = await FirebaseFirestore.instance
          .collection('userProgress')
          .doc(_firebaseService.userId)
          .get();
      if (userProgressDoc.exists) {
        final data = userProgressDoc.data();
        final lessonAttemptsMap =
            data?['lessonAttempts'] as Map<String, dynamic>?;
        _lessonNumericToFirestoreKey.forEach((lessonNum, firestoreKey) {
          _lessonSpecificAttemptCounts[firestoreKey] =
              (lessonAttemptsMap?[firestoreKey] as List<dynamic>?)?.length ?? 0;
        });
      } else {
        _lessonNumericToFirestoreKey.forEach((_, firestoreKey) {
          _lessonSpecificAttemptCounts[firestoreKey] = 0;
        });
      }
      // This call is fine on successful load. It will either determine the initial lesson
      // or confirm the current lesson based on fresh progress data. If currentLesson was
      // explicitly changed by "Next Lesson" button, this will re-evaluate based on latest
      // progress and ideally still land on the intended lesson or the actual next incomplete one.
      _determineCurrentLessonFromProgressFlags();
      _logger.i(
          'Module 2 Progress Loaded: currentLesson=$currentLesson, completion=$_module2LessonCompletion, specificAttempts=$_lessonSpecificAttemptCounts');
    } catch (e, s) {
      _logger.e('Module 2: Error loading overall progress: $e',
          error: e, stackTrace: s);
      _setDefaultProgressStates(); // Reset local completion flags to default (all false) if server data is inaccessible.
      // DO NOT call _determineCurrentLessonFromProgressFlags() here.
      // This prevents currentLesson from being reset to 1 if it was already changed
      // by user navigation (e.g., to 2) before this error occurred.
      // The UI will proceed with the 'currentLesson' value set by the navigation,
      // and 'showActivitySectionForLesson' will be determined by the (now default/false)
      // '_module2LessonCompletion' flags, which is acceptable behavior.
      _logger.w(
          'Module 2: Using default progress states due to error, but preserving current navigation target if any.');
    }
  }

  void _setDefaultProgressStates() {
    _module2LessonCompletion = {
      _lessonNumericToModuleKey[1]!: false,
      _lessonNumericToModuleKey[2]!: false,
      _lessonNumericToModuleKey[3]!: false
    };
    _lessonNumericToFirestoreKey.forEach((_, firestoreKey) {
      _lessonSpecificAttemptCounts[firestoreKey] = 0;
    });
    _moduleLevelLessonAttemptCounts = {
      _lessonNumericToModuleKey[1]!: 0,
      _lessonNumericToModuleKey[2]!: 0,
      _lessonNumericToModuleKey[3]!: 0
    };
  }

  void _determineCurrentLessonFromProgressFlags() {
    if (widget.targetLessonKey != null) {
      final targetNum = _lessonNumericToModuleKey.entries
          .firstWhere((entry) => entry.value == widget.targetLessonKey,
              orElse: () => const MapEntry(0, ""))
          .key;
      if (targetNum >= 1 && targetNum <= 3) {
        currentLesson = targetNum;
        return;
      }
    }
    if (!(_module2LessonCompletion[_lessonNumericToModuleKey[1]!] ?? false))
      currentLesson = 1;
    else if (!(_module2LessonCompletion[_lessonNumericToModuleKey[2]!] ??
        false))
      currentLesson = 2;
    else if (!(_module2LessonCompletion[_lessonNumericToModuleKey[3]!] ??
        false))
      currentLesson = 3;
    else
      currentLesson = 3;
  }

  Future<void> _loadFullLessonContentForCurrent() async {
    if (!mounted) return;
    final String lessonContentDocId =
        _lessonNumericToContentDocId[currentLesson]!;
    final String firestoreKey = _lessonNumericToFirestoreKey[currentLesson]!;

    if (_loadedLessonData[firestoreKey] == null) {
      _logger.i(
          "Module 2: Loading full content for $firestoreKey (doc: $lessonContentDocId)");
      setStateIfMounted(() {
        _currentLessonFullData = null;
      });

      final content =
          await _firebaseService.getLessonContent(lessonContentDocId);
      if (mounted) {
        setStateIfMounted(() {
          if (content != null) {
            _loadedLessonData[firestoreKey] = content;
            _currentLessonFullData = content;
            final prompts = _currentLessonFullData?['activity']?['prompts']
                    as List<dynamic>? ??
                [];
            _maxPossibleAIScoreForCurrentLesson =
                _currentLessonFullData?['activity']?['maxPossibleAIScore']
                        as int? ??
                    (prompts.length * 5);
          } else {
            _currentLessonFullData = {};
            _maxPossibleAIScoreForCurrentLesson = 0;
          }
        });
      }
    } else {
      if (mounted)
        setStateIfMounted(() {
          _currentLessonFullData = _loadedLessonData[firestoreKey];
          final prompts = _currentLessonFullData?['activity']?['prompts']
                  as List<dynamic>? ??
              [];
          _maxPossibleAIScoreForCurrentLesson =
              _currentLessonFullData?['activity']?['maxPossibleAIScore']
                      as int? ??
                  (prompts.length * 5);
        });
    }
  }

  void setStateIfMounted(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  Future<Map<String, dynamic>?> _getAiFeedbackFromServer({
    required Map<String, String> userScenarioAnswers,
    required String lessonIdForServer,
  }) async {
    final String serverUrl =
        'http://192.168.208.38:5000/evaluate-scenario'; // TODO: Replace with your actual IP or use a config
    _logger.i(
        'Sending to AI server ($serverUrl) for $lessonIdForServer: $userScenarioAnswers');
    try {
      final response = await http
          .post(
            Uri.parse(serverUrl),
            headers: {'Content-Type': 'application/json; charset=UTF-8'},
            body: jsonEncode(
                {'answers': userScenarioAnswers, 'lesson': lessonIdForServer}),
          )
          .timeout(const Duration(seconds: 90));
      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        return responseBody['feedback'] as Map<String, dynamic>?;
      } else {
        _logger.e(
            'AI Server Error. Status: ${response.statusCode}, Body: ${response.body}');
        return null;
      }
    } catch (e, s) {
      _logger.e('Error calling AI server: $e', error: e, stackTrace: s);
      return null;
    }
  }

  Future<void> _handleLessonSubmission({
    required Map<String, String> userScenarioAnswersFromLesson,
    required int timeSpentFromLesson,
    required int
        initialAttemptNumberOfSession, // This is the count of *previous* attempts for this lesson
  }) async {
    final String firestoreLessonKey =
        _lessonNumericToFirestoreKey[currentLesson]!;
    final String lessonKeyForModuleProgress =
        _lessonNumericToModuleKey[currentLesson]!;

    if (userScenarioAnswersFromLesson.values.any((ans) => ans.trim().isEmpty)) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please answer all scenarios.')));
      return;
    }

    setStateIfMounted(() {
      _isSubmittingLesson = true;
    });

    final Map<String, dynamic>? aiFeedbackMap = await _getAiFeedbackFromServer(
        userScenarioAnswers: userScenarioAnswersFromLesson,
        lessonIdForServer: firestoreLessonKey);

    if (!mounted) return;

    if (aiFeedbackMap == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not get AI feedback. Please try again.')));
      setStateIfMounted(() {
        _isSubmittingLesson = false;
      });
      return;
    }

    int calculatedOverallAIScore = 0;
    aiFeedbackMap.forEach((_, val) {
      if (val is Map && val['score'] is num)
        calculatedOverallAIScore += (val['score'] as num).toInt();
    });

    int maxScore = _maxPossibleAIScoreForCurrentLesson ??
        (_currentLessonFullData?['activity']?['prompts'] as List<dynamic>? ??
                    [])
                .length *
            5;

    int attemptNumberToSave =
        initialAttemptNumberOfSession + 1; // Correct attempt number to save

    Map<String, dynamic> detailedResponsesPayload;
    if (firestoreLessonKey == "Lesson 2.1")
      detailedResponsesPayload = <String, dynamic>{
        'scenarioAnswers_L2_1': userScenarioAnswersFromLesson,
        'scenarioFeedback_L2_1': aiFeedbackMap
      };
    else if (firestoreLessonKey == "Lesson 2.2")
      detailedResponsesPayload = <String, dynamic>{
        'scenarioAnswers_L2_2': userScenarioAnswersFromLesson,
        'scenarioFeedback_L2_2': aiFeedbackMap
      };
    else if (firestoreLessonKey == "Lesson 2.3")
      detailedResponsesPayload = <String, dynamic>{
        'answers': userScenarioAnswersFromLesson,
        'feedbackForEachAnswer': aiFeedbackMap
      };
    else
      detailedResponsesPayload = {
        'userAnswers': userScenarioAnswersFromLesson,
        'aiFeedback': aiFeedbackMap
      };

    try {
      await _firebaseService.saveSpecificLessonAttempt(
          lessonIdKey: firestoreLessonKey,
          score: calculatedOverallAIScore,
          attemptNumberToSave: attemptNumberToSave,
          timeSpent: timeSpentFromLesson,
          detailedResponsesPayload: detailedResponsesPayload);

      if (mounted) {
        setState(() {
          _lessonSpecificAttemptCounts[firestoreLessonKey] =
              attemptNumberToSave;
          _module2LessonCompletion[lessonKeyForModuleProgress] = true;
          _moduleLevelLessonAttemptCounts[lessonKeyForModuleProgress] =
              (_moduleLevelLessonAttemptCounts[lessonKeyForModuleProgress] ??
                      0) +
                  1;
          _aiFeedbackForCurrentLessonAttempt = aiFeedbackMap;
          _overallAIScoreForCurrentAttempt = calculatedOverallAIScore;
          _maxPossibleAIScoreForCurrentLesson =
              maxScore; // Use calculated/fetched max score
          _shouldDisplayFeedbackForCurrentLesson = true;
          showActivitySectionForLesson = true;
        });
        await _saveModuleLessonProgress(currentLesson);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                '$firestoreLessonKey progress saved! Score: $calculatedOverallAIScore/$maxScore')));
      }
    } catch (e, s) {
      _logger.e("Failed to save specific attempt for $firestoreLessonKey: $e",
          error: e, stackTrace: s);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error saving attempt for $firestoreLessonKey: $e')));
    } finally {
      if (mounted)
        setStateIfMounted(() {
          _isSubmittingLesson = false;
        });
    }
  }

  Future<bool> _saveModuleLessonProgress(int lessonNumberInModule) async {
    try {
      final lessonFirebaseKey =
          _lessonNumericToModuleKey[lessonNumberInModule]!;
      Map<String, int> updatedModuleAttempts = Map.from(
          _moduleLevelLessonAttemptCounts); // Already updated in _handleLessonSubmission

      await _firebaseService.updateLessonProgress(
          'module2', lessonFirebaseKey, true,
          attempts: updatedModuleAttempts);
      _logger.i(
          'Module 2: Saved $lessonFirebaseKey module-level progress. Module Attempts: $updatedModuleAttempts');
      return true;
    } catch (e) {
      _logger.e(
          'Module 2: Error saving module-level lesson progress for $lessonNumberInModule : $e');
      return false;
    }
  }

  void _goToNextLesson() async {
    // Or whatever your method for changing lesson is
    // ... (logic to increment currentLesson) ...
    if (mounted) {
      setState(() {
        // currentLesson++; // update currentLesson
        _currentSlide = 0; // RESET slide index for the new lesson
        showActivitySectionForLesson = _module2LessonCompletion[
                _lessonNumericToModuleKey[currentLesson]!] ??
            false;
        _shouldDisplayFeedbackForCurrentLesson = false;
        // DO NOT call _carouselController.jumpToPage(0) here.
      });
      // Then call _loadContentForNavigatedLesson if it handles the rest
      await _loadContentForNavigatedLesson();
    }
  }

  // New method in _Module2PageState:
  Future<void> _loadContentForNavigatedLesson() async {
    if (!mounted) return;

    setStateIfMounted(() {
      _isContentLoaded = false;
      _youtubeError = null;
      _currentSlide =
          0; // Ensure currentSlide is reset BEFORE the new lesson widget builds
    });

    try {
      // The lesson widget (e.g., buildLesson2_2) will use its own hardcoded content
      // via its _fetchLessonContentAndInitialize method.
      // _loadFullLessonContentForCurrent might only be needed if module2.dart
      // needs specific data from the lesson content (like max score) before the lesson widget builds.
      // For now, assuming the lesson widget handles its own content.

      String? videoIdToUse = _hardcodedVideoIdsM2[currentLesson];
      _logger.i(
          "Module 2 _loadContentForNavigatedLesson: Using hardcoded video ID for lesson $currentLesson: $videoIdToUse");
      _updateYoutubeControllerWithVideoId(videoIdToUse);

      if (mounted) {
        setStateIfMounted(() {
          // _currentSlide is already 0. Carousel in child will use this as initialPage.
          // NO _carouselController.jumpToPage(0); needed here.

          final currentLessonModuleKey =
              _lessonNumericToModuleKey[currentLesson]!;
          showActivitySectionForLesson =
              _module2LessonCompletion[currentLessonModuleKey] ?? false;
          _shouldDisplayFeedbackForCurrentLesson = false;
          _aiFeedbackForCurrentLessonAttempt = null;
          _overallAIScoreForCurrentAttempt = null;
          _isContentLoaded = true;
        });
      }
    } catch (error, stackTrace) {
      // ... (your existing error handling) ...
    }
  }

  @override
  void dispose() {
    _logger.i('Disposing Module2Page state.');
    _youtubeController
        .removeListener(_youtubePlayerListener); // Remove the specific listener
    _youtubeController.pause();
    _youtubeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isContentLoaded) {
      return Scaffold(
          appBar: AppBar(title: const Text('Module 2')),
          body: const Center(child: CircularProgressIndicator()));
    }

    bool isModuleCompleted =
        _module2LessonCompletion.values.every((completed) => completed);
    int initialAttemptForChild = _lessonSpecificAttemptCounts[
            _lessonNumericToFirestoreKey[currentLesson]!] ??
        0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
            'Module 2: ${_lessonNumericToFirestoreKey[currentLesson] ?? "Lesson"}',
            style: const TextStyle(fontSize: 16)),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              if (_isSubmittingLesson) const LinearProgressIndicator(),
              Text(
                  'Lesson $currentLesson of 3 (${_lessonNumericToFirestoreKey[currentLesson]})',
                  style: const TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 16),
              if (_youtubeError != null)
                Center(
                    child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(_youtubeError!,
                            style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold)))),
              _buildLessonContentWidget(initialAttemptForChild),
              if (showActivitySectionForLesson &&
                  _shouldDisplayFeedbackForCurrentLesson &&
                  _youtubeError == null) ...[
                const SizedBox(height: 24),
                if (currentLesson < 3)
                  ElevatedButton(
                    onPressed: () {
                      if (mounted) {
                        int nextLessonNumber = currentLesson + 1;
                        if (nextLessonNumber <= 3) {
                          // Assuming 3 lessons in Module 2
                          setState(() {
                            currentLesson = nextLessonNumber;
                            _shouldDisplayFeedbackForCurrentLesson = false;
                            _aiFeedbackForCurrentLessonAttempt = null;
                            _overallAIScoreForCurrentAttempt = null;
                            // Update showActivitySectionForLesson based on the NEW lesson's existing completion status
                            showActivitySectionForLesson =
                                _module2LessonCompletion[
                                        _lessonNumericToModuleKey[
                                            currentLesson]!] ??
                                    false;
                            _currentSlide = 0;
                            if (_carouselController.ready)
                              _carouselController.jumpToPage(0);

                            // Instead of full _performAsyncInit(), trigger specific loading for the new lesson:
                            _isContentLoaded =
                                false; // Show loader while new content loads
                          });
                          // Call a more focused method outside of setState to load content and update UI
                          _loadContentForNavigatedLesson();
                        }
                      }
                    },
                    child: const Text('Next Lesson'),
                  )
                else if (currentLesson == 3)
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: isModuleCompleted
                            ? Colors.green
                            : Theme.of(context).primaryColor),
                    child: Text(isModuleCompleted
                        ? 'Module Completed - Return'
                        : 'Finish Module & Return'),
                  )
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLessonContentWidget(int initialAttemptNumberForUi) {
    if (_currentLessonFullData == null && _isContentLoaded) {
      // Data fetch failed for this lesson
      return Center(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 10),
          Text(
              "Error loading content for ${_lessonNumericToFirestoreKey[currentLesson]}.\nPlease check your connection or try again later.",
              textAlign: TextAlign.center),
          const SizedBox(height: 10),
          ElevatedButton(
              onPressed: _performAsyncInit, child: const Text("Retry Load"))
        ],
      ));
    }
    if (_currentLessonFullData == null) {
      // Still loading initial content (covered by main build _isContentLoaded but safe)
      return const Center(
          child: CircularProgressIndicator(
              semanticsLabel: "Loading lesson details..."));
    }

    final String firestoreKey = _lessonNumericToFirestoreKey[currentLesson]!;

    // This callback is for the "Proceed to Activity" or "Try Again" buttons in the child lesson widget
    VoidCallback onShowActivityCallback = () {
      if (mounted) {
        setState(() {
          showActivitySectionForLesson = true; // Show the input/feedback area
          _shouldDisplayFeedbackForCurrentLesson = false; // Start in input mode
          _aiFeedbackForCurrentLessonAttempt = null; // Clear old feedback
          _overallAIScoreForCurrentAttempt = null; // Clear old score

          // Recalculate max score based on the current lesson's loaded data, if needed for UI
          final List<dynamic> prompts = _currentLessonFullData?['activity']
                  ?['prompts'] as List<dynamic>? ??
              [];
          _maxPossibleAIScoreForCurrentLesson =
              _currentLessonFullData?['activity']?['maxPossibleAIScore']
                      as int? ??
                  (prompts.length * 5);

          // The child lesson widget (e.g., buildLesson2_1) will handle resetting its own timer and text fields
          // when it sees that `displayFeedback` is false and initialAttemptNumber might have changed.
        });
      }
    };

    switch (currentLesson) {
      case 1:
        return buildLesson2_1(
          parentContext: context,
          currentSlide: _currentSlide,
          carouselController: _carouselController,
          youtubeController: _youtubeController,
          showActivitySection: showActivitySectionForLesson,
          onShowActivitySection: onShowActivityCallback,
          onSubmitAnswers:
              (userAnswersMap, timeSpent, initialAttemptNumFromChild) =>
                  _handleLessonSubmission(
            userScenarioAnswersFromLesson: userAnswersMap,
            timeSpentFromLesson: timeSpent,
            // Use the name defined in _handleLessonSubmission's signature:
            initialAttemptNumberOfSession: initialAttemptNumberForUi,
          ),
          onSlideChanged: (index) =>
              setStateIfMounted(() => _currentSlide = index),
          initialAttemptNumber: initialAttemptNumberForUi,
          displayFeedback: _shouldDisplayFeedbackForCurrentLesson,
          aiFeedbackData: _aiFeedbackForCurrentLessonAttempt,
          overallAIScoreForDisplay: _overallAIScoreForCurrentAttempt,
          maxPossibleAIScoreForDisplay: _maxPossibleAIScoreForCurrentLesson,
        );
      case 2:
        return buildLesson2_2(
            parentContext: context,
            currentSlide: _currentSlide,
            carouselController: _carouselController,
            youtubeController: _youtubeController,
            showActivitySection: showActivitySectionForLesson,
            onShowActivitySection: onShowActivityCallback,
            onSubmitAnswers:
                (userAnswersMap, timeSpent, initialAttemptNumFromChild) =>
                    _handleLessonSubmission(
                      userScenarioAnswersFromLesson: userAnswersMap,
                      timeSpentFromLesson: timeSpent,
                      initialAttemptNumberOfSession: initialAttemptNumberForUi,
                    ),
            onSlideChanged: (index) =>
                setStateIfMounted(() => _currentSlide = index),
            initialAttemptNumber: initialAttemptNumberForUi,
            displayFeedback: _shouldDisplayFeedbackForCurrentLesson,
            aiFeedbackData: _aiFeedbackForCurrentLessonAttempt,
            overallAIScoreForDisplay: _overallAIScoreForCurrentAttempt,
            maxPossibleAIScoreForDisplay: _maxPossibleAIScoreForCurrentLesson);
      case 3:
        return buildLesson2_3(
            parentContext: context,
            currentSlide: _currentSlide,
            carouselController: _carouselController,
            youtubeController: _youtubeController,
            showActivitySection: showActivitySectionForLesson,
            onShowActivitySection: onShowActivityCallback,
            onSubmitAnswers:
                (userAnswersMap, timeSpent, initialAttemptNumFromChild) =>
                    _handleLessonSubmission(
                      userScenarioAnswersFromLesson: userAnswersMap,
                      timeSpentFromLesson: timeSpent,
                      initialAttemptNumberOfSession: initialAttemptNumberForUi,
                    ),
            onSlideChanged: (index) =>
                setStateIfMounted(() => _currentSlide = index),
            initialAttemptNumber: initialAttemptNumberForUi,
            displayFeedback: _shouldDisplayFeedbackForCurrentLesson,
            aiFeedbackData: _aiFeedbackForCurrentLessonAttempt,
            overallAIScoreForDisplay: _overallAIScoreForCurrentAttempt,
            maxPossibleAIScoreForDisplay: _maxPossibleAIScoreForCurrentLesson);
      default:
        return Container(child: Text('Error: Invalid lesson $currentLesson'));
    }
  }
}