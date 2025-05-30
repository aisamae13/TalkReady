import 'package:flutter/material.dart' hide CarouselController;
import 'package:carousel_slider/carousel_slider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:logger/logger.dart';
import '../firebase_service.dart';
import '../lessons/lesson3_1.dart';
import '../lessons/lesson3_2.dart';

class Module3Page extends StatefulWidget {
  final String? targetLessonKey;
  const Module3Page({super.key, this.targetLessonKey});

  @override
  State<Module3Page> createState() => _Module3PageState();
}

class _Module3PageState extends State<Module3Page> {
  int currentLesson = 1;
  bool showActivity = false;
  late YoutubePlayerController _youtubeController;
  int _currentSlide = 0;
  final CarouselSliderController _carouselController = CarouselSliderController();
  final Logger _logger = Logger();
  final FirebaseService _firebaseService = FirebaseService();

  late List<List<String>> _selectedAnswers;
  late List<bool?> _isCorrectStates;
  late List<String?> _errorMessages;
  late List<bool> _answerCorrectness; // To track overall correctness for scoring

  String? _youtubeError;
  Map<String, bool> _lessonCompletion = {
    'lesson1': false, // Corresponds to Lesson 3.1
    'lesson2': false, // Corresponds to Lesson 3.2
  };
  late Map<String, int> _lessonAttemptCounts;
  late Stopwatch _stopwatch;
  bool _isContentLoaded = false;
  bool _isLoading = false; // <-- Add this line

  final Map<int, String> _videoIds = {
    1: 'nMC16FZhsUM', // Lesson 3.1: Listening Comprehension
    2: 'caieIZfl3Ew', // Lesson 3.2: Speaking Practice
  };

