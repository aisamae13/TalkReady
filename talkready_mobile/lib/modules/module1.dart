import 'package:flutter/material.dart' hide CarouselController;
import 'package:carousel_slider/carousel_slider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:logger/logger.dart';
import '../firebase_service.dart';
import '../lessons/lesson1_1.dart';
import '../lessons/lesson1_2.dart';
import '../lessons/lesson1_3.dart';

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
  final CarouselSliderController _carouselController = CarouselSliderController();
  late List<bool> _answerCorrectness;
  late List<List<String>> _selectedAnswers;
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
  late Map<String, int> _lessonAttemptCounts;
  late Stopwatch _stopwatch;

  final Map<int, String> _videoIds = {
    1: '0GVcQjDOW6Q', // Lesson 1.1: Nouns and Pronouns
    2: 'LRJXMKZ4wOw', // Lesson 1.2: Simple Sentences
    3: 'LfJPA8GwTdk', // Lesson 1.3: Verb and Tenses (Present Simple)
  };

  bool _isContentLoaded = false; // Flag to track loading state

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();
    _lessonAttemptCounts = {'lesson1': 0, 'lesson2': 0, 'lesson3': 0};
    _performAsyncInit();
  }

  Future<void> _performAsyncInit() async {
    try {
      await _loadLessonProgress();
      _initializeStateLists(); // Call this after currentLesson is potentially set by _loadLessonProgress
      _initializeYoutubeController();

      if (mounted) {
        setState(() {
          if (widget.targetLessonKey != null) {
            // Determine showActivity based on the specific target lesson's completion
            showActivity = _lessonCompletion[widget.targetLessonKey!] ?? false;
             _logger.i("Target lesson ${widget.targetLessonKey} specified. showActivity set to: $showActivity");
          } else {
            // Default behavior if no target lesson is specified
            showActivity = _lessonCompletion['lesson$currentLesson'] ?? false;
            _logger.i("No target lesson. currentLesson: $currentLesson. showActivity set to: $showActivity");
          }
          _isContentLoaded = true;
        });
      }
    } catch (error) {
      _logger.e("Error during initState loading for Module 1: $error");
      if (mounted) {
        setState(() {
          _youtubeError = "Failed to load lesson content. Please try again.";
          _isContentLoaded = true; // Ensure UI can build even with error
        });
      }
    }
  }

  Future<void> _loadLessonProgress() async {
    try {
      final progress = await _firebaseService.getModuleProgress('module1');
      final lessonsData = progress['lessons'] as Map<String, dynamic>? ?? {};
      final attemptData = progress['attempts'] as Map<String, dynamic>? ?? {};

      _lessonCompletion = {
        'lesson1': lessonsData['lesson1'] ?? false,
        'lesson2': lessonsData['lesson2'] ?? false,
        'lesson3': lessonsData['lesson3'] ?? false,
      };

      _lessonAttemptCounts = {
        'lesson1': attemptData['lesson1'] as int? ?? 0,
        'lesson2': attemptData['lesson2'] as int? ?? 0,
        'lesson3': attemptData['lesson3'] as int? ?? 0,
      };

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
            _logger.w("Unknown targetLessonKey: ${widget.targetLessonKey}. Defaulting to normal progression.");
            // Fallback logic if targetLessonKey is invalid
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
      } else {
        _logger.i("No target lesson key. Determining current lesson by progress.");
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
      _logger.i('Loaded lesson progress for module1: currentLesson=$currentLesson, lessonCompletion=$_lessonCompletion, targetKey=${widget.targetLessonKey}, attempts=$_lessonAttemptCounts');
    } catch (e) {
      _logger.e('Error loading lesson progress for module1: $e');
      // Optionally, set default values or rethrow to be handled by caller
      rethrow; // Or handle more gracefully, e.g., by setting default states
    }
  }

  Future<bool> _saveLessonProgress(int lessonNumberInModule) async {
    try {
      final lessonFirebaseKey = 'lesson$lessonNumberInModule';
      // _lessonAttemptCounts is used here. It should be up-to-date with attemptNumberFromLesson for the current lesson.
      await _firebaseService.updateLessonProgress('module1', lessonFirebaseKey, true, attempts: _lessonAttemptCounts);
      if (mounted) {
        setState(() {
          _lessonCompletion[lessonFirebaseKey] = true;
        });
      }
      _logger.i('Saved $lessonFirebaseKey as completed for module1 with attempts: ${_lessonAttemptCounts[lessonFirebaseKey]}');
      return true;
    } catch (e) {
      _logger.e('Error saving lesson progress for module1 ($lessonNumberInModule): $e');
      return false;
    }
  }

  void _initializeStateLists() {
    // Lesson 1.1 and 1.2 have 8 questions, Lesson 1.3 has 10 questions.
    int questionCount = currentLesson == 3 ? 10 : 8;
    _logger.i('Initializing state lists for Lesson $currentLesson (module1): questionCount=$questionCount');
    _answerCorrectness = List<bool>.filled(questionCount, false);
    _selectedAnswers = List<List<String>>.generate(questionCount, (_) => <String>[]);
    _isCorrectStates = List<bool?>.filled(questionCount, null);
    _errorMessages = List<String?>.filled(questionCount, null);
  }

  void _initializeYoutubeController() {
    String? videoId = _videoIds[currentLesson];
    _logger.i('Initializing YouTube controller for Lesson $currentLesson (module1): videoId=$videoId');
    if (videoId == null || videoId.isEmpty) {
      _logger.w('No video ID for Lesson $currentLesson (module1), controller will use empty ID.');
      videoId = ''; // Prevent null error, player will show error state
    }
    _youtubeController = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: false,
        mute: false,
        enableCaption: true,
        captionLanguage: 'en',
        hideControls: false, // Show controls by default
      ),
    );
    // Add listener for errors
    _youtubeController.addListener(() {
      if (_youtubeController.value.errorCode != 0 && mounted) {
        setState(() {
          _youtubeError = 'Error playing video: ${_youtubeController.value.errorCode}';
        });
        _logger.e('YouTube Player Error (module1): ${_youtubeController.value.errorCode}');
      }
    });
  }

  void _updateYoutubeVideoId() {
    String? videoId = _videoIds[currentLesson];
    _logger.i('Updating YouTube video for Lesson $currentLesson (module1): videoId=$videoId');
    if (videoId != null && videoId.isNotEmpty) {
      try {
        // It's generally safer to create a new controller instance
        // than to try and load a new video into an existing one if issues arise.
        _youtubeController.pause(); // Pause current video if playing
        _youtubeController.removeListener(() {}); // Clean up old listeners
        _youtubeController.dispose(); // Dispose of the old controller

        _youtubeController = YoutubePlayerController( // Create a new one
          initialVideoId: videoId,
          flags: const YoutubePlayerFlags(
            autoPlay: false,
            mute: false,
            enableCaption: true,
            captionLanguage: 'en',
            hideControls: false,
          ),
        );
        _youtubeController.addListener(() { // Add error listener to new controller
            if (_youtubeController.value.errorCode != 0 && mounted) {
                setState(() {
                _youtubeError = 'Error playing video: ${_youtubeController.value.errorCode}';
                });
                _logger.e('YouTube Player Error on update (module1): ${_youtubeController.value.errorCode}');
            }
        });

        if (mounted) {
          setState(() {
            _youtubeError = null; // Clear previous errors
          });
        }
        _logger.i('Successfully updated YouTube video for Lesson $currentLesson (module1): videoId=$videoId');
      } catch (e) {
        _logger.e('Error loading YouTube video for Lesson $currentLesson (module1): $e');
        if (mounted) {
          setState(() {
            _youtubeError = 'Failed to load video for Lesson $currentLesson. Please try again.';
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

  Future<void> _validateAllAnswers({
    required List<Map<String, dynamic>> questionsData,
    List<String>? userAnswersFromLesson1_3, // Specific for Lesson 1.3
    required int timeSpentFromLesson,
    required int attemptNumberFromLesson, // This is the current attempt number from the lesson
  }) async {
    final String lessonKey = 'lesson$currentLesson';
    // Ensure _lessonAttemptCounts is updated with the attempt number from the lesson widget
    _lessonAttemptCounts[lessonKey] = attemptNumberFromLesson;

    _logger.i('Validating answers for ${questionsData.length} questions in Lesson $currentLesson (module1). Attempt: $attemptNumberFromLesson, Time: $timeSpentFromLesson s');

    List<List<String>> selectedAnswersForValidation;

    // Handle answers from Lesson 1.3 (fill-in-the-blanks) differently
    if (userAnswersFromLesson1_3 != null && currentLesson == 3) {
      selectedAnswersForValidation = userAnswersFromLesson1_3.map((answer) => [answer.trim()]).toList();
      // Update the main _selectedAnswers list for UI consistency if needed
      if (mounted) {
        setState(() {
          for (int i = 0; i < userAnswersFromLesson1_3.length; i++) {
            if (i < _selectedAnswers.length) {
              _selectedAnswers[i] = [userAnswersFromLesson1_3[i].trim()];
            }
          }
        });
      }
    } else {
      // For Lesson 1.1 and 1.2 (word selection)
      selectedAnswersForValidation = _selectedAnswers
          .map((list) => list.map((e) => e.toString().trim()).toList())
          .toList();
    }

    // Check if all questions have been answered
    for (int i = 0; i < questionsData.length; i++) {
      if (selectedAnswersForValidation.length <= i || selectedAnswersForValidation[i].isEmpty || (selectedAnswersForValidation[i].length == 1 && selectedAnswersForValidation[i].first.isEmpty)) {
        _logger.w('Lesson $currentLesson (module1) submission attempt $attemptNumberFromLesson, but question ${i + 1} was not answered.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please answer all questions before submitting.'))
          );
        }
        return; // Stop validation if any question is unanswered
      }
    }

    if (mounted) {
      setState(() {
        // Ensure lists are correctly sized for the current questionsData
        if (_answerCorrectness.length != questionsData.length) _answerCorrectness = List<bool>.filled(questionsData.length, false);
        if (_isCorrectStates.length != questionsData.length) _isCorrectStates = List<bool?>.filled(questionsData.length, null);
        if (_errorMessages.length != questionsData.length) _errorMessages = List<String?>.filled(questionsData.length, null);
        
        for (int i = 0; i < questionsData.length; i++) {
          List<String> correctAnswers;
          final rawCorrectAnswer = questionsData[i]['correctAnswer'];
          final explanation = questionsData[i]['explanation'] ?? 'No explanation provided'; // Default explanation

          // Handle different formats of correctAnswer
          if (rawCorrectAnswer is String) {
            correctAnswers = rawCorrectAnswer.toLowerCase().split(', ').map((e) => e.trim()).toList();
          } else if (rawCorrectAnswer is List<dynamic>) {
            correctAnswers = rawCorrectAnswer.map((e) => e.toString().toLowerCase().trim()).toList();
          } else {
            // Invalid format for correctAnswer
            correctAnswers = []; // No correct answer to compare against
            if (i < _errorMessages.length) _errorMessages[i] = 'Invalid correct answer format: $explanation';
            if (i < _isCorrectStates.length) _isCorrectStates[i] = false;
            if (i < _answerCorrectness.length) _answerCorrectness[i] = false;
            _logger.e('Invalid correct answer format for question $i in Lesson $currentLesson (module1)');
            continue; // Move to the next question
          }

          // Get current selected answers for this question
          List<String> currentSelected = selectedAnswersForValidation[i].map((e) => e.toLowerCase()).toList();

          // Validate the answer
          bool isCorrect = correctAnswers.every((correct) => currentSelected.contains(correct)) &&
              currentSelected.every((selected) => correctAnswers.contains(selected));

          if (i < _isCorrectStates.length) _isCorrectStates[i] = isCorrect;
          if (i < _errorMessages.length) _errorMessages[i] = isCorrect ? null : explanation;
          if (i < _answerCorrectness.length) _answerCorrectness[i] = isCorrect;
          _logger.d('Validated question $i in Lesson $currentLesson (module1): isCorrect=$isCorrect, selected=$currentSelected, correct=$correctAnswers');
        }
      });
    }

    int score = _answerCorrectness.where((c) => c).length;
    int totalScore = questionsData.length;

    final Map<int, String> lessonTitles = {
      1: 'Lesson 1.1: Nouns and Pronouns',
      2: 'Lesson 1.2: Simple Sentences',
      3: 'Lesson 1.3: Verb and Tenses (Present Simple)',
    };
    String lessonIdForLogging = lessonTitles[currentLesson]!; // Assuming currentLesson is always 1, 2, or 3

    List<Map<String, dynamic>> detailedResponses = questionsData.asMap().entries.map((e) {
      int idx = e.key;
      return {
        'question': e.value['question'],
        'userAnswer': idx < selectedAnswersForValidation.length ? selectedAnswersForValidation[idx] : <String>[],
        'correct': idx < _isCorrectStates.length ? _isCorrectStates[idx] : false,
      };
    }).toList();

    // Log activity with the attemptNumberFromLesson
    await _firebaseService.logLessonActivity('module1', lessonIdForLogging, attemptNumberFromLesson, score, totalScore, timeSpentFromLesson, detailedResponses);
    
    // Save progress, which will use the updated _lessonAttemptCounts
    bool success = await _saveLessonProgress(currentLesson);
    if (success) {
      _logger.i('Lesson $lessonIdForLogging (module1) marked as completed. Logged attempt $attemptNumberFromLesson with score $score/$totalScore, time $timeSpentFromLesson s.');
      if (mounted) {
        setState(() {
          showActivity = true; // Show activity/results section
        });
      }
    } else {
      _logger.e('Failed to mark Lesson $currentLesson (module1) as completed, but still logging attempt.');
      // Note: logLessonActivity was already called above.
    }
  }

  @override
  void dispose() {
    _stopwatch.stop();
    // Only dispose if the controller was initialized and no critical error prevented it.
    if (_isContentLoaded && _youtubeError == null && mounted) { // Check mounted as well
        _youtubeController.pause();
        _youtubeController.removeListener(() {}); // Clean up listeners
        _youtubeController.dispose();
    }
    super.dispose();
    _logger.i('Disposed Module1Page');
  }

  @override
  Widget build(BuildContext context) {
    if (!_isContentLoaded) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Module 1: Basic English Grammar',
            style: TextStyle(fontSize: 15), // Adjusted for potentially long titles
          ),
          backgroundColor: Colors.transparent, // Make AppBar transparent
          foregroundColor: const Color(0xFF00568D), // Set icon and text color
          elevation: 0, // Remove shadow
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Determine if the entire module is completed
    bool isModuleCompleted = _lessonCompletion.values.every((completed) => completed);
    // Determine if the current lesson is completed (based on loaded progress)
    bool currentLessonLocallyCompleted = _lessonCompletion['lesson$currentLesson'] ?? false;


    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Module 1: Basic English Grammar',
          style: TextStyle(fontSize: 15), // Adjusted for potentially long titles
        ),
        backgroundColor: Colors.transparent, // Make AppBar transparent
        foregroundColor: const Color(0xFF00568D), // Set icon and text color
        elevation: 0, // Remove shadow
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            _logger.i('Back button pressed on Module1Page. Popping.');
            Navigator.pop(context);
          }
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
                      Text(
                        'Lesson $currentLesson of 3',
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_youtubeError != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        _youtubeError!,
                        style: const TextStyle(color: Colors.red, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  // Only build lesson content if there's no YouTube error
                  if (_youtubeError == null) _buildLessonContent(),

                  // Conditional "Next Lesson" button
                  if (showActivity && currentLessonLocallyCompleted && currentLesson < 3 && _youtubeError == null) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                                _logger.i('Next Lesson button pressed, switching to Lesson ${currentLesson + 1} (module1)');
                                if (mounted) {
                                  setState(() {
                                    currentLesson++;
                                    // Determine if the new lesson's activity should be shown based on its completion status
                                    showActivity = _lessonCompletion['lesson$currentLesson'] ?? false;
                                    _currentSlide = 0; // Reset slide for the new lesson
                                    _carouselController.jumpToPage(0);
                                    _initializeStateLists(); // Re-initialize lists for the new lesson's question count
                                    _updateYoutubeVideoId(); // Load the new lesson's video
                                    _stopwatch.reset(); // Reset and start stopwatch for the new lesson
                                    _stopwatch.start();
                                    _logger.i('Switched to Lesson $currentLesson (module1). showActivity: $showActivity');
                                  });
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00568D), // Theme color
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Next Lesson'),
                      ),
                    ),
                  ],
                  // Conditional "Module Completed" button
                  if (showActivity && currentLessonLocallyCompleted && currentLesson == 3 && isModuleCompleted && _youtubeError == null) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                                _logger.i('Complete Module & Return to Courses button pressed (Module 1).');
                                if (mounted) {
                                   Navigator.pop(context); // Go back to the courses page
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green, // Success color
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Module Completed - Return to Courses'),
                      ),
                    ),
                  ],
                  // Case: Last lesson completed, but module not yet fully marked as complete (e.g., due to async operations)
                  // Still allow user to exit as they've finished the last lesson's activity.
                  if (showActivity && currentLessonLocallyCompleted && currentLesson == 3 && !isModuleCompleted && _youtubeError == null) ...[
                     const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                                _logger.i('Complete Lesson 1.3 & Return to Courses button pressed (module not yet fully marked complete).');
                                if (mounted) {
                                   // Check one last time if all lessons are now marked complete
                                   bool allDone = _lessonCompletion.values.every((c) => c);
                                   if (allDone) {
                                       _logger.i('Module 1 confirmed complete. Popping to CoursesPage.');
                                       Navigator.pop(context);
                                   } else {
                                       // This case might occur if Firebase updates are slow or if there's a logic discrepancy.
                                       // For a better user experience, allow them to exit.
                                       _logger.w('Lesson 1.3 marked complete, but module state not fully updated or other lessons incomplete. Popping anyway. State: $_lessonCompletion');
                                       Navigator.pop(context);
                                   }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00568D), // Theme color
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Complete Module & Return to Courses'),
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

  Widget _buildLessonContent() {
    int questionCount = currentLesson == 3 ? 10 : 8;
    if (_selectedAnswers.length != questionCount ||
        _isCorrectStates.length != questionCount ||
        _errorMessages.length != questionCount ||
        _answerCorrectness.length != questionCount) {
      _logger.w('List length mismatch for Lesson $currentLesson (module1) in _buildLessonContent. Re-initializing lists.');
      _initializeStateLists();
    }

    // Calculate the next attempt number
    int nextAttemptNumber = (_lessonAttemptCounts['lesson$currentLesson'] ?? 0) + 1;
    _logger.i('Module 1, Lesson $currentLesson: Initializing with attempt number: $nextAttemptNumber');

    // Callback for interactive word selection questions
    Function(int, List<String>) onWordsSelectedCallback = (int questionIndex, List<String> selectedWords) {
      if (mounted) {
        setState(() {
          if (questionIndex < _selectedAnswers.length) {
            _selectedAnswers[questionIndex] = selectedWords;
            _logger.d('Module 1, Lesson $currentLesson, Q$questionIndex selection updated: $selectedWords');
            // Optionally reset validation state for this question
            if (questionIndex < _isCorrectStates.length) _isCorrectStates[questionIndex] = null;
            if (questionIndex < _errorMessages.length) _errorMessages[questionIndex] = null;
          } else {
            _logger.w('onWordsSelectedCallback: questionIndex $questionIndex out of bounds for _selectedAnswers (length: ${_selectedAnswers.length})');
          }
        });
      }
    };

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
          selectedAnswers: _selectedAnswers,
          isCorrectStates: _isCorrectStates,
          errorMessages: _errorMessages,
          onAnswerChanged: (index, isCorrect) {
            _logger.d('Answer changed for question $index in Lesson $currentLesson (module1)');
          },
          onSlideChanged: (index) {
            if (mounted) setState(() => _currentSlide = index);
            _logger.d('Slide changed to $index in Lesson $currentLesson (module1)');
          },
          onSubmitAnswers: (questions, timeSpent, attemptNumber) => _validateAllAnswers(
            questionsData: questions,
            timeSpentFromLesson: timeSpent,
            attemptNumberFromLesson: attemptNumber,
          ),
          onWordsSelected: onWordsSelectedCallback,
          initialAttemptNumber: nextAttemptNumber, 
        );
      case 2:
        return buildLesson1_2(
          context: context,
          currentSlide: _currentSlide,
          carouselController: _carouselController,
          youtubeController: _youtubeController,
          showActivity: showActivity,
          onShowActivity: () {
            if (mounted) setState(() => showActivity = true);
          },
          selectedAnswers: _selectedAnswers,
          isCorrectStates: _isCorrectStates,
          errorMessages: _errorMessages,
          onAnswerChanged: (index, isCorrect) {
            _logger.d('Answer changed for question $index in Lesson $currentLesson (module1)');
          },
          onSlideChanged: (index) {
            if (mounted) setState(() => _currentSlide = index);
            _logger.d('Slide changed to $index in Lesson $currentLesson (module1)');
          },
          onSubmitAnswers: (questions, timeSpent, attemptNumber) => _validateAllAnswers(
            questionsData: questions,
            timeSpentFromLesson: timeSpent,
            attemptNumberFromLesson: attemptNumber,
          ),
          onWordsSelected: onWordsSelectedCallback,
          initialAttemptNumber: nextAttemptNumber, 
        );
      case 3:
        return buildLesson1_3(
          context: context,
          currentSlide: _currentSlide,
          carouselController: _carouselController,
          youtubeController: _youtubeController,
          showActivity: showActivity,
          onShowActivity: () {
            if (mounted) setState(() => showActivity = true);
          },
          selectedAnswers: _selectedAnswers,
          isCorrectStates: _isCorrectStates,
          errorMessages: _errorMessages,
          onAnswerChanged: (index, isCorrect) {
            _logger.d('Answer changed for question $index in Lesson $currentLesson (module1)');
          },
          onSlideChanged: (index) {
            if (mounted) setState(() => _currentSlide = index);
            _logger.d('Slide changed to $index in Lesson $currentLesson (module1)');
          },
          onSubmitAnswers: (questions, userAnswers, timeSpent, attemptNumber) => _validateAllAnswers(
            questionsData: questions,
            userAnswersFromLesson1_3: userAnswers,
            timeSpentFromLesson: timeSpent,
            attemptNumberFromLesson: attemptNumber,
          ),
          initialAttemptNumber: nextAttemptNumber, 
        );
      default:
        _logger.w('Invalid lesson number: $currentLesson (module1)');
        return Container(child: Text('Error: Invalid lesson $currentLesson'));
    }
  }
}