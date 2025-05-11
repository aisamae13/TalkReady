import 'package:flutter/material.dart' hide CarouselController;
import 'package:carousel_slider/carousel_slider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:logger/logger.dart';
import '../firebase_service.dart';
import '../lessons/lesson1_1.dart';
import '../lessons/lesson1_2.dart';
import '../lessons/lesson1_3.dart';

class Module1Page extends StatefulWidget {
  const Module1Page({super.key});

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

  final Map<int, String> _videoIds = {
    1: '0GVcQjDOW6Q', // Lesson 1.1: Nouns and Pronouns
    2: 'LRJXMKZ4wOw', // Lesson 1.2: Simple Sentences
    3: 'LfJPA8GwTdk', // Lesson 1.3: Verb and Tenses (Present Simple)
  };

  @override
  void initState() {
    super.initState();
    _loadLessonProgress();
    _initializeStateLists();
    _initializeYoutubeController();
  }

  Future<void> _loadLessonProgress() async {
    try {
      final progress = await _firebaseService.getModuleProgress('module1');
      final lessons = progress['lessons'] as Map<String, dynamic>? ?? {};
      setState(() {
        // Find the first incomplete lesson
        if (!(lessons['lesson1'] ?? false)) {
          currentLesson = 1;
        } else if (!(lessons['lesson2'] ?? false)) {
          currentLesson = 2;
        } else if (!(lessons['lesson3'] ?? false)) {
          currentLesson = 3;
        } else {
          currentLesson = 3; // All completed, stay on last lesson
        }
        _logger.i('Loaded lesson progress: currentLesson=$currentLesson');
      });
    } catch (e) {
      _logger.e('Error loading lesson progress: $e');
    }
  }

  Future<void> _saveLessonProgress(int lesson) async {
    try {
      await _firebaseService.updateLessonProgress('module1', 'lesson$lesson', true);
      _logger.i('Saved lesson $lesson as completed');
    } catch (e) {
      _logger.e('Error saving lesson progress: $e');
    }
  }

  void _initializeStateLists() {
    int questionCount = currentLesson == 3 ? 10 : 8;
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
    final List<List<String>> selectedAnswersCopy = _selectedAnswers
        .map((list) => list.map((e) => e.toString()).toList())
        .toList();
    setState(() {
      for (int i = 0; i < questions.length; i++) {
        List<String> correctAnswers;
        final rawCorrectAnswer = questions[i]['correctAnswer'];
        if (rawCorrectAnswer is String) {
          correctAnswers = rawCorrectAnswer.toLowerCase().split(', ').map((e) => e.trim()).toList();
        } else if (rawCorrectAnswer is List<dynamic>) {
          correctAnswers = rawCorrectAnswer.map((e) => e.toString().toLowerCase().trim()).toList();
        } else {
          correctAnswers = [];
          _errorMessages[i] = 'Invalid correct answer format';
          _isCorrectStates[i] = false;
          _answerCorrectness[i] = false;
          _logger.e('Invalid correct answer format for question $i in Lesson $currentLesson');
          continue;
        }

        List<String> selectedAnswers = selectedAnswersCopy[i].map((e) => e.toLowerCase()).toList();
        bool isCorrect = correctAnswers.every((correct) => selectedAnswers.contains(correct)) &&
            selectedAnswers.every((selected) => correctAnswers.contains(selected));

        _isCorrectStates[i] = isCorrect;
        _errorMessages[i] = isCorrect ? null : 'Correct answer: ${correctAnswers.join(', ')}';
        _answerCorrectness[i] = isCorrect;
        _logger.d('Validated question $i in Lesson $currentLesson: isCorrect=$isCorrect');
      }

      if (_answerCorrectness.every((isCorrect) => isCorrect)) {
        _saveLessonProgress(currentLesson);
      }
    });
  }

  @override
  void dispose() {
    _youtubeController.pause();
    _youtubeController.removeListener(() {});
    _youtubeController.dispose();
    super.dispose();
    _logger.i('Disposed Module1Page');
  }

  @override
  Widget build(BuildContext context) {
    bool allAnswersCorrect = _answerCorrectness.every((isCorrect) => isCorrect);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Module 1: Basic English Grammar',
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
                        'Please correct all answers to complete the module.',
                        style: TextStyle(color: Colors.red),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: allAnswersCorrect
                            ? () {
                                _logger.i('Module completed, exiting Module 1');
                                Navigator.pop(context);
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00568D),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Complete Module'),
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
    switch (currentLesson) {
      case 1:
        return buildLesson1_1(
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
        return buildLesson1_2(
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
        return buildLesson1_3(
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