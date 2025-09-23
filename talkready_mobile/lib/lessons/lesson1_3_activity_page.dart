// lib/lessons/lesson1_3_activity_page.dart
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'dart:async';
import '../services/unified_progress_service.dart';
import '../widgets/fill_in_the_blank_question_widget.dart';

class Lesson1_3ActivityPage extends StatefulWidget {
  final String lessonId;
  final String lessonTitle;
  final Map<String, dynamic> lessonData;

  const Lesson1_3ActivityPage({
    super.key,
    required this.lessonId,
    required this.lessonTitle,
    required this.lessonData,
  });

  @override
  _Lesson1_3ActivityPageState createState() => _Lesson1_3ActivityPageState();
}

class _Lesson1_3ActivityPageState extends State<Lesson1_3ActivityPage> {
  final Logger _logger = Logger();
  final UnifiedProgressService _progressService = UnifiedProgressService();

  bool _areAllQuestionsAnswered() {
    for (var question in _shuffledQuestions) {
      final answer = _answers[question['id']];
      if (answer == null) return false;
      if (answer is String && answer.isEmpty) return false;
      if (answer is List && answer.isEmpty) return false;
    }
    return true;
  }

  bool _isSubmitting = false;
  Map<String, dynamic>? _activityData;
  List<Map<String, dynamic>> _shuffledQuestions = [];
  final Map<String, dynamic> _answers = {};
  int _currentQuestionIndex = 0;
  Timer? _timer;
  int _secondsRemaining = 600;
  bool _showResults = false;
  int _score = 0;

  // --- ADD THIS TO MANAGE TEXT CONTROLLERS ---
  final Map<String, TextEditingController> _textControllers = {};

  @override
  void initState() {
    super.initState();
    _initializeActivity();
  }

  void _initializeActivity() {
    // --- CLEAR OLD CONTROLLERS ---
    for (var controller in _textControllers.values) {
      controller.dispose();
    }
    _textControllers.clear();

    setState(() {
      _showResults = false;
      _currentQuestionIndex = 0;
      _answers.clear();

      try {
        final activity = widget.lessonData['activity'] as Map<String, dynamic>?;
        if (activity == null) throw Exception("Activity data not found.");

        final questionsList = activity['questions'] as List? ?? [];
        final typedQuestions = questionsList
            .map((q) => Map<String, dynamic>.from(q as Map))
            .toList();

        typedQuestions.shuffle();
        for (var q in typedQuestions) {
          final questionId = q['id'] as String;
          if (q['type'] == 'multiple-choice') {
            (q['options'] as List?)?.shuffle();
            _answers[questionId] = '';
          } else if (q['type'] == 'fill-in-the-blank') {
            _answers[questionId] = '';
            // --- CREATE AND STORE A CONTROLLER FOR EACH BLANK ---
            final controller = TextEditingController();
            _textControllers[questionId] = controller;
            controller.addListener(() {
              _answers[questionId] = controller.text;
            });
          }
        }

        _activityData = activity;
        _shuffledQuestions = typedQuestions;
        _secondsRemaining = widget.lessonData['timerDuration'] as int? ?? 600;
      } catch (e) {
        _logger.e("Error initializing activity for 1.3: $e");
        Navigator.of(context).pop();
      }
    });
    _startTimer();
  }

  // No changes needed for handleSubmit, _startTimer, or _handleAnswerChanged
  Future<void> _handleSubmit() async {
    /* ... same as before ... */
    if (_isSubmitting || _showResults) return;
    setState(() => _isSubmitting = true);
    _timer?.cancel();

    int correctAnswers = 0;
    for (var question in _shuffledQuestions) {
      final userAnswer = _answers[question['id']] ?? '';
      if (question['type'] == 'multiple-choice') {
        if (userAnswer == question['correctAnswer']) correctAnswers++;
      } else if (question['type'] == 'fill-in-the-blank') {
        final correctAnsList = List<String>.from(
          question['correctAnswers'] ?? [],
        );
        if (correctAnsList.any(
          (ans) =>
              ans.toLowerCase() == (userAnswer as String).trim().toLowerCase(),
        )) {
          correctAnswers++;
        }
      }
    }
    _score = correctAnswers;
    try {
      await _progressService.saveLessonAttempt(
        lessonId: widget.lessonId,
        score: _score,
        maxScore: _shuffledQuestions.length,
        timeSpent:
            (_activityData?['timerDuration'] as int? ?? 600) -
            _secondsRemaining,
        detailedResponses: {'answers': _answers},
      );
    } catch (e) {
      _logger.e("Failed to submit attempt for 1.3: $e");
    } finally {
      if (mounted)
        setState(() {
          _isSubmitting = false;
          _showResults = true;
        });
    }
  }

