import 'package:flutter/material.dart' hide CarouselController;
import 'package:carousel_slider/carousel_slider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:logger/logger.dart';
import '../firebase_service.dart';
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
    1: 'B875gLnHSpw', // Placeholder for Lesson 2.1
    2: 'rpHEd8OEzLw', // Placeholder for Lesson 2.2
    3: 'qm2h74xpuUA', // Placeholder for Lesson 2.3
  };

  final Map<int, int> _lessonQuestionCountsMap = {
    1: 8, // Lesson 2.1 has 8 questions
    2: 8, // Lesson 2.2 has 8 questions
    3: 10, // Lesson 2.3 has 10 questions
  };

  bool _isContentLoaded = false;


  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();
    _lessonAttemptCounts = {'lesson1': 0, 'lesson2': 0, 'lesson3': 0};
    _performAsyncInit();
  }

  Future<void> _performAsyncInit() async {
    try {
      await _loadLessonProgress(); // Sets currentLesson
      _initializeStateLists(); // Call this after currentLesson is set
      _initializeYoutubeController();

      if (mounted) {
        setState(() {
          if (widget.targetLessonKey != null) {
            showActivity = _lessonCompletion[widget.targetLessonKey!] ?? false;
            _logger.i("Module 2: Target lesson ${widget.targetLessonKey} specified. showActivity set to: $showActivity");
          } else {
            showActivity = _lessonCompletion['lesson$currentLesson'] ?? false;
            _logger.i("Module 2: No target lesson. currentLesson: $currentLesson. showActivity set to: $showActivity");
          }
          _isContentLoaded = true;
        });
      }
    } catch (error) {
      _logger.e("Error during initState loading for Module 2: $error");
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
      final progress = await _firebaseService.getModuleProgress('module2');
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
        _logger.i("Module 2: Target lesson key provided: ${widget.targetLessonKey}");
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
            _logger.w("Module 2: Unknown targetLessonKey: ${widget.targetLessonKey}. Defaulting to first incomplete or last lesson.");
            if (!(_lessonCompletion['lesson1'] ?? false)) {
              currentLesson = 1;
            } else if (!(_lessonCompletion['lesson2'] ?? false)) currentLesson = 2;
            else if (!(_lessonCompletion['lesson3'] ?? false)) currentLesson = 3;
            else currentLesson = 3;
        }
      } else {
        _logger.i("Module 2: No target lesson key. Determining current lesson by progress.");
        if (!(_lessonCompletion['lesson1'] ?? false)) {
          currentLesson = 1;
        } else if (!(_lessonCompletion['lesson2'] ?? false)) currentLesson = 2;
        else if (!(_lessonCompletion['lesson3'] ?? false)) currentLesson = 3;
        else currentLesson = 3;
      }
      _logger.i('Module 2: Loaded lesson progress: currentLesson=$currentLesson, lessonCompletion=$_lessonCompletion, targetKey=${widget.targetLessonKey}, attempts=$_lessonAttemptCounts');
    } catch (e) {
      _logger.e('Module 2: Error loading lesson progress: $e');
      rethrow;
    }
  }

  Future<bool> _saveLessonProgress(int lessonNumberInModule) async {
    try {
      final lessonFirebaseKey = 'lesson$lessonNumberInModule';
      await _firebaseService.updateLessonProgress('module2', lessonFirebaseKey, true, attempts: _lessonAttemptCounts);
      if (mounted) {
        setState(() {
          _lessonCompletion[lessonFirebaseKey] = true;
        });
      }
      _logger.i('Module 2: Saved $lessonFirebaseKey as completed with attempts: ${_lessonAttemptCounts[lessonFirebaseKey]}.');
      return true;
    } catch (e) {
      _logger.e('Module 2: Error saving lesson progress for $lessonNumberInModule: $e');
      return false;
    }
  }

  void _initializeStateLists() {
    int questionCount = _lessonQuestionCountsMap[currentLesson] ?? 0;
    if (questionCount == 0) {
        _logger.e('Module 2: CRITICAL - No question count defined for Lesson $currentLesson. Defaulting to 0. This will cause errors.');
    }

    _logger.i('Module 2: Initializing state lists for Lesson $currentLesson: questionCount=$questionCount');
    _answerCorrectness = List<bool>.filled(questionCount, false, growable: true);
    _selectedAnswers = List<List<String>>.generate(questionCount, (_) => <String>[], growable: true);
    _isCorrectStates = List<bool?>.filled(questionCount, null, growable: true);
    _errorMessages = List<String?>.filled(questionCount, null, growable: true);
  }

  void _initializeYoutubeController() {
    String? videoId = _videoIds[currentLesson];
    _logger.i('Module 2: Initializing YouTube controller for Lesson $currentLesson: videoId=$videoId');
    if (videoId == null || videoId.isEmpty) {
      _logger.w('Module 2: No video ID for Lesson $currentLesson, controller will use empty ID.');
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
          _youtubeError = 'Error playing video: ${_youtubeController.value.errorCode}';
        });
        _logger.e('Module 2: YouTube Player Error: ${_youtubeController.value.errorCode}');
      }
    });
  }

  void _updateYoutubeVideoId() {
    String? videoId = _videoIds[currentLesson];
    _logger.i('Module 2: Updating YouTube video for Lesson $currentLesson: videoId=$videoId');
    if (videoId != null && videoId.isNotEmpty) {
      try {
        _youtubeController.pause();
        _youtubeController.removeListener(() {});
        _youtubeController.dispose();

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
                _youtubeError = 'Error playing video: ${_youtubeController.value.errorCode}';
                });
                _logger.e('Module 2: YouTube Player Error on update: ${_youtubeController.value.errorCode}');
            }
        });

        if (mounted) {
          setState(() {
            _youtubeError = null;
          });
        }
        _logger.i('Module 2: Successfully updated YouTube video for Lesson $currentLesson: videoId=$videoId');
      } catch (e) {
        _logger.e('Module 2: Error loading YouTube video for Lesson $currentLesson: $e');
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
      _logger.w('Module 2: No video ID found for Lesson $currentLesson');
    }
  }

  Future<void> _validateAllAnswers(
    List<Map<String, dynamic>> questionsData,
    int timeSpentFromLesson,
    int attemptNumberFromLesson,
  ) async {
    final String lessonKey = 'lesson$currentLesson';
    _lessonAttemptCounts[lessonKey] = attemptNumberFromLesson;
    
    _logger.i('Module 2: Validating answers for ${questionsData.length} questions in Lesson $currentLesson. Attempt: $attemptNumberFromLesson, Time: $timeSpentFromLesson s');

    final List<List<String>> selectedAnswersForValidation = _selectedAnswers
        .map((list) => list.map((e) => e.toString().trim()).toList())
        .toList();

    for (int i = 0; i < questionsData.length; i++) {
      if (selectedAnswersForValidation.length <= i || selectedAnswersForValidation[i].isEmpty) {
        _logger.w('Module 2: Lesson $currentLesson submission attempt $attemptNumberFromLesson, but question ${i + 1} was not answered.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please answer all questions before submitting.'))
          );
        }
        return;
      }
    }

    if (mounted) {
      setState(() {
        // Ensure lists are correctly sized for the current questionsData
        // This is a safeguard; _initializeStateLists should handle primary sizing.
        if (_answerCorrectness.length != questionsData.length) _answerCorrectness = List<bool>.filled(questionsData.length, false, growable: true);
        if (_selectedAnswers.length != questionsData.length) _selectedAnswers = List<List<String>>.generate(questionsData.length, (_) => [], growable: true);
        if (_isCorrectStates.length != questionsData.length) _isCorrectStates = List<bool?>.filled(questionsData.length, null, growable: true);
        if (_errorMessages.length != questionsData.length) _errorMessages = List<String?>.filled(questionsData.length, null, growable: true);


        for (int i = 0; i < questionsData.length; i++) {
          List<String> correctAnswers;
          final rawCorrectAnswer = questionsData[i]['correctAnswer'];
          final explanation = questionsData[i]['explanation'] ?? 'No explanation provided';

          if (rawCorrectAnswer is String) {
            correctAnswers = rawCorrectAnswer.toLowerCase().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
          } else if (rawCorrectAnswer is List<dynamic>) {
            correctAnswers = rawCorrectAnswer.map((e) => e.toString().toLowerCase().trim()).toList();
          } else {
            correctAnswers = [];
            if (i < _errorMessages.length) _errorMessages[i] = 'Invalid correct answer format: $explanation';
            if (i < _isCorrectStates.length) _isCorrectStates[i] = false;
            if (i < _answerCorrectness.length) _answerCorrectness[i] = false;
            _logger.e('Module 2: Invalid correct answer format for question $i in Lesson $currentLesson');
            continue;
          }
          
          // Ensure selectedAnswersForValidation has an entry for this index
          List<String> currentSelected = (i < selectedAnswersForValidation.length)
              ? selectedAnswersForValidation[i].map((e) => e.toLowerCase()).toList()
              : <String>[];


          bool isCorrect = correctAnswers.isNotEmpty && // Cannot be correct if there are no correct answers defined
                           correctAnswers.every((correct) => currentSelected.contains(correct)) &&
                           currentSelected.every((selected) => correctAnswers.contains(selected)) &&
                           currentSelected.length == correctAnswers.length;


          if (i < _isCorrectStates.length) _isCorrectStates[i] = isCorrect;
          if (i < _errorMessages.length) _errorMessages[i] = isCorrect ? null : explanation;
          if (i < _answerCorrectness.length) _answerCorrectness[i] = isCorrect;
        }
      });
    }

    int score = _answerCorrectness.where((c) => c).length;
    int totalScore = questionsData.length;

    final Map<int, String> lessonTitles = {
      1: 'Lesson 2.1: Greetings and Introductions',
      2: 'Lesson 2.2: Asking for Information',
      3: 'Lesson 2.3: Numbers and Dates',
    };
    String lessonIdForLogging = lessonTitles[currentLesson] ?? "Module 2 Lesson $currentLesson";

    List<Map<String, dynamic>> detailedResponses = questionsData.asMap().entries.map((e) {
      int idx = e.key;
      return {
        'question': e.value['question'],
        'userAnswer': idx < selectedAnswersForValidation.length ? selectedAnswersForValidation[idx] : <String>[],
        'correct': idx < _isCorrectStates.length ? _isCorrectStates[idx] : false,
      };
    }).toList();

    await _firebaseService.logLessonActivity('module2', lessonIdForLogging, attemptNumberFromLesson, score, totalScore, timeSpentFromLesson, detailedResponses);
    
    bool success = await _saveLessonProgress(currentLesson);
    if (success) {
      _logger.i('Module 2: Lesson $lessonIdForLogging marked as completed. Logged attempt $attemptNumberFromLesson with score $score/$totalScore, time $timeSpentFromLesson s.');
      if (mounted) setState(() => showActivity = true);
    } else {
      _logger.e('Module 2: Failed to mark Lesson $currentLesson as completed.');
    }
  }

  @override
  void dispose() {
    _stopwatch.stop();
    if (_isContentLoaded && _youtubeError == null && mounted) {
        _youtubeController.pause();
        _youtubeController.removeListener(() {});
        _youtubeController.dispose();
    }
    super.dispose();
    _logger.i('Disposed Module2Page');
  }

  @override
  Widget build(BuildContext context) {
    if (!_isContentLoaded) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Module 2: Vocabulary & Everyday Conversations',
            style: TextStyle(fontSize: 15),
          ),
          backgroundColor: Colors.transparent,
          foregroundColor: const Color(0xFF00568D),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    bool isModuleCompleted = _lessonCompletion.values.every((completed) => completed);
    bool currentLessonLocallyCompleted = _lessonCompletion['lesson$currentLesson'] ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Module 2: Vocabulary & Everyday Conversations',
          style: TextStyle(fontSize: 15),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF00568D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            _logger.i('Back button pressed on Module2Page. Popping.');
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
                  if (_youtubeError == null) _buildLessonContent(),

                  if (showActivity && currentLessonLocallyCompleted && currentLesson < 3 && _youtubeError == null) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                                _logger.i('Module 2: Next Lesson button pressed, switching to Lesson ${currentLesson + 1}');
                                if (mounted) {
                                  setState(() {
                                    currentLesson++;
                                    showActivity = _lessonCompletion['lesson$currentLesson'] ?? false;
                                    _currentSlide = 0;
                                    _carouselController.jumpToPage(0);
                                    _initializeStateLists(); // Re-initialize for new lesson
                                    _updateYoutubeVideoId();
                                    _stopwatch.reset();
                                    _stopwatch.start();
                                  });
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00568D),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Next Lesson'),
                      ),
                    ),
                  ],
                  if (showActivity && currentLessonLocallyCompleted && currentLesson == 3 && isModuleCompleted && _youtubeError == null) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                                _logger.i('Module 2: Module Completed button pressed.');
                                if (mounted) Navigator.pop(context);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Module Completed - Return to Courses'),
                      ),
                    ),
                  ],
                  if (showActivity && currentLessonLocallyCompleted && currentLesson == 3 && !isModuleCompleted && _youtubeError == null) ...[
                     const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                                _logger.i('Module 2: Complete Last Lesson & Return button pressed.');
                                if (mounted) {
                                   bool allDone = _lessonCompletion.values.every((c) => c);
                                   if (allDone) {
                                       Navigator.pop(context);
                                   } else {
                                       _logger.w('Module 2: Last lesson completed, but module not fully marked. Popping. State: $_lessonCompletion');
                                       Navigator.pop(context);
                                   }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00568D),
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
    int questionCount = _lessonQuestionCountsMap[currentLesson] ?? 0;
    if (questionCount == 0) {
        _logger.e('Module 2 _buildLessonContent: CRITICAL - No question count defined for Lesson $currentLesson. Returning error widget.');
        return Container(child: Text('Error: Configuration error for Lesson $currentLesson. Question count is zero.'));
    }


    // Safety check and re-initialization if list lengths are incorrect
    if (_selectedAnswers.length != questionCount ||
        _isCorrectStates.length != questionCount ||
        _errorMessages.length != questionCount ||
        _answerCorrectness.length != questionCount) {
      _logger.w('Module 2 _buildLessonContent: List length mismatch for Lesson $currentLesson. Expected $questionCount. Re-initializing lists.');
      _initializeStateLists(); // This will use the correct questionCount
    }

    int nextAttemptNumber = (_lessonAttemptCounts['lesson$currentLesson'] ?? 0) + 1;
    _logger.i('Module 2, Lesson $currentLesson: Initializing with attempt number: $nextAttemptNumber');

    onWordsSelectedCallback(int questionIndex, List<String> selectedWords) {
      if (mounted) {
        setState(() {
          if (questionIndex < _selectedAnswers.length) {
            _selectedAnswers[questionIndex] = selectedWords;
            _logger.d('Module 2, Lesson $currentLesson, Q$questionIndex selection updated: $selectedWords');
            if (questionIndex < _isCorrectStates.length) _isCorrectStates[questionIndex] = null;
            if (questionIndex < _errorMessages.length) _errorMessages[questionIndex] = null;
          } else {
            _logger.w('onWordsSelectedCallback: questionIndex $questionIndex out of bounds for _selectedAnswers (length: ${_selectedAnswers.length})');
          }
        });
      }
    }

    _logger.d("Module 2: Building lesson content for Lesson $currentLesson");
    switch (currentLesson) {
      case 1:
        return buildLesson2_1(
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
             _logger.d('Answer changed for question $index in Lesson $currentLesson (module2)');
          },
          onSlideChanged: (index) {
            if (mounted) setState(() => _currentSlide = index);
             _logger.d('Slide changed to $index in Lesson $currentLesson (module2)');
          },
          onSubmitAnswers: (questions, timeSpent, attemptNumber) => _validateAllAnswers(
            questions,
            timeSpent,
            attemptNumber,
          ),
          onWordsSelected: onWordsSelectedCallback,
          initialAttemptNumber: nextAttemptNumber, 
        );
      case 2:
        return buildLesson2_2(
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
             _logger.d('Answer changed for question $index in Lesson $currentLesson (module2)');
          },
          onSlideChanged: (index) {
            if (mounted) setState(() => _currentSlide = index);
             _logger.d('Slide changed to $index in Lesson $currentLesson (module2)');
          },
          onSubmitAnswers: (questions, timeSpent, attemptNumber) => _validateAllAnswers(
            questions,
            timeSpent,
            attemptNumber,
          ),
          onWordsSelected: onWordsSelectedCallback,
          initialAttemptNumber: nextAttemptNumber, 
        );
      case 3:
        return buildLesson2_3(
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
             _logger.d('Answer changed for question $index in Lesson $currentLesson (module2)');
          },
          onSlideChanged: (index) {
            if (mounted) setState(() => _currentSlide = index);
             _logger.d('Slide changed to $index in Lesson $currentLesson (module2)');
          },
          onSubmitAnswers: (questions, timeSpent, attemptNumber) => _validateAllAnswers(
            questions,
            timeSpent,
            attemptNumber,
          ),
          onWordsSelected: onWordsSelectedCallback,
          initialAttemptNumber: nextAttemptNumber, 
        );
      default:
        _logger.w('Module 2: Invalid lesson number: $currentLesson');
        return Container(child: Text('Error: Invalid lesson $currentLesson for Module 2'));
    }
  }
}