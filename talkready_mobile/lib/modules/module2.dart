import 'package:flutter/material.dart' hide CarouselController;
import 'package:carousel_slider/carousel_slider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:logger/logger.dart';
import '../firebase_service.dart';
import '../lessons/lesson2_1.dart';
import '../lessons/lesson2_2.dart';
import '../lessons/lesson2_3.dart';

class Module2Page extends StatefulWidget {
  const Module2Page({super.key});

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
  final Map<String, int> _lessonAttemptCounts = {'lesson1': 0, 'lesson2': 0, 'lesson3': 0};
  late Stopwatch _stopwatch;

  final Map<int, String> _videoIds = {
    1: 'B875gLnHSpw',
    2: 'rpHEd8OEzLw',
    3: 'qm2h74xpuUA',
  };

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();
    _loadLessonProgress().then((_) {
      setState(() {
        showActivity = _lessonCompletion['lesson$currentLesson'] ?? false;
      });
    });
    _initializeStateLists();
    _initializeYoutubeController();
  }

  Future<void> _loadLessonProgress() async {
    try {
      final progress = await _firebaseService.getModuleProgress('module2');
      final lessons = progress['lessons'] as Map<String, dynamic>? ?? {};
      setState(() {
        _lessonCompletion = {
          'lesson1': lessons['lesson1'] ?? false,
          'lesson2': lessons['lesson2'] ?? false,
          'lesson3': lessons['lesson3'] ?? false,
        };
        if (!(lessons['lesson1'] ?? false)) {
          currentLesson = 1;
        } else if (!(lessons['lesson2'] ?? false)) {
          currentLesson = 2;
        } else if (!(lessons['lesson3'] ?? false)) {
          currentLesson = 3;
        } else {
          currentLesson = 3;
        }
        _logger.i('Loaded lesson progress: currentLesson=$currentLesson, lessonCompletion=$_lessonCompletion');
      });
    } catch (e) {
      _logger.e('Error loading lesson progress: $e');
    }
  }

  Future<bool> _saveLessonProgress(int lesson) async {
    try {
      final lessonId = 'lesson$lesson';
      await _firebaseService.updateLessonProgress('module2', lessonId, true);
      setState(() {
        _lessonCompletion[lessonId] = true;
      });
      _logger.i('Saved lesson $lesson as completed');
      return true;
    } catch (e) {
      _logger.e('Error saving lesson progress: $e');
      return false;
    }
  }

  void _initializeStateLists() {
    int questionCount = currentLesson == 3 ? 10 : 8;
    _logger.i('Initializing state lists for Lesson $currentLesson: questionCount=$questionCount');
    _answerCorrectness = List<bool>.filled(questionCount, false);
    _selectedAnswers = List<List<String>>.generate(questionCount, (_) => <String>[]);
    _isCorrectStates = List<bool?>.filled(questionCount, null);
    _errorMessages = List<String?>.filled(questionCount, null);
  }

  void _initializeYoutubeController() {
    String? videoId = _videoIds[currentLesson];
    _logger.i('Initializing YouTube controller for Lesson $currentLesson: videoId=$videoId');
    if (videoId == null || videoId.isEmpty) {
      setState(() {
        _youtubeError = 'No video available for Lesson $currentLesson';
      });
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
  }

  void _updateYoutubeVideoId() {
    String? videoId = _videoIds[currentLesson];
    _logger.i('Updating YouTube video for Lesson $currentLesson: videoId=$videoId');
    if (videoId != null && videoId.isNotEmpty) {
      try {
        WidgetsBinding.instance.addPostFrameCallback((_) {
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
          setState(() {
            _youtubeError = null;
          });
          _logger.i('Successfully updated YouTube video for Lesson $currentLesson: videoId=$videoId');
        });
      } catch (e) {
        _logger.e('Error loading YouTube video for Lesson $currentLesson: $e');
        setState(() {
          _youtubeError = 'Failed to load video for Lesson $currentLesson. Please try again.';
        });
      }
    } else {
      setState(() {
        _youtubeError = 'No video available for Lesson $currentLesson';
      });
      _logger.w('No video ID found for Lesson $currentLesson');
    }
  }

  void _validateAllAnswers(List<Map<String, dynamic>> questions) {
  _logger.i('Validating answers for ${questions.length} questions in Lesson $currentLesson');
  _lessonAttemptCounts['lesson$currentLesson'] = (_lessonAttemptCounts['lesson$currentLesson'] ?? 0) + 1;
  final int attemptNumber = _lessonAttemptCounts['lesson$currentLesson']!;
  final List<List<String>> selectedAnswersCopy = _selectedAnswers
      .map((list) => list.map((e) => e.toString()).toList())
      .toList();
  setState(() {
    for (int i = 0; i < questions.length; i++) {
      List<String> correctAnswers;
      final rawCorrectAnswer = questions[i]['correctAnswer'];
      final explanation = questions[i]['explanation'] ?? 'No explanation provided';
      if (rawCorrectAnswer is String) {
        correctAnswers = rawCorrectAnswer.toLowerCase().split(', ').map((e) => e.trim()).toList();
      } else if (rawCorrectAnswer is List<dynamic>) {
        correctAnswers = rawCorrectAnswer.map((e) => e.toString().toLowerCase().trim()).toList();
      } else {
        correctAnswers = [];
        _errorMessages[i] = 'Invalid correct answer format: $explanation';
        _isCorrectStates[i] = false;
        _answerCorrectness[i] = false;
        _logger.e('Invalid correct answer format for question $i in Lesson $currentLesson');
        continue;
      }

      List<String> selectedAnswers = selectedAnswersCopy[i].map((e) => e.toLowerCase()).toList();
      bool isCorrect = correctAnswers.every((correct) => selectedAnswers.contains(correct)) &&
          selectedAnswers.every((selected) => correctAnswers.contains(selected));

      _isCorrectStates[i] = isCorrect;
      _errorMessages[i] = isCorrect ? null : explanation;
      _answerCorrectness[i] = isCorrect;
      _logger.d('Validated question $i in Lesson $currentLesson: isCorrect=$isCorrect, selected=$selectedAnswers, correct=$correctAnswers');
    }

    final Map<int, String> lessonTitles = {
      1: 'Lesson 2.1: Greetings and Introductions',
      2: 'Lesson 2.2: Asking for Information',
      3: 'Lesson 2.3: Numbers and Dates',
    };

    if (_answerCorrectness.every((isCorrect) => isCorrect)) {
      _stopwatch.stop();
      int timeSpent = _stopwatch.elapsed.inSeconds;
      int score = _answerCorrectness.where((c) => c).length; // 1 point per correct answer
      int totalScore = currentLesson == 3 ? 10 : 8; // Total questions per lesson
      String lessonId = lessonTitles[currentLesson]!;

      List<Map<String, dynamic>> detailedResponses = questions.asMap().entries.map((e) {
        return {
          'question': e.value['question'],
          'userAnswer': _selectedAnswers[e.key],
          'correct': _isCorrectStates[e.key],
        };
      }).toList();

      _saveLessonProgress(currentLesson).then((success) {
        if (success) {
          _firebaseService.logLessonActivity('module2', lessonId, attemptNumber, score, totalScore, timeSpent, detailedResponses);
          _logger.i('Lesson $lessonId marked as completed with score $score/$totalScore, attempt $attemptNumber');
        } else {
          _logger.e('Failed to mark Lesson $currentLesson as completed');
        }
      });
      _stopwatch.reset();
    } else {
      _stopwatch.stop();
      int timeSpent = _stopwatch.elapsed.inSeconds;
      int score = _answerCorrectness.where((c) => c).length;
      int totalScore = currentLesson == 3 ? 10 : 8;
      String lessonId = lessonTitles[currentLesson]!;

      List<Map<String, dynamic>> detailedResponses = questions.asMap().entries.map((e) {
        return {
          'question': e.value['question'],
          'userAnswer': _selectedAnswers[e.key],
          'correct': _isCorrectStates[e.key],
        };
      }).toList();

      _firebaseService.logLessonActivity('module2', lessonId, attemptNumber, score, totalScore, timeSpent, detailedResponses);
      _logger.i('Logged attempt $attemptNumber for Lesson $lessonId with score $score/$totalScore');
      _stopwatch.reset();
      _stopwatch.start();
    }
  });
}

  @override
  void dispose() {
    _stopwatch.stop();
    _youtubeController.pause();
    _youtubeController.removeListener(() {});
    _youtubeController.dispose();
    super.dispose();
    _logger.i('Disposed Module2Page');
  }

  @override
  Widget build(BuildContext context) {
    bool allAnswersCorrect = _answerCorrectness.every((isCorrect) => isCorrect);
    bool isModuleCompleted = _lessonCompletion.values.every((completed) => completed);

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
                    Text(
                      _youtubeError!,
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                    ),
                  _buildLessonContent(),
                  if (showActivity && currentLesson < 3) ...[
                    const SizedBox(height: 16),
                    if (!allAnswersCorrect)
                      const Text(
                        'Please correct all answers before proceeding.',
                        style: TextStyle(color: Colors.red),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: allAnswersCorrect
                            ? () {
                                _logger.i('Next Lesson button pressed, switching to Lesson ${currentLesson + 1}');
                                setState(() {
                                  currentLesson++;
                                  showActivity = false;
                                  _currentSlide = 0;
                                  _carouselController.jumpToPage(0);
                                  _initializeStateLists();
                                  _youtubeController.pause();
                                  _updateYoutubeVideoId();
                                  _stopwatch.reset();
                                  _stopwatch.start();
                                  _logger.i('Switched to Lesson $currentLesson');
                                });
                              }
                            : null,
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
                  if (showActivity && currentLesson == 3) ...[
                    const SizedBox(height: 16),
                    if (!allAnswersCorrect)
                      const Text(
                        'Please correct all answers to complete this lesson.',
                        style: TextStyle(color: Colors.red),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: allAnswersCorrect
                            ? () async {
                                _logger.i('Lesson 2.3 completed, checking module completion');
                                await _saveLessonProgress(currentLesson);
                                setState(() {
                                  if (_lessonCompletion.values.every((completed) => completed)) {
                                    _logger.i('All lessons completed for Module 2');
                                    Navigator.pop(context);
                                  }
                                });
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isModuleCompleted ? Colors.green : const Color(0xFF00568D),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(isModuleCompleted ? 'Completed Module 2' : 'Complete Lesson 2.3'),
                      ),
                    ),
                  ],
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
      _logger.w('List length mismatch for Lesson $currentLesson. Expected $questionCount, got '
          'selectedAnswers=${_selectedAnswers.length}, '
          'isCorrectStates=${_isCorrectStates.length}, '
          'errorMessages=${_errorMessages.length}, '
          'answerCorrectness=${_answerCorrectness.length}');
      _initializeStateLists();
    }
    switch (currentLesson) {
      case 1:
        return buildLesson2_1(
          context: context,
          currentSlide: _currentSlide,
          carouselController: _carouselController,
          youtubeController: _youtubeController,
          showActivity: showActivity,
          onShowActivity: () => setState(() => showActivity = true),
          selectedAnswers: _selectedAnswers,
          isCorrectStates: _isCorrectStates,
          errorMessages: _errorMessages,
          onAnswerChanged: (index, isCorrect) {
            setState(() => _answerCorrectness[index] = isCorrect);
            _logger.d('Answer changed for question $index in Lesson $currentLesson: isCorrect=$isCorrect');
          },
          onSlideChanged: (index) {
            setState(() => _currentSlide = index);
            _logger.d('Slide changed to $index in Lesson $currentLesson');
          },
          onSubmitAnswers: _validateAllAnswers,
        );
      case 2:
        return buildLesson2_2(
          context: context,
          currentSlide: _currentSlide,
          carouselController: _carouselController,
          youtubeController: _youtubeController,
          showActivity: showActivity,
          onShowActivity: () => setState(() => showActivity = true),
          selectedAnswers: _selectedAnswers,
          isCorrectStates: _isCorrectStates,
          errorMessages: _errorMessages,
          onAnswerChanged: (index, isCorrect) {
            setState(() => _answerCorrectness[index] = isCorrect);
            _logger.d('Answer changed for question $index in Lesson $currentLesson: isCorrect=$isCorrect');
          },
          onSlideChanged: (index) {
            setState(() => _currentSlide = index);
            _logger.d('Slide changed to $index in Lesson $currentLesson');
          },
          onSubmitAnswers: _validateAllAnswers,
        );
      case 3:
        return buildLesson2_3(
          context: context,
          currentSlide: _currentSlide,
          carouselController: _carouselController,
          youtubeController: _youtubeController,
          showActivity: showActivity,
          onShowActivity: () => setState(() => showActivity = true),
          selectedAnswers: _selectedAnswers,
          isCorrectStates: _isCorrectStates,
          errorMessages: _errorMessages,
          onAnswerChanged: (index, isCorrect) {
            setState(() => _answerCorrectness[index] = isCorrect);
            _logger.d('Answer changed for question $index in Lesson $currentLesson: isCorrect=$isCorrect');
          },
          onSlideChanged: (index) {
            setState(() => _currentSlide = index);
            _logger.d('Slide changed to $index in Lesson $currentLesson');
          },
          onSubmitAnswers: _validateAllAnswers,
        );
      default:
        _logger.w('Invalid lesson number: $currentLesson');
        return Container();
    }
  }
}