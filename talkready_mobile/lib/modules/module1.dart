import 'package:flutter/material.dart' hide CarouselController;
import 'package:carousel_slider/carousel_slider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:logger/logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Needed for Timestamp

import '../firebase_service.dart';
import '../lessons/lesson1_1.dart'; // Assuming buildLesson1_1 is correctly defined here
import '../lessons/lesson1_2.dart'; // Assuming buildLesson1_2 is correctly defined here
import '../lessons/lesson1_3.dart'; // Assuming buildLesson1_3 is correctly defined here

class Module1Page extends StatefulWidget {
  final String? targetLessonKey; // To specify which lesson to open

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

  // These lists will be initialized based on the current lesson's question count
  late List<List<String>>
      _selectedAnswers; // For word selection questions (L1.1, L1.2)
  late List<String>
      _fillInBlankAnswers; // For fill-in-the-blank questions (L1.3)
  late List<bool?> _isCorrectStates;
  late List<String?> _errorMessages;

  String? _youtubeError;
  final Logger _logger = Logger();
  final FirebaseService _firebaseService = FirebaseService();

  Map<String, bool> _lessonCompletion = {
    'lesson1': false,
    'lesson2': false,
    'lesson3': false,
  };
  // This map will store the count of *completed* attempts for the detailed log
  late Map<String, int> _lessonSpecificAttemptCounts;

  // This map is for the module-level attempt count that updateLessonProgress uses
  late Map<String, int> _moduleLevelLessonAttemptCounts;

  bool _isContentLoaded = false;

  // Map lesson number to its Firestore key for lessonAttempts
  final Map<int, String> _firestoreLessonKeys = {
    1: "Lesson 1.1",
    2: "Lesson 1.2", // Assuming this pattern
    3: "Lesson 1.3", // Assuming this pattern
  };

  // Map lesson number to its title for the old log system (if you keep it)
  final Map<int, String> _lessonTitlesForOldLog = {
    1: 'Lesson 1.1: Nouns and Pronouns',
    2: 'Lesson 1.2: Simple Sentences',
    3: 'Lesson 1.3: Verb and Tenses (Present Simple)',
  };

  final Map<int, String> _videoIds = {
    1: '0GVcQjDOW6Q', // Lesson 1.1: Nouns and Pronouns
    2: 'LRJXMKZ4wOw', // Lesson 1.2: Simple Sentences
    3: 'LfJPA8GwTdk', // Lesson 1.3: Verb and Tenses (Present Simple)
  };

  @override
  void initState() {
    super.initState();
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
    _performAsyncInit();
  }

  Future<void> _performAsyncInit() async {
    try {
      await _loadLessonProgressAndAttempts();
      _initializeStateListsForCurrentLesson();
      _initializeYoutubeController();

      if (mounted) {
        setState(() {
          String lessonKeyForShowActivity = 'lesson$currentLesson';
          if (widget.targetLessonKey != null &&
              _lessonCompletion.containsKey(widget.targetLessonKey)) {
            lessonKeyForShowActivity = widget.targetLessonKey!;
          }
          showActivity = _lessonCompletion[lessonKeyForShowActivity] ?? false;
          _logger.i(
              "AsyncInit: currentLesson: $currentLesson, targetKey: ${widget.targetLessonKey}, showActivity for '$lessonKeyForShowActivity': $showActivity");
          _isContentLoaded = true;
        });
      }
    } catch (error) {
      _logger.e("Error during initState loading for Module 1: $error");
      if (mounted) {
        setState(() {
          _youtubeError = "Failed to load lesson content. Please try again.";
          _isContentLoaded = true;
        });
      }
    }
  }

  Future<void> _loadLessonProgressAndAttempts() async {
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
      _determineCurrentLessonFromProgress(); // Sets currentLesson based on defaults
      return;
    }