  void _startTimer() {
    /* ... same as before ... */
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        if (mounted) setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
        if (!_showResults) _handleSubmit();
      }
    });
  }

  void _handleAnswerChanged(String questionId, dynamic value) {
    /* ... same as before ... */
    if (_showResults) return;
    setState(() => _answers[questionId] = value);
  }

  @override
  void dispose() {
    _timer?.cancel();
    // --- DISPOSE ALL CONTROLLERS TO PREVENT MEMORY LEAKS ---
    for (var controller in _textControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String timerText =
        '${(_secondsRemaining ~/ 60).toString().padLeft(2, '0')}:${(_secondsRemaining % 60).toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lessonTitle),
        backgroundColor: const Color(0xFF32CD32),
        actions: [
          if (!_showResults)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Text(
                  timerText,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      // --- WRAP THE BODY IN A WIDGET TO HANDLE KEYBOARD RESIZING ---
      body: SafeArea(
        child: _shuffledQuestions.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _showResults
            ? _buildResultsView()
            : _buildActivityView(),
      ),
    );
  }

  Widget _buildActivityView() {
    final question = _shuffledQuestions[_currentQuestionIndex];
    final questionId = question['id'] as String;

    // --- MAKE THE ENTIRE VIEW SCROLLABLE TO FIX KEYBOARD ISSUE ---
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: (_currentQuestionIndex + 1) / _shuffledQuestions.length,
            color: const Color(0xFF32CD32),
          ),
          const SizedBox(height: 16),
          Text(
            'Question ${_currentQuestionIndex + 1} of ${_shuffledQuestions.length}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 20),
          _buildQuestionWidget(question, questionId),
          const SizedBox(height: 24), // Add space before buttons
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildQuestionWidget(
    Map<String, dynamic> question,
    String questionId,
  ) {
    switch (question['type']) {
      case 'multiple-choice':
        final options = List<String>.from(question['options'] ?? []);
        return Column(
          children: [
            Text(
              question['promptText'] as String,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ...options
                .map(
                  (option) => Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: RadioListTile<String>(
                      title: Text(option),
                      value: option,
                      groupValue: _answers[questionId],
                      onChanged: (value) =>
                          _handleAnswerChanged(questionId, value!),
                    ),
                  ),
                )
                .toList(),
          ],
        );
      case 'fill-in-the-blank':
        // --- PASS THE CORRECT CONTROLLER TO THE WIDGET ---
        return FillInTheBlankQuestionWidget(
          questionData: question,
          userAnswer: _answers[questionId] as String? ?? '',
          showResults: _showResults,
          controller: _textControllers[questionId]!,
        );
      default:
        return Text('Unsupported question type: ${question['type']}');
    }
  }

  Widget _buildNavigationButtons() {
    /* ... same as before ... */
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ElevatedButton(
          onPressed: _currentQuestionIndex == 0
              ? null
              : () => setState(() => _currentQuestionIndex--),
          child: const Text('Previous'),
        ),
        if (_currentQuestionIndex == _shuffledQuestions.length - 1)
          ElevatedButton(
            onPressed: (_isSubmitting || !_areAllQuestionsAnswered())
                ? null
                : _handleSubmit,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Submit'),
          )
        else
          ElevatedButton(
            onPressed: () => setState(() => _currentQuestionIndex++),
            child: const Text('Next'),
          ),
      ],
    );
  }

  Widget _buildResultsView() {
    /* ... same as before ... */
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 80),
            const SizedBox(height: 20),
            const Text(
              'Activity Submitted!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Your Score: $_score / ${_shuffledQuestions.length}',
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _initializeActivity,
              child: const Text('Try Again'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back to Lesson'),
            ),
          ],
        ),
      ),
    );
  }
}
