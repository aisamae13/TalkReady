import 'package:flutter/material.dart' hide CarouselController;
import 'package:carousel_slider/carousel_slider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // For API Base URL

import '../firebase_service.dart';
import '../lessons/lesson4_1.dart'; // Will be refactored
import '../lessons/lesson4_2.dart'; // Will be refactored

class Module4Page extends StatefulWidget {
  final String? targetLessonKey;
  const Module4Page({super.key, this.targetLessonKey});

  @override
  State<Module4Page> createState() => _Module4PageState();
}

class _Module4PageState extends State<Module4Page> {
  int currentLesson = 1; // 1 for L4.1, 2 for L4.2
  bool showActivity = false; // General flag if activity section is shown
  YoutubePlayerController? _youtubeController;
  int _currentSlide = 0;
  final CarouselSliderController _carouselController =
      CarouselSliderController();
  final Logger _logger = Logger();
  final FirebaseService _firebaseService = FirebaseService();

  String? _youtubeError;
  Map<String, bool> _lessonCompletion = {'lesson1': false, 'lesson2': false};
  late Map<String, int> _lessonAttemptCounts;
  bool _isContentLoaded = false;
  bool _isLoading = false; // General loading state for module actions

  // Video IDs for Module 4 lessons
  final Map<int, String?> _videoIds = {
    1: 'ENCnqouZgyQ', // Placeholder for Lesson 4.1 (Asking for Clarification) from your dart file
    2: 'IddzjASeuUE', // Placeholder for Lesson 4.2 (Providing Solutions) from your dart file
    // These should match the videos used in your JSX files if applicable
    // L4.1.jsx video: '0' (googleusercontent) -> update with actual YouTube ID from your project if available
    // L4.2.jsx video: '1' (googleusercontent) -> update with actual YouTube ID from your project if available
  };

  // Firestore keys for lessons
  final Map<int, String> _lessonNumericToFirestoreKey = {
    1: "Lesson 4.1",
    2: "Lesson 4.2",
  };

  @override
  void initState() {
    super.initState();
    _lessonAttemptCounts = {'lesson1': 0, 'lesson2': 0};
    _performAsyncInit();
  }

  Future<void> _performAsyncInit() async {
    setState(() => _isContentLoaded = false);
    try {
      await _loadLessonProgress();
      _initializeYoutubeController(); // Initialize based on currentLesson
      if (mounted) {
        setState(() {
          // Determine if activity should be shown based on progress
          showActivity = _lessonCompletion['lesson$currentLesson'] ?? false;
          _isContentLoaded = true;
        });
      }
    } catch (error) {
      _logger.e("Error during Module 4 initState loading: $error");
      if (mounted) {
        setState(() {
          _youtubeError = "Failed to load lesson content. Please try again.";
          _isContentLoaded = true;
        });
      }
    }
  }

  Future<void> _loadLessonProgress() async {
    try {
      final progress = await _firebaseService.getModuleProgress('module4');
      final lessonsData = progress['lessons'] as Map<String, dynamic>? ?? {};
      final attemptData = progress['attempts'] as Map<String, dynamic>? ?? {};

      _lessonCompletion = {
        'lesson1': lessonsData['lesson1'] ?? false,
        'lesson2': lessonsData['lesson2'] ?? false,
      };
      _lessonAttemptCounts = {
        'lesson1': attemptData['lesson1'] as int? ?? 0,
        'lesson2': attemptData['lesson2'] as int? ?? 0,
      };

      // Determine current lesson based on targetKey or completion status
      if (widget.targetLessonKey != null) {
        switch (widget.targetLessonKey) {
          case 'lesson1':
            currentLesson = 1;
            break;
          case 'lesson2':
            currentLesson = 2;
            break;
          default:
            _determineInitialLesson();
        }
      } else {
        _determineInitialLesson();
      }
      _logger.i(
          'Module 4: Progress loaded. Current Lesson: $currentLesson, Completion: $_lessonCompletion, Attempts: $_lessonAttemptCounts');
    } catch (e) {
      _logger.e('Module 4: Error loading lesson progress: $e');
      _determineInitialLesson(); // Fallback
      rethrow;
    }
  }

  void _determineInitialLesson() {
    if (!(_lessonCompletion['lesson1'] ?? false))
      currentLesson = 1;
    else if (!(_lessonCompletion['lesson2'] ?? false))
      currentLesson = 2;
    else
      currentLesson = 2; // Default to last if all complete or other issue
  }