    try {
      // Load module-level progress (completion status, module-level attempts)
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
        // For _saveLessonProgress
        'lesson1': moduleAttemptsData['lesson1'] as int? ?? 0,
        'lesson2': moduleAttemptsData['lesson2'] as int? ?? 0,
        'lesson3': moduleAttemptsData['lesson3'] as int? ?? 0,
      };

      // Load detailed attempt counts from userProgress.lessonAttempts
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

      _determineCurrentLessonFromProgress(); // Sets currentLesson

      _logger.i(
          'Loaded Progress for Module 1: currentLesson=$currentLesson, completion=$_lessonCompletion, specificAttempts=$_lessonSpecificAttemptCounts, moduleAttempts=$_moduleLevelLessonAttemptCounts, targetKey=${widget.targetLessonKey}');
    } catch (e) {
      _logger.e('Error loading all progress for module1: $e');
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
      _determineCurrentLessonFromProgress(); // Sets currentLesson based on defaults
      rethrow;
    }
  }

  void _determineCurrentLessonFromProgress() {
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
              "Unknown targetLessonKey: ${widget.targetLessonKey}. Defaulting to normal progression.");
          _setLessonBySequentialProgress();
      }
    } else {
      _logger.i(
          "No target lesson key. Determining current lesson by sequential progress.");
      _setLessonBySequentialProgress();
    }
  }

  void _setLessonBySequentialProgress() {
    if (!(_lessonCompletion['lesson1'] ?? false)) {
      currentLesson = 1;
    } else if (!(_lessonCompletion['lesson2'] ?? false)) {
      currentLesson = 2;
    } else if (!(_lessonCompletion['lesson3'] ?? false)) {
      currentLesson = 3;
    } else {
      currentLesson = 3; // All complete, default to last
    }
  }

  // This existing method updates the module-level completion and simple attempt count
  Future<bool> _saveModuleLessonProgress(int lessonNumberInModule) async {
    try {
      final lessonFirebaseKey = 'lesson$lessonNumberInModule';
      // Use the _moduleLevelLessonAttemptCounts for this specific type of progress update
      // This map should be incremented *after* a successful attempt if needed for this function
      // Or this function just marks completion and doesn't care about specific counts if it's just a flag.
      // Let's assume this call is primarily to mark the lesson as 'true' in module.lessons.lessonX
      // and the attempt count here is the module-level one which might just be a simple increment.

      // For now, we'll pass the _moduleLevelLessonAttemptCounts as is.
      // It needs to be updated if its meaning is "total attempts taken for this lesson type in this module"
      int newModuleLevelAttemptCount =
          (_moduleLevelLessonAttemptCounts[lessonFirebaseKey] ?? 0) + 1;
      Map<String, int> updatedModuleAttempts =
          Map.from(_moduleLevelLessonAttemptCounts);
      updatedModuleAttempts[lessonFirebaseKey] = newModuleLevelAttemptCount;

      await _firebaseService.updateLessonProgress(
          'module1', lessonFirebaseKey, true,
          attempts: updatedModuleAttempts);

      if (mounted) {
        setState(() {
          _lessonCompletion[lessonFirebaseKey] = true;
          _moduleLevelLessonAttemptCounts =
              updatedModuleAttempts; // Keep local state in sync
        });
      }
      _logger.i(
          'Saved $lessonFirebaseKey as completed for module1 (module-level). Attempts map: $updatedModuleAttempts');
      return true;
    } catch (e) {
      _logger.e(
          'Error saving module-level lesson progress for module1 ($lessonNumberInModule): $e');
      return false;
    }
  }

  void _initializeStateListsForCurrentLesson() {
    int questionCount =
        currentLesson == 3 ? 10 : 8; // L1.1 & L1.2 have 8, L1.3 has 10
    _logger.i(
        'Initializing state lists for Lesson $currentLesson (module1): questionCount=$questionCount');

    _selectedAnswers =
        List<List<String>>.generate(questionCount, (_) => <String>[]);
    _fillInBlankAnswers =
        List<String>.filled(questionCount, ""); // Only for L1.3

    _isCorrectStates = List<bool?>.filled(questionCount, null);
    _errorMessages = List<String?>.filled(questionCount, null);
  }

  void _initializeYoutubeController() {
    String? videoId = _videoIds[currentLesson];
    _logger.i(
        'Initializing YouTube controller for Lesson $currentLesson (module1): videoId=$videoId');
    if (videoId == null || videoId.isEmpty) {
      _logger.w(
          'No video ID for Lesson $currentLesson (module1), controller will use empty ID.');
      videoId = '';
    }
    _youtubeController = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: false,
        mute: false,
        enableCaption: true,
        captionLanguage: 'en',
        hideControls: false,
      ),
    );
    _youtubeController.addListener(() {
      if (_youtubeController.value.errorCode != 0 && mounted) {
        setState(() {
          _youtubeError =
              'Error playing video: ${_youtubeController.value.errorCode}';
        });
        _logger.e(
            'YouTube Player Error (module1): ${_youtubeController.value.errorCode}');
      }
    });
  }

  void _updateYoutubeVideoId() {
    String? videoId = _videoIds[currentLesson];
    _logger.i(
        'Updating YouTube video for Lesson $currentLesson (module1): videoId=$videoId');
    if (videoId != null && videoId.isNotEmpty) {
      try {
        final oldController = _youtubeController;
        // It's important to remove listeners before disposing
        oldController.removeListener(
            () {}); // This needs a specific listener function if you added one with specific logic.
        // For the general error listener, it will be added to the new one.
        oldController.pause(); // Good practice

        // Delay disposal slightly if experiencing issues, though usually direct disposal is fine
        // Future.delayed(Duration(milliseconds: 100), () => oldController.dispose());

        _youtubeController = YoutubePlayerController(
          initialVideoId: videoId,
          flags: const YoutubePlayerFlags(
            autoPlay: false,
            mute: false,
            enableCaption: true,
            captionLanguage: 'en',
            hideControls: false,
          ),
        );
        _youtubeController.addListener(() {
          if (_youtubeController.value.errorCode != 0 && mounted) {
            setState(() {
              _youtubeError =
                  'Error playing video: ${_youtubeController.value.errorCode}';
            });
            _logger.e(
                'YouTube Player Error on update (module1): ${_youtubeController.value.errorCode}');
          }
        });
        // Dispose the old controller *after* the new one is ready or after a short delay
        // This can sometimes help with transition issues on some platforms.
        // For robustness, ensure the old one is truly disposed.
        // If the above dispose causes issues by being too quick, you might keep a reference and dispose later,
        // but typically replacing the controller instance and disposing the old one is the way.
        oldController.dispose(); // Dispose after new one is set up

        if (mounted) {
          setState(() {
            _youtubeError = null;
          });
        }
        _logger.i(
            'Successfully updated YouTube video for Lesson $currentLesson (module1): videoId=$videoId');
      } catch (e) {
        _logger.e(
            'Error loading YouTube video for Lesson $currentLesson (module1): $e');
        if (mounted) {
          setState(() {
            _youtubeError =
                'Failed to load video for Lesson $currentLesson. Please try again.';
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _youtubeError = 'No video available for Lesson $currentLesson';
        });
      }
      _logger.w('No video ID found for Lesson $currentLesson (module1)');
    }
  }

  // This is the callback passed to the lesson widgets.
  // It now incorporates score calculation and calling the new Firebase service method.
  Future<void> _handleLessonSubmission({
    required List<Map<String, dynamic>> questionsData,
    List<String>?
        userAnswersFromLesson1_3, // Specific for Lesson 1.3's fill-in-the-blanks
    required int timeSpentFromLesson,
    // attemptNumberFromLessonWidget is the initialAttemptNumber for that session (0-indexed for current try, or count of past attempts)
    required int attemptNumberFromLessonWidget,
  }) async {
    final String lessonKeyForModuleProgress =
        'lesson$currentLesson'; // e.g., "lesson1"
    final String firestoreLessonKey =
        _firestoreLessonKeys[currentLesson]!; // e.g., "Lesson 1.1"
    final String lessonTitleForOldLog = _lessonTitlesForOldLog[currentLesson]!;

    _logger.i(
        'Handling submission for $firestoreLessonKey. Time: $timeSpentFromLesson s. '
        'Attempt number from lesson widget (initial for this try): $attemptNumberFromLessonWidget');

    // --- 1. Validate all questions answered (example) ---
    bool allAnswered = true;
    if (currentLesson == 1 || currentLesson == 2) {
      // Word selection
      allAnswered = _selectedAnswers.every((answers) => answers.isNotEmpty);
    } else if (currentLesson == 3) {
      // Fill in the blank
      allAnswered = userAnswersFromLesson1_3
              ?.every((answer) => answer.trim().isNotEmpty) ??
          false;
    }
    if (!allAnswered) {
      _logger.w(
          '$firestoreLessonKey submission attempt, but not all questions answered.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Please answer all questions before submitting.')));
      }
      return;
    }

    // --- 2. Calculate Score ---
    int calculatedScore = 0;
    int totalQuestions = questionsData.length;

    if (currentLesson == 1 || currentLesson == 2) {
      // Scoring for Lesson 1.1 and 1.2 (Word Selection)
      if (questionsData.length != _selectedAnswers.length) {
        _logger.e(
            "Score Calc Error: Question data length (${questionsData.length}) != selected answers length (${_selectedAnswers.length}) for $firestoreLessonKey");
      } else {
        for (int i = 0; i < questionsData.length; i++) {
          List<String> selectedWords =
              _selectedAnswers[i].map((e) => e.toLowerCase()).toList();
          String correctAnswerString =
              questionsData[i]['correctAnswer'] as String;
          List<String> correctWords = correctAnswerString
              .split(',')
              .map((e) => e.trim().toLowerCase())
              .toList();

          bool isCorrect = selectedWords.length == correctWords.length &&
              correctWords.every((word) => selectedWords.contains(word)) &&
              selectedWords.every((word) => correctWords.contains(word));
          if (isCorrect) {
            calculatedScore++;
          }
          if (i < _isCorrectStates.length) {
            _isCorrectStates[i] = isCorrect; // Update UI feedback state
          }
          if (i < _errorMessages.length) {
            _errorMessages[i] = isCorrect
                ? null
                : (questionsData[i]['explanation'] ?? 'Incorrect');
          }
        }
      }
    } else if (currentLesson == 3) {
      // Scoring for Lesson 1.3 (Fill-in-the-blank)
      if (userAnswersFromLesson1_3 != null &&
          questionsData.length == userAnswersFromLesson1_3.length) {
        for (int i = 0; i < questionsData.length; i++) {
          String userAnswer = userAnswersFromLesson1_3[i].trim().toLowerCase();

          // CORRECTED PART: Treat correctAnswer as a String
          String correctAnswer =
              (questionsData[i]['correctAnswer'] as String? ?? "")
                  .trim()
                  .toLowerCase();
          // Added '??"" ' for null safety, though your data has it.

          bool isCorrect =
              correctAnswer == userAnswer; // Direct string comparison

          if (isCorrect) {
            calculatedScore++;
          }
          // Update UI feedback states
          if (i < _isCorrectStates.length) _isCorrectStates[i] = isCorrect;
          if (i < _errorMessages.length) {
            _errorMessages[i] = isCorrect
                ? null
                : (questionsData[i]['explanation'] as String? ?? 'Incorrect');
          }
        }
      } else {
        _logger.e(
            "Score Calc Error: Mismatch in question/answer lengths or null userAnswersFromLesson1_3 for Lesson 1.3");
      }
    }

    _logger.i(
        "$firestoreLessonKey Calculated Score: $calculatedScore / $totalQuestions");

    // --- 3. Determine Attempt Number to Save ---
    // _lessonSpecificAttemptCounts stores the number of *already successfully saved* attempts for this specific lesson key.
    int currentCompletedSpecificAttempts =
        _lessonSpecificAttemptCounts[firestoreLessonKey] ?? 0;
    int attemptNumberToSave = currentCompletedSpecificAttempts + 1;

    // --- 4. Log activity using the old system (optional, if you're migrating) ---
    // Consider if you still need this if the new system captures everything.
    /*
    List<Map<String, dynamic>> detailedResponsesForOldLog = questionsData.asMap().entries.map((e) {
      return {
        'question': e.value['question'],
        'userAnswer': currentLesson == 3 ?
                      (e.key < (userAnswersFromLesson1_3?.length ?? 0) ? [userAnswersFromLesson1_3![e.key]] : []) :
                      (e.key < _selectedAnswers.length ? _selectedAnswers[e.key] : []),
        'correct': e.key < _isCorrectStates.length ? _isCorrectStates[e.key] : false,
      };
    }).toList();
    await _firebaseService.logLessonActivity(
        'module1', lessonTitleForOldLog, attemptNumberToSave, calculatedScore, totalQuestions, timeSpentFromLesson, detailedResponsesForOldLog);
    */

    // --- 5. Call new FirebaseService method to save specific attempt details ---
    try {
      await _firebaseService.saveSpecificLessonAttempt(
        lessonIdKey: firestoreLessonKey, // e.g., "Lesson 1.1"
        score: calculatedScore,
        attemptNumberToSave: attemptNumberToSave,
        timeSpent: timeSpentFromLesson,
      );
      _logger.i(
          "Successfully saved specific attempt $attemptNumberToSave for $firestoreLessonKey to lessonAttempts.");

      if (mounted) {
        setState(() {
          // Update local count of completed specific attempts
          _lessonSpecificAttemptCounts[firestoreLessonKey] =
              attemptNumberToSave;

          // Mark lesson as "touched" or "completed" in the module-level progress
          _lessonCompletion[lessonKeyForModuleProgress] = true;

          // Update module-level attempt count (simple increment)
          int newModuleLevelAttemptCount =
              (_moduleLevelLessonAttemptCounts[lessonKeyForModuleProgress] ??
                      0) +
                  1;
          _moduleLevelLessonAttemptCounts[lessonKeyForModuleProgress] =
              newModuleLevelAttemptCount;

          showActivity = true; // Ensure results/feedback section is shown
        });
        // Now update the module-level progress in Firestore (completion flag and simple attempt count)
        await _saveModuleLessonProgress(currentLesson);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '$firestoreLessonKey progress saved! Score: $calculatedScore/$totalQuestions')),
        );
      }
    } catch (e) {
      _logger.e("Failed to save specific attempt for $firestoreLessonKey: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Error saving detailed attempt for $firestoreLessonKey: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    // _stopwatch.stop(); // Stopwatch was removed, timer is handled in lesson widgets
    if (_isContentLoaded && _youtubeError == null && mounted) {
      // Check if _youtubeController was initialized
      try {
        _youtubeController.pause();
        _youtubeController.removeListener(() {});
        _youtubeController.dispose();
      } catch (e) {
        _logger.w("Error disposing YouTube controller: $e");
      }
    }
    super.dispose();
    _logger.i('Disposed Module1Page');
  }

  @override
  Widget build(BuildContext context) {
    if (!_isContentLoaded) {
      return Scaffold(
        appBar: AppBar(
            title: const Text('Module 1', style: TextStyle(fontSize: 18))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    bool isModuleCompleted =
        _lessonCompletion.values.every((completed) => completed);
    bool currentLessonIsCompletedForUI =
        _lessonCompletion['lesson$currentLesson'] ?? false;

    // Determine the initial attempt number to pass to the lesson widget
    // This is the count of *previously completed* attempts for this specific lesson.
    int initialAttemptNumberForLessonWidget =
        _lessonSpecificAttemptCounts[_firestoreLessonKeys[currentLesson]!] ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Module 1: Basic English Grammar',
            style: TextStyle(fontSize: 18)),
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF00568D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16.0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Lesson $currentLesson of 3',
                          style: const TextStyle(
                              fontSize: 16, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_youtubeError != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(_youtubeError!,
                          style:
                              const TextStyle(color: Colors.red, fontSize: 16),
                          textAlign: TextAlign.center),
                    ),
                  if (_youtubeError == null)
                    _buildLessonContent(
                        initialAttemptNumberForLessonWidget), // Pass initial attempt number

                  if (showActivity &&
                      currentLessonIsCompletedForUI &&
                      currentLesson < 3 &&
                      _youtubeError == null) ...[
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          _logger.i(
                              'Next Lesson button pressed, switching to Lesson ${currentLesson + 1}');
                          if (mounted) {
                            setState(() {
                              currentLesson++;
                              String newLessonKeyForShowActivity =
                                  'lesson$currentLesson';
                              showActivity = _lessonCompletion[
                                      newLessonKeyForShowActivity] ??
                                  false;
                              _currentSlide = 0;
                              _carouselController.jumpToPage(0);
                              _initializeStateListsForCurrentLesson();
                              _updateYoutubeVideoId();
                              _logger.i(
                                  'Switched to Lesson $currentLesson. showActivity: $showActivity');
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00568D),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Next Lesson',
                            style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                  if (showActivity &&
                      currentLessonIsCompletedForUI &&
                      currentLesson == 3 &&
                      isModuleCompleted &&
                      _youtubeError == null) ...[
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          _logger
                              .i('Module 1 Completed. Returning to Courses.');
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text(
                            'Module Completed - Return to Courses',
                            style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                  if (showActivity &&
                      currentLessonIsCompletedForUI &&
                      currentLesson == 3 &&
                      !isModuleCompleted &&
                      _youtubeError == null) ...[
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          _logger.i(
                              'Last lesson of Module 1 completed. Returning to Courses.');
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00568D),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Finish Module & Return',
                            style: TextStyle(fontSize: 16)),
                      ),
                    ),
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
    // Accept initialAttemptNumber
    // This check might be redundant if _initializeStateListsForCurrentLesson is always called when currentLesson changes.
    int questionCount = currentLesson == 3 ? 10 : 8;
    if (_selectedAnswers.length != questionCount ||
        _isCorrectStates.length != questionCount ||
        _errorMessages.length != questionCount) {
      _logger.w(
          'Re-initializing lists in _buildLessonContent for Lesson $currentLesson');
      _initializeStateListsForCurrentLesson();
    }

    // This is the callback for Lesson 1.1 and 1.2 (word selection)
    onWordsSelectedCallback(int questionIndex, List<String> selectedWords) {
      if (mounted) {
        setState(() {
          if (questionIndex < _selectedAnswers.length) {
            _selectedAnswers[questionIndex] = selectedWords;
            _logger.d(
                'Module 1, Lesson $currentLesson, Q$questionIndex selection updated: $selectedWords');
            if (questionIndex < _isCorrectStates.length) {
              _isCorrectStates[questionIndex] = null;
            }
            if (questionIndex < _errorMessages.length) {
              _errorMessages[questionIndex] = null;
            }
          }
        });
      }
    }

    // This is the callback for Lesson 1.3 (fill-in-the-blank)
    onFillInBlankAnswerChangedCallback(int questionIndex, String answer) {
      if (mounted) {
        setState(() {
          if (questionIndex < _fillInBlankAnswers.length) {
            _fillInBlankAnswers[questionIndex] = answer;
            _logger.d(
                'Module 1, Lesson 1.3, Q$questionIndex answer updated: $answer');
            if (questionIndex < _isCorrectStates.length) {
              _isCorrectStates[questionIndex] = null;
            }
            if (questionIndex < _errorMessages.length) {
              _errorMessages[questionIndex] = null;
            }
          }
        });
      }
    }

    switch (currentLesson) {
      case 1:
        return buildLesson1_1(
          context: context,
          currentSlide: _currentSlide,
          carouselController: _carouselController,
          youtubeController: _youtubeController,
          showActivity: showActivity,
          onShowActivity: () {
            if (mounted) setState(() => showActivity = true);
          },
          selectedAnswers: _selectedAnswers, // For L1.1 word selection
          isCorrectStates: _isCorrectStates,
          errorMessages: _errorMessages,
          onAnswerChanged: (index, isCorrect) {
            /* General feedback if needed */
          },
          onSlideChanged: (index) {
            if (mounted) setState(() => _currentSlide = index);
          },
          onSubmitAnswers: (questions, timeSpent, attemptNumberFromWidget) =>
              _handleLessonSubmission(
            questionsData: questions,
            timeSpentFromLesson: timeSpent,
            attemptNumberFromLessonWidget: attemptNumberFromWidget,
          ),
          onWordsSelected: onWordsSelectedCallback, // Specific to L1.1
          initialAttemptNumber:
              initialAttemptNumberForLessonUi, // Pass the 0-indexed count of previous attempts
        );
      case 2:
        return buildLesson1_2(
          // Ensure buildLesson1_2 uses a similar callback structure
          context: context,
          currentSlide: _currentSlide,
          carouselController: _carouselController,
          youtubeController: _youtubeController,
          showActivity: showActivity,
          onShowActivity: () {
            if (mounted) setState(() => showActivity = true);
          },
          selectedAnswers: _selectedAnswers, // For L1.2 word selection
          isCorrectStates: _isCorrectStates,
          errorMessages: _errorMessages,
          onAnswerChanged: (index, isCorrect) {/* ... */},
          onSlideChanged: (index) {
            if (mounted) setState(() => _currentSlide = index);
          },
          onSubmitAnswers: (questions, timeSpent, attemptNumberFromWidget) =>
              _handleLessonSubmission(
            questionsData: questions,
            timeSpentFromLesson: timeSpent,
            attemptNumberFromLessonWidget: attemptNumberFromWidget,
          ),
          onWordsSelected: onWordsSelectedCallback, // Specific to L1.2
          initialAttemptNumber: initialAttemptNumberForLessonUi,
        );
      case 3:
        return buildLesson1_3(
          // Ensure buildLesson1_3 has a suitable callback
          context: context,
          currentSlide: _currentSlide,
          carouselController: _carouselController,
          youtubeController: _youtubeController,
          showActivity: showActivity,
          onShowActivity: () {
            if (mounted) setState(() => showActivity = true);
          },
          // For Lesson 1.3, _selectedAnswers might not be directly used if it's fill-in-the-blank
          // Instead, you'll collect answers differently.
          // The `_handleLessonSubmission` will need to use `userAnswersFromLesson1_3`

          isCorrectStates: _isCorrectStates,
          errorMessages: _errorMessages,
          onSlideChanged: (index) {
            if (mounted) setState(() => _currentSlide = index);
          },
          onSubmitAnswers: (questions, answersFromL1_3, timeSpent,
                  attemptNumberFromWidget) =>
              _handleLessonSubmission(
            questionsData: questions,
            userAnswersFromLesson1_3:
                answersFromL1_3, // Pass these specific answers
            timeSpentFromLesson: timeSpent,
            attemptNumberFromLessonWidget: attemptNumberFromWidget,
          ),
          initialAttemptNumber: initialAttemptNumberForLessonUi,
        );
      default:
        _logger
            .w('Invalid lesson number: $currentLesson in _buildLessonContent');
        return Container(child: Text('Error: Invalid lesson $currentLesson'));
    }
  }
}