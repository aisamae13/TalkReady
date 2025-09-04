import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../firebase_service.dart';
import '../lessons/lesson4_1.dart';
import '../lessons/lesson4_2.dart';

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
  final CarouselSliderController _carouselController = CarouselSliderController(); // Changed from CarouselController
  final Logger _logger = Logger();
  final FirebaseService _firebase_service = FirebaseService();
  final FirebaseService _firebaseService = FirebaseService();

  String? _youtubeError;
  Map<String, bool> _lessonCompletion = {'lesson1': false, 'lesson2': false};
  late Map<String, int> _lessonAttemptCounts;
  bool _isContentLoaded = false;
  bool _isLoading = false; // General loading state for module actions

  // Video IDs for Module 4 lessons
  final Map<int, String?> _videoIds = {
    1: 'ENCnqouZgyQ',
    2: 'IddzjASeuUE',
  };

  // Firestore keys for lessons
  final Map<int, String> _lessonNumericToFirestoreKey = {
    1: "Lesson 4.1",
    2: "Lesson 4.2",
  };

  // Add these state variables to the _Module4PageState class after the existing declarations

  // Enhanced UI state for lesson4_1 integration
  bool _isSaveComplete = false;
  bool _showFeedbackModal = false;
  Map<String, dynamic>? _currentFeedback;

  // Animation-related state (if you want to add transitions)
  bool _isTransitioning = false;

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
      _initializeYoutubeController();
      
      if (mounted) {
        setState(() {
          final attempts = _lessonAttemptCounts['lesson$currentLesson'] ?? 0;
          final completed = _lessonCompletion['lesson$currentLesson'] ?? false;
          showActivity = attempts > 0 || completed;
          _isContentLoaded = true;
        });
      }
    } catch (error) {
      _logger.e("Error during Module 4 initialization: $error");
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
    if (!(_lessonCompletion['lesson1'] ?? false)) {
      currentLesson = 1;
    } else if (!(_lessonCompletion['lesson2'] ?? false))
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
  Future<Map<String, dynamic>?> _handleEvaluateLesson4_1Scenarios({
    required Map<String, String> scenarioAnswers,
    required String lessonId,
  }) async {
    setState(() => _isLoading = true);
    _logger.i("Evaluating Lesson 4.1 scenarios: $scenarioAnswers for lesson ID: $lessonId");
    
    final String apiBaseUrl = dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:5001';  // For Android emulator
    // OR use your computer's actual IP address
    // final String apiBaseUrl = dotenv.env['API_BASE_URL'] ?? 'http://192.168.x.x:5000';

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/evaluate-clarification'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'answers': scenarioAnswers,
          'lesson': lessonId
        }),
      );

      if (!mounted) return null;
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        _logger.i("Lesson 4.1 AI Feedback received: $result");
        return {
          'aiFeedbackForScenarios': result['feedback'],
          'overallAIScore': result['overallScore'] ?? 0.0
        };
      } else {
        _logger.e("Error evaluating L4.1 scenarios: ${response.statusCode} ${response.body}");
        return {'error': 'Server error: ${response.statusCode}'};
      }
    } catch (e) {
      _logger.e("Exception evaluating L4.1 scenarios: $e");
      return {'error': 'Network error: ${e.toString()}'};
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
    required bool isUpdate,
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error saving attempt: ${e.toString()}")));
      }
    }
  }

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
      await _handleSaveLesson4_1Attempt(
        lessonIdFirestoreKey: lessonIdFirestoreKey,
        attemptNumber: attemptNumber,
        timeSpent: -1,
        scenarioResponses: submittedScenarioResponses,
        aiFeedbackForScenarios: aiFeedbackForScenarios,
        overallAIScore: originalOverallAIScore,
        reflectionResponses: reflectionResponses,
        isUpdate: true,
      );
      _logger.i("Lesson 4.1 Reflection for attempt #$attemptNumber saved.");
    } catch (e) {
      _logger.e("Error saving L4.1 reflection: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Error saving reflection: ${e.toString()}")));
      }
    }
  }

  // --- Lesson 4.2 Handlers ---
  Future<Map<String, dynamic>?> _handleEvaluateLesson4_2Solutions({
    required Map<String, String> solutionResponses,
  }) async {
    setState(() => _isLoading = true);
    _logger.i("Evaluating Lesson 4.2 solutions: $solutionResponses");
    final String apiBaseUrl =
        dotenv.env['API_BASE_URL'] ?? 'http://192.168.254.103:5001';

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
        return {
          'aiSolutionFeedback': result['feedback'],
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
    required Map<String, String> solutionResponses,
    required Map<String, dynamic> aiSolutionFeedback,
    required double overallAIScore,
    Map<String, String>? reflectionResponses,
    required bool isUpdate,
  }) async {
    _logger.i(
        "Saving Lesson 4.2 attempt: #$attemptNumber, Overall Score: $overallAIScore, isUpdate: $isUpdate");
    final String lessonKeyForProgress =
        'lesson2'; // Assuming L4.2 is 'lesson2' in module4 context

    try {
      final detailedResponsesPayload = {
        'solutionResponses_L4_2': solutionResponses,
        'solutionFeedback_L4_2': aiSolutionFeedback,
        'reflectionResponses_L4_2': reflectionResponses ?? {},
      };

      await _firebaseService.saveSpecificLessonAttempt(
        lessonIdKey: lessonIdFirestoreKey,
        score: overallAIScore.round(),
        attemptNumberToSave: attemptNumber,
        timeSpent: timeSpent,
        detailedResponsesPayload: detailedResponsesPayload,
        isUpdate: isUpdate,
      );
      _lessonAttemptCounts[lessonKeyForProgress] = attemptNumber;
      await _saveLessonProgressAndUpdateCompletion(2); // 2 for lesson 4.2
    } catch (e) {
      _logger.e("Error saving L4.2 attempt: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error saving attempt: ${e.toString()}")));
      }
    }
  }

  Future<void> _handleSaveLesson4_2Reflection({
    required String lessonIdFirestoreKey,
    required int attemptNumber,
    required Map<String, String> submittedSolutionResponses,
    required Map<String, dynamic> aiSolutionFeedback,
    required double originalOverallAIScore,
    required Map<String, String> reflectionResponses,
  }) async {
    _logger.i("Saving Lesson 4.2 reflection for attempt: #$attemptNumber");
    try {
      await _handleSaveLesson4_2Attempt(
        lessonIdFirestoreKey: lessonIdFirestoreKey,
        attemptNumber: attemptNumber,
        timeSpent: -1,
        solutionResponses: submittedSolutionResponses,
        aiSolutionFeedback: aiSolutionFeedback,
        overallAIScore: originalOverallAIScore,
        reflectionResponses: reflectionResponses,
        isUpdate: true,
      );
      _logger.i("Lesson 4.2 Reflection for attempt #$attemptNumber saved.");
    } catch (e) {
      _logger.e("Error saving L4.2 reflection: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Error saving reflection: ${e.toString()}")));
      }
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
          _carouselController.animateToPage(0);
          // recompute showActivity using same rule (attempts OR completion)
          final attempts = _lessonAttemptCounts['lesson$currentLesson'] ?? 0;
          final completed = _lessonCompletion['lesson$currentLesson'] ?? false;
          showActivity = attempts > 0 || completed;
          _initializeYoutubeController(); // Re-initialize for new lesson
          _isLoading = false;
        });
      }
    } else {
      _logger.i("Module 4 completed. Navigating back or to summary.");
      if (mounted) Navigator.pop(context);
    }
  }

  // Add this method to help with debugging
  void _debugResetAndReload() {
    setState(() {
      _isContentLoaded = false;
      _youtubeError = null;
    });
    
    // Force dispose and re-initialize
    _youtubeController?.dispose();
    _youtubeController = null;
    
    // Re-initialize everything
    _performAsyncInit();
  }

  // Modify your build method to include debug options
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

    return Scaffold(
      appBar: AppBar(
        title: Text('Module 4: Lesson $currentLesson'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Add debug button
          IconButton(
            icon: Icon(Icons.bug_report),
            onPressed: _debugResetAndReload,
            tooltip: 'Debug Reset',
          )
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Add debug container to ensure something is visible
            Container(
              color: Colors.white,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Debug information section
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(8),
                      margin: EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        border: Border.all(color: Colors.blue),
                        borderRadius: BorderRadius.circular(8)
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Debug Info:'),
                          Text('Lesson: $currentLesson of ${_videoIds.length}'),
                          Text('Attempts: ${_lessonAttemptCounts['lesson$currentLesson'] ?? 0}'),
                          Text('Completed: ${_lessonCompletion['lesson$currentLesson'] ?? false}'),
                          Text('Show Activity: $showActivity'),
                          Text('YouTube Error: ${_youtubeError ?? "None"}'),
                        ],
                      ),
                    ),
                    
                    Text(
                      'Lesson $currentLesson of ${_videoIds.length}',
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    if (_youtubeError != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red[200]!),
                          ),
                          child: Text(
                            _youtubeError!,
                            style: TextStyle(color: Colors.red[700], fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    _buildLessonContentWidget(initialAttemptForChild),
                    if (showActivity &&
                        (_lessonCompletion['lesson$currentLesson'] ?? false) &&
                        _youtubeError == null) ...[
                      const SizedBox(height: 24),
                      _buildNavigationButton(),
                    ],
                  ],
                ),
              ),
            ),
            
            // Loading overlay
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text(
                        'Processing...',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Replace your _buildLessonContentWidget method with this version
  Widget _buildLessonContentWidget(int initialAttemptNumberFromModule) {
    // Debug visibility to find issue
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.red, width: 2)
      ),
      child: Column(
        children: [
          // Debug text to confirm this method is being called
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.yellow[100],
            child: Text(
              "Debug: Loading lesson ${currentLesson}, attempts: ${_lessonAttemptCounts['lesson$currentLesson']}, show activity: $showActivity",
              style: TextStyle(color: Colors.black),
            ),
          ),
          
          // Callback function to show activity section
          Builder(builder: (context) {
            onShowActivityCallback() {
              if (mounted) {
                setState(() {
                  showActivity = true;
                });
              }
            }

            // compute showActivityInitially for the child
            final bool showActivityInitiallyForChild =
                (_lessonAttemptCounts['lesson$currentLesson'] ?? 0) > 0 ||
                (_lessonCompletion['lesson$currentLesson'] ?? false);

            try {
              switch (currentLesson) {
                case 1:
                  return Container(
                    color: Colors.green[50],
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.all(8),
                    child: buildLesson4_1(  // Capitalized class name
                      currentSlide: _currentSlide,
                      carouselController: _carouselController,
                      youtubeController: _youtubeController,
                      showActivityInitially: showActivityInitiallyForChild,
                      onShowActivitySection: onShowActivityCallback,
                      initialAttemptNumber: initialAttemptNumberFromModule,
                      onSlideChanged: (index) => setState(() => _currentSlide = index),
                      onEvaluateScenarios: _handleEvaluateLesson4_1Scenarios,
                      onSaveAttempt: _handleSaveLesson4_1Attempt,
                      onSaveReflection: _handleSaveLesson4_1Reflection,
                    ),
                  );
                case 2:
                  return Container(
                    color: Colors.blue[50],
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.all(8),
                    child: buildLesson4_2(  // Capitalized class name
                      currentSlide: _currentSlide,
                      carouselController: _carouselController,
                      youtubeController: _youtubeController,
                      showActivityInitially: showActivityInitiallyForChild,
                      onShowActivitySection: onShowActivityCallback,
                      initialAttemptNumber: initialAttemptNumberFromModule,
                      onSlideChanged: (index) => setState(() => _currentSlide = index),
                      onEvaluateSolutions: _handleEvaluateLesson4_2Solutions,
                      onSaveAttempt: _handleSaveLesson4_2Attempt,
                      onSaveReflection: _handleSaveLesson4_2Reflection,
                    ),
                  );
                default:
                  return Text('Error: Invalid lesson $currentLesson');
              }
            } catch (e) {
              // Debug error in rendering
              return Container(
                padding: EdgeInsets.all(16),
                color: Colors.red[100],
                child: Column(
                  children: [
                    Text('Error rendering lesson: $e', 
                      style: TextStyle(color: Colors.red[900]),
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _initializeYoutubeController(),
                      child: Text('Try Reinitialize'),
                    )
                  ],
                ),
              );
            }
          }),
        ],
      ),
    );
  }

  // Add these methods before the dispose() method

  Future<void> _handleFetchActivityLog() async {
    // This method will be called by lesson4_1 when user clicks activity log
    _logger.i("Activity log requested from lesson 4.1");
    // The actual implementation is handled by the lesson widget itself
  }

  Future<Map<String, dynamic>?> _handleGetLessonData() async {
    // Provide lesson data structure for the enhanced lesson4_1
    return {
      'moduleTitle': 'Module 4: Professional Communication',
      'lessonTitle': 'Lesson 4.1: Asking for Clarification',
      'video': {
        'url': 'https://www.youtube.com/embed/${_videoIds[1] ?? ""}'
      },
      'objective': {
        'heading': 'Learning Objectives',
        'points': [
          'Use polite and professional phrases to ask customers to repeat or clarify information',
          'Respond naturally when you don\'t understand a customer during a call',
          'Practice these skills in simulated role-play conversations',
          'Build confidence in handling unclear communication'
        ]
      },
      'introduction': {
        'heading': 'Why Clarification Matters',
        'paragraph': 'In a call center, background noise, unclear speech, or unfamiliar accents can make it hard to understand the customer. Agents must ask for clarification politely and confidently to ensure accuracy and professionalism.'
      },
      'keyPhrases': {
        'table': [
          {'situation': 'Didn\'t catch what was said', 'phrase': '"Sorry, can you say that again?"'},
          {'situation': 'Didn\'t understand fully', 'phrase': '"I didn\'t quite get that. Could you repeat it?"'},
          {'situation': 'Need spelling confirmation', 'phrase': '"Could you spell that for me, please?"'},
          {'situation': 'Need to confirm details', 'phrase': '"Just to confirm, did you say [repeat info]?"'},
          {'situation': 'Need more information', 'phrase': '"Could you explain that a little more?"'},
          {'situation': 'Need clarification on meaning', 'phrase': '"Could you clarify what you meant by...?"'},
        ]
      },
      'summary': {
        'heading': 'Lesson Summary',
        'paragraph': 'Asking for clarification politely and effectively is crucial in call center environments. These strategies help ensure clear understanding, build trust, and prevent mistakes. With practice, these techniques will become natural, enhancing your confidence and communication skills.'
      }
    };
  }

  // Add this method before the dispose() method

  Widget _buildNavigationButton() {
    final isModuleCompleted = _lessonCompletion.values.every((completed) => completed);
    
    if (currentLesson < _videoIds.length) {
      return ElevatedButton.icon(
        onPressed: _isLoading ? null : _goToNextLesson,
        icon: _isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.arrow_forward),
        label: Text(_isLoading ? 'Loading...' : 'Next Lesson'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[600],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } else {
      return ElevatedButton.icon(
        onPressed: () => Navigator.pop(context),
        icon: Icon(isModuleCompleted ? Icons.check_circle : Icons.home),
        label: Text(isModuleCompleted ? 'Module Completed' : 'Return to Modules'),
        style: ElevatedButton.styleFrom(
          backgroundColor: isModuleCompleted ? Colors.green[600] : Colors.grey[600],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }
}