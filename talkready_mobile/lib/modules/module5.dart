import 'package:flutter/material.dart'
    hide
        CarouselController; // Hide to avoid conflict if CarouselController is also defined elsewhere
import 'package:carousel_slider/carousel_slider.dart';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../firebase_service.dart';
import '../lessons/lesson5_1.dart'; // Assuming this is your refactored Lesson5_1
import '../lessons/lesson5_2.dart'; // Assuming this will be your refactored Lesson5_2

class Module5Page extends StatefulWidget {
  final String? targetLessonKey; // e.g., "lesson1", "lesson2"
  const Module5Page({super.key, this.targetLessonKey});

  @override
  State<Module5Page> createState() => _Module5PageState();
}

class _Module5PageState extends State<Module5Page> {
  final Logger _logger = Logger();
  final FirebaseService _firebaseService = FirebaseService();

  int currentLesson = 1; // 1 for L5.1, 2 for L5.2
  bool showActivity =
      false; // Controls if the activity part of a lesson is shown
  int _currentSlide = 0; // For study material carousel within lessons
  final CarouselSliderController _carouselController =
      CarouselSliderController();

  // Progress and state
  Map<String, bool> _lessonCompletion = {'lesson1': false, 'lesson2': false};
  late Map<String, int> _lessonAttemptCounts;
  bool _isContentLoaded = false;
  bool _isLoading =
      false; // General loading for module-level actions (e.g., fetching API)

  Map<int, bool> _showSummaryAfterCompletion = {1: false, 2: false};

  Map<int, Map<String, dynamic>?> _lastAttemptDataForSummary = {
    1: null,
    2: null
  };
  Map<int, bool> _triggerSummaryDisplay = {1: false, 2: false};