  // Define how many questions each lesson in this module has
  final Map<int, int> _lessonQuestionCountsMap = {
    1: 1, // Lesson 3.1 has 1 question (MCQ)
    2: 1, // Lesson 3.2 has 1 "question" (speaking prompt)
  };

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();
    _lessonAttemptCounts = {'lesson1': 0, 'lesson2': 0};
    _performAsyncInit();
  }

  Future<void> _performAsyncInit() async {
    try {
      await _loadLessonProgress();
      _initializeStateLists();
      _initializeYoutubeController();

      if (mounted) {
        setState(() {
          if (widget.targetLessonKey != null) {
            showActivity = _lessonCompletion[widget.targetLessonKey!] ?? false;
            _logger.i("Module 3: Target lesson ${widget.targetLessonKey} specified. showActivity set to: $showActivity");
          } else {
            showActivity = _lessonCompletion['lesson$currentLesson'] ?? false;
            _logger.i("Module 3: No target lesson. currentLesson: $currentLesson. showActivity set to: $showActivity");
          }
          _isContentLoaded = true;
        });
      }
    } catch (error) {
      _logger.e("Error during initState loading for Module 3: $error");
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
      final progress = await _firebaseService.getModuleProgress('module3');
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
            else currentLesson = 2; // All complete, default to last
        }
      } else {
        _logger.i("Module 3: No target lesson key. Determining current lesson by progress.");
        if (!(_lessonCompletion['lesson1'] ?? false)) currentLesson = 1;
        else if (!(_lessonCompletion['lesson2'] ?? false)) currentLesson = 2;
        else currentLesson = 2; // All complete, default to last
      }
      _logger.i('Module 3: Loaded lesson progress: currentLesson=$currentLesson, completion=$_lessonCompletion, attempts=$_lessonAttemptCounts');
    } catch (e) {
      _logger.e('Module 3: Error loading lesson progress: $e');
      rethrow;
    }
  }

  void _initializeStateLists() {
    int questionCount = _lessonQuestionCountsMap[currentLesson] ?? 0;
    _logger.i('Module 3: Initializing state lists for Lesson $currentLesson: questionCount=$questionCount');
    _selectedAnswers = List<List<String>>.generate(questionCount, (_) => <String>[], growable: true);
    _isCorrectStates = List<bool?>.filled(questionCount, null, growable: true);
    _errorMessages = List<String?>.filled(questionCount, null, growable: true);
    _answerCorrectness = List<bool>.filled(questionCount, false, growable: true);
  }

  void _initializeYoutubeController() {
    String? videoId = _videoIds[currentLesson];
    _logger.i('Module 3: Initializing YouTube controller for Lesson $currentLesson: videoId=$videoId');
    _youtubeController = YoutubePlayerController(
      initialVideoId: videoId ?? '',
      flags: const YoutubePlayerFlags(
        autoPlay: false, mute: false, enableCaption: true, captionLanguage: 'en', hideControls: false,
      ),
    );
    _youtubeController.addListener(() {
      if (_youtubeController.value.errorCode != 0 && mounted) {
        setState(() => _youtubeError = 'Error playing video: ${_youtubeController.value.errorCode}');
        _logger.e('Module 3: YouTube Player Error: ${_youtubeController.value.errorCode}');
      }
    });
  }

  void _updateYoutubeVideoId() {
    String? videoId = _videoIds[currentLesson];
    _logger.i('Module 3: Updating YouTube video for Lesson $currentLesson: videoId=$videoId');
    if (videoId != null && videoId.isNotEmpty) {
      _youtubeController.pause();
      _youtubeController.load(videoId);
      if (mounted) setState(() => _youtubeError = null);
    } else {
      if (mounted) setState(() => _youtubeError = 'No video available for Lesson $currentLesson');
      _logger.w('Module 3: No video ID found for Lesson $currentLesson');
    }
  }
  
  Future<bool> _saveLessonProgress(int lessonNumberInModule) async {
    try {
      final lessonFirebaseKey = 'lesson$lessonNumberInModule';
      await _firebaseService.updateLessonProgress('module3', lessonFirebaseKey, true, attempts: _lessonAttemptCounts);
      if (mounted) {
        setState(() {
          _lessonCompletion[lessonFirebaseKey] = true;
        });
      }
      _logger.i('Module 3: Saved $lessonFirebaseKey as completed with attempts: ${_lessonAttemptCounts[lessonFirebaseKey]}.');
      return true;
    } catch (e) {
      _logger.e('Module 3: Error saving lesson progress for $lessonNumberInModule: $e');
      return false;
    }
  }

  Future<void> _validateAllAnswers({
    required List<Map<String, dynamic>> questionsData,
    required int timeSpentFromLesson,
    required int attemptNumberFromLesson,
    List<List<String>>? directSelectedAnswers, // For lessons providing answers directly
  }) async {
    final String lessonKey = 'lesson$currentLesson';
    _lessonAttemptCounts[lessonKey] = attemptNumberFromLesson;

    _logger.i('Module 3: Validating answers for Lesson $currentLesson. Attempt: $attemptNumberFromLesson, Time: $timeSpentFromLesson s');

    final List<List<String>> answersToValidate = directSelectedAnswers ?? _selectedAnswers;

    if (answersToValidate.any((ans) => ans.isEmpty || ans.first.trim().isEmpty)) {
        _logger.w('Module 3: Lesson $currentLesson submission attempt $attemptNumberFromLesson, but not all parts answered.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please complete the activity before submitting.'))
          );
        }
        return;
    }
    
    int score = 0;
    int totalScore = questionsData.length;

    if (mounted) {
      setState(() {
        for (int i = 0; i < questionsData.length; i++) {
          final question = questionsData[i];
          final userAnswer = answersToValidate.length > i ? answersToValidate[i].first.trim() : "";
          bool isCorrect = false;

          if (currentLesson == 1) { // Lesson 3.1 MCQ
            final correctAnswerIndex = question['correctAnswer'] as String?; // Storing index as string
            isCorrect = userAnswer == correctAnswerIndex;
          } else if (currentLesson == 2) { // Lesson 3.2 Speaking
            isCorrect = userAnswer.isNotEmpty; // Mark as "correct" if recording submitted
          }
          
          if (i < _answerCorrectness.length) _answerCorrectness[i] = isCorrect;
          if (i < _isCorrectStates.length) _isCorrectStates[i] = isCorrect;
          if (i < _errorMessages.length) _errorMessages[i] = isCorrect ? null : (question['explanation'] as String? ?? 'Please review the material.');
        }
        score = _answerCorrectness.where((c) => c).length;
      });
    }


    final Map<int, String> lessonTitles = {
      1: 'Lesson 3.1: Listening Comprehension',
      2: 'Lesson 3.2: Speaking Practice',
    };
    String lessonIdForLogging = lessonTitles[currentLesson] ?? "Module 3 Lesson $currentLesson";

    List<Map<String, dynamic>> detailedResponses = questionsData.asMap().entries.map((e) {
      int idx = e.key;
      return {
        'question': e.value['question'],
        'userAnswer': idx < answersToValidate.length ? answersToValidate[idx] : <String>[],
        'correct': idx < _isCorrectStates.length ? _isCorrectStates[idx] : false,
      };
    }).toList();

    await _firebaseService.logLessonActivity('module3', lessonIdForLogging, attemptNumberFromLesson, score, totalScore, timeSpentFromLesson, detailedResponses);
    
    bool success = await _saveLessonProgress(currentLesson);
    if (success) {
      _logger.i('Module 3: Lesson $lessonIdForLogging marked as completed. Logged attempt $attemptNumberFromLesson with score $score/$totalScore.');
      if (mounted) setState(() => showActivity = true);
    } else {
      _logger.e('Module 3: Failed to mark Lesson $currentLesson as completed.');
    }
  }


  @override
  void dispose() {
    _stopwatch.stop();
    if (_isContentLoaded && mounted) {
        _youtubeController.pause();
        _youtubeController.removeListener(() {});
        _youtubeController.dispose();
    }
    super.dispose();
    _logger.i('Disposed Module3Page');
  }

  @override
  Widget build(BuildContext context) {
    if (!_isContentLoaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('Module 3')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    bool isModuleCompleted = _lessonCompletion.values.every((completed) => completed);
    bool currentLessonLocallyCompleted = _lessonCompletion['lesson$currentLesson'] ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Module 3: Listening & Speaking'),
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
                      Text(
                        'Lesson $currentLesson of 2',
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_youtubeError != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(_youtubeError!, style: const TextStyle(color: Colors.red, fontSize: 16), textAlign: TextAlign.center),
                    ),
                  if (_youtubeError == null) _buildLessonContent(),
                  
                  // Next Lesson button with loading
                  if (showActivity && currentLessonLocallyCompleted && currentLesson < 2 && _youtubeError == null) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton(
                              onPressed: () async {
                                setState(() => _isLoading = true);
                                _logger.i('Module 3: Next Lesson button pressed, switching to Lesson ${currentLesson + 1}');
                                await Future.delayed(const Duration(milliseconds: 600)); // Simulate async work
                                if (mounted) {
                                  setState(() {
                                    currentLesson++;
                                    showActivity = _lessonCompletion['lesson$currentLesson'] ?? false;
                                    _currentSlide = 0;
                                    _carouselController.jumpToPage(0);
                                    _initializeStateLists();
                                    _updateYoutubeVideoId();
                                    _stopwatch.reset();
                                    _stopwatch.start();
                                    _isLoading = false;
                                  });
                                }
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00568D), foregroundColor: Colors.white),
                              child: const Text('Next Lesson'),
                            ),
                    ),
                  ],
                  // Module Completed button with loading
                  if (showActivity && currentLessonLocallyCompleted && currentLesson == 2 && isModuleCompleted && _youtubeError == null) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton(
                              onPressed: () async {
                                setState(() => _isLoading = true);
                                _logger.i('Module 3: Module Completed button pressed.');
                                await Future.delayed(const Duration(milliseconds: 600)); // Simulate async work
                                if (mounted) {
                                  setState(() => _isLoading = false);
                                  Navigator.pop(context);
                                }
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                              child: const Text('Module Completed - Return to Courses'),
                            ),
                    ),
                  ],
                  // Complete Module & Return button with loading
                  if (showActivity && currentLessonLocallyCompleted && currentLesson == 2 && !isModuleCompleted && _youtubeError == null) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton(
                              onPressed: () async {
                                setState(() => _isLoading = true);
                                _logger.i('Module 3: Complete Last Lesson & Return button pressed.');
                                await Future.delayed(const Duration(milliseconds: 600)); // Simulate async work
                                if (mounted) {
                                  bool allDone = _lessonCompletion.values.every((c) => c);
                                  setState(() => _isLoading = false);
                                  Navigator.pop(context);
                                }
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00568D), foregroundColor: Colors.white),
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
    int questionCount = _lessonQuestionCountsMap[currentLesson] ?? 0;
     if (_selectedAnswers.length != questionCount ||
        _isCorrectStates.length != questionCount ||
        _errorMessages.length != questionCount ||
        _answerCorrectness.length != questionCount) {
      _logger.w('Module 3 List length mismatch for Lesson $currentLesson. Re-initializing.');
      _initializeStateLists();
    }

    int nextAttemptNumber = (_lessonAttemptCounts['lesson$currentLesson'] ?? 0) + 1;
    _logger.i('Module 3, Lesson $currentLesson: Initializing with attempt number: $nextAttemptNumber');

    switch (currentLesson) {
      case 1:
        return Lesson3_1(
          carouselController: _carouselController,
          youtubeController: _youtubeController,
          showActivity: showActivity,
          onShowActivity: () {
            if (mounted) setState(() => showActivity = true);
          },
          // New props for Lesson 3.1
          selectedAnswers: _selectedAnswers, // Will be List<List<String>>
          isCorrectStates: _isCorrectStates,
          errorMessages: _errorMessages,
          onAnswerChanged: (questionIndex, isCorrect, selectedOptionIndex) { // Modified for MCQ
            if (mounted) {
              setState(() {
                if (questionIndex < _selectedAnswers.length) {
                   _selectedAnswers[questionIndex] = [selectedOptionIndex.toString()]; // Store index as string
                }
                if (questionIndex < _isCorrectStates.length) _isCorrectStates[questionIndex] = isCorrect;
              });
            }
          },
          onSubmitAnswers: (questions, timeSpent, attemptNumber, directAnswers) {
            _validateAllAnswers(
              questionsData: questions, 
              timeSpentFromLesson: timeSpent, 
              attemptNumberFromLesson: attemptNumber,
              directSelectedAnswers: directAnswers, // Pass direct answers from lesson
            );
          },
          initialAttemptNumber: nextAttemptNumber,
          currentSlide: _currentSlide,
           onSlideChanged: (index) {
            if (mounted) setState(() => _currentSlide = index);
          },
        );
      case 2:
        return Lesson3_2(
          carouselController: _carouselController,
          youtubeController: _youtubeController,
          showActivity: showActivity,
          onShowActivity: () {
            if (mounted) setState(() => showActivity = true);
          },
          // New props for Lesson 3.2
          selectedAnswers: _selectedAnswers, // Will be List<List<String>>
          isCorrectStates: _isCorrectStates, // Likely always true if submitted
          errorMessages: _errorMessages,     // Likely always null
          onAnswerChanged: (questionIndex, isCorrect, recordedText) { // Modified for speaking
             if (mounted) {
              setState(() {
                if (questionIndex < _selectedAnswers.length) {
                   _selectedAnswers[questionIndex] = [recordedText];
                }
                 if (questionIndex < _isCorrectStates.length) _isCorrectStates[questionIndex] = isCorrect; // True if submitted
              });
            }
          },
          onSubmitAnswers: (questions, timeSpent, attemptNumber, directAnswers) {
             _validateAllAnswers(
              questionsData: questions, 
              timeSpentFromLesson: timeSpent, 
              attemptNumberFromLesson: attemptNumber,
              directSelectedAnswers: directAnswers,
            );
          },
          initialAttemptNumber: nextAttemptNumber,
          currentSlide: _currentSlide,
          onSlideChanged: (index) {
            if (mounted) setState(() => _currentSlide = index);
          },
        );
      default:
        _logger.w('Module 3: Invalid lesson number: $currentLesson');
        return Text('Invalid lesson $currentLesson');
    }
  }
}