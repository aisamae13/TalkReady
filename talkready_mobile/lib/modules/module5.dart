import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../firebase_service.dart';
import '../lessons/lesson5_1.dart';
import '../lessons/lesson5_2.dart';

class Module5Page extends StatefulWidget {
  final String? targetLessonKey;
  const Module5Page({super.key, this.targetLessonKey});

  @override
  State<Module5Page> createState() => _Module5PageState();
}

class _Module5PageState extends State<Module5Page> {
  int currentLesson = 1;
  bool showActivity = false;
  int _currentSlide = 0;
  final CarouselSliderController _carouselController = CarouselSliderController();
  final FirebaseService _firebaseService = FirebaseService();

  late List<List<String>> _selectedAnswers;
  late List<bool?> _isCorrectStates;
  late List<String?> _errorMessages;
  late List<bool> _answerCorrectness;

  Map<String, bool> _lessonCompletion = {'lesson1': false, 'lesson2': false};
  late Map<String, int> _lessonAttemptCounts;
  late Stopwatch _stopwatch;
  bool _isContentLoaded = false;
  bool _isLoading = false;

  final Map<int, int> _lessonQuestionCountsMap = {
    1: 3, // Adjust as needed
    2: 5, // Adjust as needed
  };

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();
    _lessonAttemptCounts = {'lesson1': 0, 'lesson2': 0};
    _performAsyncInit();
  }

  Future<void> _performAsyncInit() async {
    await _loadLessonProgress();
    _initializeStateLists();
    if (mounted) setState(() => _isContentLoaded = true);
  }

  Future<void> _loadLessonProgress() async {
    final progress = await _firebaseService.getModuleProgress('module5');
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
        case 'lesson1': currentLesson = 1; break;
        case 'lesson2': currentLesson = 2; break;
        default:
          if (!(_lessonCompletion['lesson1'] ?? false)) {
            currentLesson = 1;
          } else if (!(_lessonCompletion['lesson2'] ?? false)) currentLesson = 2;
          else currentLesson = 2;
      }
    } else {
      if (!(_lessonCompletion['lesson1'] ?? false)) {
        currentLesson = 1;
      } else if (!(_lessonCompletion['lesson2'] ?? false)) currentLesson = 2;
      else currentLesson = 2;
    }
  }

  Future<bool> _saveLessonProgress(int lessonNumberInModule) async {
    try {
      final lessonFirebaseKey = 'lesson$lessonNumberInModule';
      await _firebaseService.updateLessonProgress('module5', lessonFirebaseKey, true, attempts: _lessonAttemptCounts);
      if (mounted) setState(() => _lessonCompletion[lessonFirebaseKey] = true);
      return true;
    } catch (_) {
      return false;
    }
  }

  void _initializeStateLists() {
    int questionCount = _lessonQuestionCountsMap[currentLesson] ?? 0;
    _answerCorrectness = List<bool>.filled(questionCount, false, growable: true);
    _selectedAnswers = List<List<String>>.generate(questionCount, (_) => <String>[], growable: true);
    _isCorrectStates = List<bool?>.filled(questionCount, null, growable: true);
    _errorMessages = List<String?>.filled(questionCount, null, growable: true);
  }

  Future<void> _validateAllAnswers(
    List<Map<String, dynamic>> questionsData,
    int timeSpentFromLesson,
    int attemptNumberFromLesson,
  ) async {
    final String lessonKey = 'lesson$currentLesson';
    _lessonAttemptCounts[lessonKey] = attemptNumberFromLesson;

    final List<List<String>> selectedAnswersForValidation = _selectedAnswers
        .map((list) => list.map((e) => e.toString().trim()).toList())
        .toList();

    for (int i = 0; i < questionsData.length; i++) {
      if (selectedAnswersForValidation.length <= i || selectedAnswersForValidation[i].isEmpty) {
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
        for (int i = 0; i < questionsData.length; i++) {
          List<String> correctAnswers;
          final rawCorrectAnswer = questionsData[i]['correctAnswer'];
          final explanation = questionsData[i]['explanation'] ?? 'No explanation provided';

          if (rawCorrectAnswer is String) {
            correctAnswers = [rawCorrectAnswer.toLowerCase()];
          } else if (rawCorrectAnswer is List<dynamic>) {
            correctAnswers = rawCorrectAnswer.map((e) => e.toString().toLowerCase().trim()).toList();
          } else {
            correctAnswers = [];
            if (i < _errorMessages.length) _errorMessages[i] = 'Invalid correct answer format: $explanation';
            if (i < _isCorrectStates.length) _isCorrectStates[i] = false;
            if (i < _answerCorrectness.length) _answerCorrectness[i] = false;
            continue;
          }

          List<String> currentSelected = (i < selectedAnswersForValidation.length)
              ? selectedAnswersForValidation[i].map((e) => e.toLowerCase()).toList()
              : <String>[];

          bool isCorrect = correctAnswers.isNotEmpty &&
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
      1: 'Review: Go through key concepts',
      2: 'Final Test: A combination of grammar, vocabulary, and practical speaking exercises',
    };
    String lessonIdForLogging = lessonTitles[currentLesson] ?? "Module 5 Lesson $currentLesson";

    List<Map<String, dynamic>> detailedResponses = questionsData.asMap().entries.map((e) {
      int idx = e.key;
      return {
        'question': e.value['question'],
        'userAnswer': idx < selectedAnswersForValidation.length ? selectedAnswersForValidation[idx] : <String>[],
        'correct': idx < _isCorrectStates.length ? _isCorrectStates[idx] : false,
      };
    }).toList();

    await _firebaseService.logLessonActivity('module5', lessonIdForLogging, attemptNumberFromLesson, score, totalScore, timeSpentFromLesson, detailedResponses);

    bool success = await _saveLessonProgress(currentLesson);
    if (success) {
      if (mounted) setState(() => showActivity = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isContentLoaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('Module 5')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    bool isModuleCompleted = _lessonCompletion.values.every((completed) => completed);
    bool currentLessonLocallyCompleted = _lessonCompletion['lesson$currentLesson'] ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Module 5: Review and Assessment'),
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
                  _buildLessonContent(),
                  if (showActivity && currentLessonLocallyCompleted && currentLesson < 2) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton(
                              onPressed: () async {
                                setState(() => _isLoading = true);
                                await Future.delayed(const Duration(milliseconds: 600));
                                if (mounted) {
                                  setState(() {
                                    currentLesson++;
                                    showActivity = _lessonCompletion['lesson$currentLesson'] ?? false;
                                    _currentSlide = 0;
                                    _carouselController.jumpToPage(0);
                                    _initializeStateLists();
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
                  if (showActivity && currentLessonLocallyCompleted && currentLesson == 2 && isModuleCompleted) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton(
                              onPressed: () async {
                                setState(() => _isLoading = true);
                                await Future.delayed(const Duration(milliseconds: 600));
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
                  if (showActivity && currentLessonLocallyCompleted && currentLesson == 2 && !isModuleCompleted) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton(
                              onPressed: () async {
                                setState(() => _isLoading = true);
                                await Future.delayed(const Duration(milliseconds: 600));
                                if (mounted) {
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
      _initializeStateLists();
    }

    int nextAttemptNumber = (_lessonAttemptCounts['lesson$currentLesson'] ?? 0) + 1;

    switch (currentLesson) {
      case 1:
        return Lesson5_1(
          currentSlide: _currentSlide,
          carouselController: _carouselController,
          showActivity: showActivity,
          onShowActivity: () {
            if (mounted) setState(() => showActivity = true);
          },
          selectedAnswers: _selectedAnswers,
          isCorrectStates: _isCorrectStates,
          errorMessages: _errorMessages,
          onAnswerChanged: (index, isCorrect) {},
          onSlideChanged: (index) {
            if (mounted) setState(() => _currentSlide = index);
          },
          onSubmitAnswers: (questions, timeSpent, attemptNumber) => _validateAllAnswers(
            questions,
            timeSpent,
            attemptNumber,
          ),
          onWordsSelected: (questionIndex, selectedWords) {
            if (mounted) {
              setState(() {
                if (questionIndex < _selectedAnswers.length) {
                  _selectedAnswers[questionIndex] = selectedWords;
                  if (questionIndex < _isCorrectStates.length) _isCorrectStates[questionIndex] = null;
                  if (questionIndex < _errorMessages.length) _errorMessages[questionIndex] = null;
                }
              });
            }
          },
          initialAttemptNumber: nextAttemptNumber,
        );
      case 2:
        return Lesson5_2(
          currentSlide: _currentSlide,
          carouselController: _carouselController,
          showActivity: showActivity,
          onShowActivity: () {
            if (mounted) setState(() => showActivity = true);
          },
          selectedAnswers: _selectedAnswers,
          isCorrectStates: _isCorrectStates,
          errorMessages: _errorMessages,
          onAnswerChanged: (index, isCorrect) {},
          onSlideChanged: (index) {
            if (mounted) setState(() => _currentSlide = index);
          },
          onSubmitAnswers: (questions, timeSpent, attemptNumber) => _validateAllAnswers(
            questions,
            timeSpent,
            attemptNumber,
          ),
          onWordsSelected: (questionIndex, selectedWords) {
            if (mounted) {
              setState(() {
                if (questionIndex < _selectedAnswers.length) {
                  _selectedAnswers[questionIndex] = selectedWords;
                  if (questionIndex < _isCorrectStates.length) _isCorrectStates[questionIndex] = null;
                  if (questionIndex < _errorMessages.length) _errorMessages[questionIndex] = null;
                }
              });
            }
          },
          initialAttemptNumber: nextAttemptNumber,
        );
      default:
        return const Text('Invalid lesson');
    }
  }
}