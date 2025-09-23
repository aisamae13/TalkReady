// lib/lessons/lesson1_2_activity_page.dart
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'dart:async';
import 'package:talkready_mobile/widgets/sentence_scramble_question_widget.dart';
import '../services/unified_progress_service.dart';

class Lesson1_2ActivityPage extends StatefulWidget {
  final String lessonId;
  final String lessonTitle;
  final Map<String, dynamic> lessonData;

  const Lesson1_2ActivityPage({
    super.key,
    required this.lessonId,
    required this.lessonTitle,
    required this.lessonData,
  });

  @override
  _Lesson1_2ActivityPageState createState() => _Lesson1_2ActivityPageState();
}

class _Lesson1_2ActivityPageState extends State<Lesson1_2ActivityPage> {
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
  int _secondsRemaining = 300;
  bool _showResults = false;
  int _score = 0;

  @override
  void initState() {
    super.initState();
    _initializeActivity();
  }

  void _initializeActivity() {
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
          if (q['type'] == 'multiple-choice') {
            (q['options'] as List?)?.shuffle();
            _answers[q['id']] = '';
          } else if (q['type'] == 'sentence-scramble') {
            _answers[q['id']] = List<String>.from(q['parts'] ?? []);
          }
        }

        _activityData = activity;
        _shuffledQuestions = typedQuestions;
        _secondsRemaining = widget.lessonData['timerDuration'] as int? ?? 300;
      } catch (e) {
        _logger.e("Error initializing activity for 1.2: $e");
        Navigator.of(context).pop();
      }
    });
    _startTimer();
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting || _showResults) return;
    setState(() => _isSubmitting = true);
    _timer?.cancel();

    int correctAnswers = 0;
    for (var question in _shuffledQuestions) {
      final questionId = question['id'] as String;
      final userAnswer = _answers[questionId];

      if (question['type'] == 'multiple-choice') {
        if (userAnswer == question['correctAnswer']) correctAnswers++;
      } else if (question['type'] == 'sentence-scramble') {
        final correctOrder = List<String>.from(question['correctOrder'] ?? []);
        final userOrder = List<String>.from(userAnswer ?? []);
        if (correctOrder.length == userOrder.length &&
            List.generate(
              userOrder.length,
              (i) => userOrder[i] == correctOrder[i],
            ).every((b) => b)) {
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
            (_activityData?['timerDuration'] as int? ?? 300) -
            _secondsRemaining,
        detailedResponses: {'answers': _answers},
      );
    } catch (e) {
      _logger.e("Failed to submit attempt for 1.2: $e");
    } finally {
      if (mounted)
        setState(() {
          _isSubmitting = false;
          _showResults = true;
        });
    }
  }

  // The rest of the logic (_startTimer, _handleAnswerChanged, dispose) is the same
  void _startTimer() {
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
    if (_showResults) return;
    setState(() => _answers[questionId] = value);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // The build methods are also very similar, just with updated logic for the new question type
  @override
  Widget build(BuildContext context) {
    String timerText =
        '${(_secondsRemaining ~/ 60).toString().padLeft(2, '0')}:${(_secondsRemaining % 60).toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lessonTitle),
        backgroundColor: const Color(0xFFFF9900),
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
      body: _shuffledQuestions.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _showResults
          ? _buildResultsView()
          : _buildActivityView(),
    );
  }

  Widget _buildActivityView() {
    final question = _shuffledQuestions[_currentQuestionIndex];
    final questionId = question['id'] as String;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: (_currentQuestionIndex + 1) / _shuffledQuestions.length,
            color: const Color(0xFFFF9900),
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
          Expanded(
            child: SingleChildScrollView(
              child: _buildQuestionWidget(question, questionId),
            ),
          ),
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
      case 'sentence-scramble':
        return SentenceScrambleQuestionWidget(
          questionData: question,
          currentOrder: List<String>.from(_answers[questionId] ?? []),
          showResults: _showResults,
          onOrderChanged: (newOrder) =>
              _handleAnswerChanged(questionId, newOrder),
        );
      default:
        return Text('Unsupported question type: ${question['type']}');
    }
  }

  Widget _buildNavigationButtons() {
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