  void _initializeYoutubeController() {
    String? videoId = _videoIds[currentLesson];
    _youtubeController?.dispose(); // Dispose existing controller if any

    if (videoId != null && videoId.isNotEmpty) {
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
      _youtubeController!.addListener(() {
        if (_youtubeController!.value.errorCode != 0 && mounted) {
          setState(() => _youtubeError =
              'YT Error: ${_youtubeController!.value.errorCode}');
        }
      });
      if (mounted) setState(() => _youtubeError = null);
    } else {
      _logger.w('Module 4: No video ID for Lesson $currentLesson.');
      _youtubeController = null; // Explicitly set to null if no video
      if (mounted) setState(() => _youtubeError = null);
    }
  }

  // --- Lesson 4.1 Handlers ---
  // Matches: onEvaluateScenarios in buildLesson4_1
  Future<Map<String, dynamic>?> _handleEvaluateLesson4_1Scenarios({
    required Map<String, String> scenarioAnswers,
    // Add 'required String lessonId,' here if your buildLesson4_1 onEvaluateScenarios prop signature includes it.
    // Based on your latest lesson4_1.dart, it *does* require lessonId.
    required String lessonId,
  }) async {
    setState(() => _isLoading = true);
    _logger.i(
        "Evaluating Lesson 4.1 scenarios: $scenarioAnswers for lesson ID: $lessonId");
    final String apiBaseUrl =
        dotenv.env['API_BASE_URL'] ?? 'http://192.168.254.103:5000';

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/evaluate-clarification'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'answers': scenarioAnswers,
          'lesson': lessonId
        }), // Use the passed lessonId
      );

      if (!mounted) return null;
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        _logger.i("Lesson 4.1 AI Feedback received: $result");
        return {
          'aiFeedbackForScenarios': result['feedback'],
          'overallAIScore': result['overallScore']
        };
      } else {
        _logger.e(
            "Error evaluating L4.1 scenarios: ${response.statusCode} ${response.body}");
        return {'error': response.body};
      }
    } catch (e) {
      _logger.e("Exception evaluating L4.1 scenarios: $e");
      return {'error': e.toString()};
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSaveLesson4_1Attempt({
    required String lessonIdFirestoreKey,
    required int attemptNumber,
    required int timeSpent,
    required Map<String, String> scenarioResponses,
    required Map<String, dynamic> aiFeedbackForScenarios,
    required double overallAIScore,
    Map<String, String>? reflectionResponses,
    required bool isUpdate, // Make sure to include this
  }) async {
    _logger.i(
        "Saving Lesson 4.1 attempt: #$attemptNumber, Score: $overallAIScore, isUpdate: $isUpdate");
    final String lessonKeyForProgress =
        'lesson1'; // Assuming L4.1 is 'lesson1' in module4 context

    try {
      final detailedResponsesPayload = {
        'scenarioResponses': scenarioResponses,
        'aiFeedbackForScenarios': aiFeedbackForScenarios,
        'reflectionResponses': reflectionResponses ?? {},
      };

      await _firebaseService.saveSpecificLessonAttempt(
        lessonIdKey: lessonIdFirestoreKey, // Should be "Lesson 4.1"
        score: overallAIScore.round(),
        attemptNumberToSave: attemptNumber,
        timeSpent: timeSpent,
        detailedResponsesPayload: detailedResponsesPayload,
        isUpdate: isUpdate, // Pass it to the service
      );
      _lessonAttemptCounts[lessonKeyForProgress] = attemptNumber;
      await _saveLessonProgressAndUpdateCompletion(1); // 1 for lesson 4.1
    } catch (e) {
      _logger.e("Error saving L4.1 attempt: $e");
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error saving attempt: ${e.toString()}")));
    }
  }

  // Matches: onSaveReflection in buildLesson4_1
  Future<void> _handleSaveLesson4_1Reflection({
    required String lessonIdFirestoreKey,
    required int attemptNumber,
    required Map<String, String> submittedScenarioResponses,
    required Map<String, dynamic> aiFeedbackForScenarios,
    required double originalOverallAIScore,
    required Map<String, String> reflectionResponses,
  }) async {
    _logger.i("Saving Lesson 4.1 reflection for attempt: #$attemptNumber");
    try {
      // For reflections, we call onSaveAttempt with isUpdate: true
      await _handleSaveLesson4_1Attempt(
        lessonIdFirestoreKey: lessonIdFirestoreKey, // Should be "Lesson 4.1"
        attemptNumber: attemptNumber,
        timeSpent:
            -1, // Indicate no new time spent or use a specific value if needed
        scenarioResponses: submittedScenarioResponses,
        aiFeedbackForScenarios: aiFeedbackForScenarios,
        overallAIScore:
            originalOverallAIScore, // The score does not change with reflection
        reflectionResponses: reflectionResponses,
        isUpdate: true, // This is an update to an existing attempt
      );
      _logger.i("Lesson 4.1 Reflection for attempt #$attemptNumber saved.");
    } catch (e) {
      _logger.e("Error saving L4.1 reflection: $e");
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Error saving reflection: ${e.toString()}")));
    }
  }

  // --- Lesson 4.2 Handlers ---
  Future<Map<String, dynamic>?> _handleEvaluateLesson4_2Solutions({
    required Map<String, String> solutionResponses,
    // Add 'required String lessonId,' if your buildLesson4_2 onEvaluateSolutions prop needs it.
    // Let's assume for now it's specific and doesn't need lessonId passed.
  }) async {
    setState(() => _isLoading = true);
    _logger.i("Evaluating Lesson 4.2 solutions: $solutionResponses");
    final String apiBaseUrl =
        dotenv.env['API_BASE_URL'] ?? 'http://192.168.254.103:5000';

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/evaluate-solutions'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(
            {'solutions': solutionResponses, 'lesson': 'Lesson 4.2'}),
      );

      if (!mounted) return null;
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        _logger.i("Lesson 4.2 AI Feedback received: $result");
        // Expected structure from server.js for /evaluate-solutions is {'feedback': {solution1: {text, score}, ...}}
        return {
          'aiSolutionFeedback': result['feedback'],
          // 'overallAIScore' is calculated in lesson4_2.dart, not directly from this endpoint usually
        };
      } else {
        _logger.e(
            "Error evaluating L4.2 solutions: ${response.statusCode} ${response.body}");
        return {'error': response.body};
      }
    } catch (e) {
      _logger.e("Exception evaluating L4.2 solutions: $e");
      return {'error': e.toString()};
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSaveLesson4_2Attempt({
    required String lessonIdFirestoreKey,
    required int attemptNumber,
    required int timeSpent,
    required Map<String, String> solutionResponses, // Specific to L4.2
    required Map<String, dynamic> aiSolutionFeedback, // Specific to L4.2
    required double overallAIScore,
    Map<String, String>? reflectionResponses,
    required bool isUpdate, // Make sure to include this
  }) async {
    _logger.i(
        "Saving Lesson 4.2 attempt: #$attemptNumber, Overall Score: $overallAIScore, isUpdate: $isUpdate");
    final String lessonKeyForProgress =
        'lesson2'; // Assuming L4.2 is 'lesson2' in module4 context

    try {
      final detailedResponsesPayload = {
        'solutionResponses_L4_2':
            solutionResponses, // Using specific keys as in firebase.js
        'solutionFeedback_L4_2': aiSolutionFeedback,
        'reflectionResponses_L4_2': reflectionResponses ?? {},
      };

      await _firebaseService.saveSpecificLessonAttempt(
        lessonIdKey: lessonIdFirestoreKey, // Should be "Lesson 4.2"
        score: overallAIScore.round(),
        attemptNumberToSave: attemptNumber,
        timeSpent: timeSpent,
        detailedResponsesPayload: detailedResponsesPayload,
        isUpdate: isUpdate, // Pass it to the service
      );
      _lessonAttemptCounts[lessonKeyForProgress] = attemptNumber;
      await _saveLessonProgressAndUpdateCompletion(2); // 2 for lesson 4.2
    } catch (e) {
      _logger.e("Error saving L4.2 attempt: $e");
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error saving attempt: ${e.toString()}")));
    }
  }

  Future<void> _handleSaveLesson4_2Reflection({
    required String lessonIdFirestoreKey,
    required int attemptNumber,
    required Map<String, String> submittedSolutionResponses, // Specific to L4.2
    required Map<String, dynamic> aiSolutionFeedback, // Specific to L4.2
    required double originalOverallAIScore,
    required Map<String, String> reflectionResponses,
  }) async {
    _logger.i("Saving Lesson 4.2 reflection for attempt: #$attemptNumber");
    try {
      // For reflections, we call onSaveAttempt with isUpdate: true
      await _handleSaveLesson4_2Attempt(
        // Reuse the L4.2 save attempt logic
        lessonIdFirestoreKey: lessonIdFirestoreKey, // "Lesson 4.2"
        attemptNumber: attemptNumber,
        timeSpent: -1,
        solutionResponses: submittedSolutionResponses,
        aiSolutionFeedback: aiSolutionFeedback,
        overallAIScore: originalOverallAIScore,
        reflectionResponses: reflectionResponses,
        isUpdate: true, // This is an update
      );
      _logger.i("Lesson 4.2 Reflection for attempt #$attemptNumber saved.");
    } catch (e) {
      _logger.e("Error saving L4.2 reflection: $e");
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Error saving reflection: ${e.toString()}")));
    }
  }

  Future<void> _saveLessonProgressAndUpdateCompletion(int lessonNumber) async {
    final lessonKey = 'lesson$lessonNumber';
    await _firebaseService.updateLessonProgress('module4', lessonKey, true,
        attempts: _lessonAttemptCounts);
    if (mounted) {
      setState(() {
        _lessonCompletion[lessonKey] = true;
      });
    }
  }

  @override
  void dispose() {
    _youtubeController?.dispose();
    super.dispose();
  }

  void _goToNextLesson() async {
    if (currentLesson < _videoIds.length) {
      setState(() => _isLoading = true);
      await Future.delayed(const Duration(milliseconds: 300)); // Simulate work
      if (mounted) {
        setState(() {
          currentLesson++;
          _currentSlide = 0;
          _carouselController.jumpToPage(0);
          showActivity = _lessonCompletion['lesson$currentLesson'] ?? false;
          _initializeYoutubeController(); // Re-initialize for new lesson
          _isLoading = false;
        });
      }
    } else {
      // All lessons in module completed
      _logger.i("Module 4 completed. Navigating back or to summary.");
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isContentLoaded) {
      return Scaffold(
        appBar: AppBar(title: Text('Module 4: Lesson $currentLesson')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    bool isModuleCompleted =
        _lessonCompletion.values.every((completed) => completed);
    int initialAttemptForChild =
        (_lessonAttemptCounts['lesson$currentLesson'] ?? 0);
    // Note: Child lesson will manage its "current attempt number for display" as initialAttemptNumber + 1

    return Scaffold(
      appBar: AppBar(
        title: Text('Module 4: Lesson $currentLesson'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    'Lesson $currentLesson of ${_videoIds.length}',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
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
                  _buildLessonContentWidget(initialAttemptForChild),
                  if (showActivity &&
                      (_lessonCompletion['lesson$currentLesson'] ?? false) &&
                      _youtubeError == null) ...[
                    const SizedBox(height: 24),
                    if (currentLesson <
                        _videoIds.length) // Check if there's a next lesson
                      ElevatedButton(
                        onPressed: _isLoading ? null : _goToNextLesson,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Next Lesson'),
                      )
                    else // This is the last lesson
                      ElevatedButton(
                        onPressed: () => Navigator.pop(
                            context), // Or navigate to a module completion page
                        style: ElevatedButton.styleFrom(
                            backgroundColor: isModuleCompleted
                                ? Colors.green
                                : Theme.of(context).primaryColor),
                        child: Text(isModuleCompleted
                            ? 'Module Completed - Return'
                            : 'Finish Module & Return'),
                      ),
                  ],
                ],
              ),
            ),
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonContentWidget(int initialAttemptNumberFromModule) {
    // Callback to show activity section, typically called by child lesson after study phase
    VoidCallback onShowActivityCallback = () {
      if (mounted) {
        setState(() {
          showActivity = true;
          // Resetting feedback states for the current lesson in module page is not needed
          // as the child lesson will manage its own display state (e.g. _showResultsView)
        });
      }
    };

    switch (currentLesson) {
      case 1:
        return buildLesson4_1(
          // context: context, // Not needed if buildLesson4_1 doesn't require BuildContext directly for routing etc.
          currentSlide: _currentSlide,
          carouselController: _carouselController,
          youtubeController: _youtubeController, // Pass null if no video
          showActivityInitially:
              showActivity, // Use a different prop name if lesson manages its own "showActivity" vs "showStudy"
          onShowActivitySection:
              onShowActivityCallback, // Renamed from onShowActivity for clarity

          initialAttemptNumber: initialAttemptNumberFromModule,
          onSlideChanged: (index) => setState(() => _currentSlide = index),

          onEvaluateScenarios: _handleEvaluateLesson4_1Scenarios,
          onSaveAttempt: _handleSaveLesson4_1Attempt,
          onSaveReflection: _handleSaveLesson4_1Reflection,
        );
      case 2:
        return buildLesson4_2(
          // context: context,
          currentSlide: _currentSlide,
          carouselController: _carouselController,
          youtubeController: _youtubeController, // Pass null if no video
          showActivityInitially: showActivity,
          onShowActivitySection: onShowActivityCallback,

          initialAttemptNumber: initialAttemptNumberFromModule,
          onSlideChanged: (index) => setState(() => _currentSlide = index),

          onEvaluateSolutions: _handleEvaluateLesson4_2Solutions,
          onSaveAttempt: _handleSaveLesson4_2Attempt,
          onSaveReflection: _handleSaveLesson4_2Reflection,
        );
      default:
        return Center(child: Text('Error: Invalid lesson $currentLesson'));
    }
  }
}