  // Firestore keys for lessons in Module 5
  final Map<int, String> _lessonNumericToFirestoreKey = {
    1: "Lesson 5.1", // Matches what Lesson5.1.jsx would use
    2: "Lesson 5.2", // Matches what Lesson5.2.jsx would use
  };
  // Module key for Firebase progress structure
  final String _moduleIdFirebase = "module5";

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
      // No top-level YouTube controller for Module 5 based on JSX structure
      if (mounted) {
        setState(() {
          showActivity = _lessonCompletion['lesson$currentLesson'] ?? false;
          _isContentLoaded = true;
        });
      }
    } catch (error) {
      _logger.e("Error during Module 5 initState loading: $error");
      if (mounted) {
        setState(() {
          // Consider adding an error message display if needed
          _isContentLoaded = true; // Allow UI to build even if error
        });
      }
    }
  }

  Future<void> _loadLessonProgress() async {
    try {
      final progress =
          await _firebaseService.getModuleProgress(_moduleIdFirebase);
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
          'Module 5: Progress loaded. Current Lesson: $currentLesson, Completion: $_lessonCompletion, Attempts: $_lessonAttemptCounts');
    } catch (e) {
      _logger.e('Module 5: Error loading lesson progress: $e');
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
      currentLesson = 2; // Default to last lesson if all complete
  }

  Future<void> _saveLessonProgressAndUpdateCompletion(int lessonNumberInModule,
      {required int newAttemptCount}) async {
    final lessonKeyString = 'lesson$lessonNumberInModule';
    _lessonAttemptCounts[lessonKeyString] = newAttemptCount;

    await _firebaseService.updateLessonProgress(
      _moduleIdFirebase,
      lessonKeyString,
      true, // Mark lesson as completed (or "touched")
      attempts: _lessonAttemptCounts,
    );
    if (mounted) {
      setState(() {
        _lessonCompletion[lessonKeyString] = true;
      });
    }
  }

  // --- Handler for Lesson 5.1 & 5.2: Process Agent's Spoken Turn ---
  Future<Map<String, dynamic>?> _handleProcessAgentTurn({
    required String turnId,
    required String localAudioPath,
    required String originalText, // Model answer/script for the agent's turn
    // required String lessonContext, // e.g., "L5.1" or "L5.2" - if needed by backend or for logging
  }) async {
    if (!mounted) return null;
    setState(() => _isLoading = true);
    _logger.i(
        "Processing Agent Turn: $turnId, AudioPath: $localAudioPath, Script: \"$originalText\"");

    final String apiBaseUrl =
        dotenv.env['API_BASE_URL'] ?? 'http://192.168.254.103:5000';
    String? audioStorageUrl;
    String lessonIdForFirebase = _lessonNumericToFirestoreKey[currentLesson]!;

    try {
      // Step 1: Upload audio to Firebase Storage
      // The promptId for Firebase Storage can be the turnId for uniqueness within the lesson attempt
      audioStorageUrl = await _firebaseService.uploadLessonAudio(
          localAudioPath, lessonIdForFirebase, turnId);
      if (audioStorageUrl == null) {
        throw Exception("Failed to upload audio to Firebase Storage.");
      }
      _logger.i("Audio uploaded for turn $turnId: $audioStorageUrl");

      // Step 2: Call backend for Azure Speech Evaluation
      _logger.i("Sending to Azure for turn $turnId via backend...");
      final azureResponse = await http
          .post(
            Uri.parse(
                '$apiBaseUrl/evaluate-speech-with-azure'), // Endpoint from server.js
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'audioUrl': audioStorageUrl,
              'originalText': originalText,
              'language': 'en-US',
            }),
          )
          .timeout(const Duration(seconds: 120));

      if (!mounted) return null;
      if (azureResponse.statusCode != 200) {
        final errorBody = jsonDecode(azureResponse.body);
        throw Exception(
            "Azure evaluation failed: ${errorBody['error'] ?? azureResponse.reasonPhrase}");
      }
      final azureResult =
          jsonDecode(azureResponse.body) as Map<String, dynamic>;
      if (azureResult['success'] != true) {
        throw Exception(
            "Azure evaluation unsuccessful: ${azureResult['error'] ?? 'Unknown Azure error'}");
      }
      _logger.i(
          "Azure feedback received for turn $turnId: Accuracy ${azureResult['accuracyScore']}");

      // Step 3: Call backend for OpenAI Coach's Explanation
      _logger.i("Sending to OpenAI for explanation for turn $turnId...");
      final openAiResponse = await http
          .post(
            Uri.parse(
                '$apiBaseUrl/explain-azure-feedback-with-openai'), // Endpoint from server.js
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'azureFeedback': azureResult, // Pass the full Azure result
              'originalText': originalText,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (!mounted) return null;
      if (openAiResponse.statusCode != 200) {
        final errorBody = jsonDecode(openAiResponse.body);
        throw Exception(
            "OpenAI explanation failed: ${errorBody['error'] ?? openAiResponse.reasonPhrase}");
      }
      final openAiResult = jsonDecode(openAiResponse.body);
      if (openAiResult['success'] != true) {
        throw Exception(
            "OpenAI explanation unsuccessful: ${openAiResult['error'] ?? 'Unknown OpenAI error'}");
      }
      _logger.i("OpenAI feedback received for turn $turnId.");

      return {
        'audioStorageUrl': audioStorageUrl,
        'transcription': azureResult['textRecognized'],
        'azureAiFeedback': azureResult, // Full Azure result
        'openAiDetailedFeedback':
            openAiResult['detailedFeedback'], // HTML string
        'error': null,
      };
    } catch (e) {
      _logger.e("Error processing agent turn $turnId: $e");
      return {
        'audioStorageUrl':
            audioStorageUrl, // Might be null if upload failed early
        'transcription': null,
        'azureAiFeedback': null,
        'openAiDetailedFeedback': null,
        'error': e.toString(),
      };
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Handler for Lesson 5.1 & 5.2: Save Lesson Attempt ---
  Future<void> _handleSaveLessonAttempt({
    required String
        lessonIdFirestoreKey, // e.g., "Lesson 5.1" from the lesson widget
    required int
        attemptNumber, // This is the new total attempt count for this lesson
    required int timeSpent,
    required double overallLessonScore,
    required List<Map<String, dynamic>> turnDetails,
  }) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    // Determine the lesson number (1 or 2) from the lessonIdFirestoreKey ("Lesson 5.1" -> 1)
    int lessonNumberInModule = _lessonNumericToFirestoreKey.entries
        .firstWhere((entry) => entry.value == lessonIdFirestoreKey,
            orElse: () => const MapEntry(0, ""))
        .key;

    if (lessonNumberInModule == 0) {
      _logger.e(
          "Could not determine lesson number for Firestore key: $lessonIdFirestoreKey during save.");
      if (mounted) setState(() => _isLoading = false);
      // Optionally show a user-facing error
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text("Internal error: Could not identify lesson for saving.")));
      return;
    }

    // This is the key used within module5.attempts and module5.lessons (e.g., "lesson1", "lesson2")
    final String lessonKeyForModuleProgress = 'lesson$lessonNumberInModule';

    try {
      final detailedResponsesPayload = {
        'overallScore': overallLessonScore,
        'timeSpent': timeSpent,
        'promptDetails':
            turnDetails, // These are the individual turns from the simulation
      };

      // Step 1: Save the detailed attempt data to the specific lesson's attempt collection
      // This writes to: userProgress/{uid}/lessonAttempts/{lessonIdFirestoreKey} (e.g., "lessonAttempts/Lesson 5.1")
      await _firebaseService.saveSpecificLessonAttempt(
        lessonIdKey: lessonIdFirestoreKey, // e.g., "Lesson 5.1"
        score: overallLessonScore.round(),
        attemptNumberToSave:
            attemptNumber, // The current attempt number for this specific lesson
        timeSpent: timeSpent,
        detailedResponsesPayload: detailedResponsesPayload,
        isUpdate:
            false, // Assuming this is always a new attempt, not an update to an existing one
      );
      _logger.i(
          "Detailed attempt #$attemptNumber for $lessonIdFirestoreKey saved to its collection.");

      // Step 2: Update the local state in module5.dart
      // This ensures _lessonAttemptCounts and _lessonCompletion are up-to-date before sending to Firestore
      // and for the UI to react.
      Map<String, int> newAttemptCountsState = Map.from(_lessonAttemptCounts);
      newAttemptCountsState[lessonKeyForModuleProgress] = attemptNumber;

      Map<String, bool> newLessonCompletionState = Map.from(_lessonCompletion);
      newLessonCompletionState[lessonKeyForModuleProgress] = true;

      if (mounted) {
        setState(() {
          _lessonAttemptCounts = newAttemptCountsState;
          _lessonCompletion = newLessonCompletionState;

          // For displaying summary view in the lesson widget
          _triggerSummaryDisplay[lessonNumberInModule] = true;
          _lastAttemptDataForSummary[lessonNumberInModule] = {
            'overallLessonScore': overallLessonScore,
            'turnDetails': turnDetails,
            'timeSpent': timeSpent,
            'attemptNumber': attemptNumber, // The attempt number just completed
          };
          // This flag seems related to UI flow within the lesson for showing summary
          if (lessonNumberInModule > 0) {
            // Check to prevent index out of bounds if lessonNumberInModule was 0
            _showSummaryAfterCompletion[lessonNumberInModule] = true;
          }
        });
      }
      _logger.i(
          "Local state in Module5Page updated for $lessonKeyForModuleProgress: attempts=$attemptNumber, completed=true.");

      // Step 3: Update the module-level progress in Firestore.
      // This updates: userProgress/{uid}/module5/attempts and userProgress/{uid}/module5/lessons/{lessonKey}
      await _firebaseService.updateLessonProgress(
        _moduleIdFirebase, // "module5"
        lessonKeyForModuleProgress, // "lesson1" or "lesson2"
        true, // Mark this lesson as completed in module5.lessons
        attempts:
            _lessonAttemptCounts, // Pass the updated _lessonAttemptCounts map
        // e.g., {'lesson1': 1, 'lesson2': 0}
      );

      _logger.i(
          "'$lessonIdFirestoreKey' (lesson $lessonKeyForModuleProgress) attempt #$attemptNumber fully processed. Module '$_moduleIdFirebase' progress (attempts and lesson completion) updated in Firestore.");
    } catch (e) {
      _logger.e(
          "Error during _handleSaveLessonAttempt for '$lessonIdFirestoreKey': $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error saving progress: ${e.toString()}")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    // _youtubeController?.dispose(); // No top-level YouTube controller in M5
    super.dispose();
  }

  void _goToNextLesson() async {
    if (currentLesson < 2) {
      // Assuming 2 lessons for Module 5
      setState(() => _isLoading = true);
      // You can keep a small delay if you want the loading spinner to be visible briefly
      await Future.delayed(const Duration(milliseconds: 100));

      if (mounted) {
        setState(() {
          currentLesson++;
          _currentSlide =
              0; // Reset slide index for the new lesson's study material
          showActivity = _lessonCompletion['lesson$currentLesson'] ?? false;
          // No _initializeYoutubeController needed as per module5 structure
          _isLoading = false;

          // REMOVED: _carouselController.jumpToPage(0);
          // We will rely on the initialPage property of the CarouselSlider
          // in Lesson5_1 / Lesson5_2 which uses widget.currentSlide (now set to 0).
        });
        _logger.i(
            "Module5: Switched to Lesson $currentLesson. Carousel should initialize to slide 0 via initialPage prop.");
      }
    } else {
      _logger.i("Module 5 completed or last lesson reached.");
      if (mounted) Navigator.pop(context); // Go back after finishing module
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isContentLoaded) {
      return Scaffold(
        appBar: AppBar(title: Text('Module 5: Lesson $currentLesson')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    bool isModuleCompleted =
        _lessonCompletion.values.every((completed) => completed);
    int initialAttemptForChildLesson =
        (_lessonAttemptCounts['lesson$currentLesson'] ?? 0);

    if (_triggerSummaryDisplay[currentLesson] == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _logger.i(
              "Module5: Attempting to jumpToPage(0) for lesson $currentLesson's carousel.");
          try {
            _carouselController.jumpToPage(0);
          } catch (e) {
            _logger.e(
                "Module5: Error in jumpToPage(0) for lesson $currentLesson: $e");
            // This might still error if the controller isn't attached quickly enough
            // or if the CarouselSlider in the new lesson isn't built yet.
            // A more robust solution might involve a key or ensuring the controller is truly ready.
          }
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Module 5: Basic Call Simulations'),
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
                    'Lesson $currentLesson of 2', // Module 5 has 2 lessons based on JSX
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  // No top-level YouTube error for Module 5 based on current structure

                  _buildLessonContentWidget(initialAttemptForChildLesson),

                  // Navigation to next lesson or finish module
                  if (showActivity &&
                      (_lessonCompletion['lesson$currentLesson'] ?? false)) ...[
                    const SizedBox(height: 24),
                    if (currentLesson < 2) // Max 2 lessons in M5
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
                    else // Current lesson is 2 (last lesson in M5)
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
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
            if (_isLoading) // Global loading overlay for API calls
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
    VoidCallback onShowActivityCallback = () {
      if (mounted) {
        setState(() {
          showActivity = true;
          // Lesson widget will handle its internal state reset (e.g., _isStudied)
        });
      }
    };

    final int lessonNum = currentLesson;

    switch (currentLesson) {
      case 1:
        return Lesson5_1(
          key: ValueKey(
              'lesson5_1_attempt_${_lessonAttemptCounts["lesson1"]}'), // Ensure re-render on new attempt
          passToShowSummary:
              _triggerSummaryDisplay[lessonNum] ?? false, // <<< NEW PROP
          summaryData: _lastAttemptDataForSummary[lessonNum], // <<< NEW PROP
          currentSlide: _currentSlide,
          carouselController: _carouselController,
          onSlideChanged: (index) {
            if (mounted) setState(() => _currentSlide = index);
          },
          initialAttemptNumber: initialAttemptNumberFromModule,
          showActivityInitially: showActivity, // From module state
          onShowActivitySection: onShowActivityCallback,
          onProcessAgentTurn: _handleProcessAgentTurn,
          onSaveLessonAttempt: _handleSaveLessonAttempt,
        );
      case 2:
        return Lesson5_2(
          key: ValueKey('lesson5_2_attempt_${_lessonAttemptCounts["lesson2"]}'),
          passToShowSummary:
              _triggerSummaryDisplay[lessonNum] ?? false, // <<< NEW PROP
          summaryData: _lastAttemptDataForSummary[lessonNum], // <<< NEW PROP
          currentSlide: _currentSlide,
          carouselController: _carouselController,
          onSlideChanged: (index) {
            if (mounted) setState(() => _currentSlide = index);
          },
          initialAttemptNumber: initialAttemptNumberFromModule,
          showActivityInitially: showActivity,
          onShowActivitySection: onShowActivityCallback,
          // Assuming L5.2 uses similar processing, adjust if handlers are different
          onProcessAgentTurn: _handleProcessAgentTurn,
          onSaveLessonAttempt: _handleSaveLessonAttempt,
        );
      default:
        _logger.w(
            'Module 5: Invalid lesson number in _buildLessonContentWidget: $currentLesson');
        return Center(child: Text('Error: Invalid lesson $currentLesson'));
    }
  }
}