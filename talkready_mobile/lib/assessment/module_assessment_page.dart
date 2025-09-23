// lib/assessment/module_assessment_page.dart
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'dart:async';
import '../services/unified_progress_service.dart';
import '../widgets/find_and_click_question_widget.dart';
import '../widgets/sentence_scramble_question_widget.dart';
import '../widgets/fill_in_the_blank_question_widget.dart';
import '../widgets/drag_drop_question_widget.dart';
import '../widgets/role_play_scenario_widget.dart';

class ModuleAssessmentPage extends StatefulWidget {
  final String assessmentId;
  const ModuleAssessmentPage({super.key, required this.assessmentId});

  @override
  _ModuleAssessmentPageState createState() => _ModuleAssessmentPageState();
}

class _ModuleAssessmentPageState extends State<ModuleAssessmentPage> {
  final Logger _logger = Logger();
  final UnifiedProgressService _progressService = UnifiedProgressService();

  bool _isLoading = true;
  bool _isSubmitting = false;
  Map<String, dynamic>? _assessmentData;
  List<Map<String, dynamic>> _shuffledQuestions = [];
  final Map<String, dynamic> _answers = {};
  int _currentQuestionIndex = 0;
  Timer? _timer;
  int _secondsRemaining = 1800;
  bool _showResults = false;
  int _score = 0;
  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, bool> _flaggedQuestions = {};

  bool get _areAllQuestionsAnswered {
    // Loop through every question in the assessment
    for (var question in _shuffledQuestions) {
      final questionId = question['id'];
      final userAnswer = _answers[questionId];

      // If the answer is null, it's definitely not answered
      if (userAnswer == null) return false;

      switch (question['type']) {
        case 'multiple-choice':
          // For text-based answers, check if the string is empty
          if ((userAnswer as String).trim().isEmpty) return false;
          break;
        case 'fill-in-the-blank':
          // For fill-in-the-blank, check the controller's text instead of _answers
          final controller = _textControllers[questionId];
          if (controller == null || controller.text.trim().isEmpty)
            return false;
          break;
        case 'find-and-click':
          // For list-based answers, check if the list is empty
          if ((userAnswer as List).isEmpty) return false;
          break;
        case 'sentence-scramble':
          // This type is pre-filled, so we can assume it's always "answered"
          break;
        case 'drag-and-drop':
          // For drag-and-drop, the question is answered if the source list is empty
          final columns = userAnswer as Map<String, dynamic>;
          final sourceId = question['sourceColumnId'] as String;
          if ((columns[sourceId]?['items'] as List?)?.isNotEmpty ?? false) {
            return false;
          }
          break;
        // ✅ FIX: Add proper role-play case
        case 'integrated-role-play-scenario':
          final result = userAnswer as Map<String, dynamic>?;
          if (result?['isComplete'] != true) return false;
          break;
      }
    }
    // If the loop finishes without finding any unanswered questions, return true
    return true;
  }

  // Helper method to check if a specific question is answered
  bool _isQuestionAnswered(String questionId) {
    final question = _shuffledQuestions.firstWhere(
      (q) => q['id'] == questionId,
      orElse: () => {},
    );

    if (question.isEmpty) return false;

    final userAnswer = _answers[questionId];

    switch (question['type']) {
      case 'multiple-choice':
        return userAnswer != null && (userAnswer as String).trim().isNotEmpty;
      case 'fill-in-the-blank':
        // Check the controller's text for fill-in-the-blank questions
        final controller = _textControllers[questionId];
        return controller != null && controller.text.trim().isNotEmpty;
      case 'find-and-click':
        return userAnswer != null && (userAnswer as List).isNotEmpty;
      case 'sentence-scramble':
        return true; // Always considered answered since it's pre-filled
      case 'drag-and-drop':
        if (userAnswer == null) return false;
        final columns = userAnswer as Map<String, dynamic>;
        final sourceId = question['sourceColumnId'] as String;
        return (columns[sourceId]?['items'] as List?)?.isEmpty ?? false;
      case 'integrated-role-play-scenario':
        final result = userAnswer as Map<String, dynamic>?;
        return result?['isComplete'] == true;
      default:
        return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadAssessment();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _textControllers.values.forEach((c) => c.dispose());
    super.dispose();
  }

  Future<void> _loadAssessment() async {
    setState(() => _isLoading = true);
    try {
      final data = await _progressService.getModuleAssessmentContent(
        widget.assessmentId,
      );
      if (data == null) throw Exception("Assessment data not found.");

      final questions = List<Map<String, dynamic>>.from(
        data['questions'] ?? [],
      );
      questions.shuffle();

      for (var q in questions) {
        final qId = q['id'] as String;
        if (q['type'] == 'multiple-choice') {
          _answers[qId] = '';
        } else if (q['type'] == 'fill-in-the-blank') {
          _answers[qId] = '';
          _textControllers[qId] = TextEditingController();
          _textControllers[qId]!.addListener(() {
            setState(() {});
          });
        } else if (q['type'] == 'find-and-click') {
          _answers[qId] = <String>[];
        } else if (q['type'] == 'sentence-scramble') {
          _answers[qId] = List<String>.from(q['parts'] ?? []);
        } else if (q['type'] == 'drag-and-drop') {
          _answers[qId] = Map<String, dynamic>.from(q['columns'] ?? {});
        } else if (q['type'] == 'integrated-role-play-scenario') {
          _answers[qId] = {'isComplete': false, 'score': 0};
        }
      }

      if (mounted) {
        setState(() {
          _assessmentData = data;
          _shuffledQuestions = questions;
          _secondsRemaining = data['timerDuration'] as int? ?? 1800;
          _isLoading = false;
        });
        _startTimer();
      }
    } catch (e) {
      _logger.e("Error loading assessment: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

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

  Future<void> _handleSubmit() async {
    if (_isSubmitting || _showResults) return;
    setState(() => _isSubmitting = true);
    _timer?.cancel();

    _textControllers.forEach((key, controller) {
      _answers[key] = controller.text;
    });

    int correctAnswers = 0;
    int totalQuestions = _shuffledQuestions.length;

    for (var question in _shuffledQuestions) {
      final userAnswer = _answers[question['id']];
      bool isCorrect = false;

      switch (question['type']) {
        case 'multiple-choice':
          isCorrect = userAnswer == question['correctAnswer'];
          if (isCorrect) correctAnswers++;
          break;
        case 'find-and-click':
          final c = List<String>.from(question['correctWords'] ?? []);
          final a = List<String>.from(userAnswer ?? []);
          isCorrect =
              c.toSet().difference(a.toSet()).isEmpty &&
              a.toSet().difference(c.toSet()).isEmpty;
          if (isCorrect) correctAnswers++;
          break;
        case 'sentence-scramble':
          final c = List<String>.from(question['correctOrder'] ?? []);
          final a = List<String>.from(userAnswer ?? []);
          isCorrect =
              c.length == a.length &&
              List.generate(a.length, (i) => a[i] == c[i]).every((b) => b);
          if (isCorrect) correctAnswers++;
          break;
        case 'fill-in-the-blank':
          final c = List<String>.from(question['correctAnswers'] ?? []);
          isCorrect = c.any(
            (ans) =>
                ans.toLowerCase() ==
                (userAnswer as String? ?? '').trim().toLowerCase(),
          );
          if (isCorrect) correctAnswers++;
          break;
        case 'drag-and-drop':
          final userColumns = _answers[question['id']] as Map<String, dynamic>;
          final sourceId = question['sourceColumnId'] as String;
          bool allCorrect = true;
          if ((userColumns[sourceId]?['items'] as List?)?.isNotEmpty ?? false) {
            allCorrect = false;
          } else {
            userColumns.forEach((columnId, columnData) {
              if (columnId != sourceId) {
                for (var item in List<Map<String, dynamic>>.from(
                  columnData['items'],
                )) {
                  if (item['correctColumn'] != columnId) {
                    allCorrect = false;
                    break;
                  }
                }
              }
            });
          }
          if (allCorrect) correctAnswers++;
          break;
        case 'integrated-role-play-scenario':
          // ✅ FIXED: Handle role-play scoring properly with assessment max score
          final result = userAnswer as Map<String, dynamic>?;
          if (result != null && result['isComplete'] == true) {
            final rolePlayScore = (result['score'] as num?)?.toInt() ?? 0;
            final maxRolePlayScore =
                (result['maxPossibleScore'] as num?)?.toInt() ??
                (question['points'] as int? ?? 20);

            _logger.i(
              'Role-play result: score=$rolePlayScore/$maxRolePlayScore, isComplete=${result['isComplete']}',
            );

            // ✅ Add the role-play score directly to correctAnswers
            correctAnswers += rolePlayScore;

            // ✅ Adjust totalQuestions to account for role-play max score
            totalQuestions =
                totalQuestions -
                1 +
                maxRolePlayScore; // Remove 1 point, add actual max
          }
          break;
      }
    }

    _score = correctAnswers;

    try {
      await _progressService.saveModuleAssessmentAttempt(
        assessmentId: widget.assessmentId,
        score: _score,
        maxScore: _assessmentData?['maxScore'] as int? ?? totalQuestions,
      );
    } catch (e) {
      _logger.e("Failed to submit assessment attempt: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _showResults = true;
        });
      }
    }
  }

  void _handleAnswerChanged(String questionId, dynamic value) {
    if (_showResults) return;
    setState(() => _answers[questionId] = value);
  }

  void _toggleFlag(String questionId) {
    setState(
      () => _flaggedQuestions[questionId] =
          !(_flaggedQuestions[questionId] ?? false),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Scaffold(
        backgroundColor: Color(0xFFF8F9FA),
        body: Center(child: CircularProgressIndicator()),
      );
    if (_assessmentData == null)
      return const Scaffold(
        backgroundColor: Color(0xFFF8F9FA),
        body: Center(child: Text('Failed to load assessment.')),
      );

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: _showResults ? _buildResultsView() : _buildActivityView(),
      ),
    );
  }

  // In module_assessment_page.dart

  Widget _buildActivityView() {
    final question = _shuffledQuestions[_currentQuestionIndex];
    final progressValue =
        (_currentQuestionIndex + 1) / _shuffledQuestions.length;
    final timerText =
        '${(_secondsRemaining ~/ 60).toString().padLeft(2, '0')}:${(_secondsRemaining % 60).toString().padLeft(2, '0')}';

    // ✅ ADD THIS CHECK:
    final isRolePlayAssessment =
        question['type'] == 'integrated-role-play-scenario';

    return Column(
      children: [
        // Enhanced Header with better mobile design
        Container(
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // ✅ CONDITIONALLY SHOW QUESTION NUMBER:
                  if (!isRolePlayAssessment)
                    Text(
                      'Question ${_currentQuestionIndex + 1} of ${_shuffledQuestions.length}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2C3E50),
                      ),
                    )
                  else
                    // Show assessment title instead
                    Expanded(
                      child: Text(
                        _assessmentData?['title'] ?? 'Module Assessment',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3498DB).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 18,
                          color: _secondsRemaining < 300
                              ? Colors.red
                              : const Color(0xFF3498DB),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          timerText,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: _secondsRemaining < 300
                                ? Colors.red
                                : const Color(0xFF3498DB),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // ✅ CONDITIONALLY SHOW PROGRESS BAR:
              if (!isRolePlayAssessment)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progressValue,
                    backgroundColor: Colors.grey[200],
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF3498DB),
                    ),
                    minHeight: 8,
                  ),
                ),
            ],
          ),
        ),

        // ✅ CONDITIONALLY SHOW QUESTION NAVIGATOR:
        if (!isRolePlayAssessment)
          Container(
            height: 70,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _shuffledQuestions.length,
              itemBuilder: (context, index) {
                final qId = _shuffledQuestions[index]['id'];
                final isFlagged = _flaggedQuestions[qId] ?? false;
                final isActive = index == _currentQuestionIndex;
                final isAnswered = _isQuestionAnswered(qId);

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: GestureDetector(
                    onTap: () => setState(() => _currentQuestionIndex = index),
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFF3498DB)
                            : isAnswered
                            ? Colors.green.shade100
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isActive
                              ? const Color(0xFF3498DB)
                              : isFlagged
                              ? Colors.orange
                              : Colors.grey.shade300,
                          width: 2,
                        ),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: const Color(
                                    0xFF3498DB,
                                  ).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : [],
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: isActive ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (isFlagged)
                            Positioned(
                              top: 2,
                              right: 2,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  color: Colors.orange,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

        // Question Area with better scrolling
        Expanded(
          child: Container(
            key: ValueKey(_currentQuestionIndex),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Container(
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // ✅ CONDITIONALLY SHOW FLAG BUTTON:
                    if (!isRolePlayAssessment)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            onPressed: () => _toggleFlag(question['id']),
                            icon: Icon(
                              _flaggedQuestions[question['id']] == true
                                  ? Icons.flag
                                  : Icons.flag_outlined,
                              color: _flaggedQuestions[question['id']] == true
                                  ? Colors.orange
                                  : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    _renderQuestionByType(question, question['id']),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Enhanced Navigation Footer - ✅ CONDITIONALLY SHOW:
        if (!isRolePlayAssessment) _buildNavigationButtons(),
      ],
    );
  }

  Widget _renderQuestionByType(
    Map<String, dynamic> question,
    String questionId,
  ) {
    switch (question['type']) {
      case 'multiple-choice':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: Text(
                question['promptText'],
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ),
            ...List<String>.from(question['options']).map(
              (opt) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: RadioListTile<String>(
                  title: Text(opt, style: const TextStyle(fontSize: 16)),
                  value: opt,
                  groupValue: _answers[questionId],
                  onChanged: (v) => _handleAnswerChanged(questionId, v),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
              ),
            ),
          ],
        );
      case 'find-and-click':
        return FindAndClickQuestionWidget(
          questionData: question,
          selectedWords: List<String>.from(_answers[questionId] ?? []),
          showResults: _showResults,
          onWordSelected: (word) {
            final s = List<String>.from(_answers[questionId] ?? []);
            if (s.contains(word))
              s.remove(word);
            else
              s.add(word);
            _handleAnswerChanged(questionId, s);
          },
        );
      case 'sentence-scramble':
        return SentenceScrambleQuestionWidget(
          questionData: question,
          currentOrder: List<String>.from(_answers[questionId] ?? []),
          showResults: _showResults,
          onOrderChanged: (newOrder) =>
              _handleAnswerChanged(questionId, newOrder),
        );
      case 'fill-in-the-blank':
        return FillInTheBlankQuestionWidget(
          questionData: question,
          userAnswer: _answers[questionId] as String? ?? '',
          showResults: _showResults,
          controller: _textControllers[questionId]!,
        );
      case 'drag-and-drop':
        return DragDropQuestionWidget(
          questionData: question,
          currentAnswer: _answers[questionId],
          showResults: _showResults,
          onAnswerChanged: (newColumns) =>
              _handleAnswerChanged(questionId, newColumns),
        );
      // REPLACE the original code with this updated block
      case 'integrated-role-play-scenario':
        return RolePlayScenarioWidget(
          assessmentId: widget.assessmentId, // ✅ ADD THIS LINE
          questionData: question,
          onScoreUpdate: (result) => _handleAnswerChanged(questionId, result),
          showResults: _showResults,
        );
      default:
        return Text('Unsupported question type: ${question['type']}');
    }
  }

  Widget _buildNavigationButtons() {
    final question = _shuffledQuestions[_currentQuestionIndex];
    final isRolePlayAssessment =
        question['type'] == 'integrated-role-play-scenario';

    // ✅ For role-play assessments, don't show traditional navigation
    if (isRolePlayAssessment) {
      return const SizedBox.shrink(); // Hide navigation buttons
    }

    // Original navigation logic for other question types
    bool isLastQuestion =
        _currentQuestionIndex == _shuffledQuestions.length - 1;
    final bool canSubmit = _areAllQuestionsAnswered;

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: _currentQuestionIndex == 0
                  ? null
                  : () => setState(() => _currentQuestionIndex--),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade100,
                foregroundColor: Colors.grey.shade700,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Previous',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: isLastQuestion
                ? Opacity(
                    opacity: canSubmit ? 1.0 : 0.5,
                    child: ElevatedButton(
                      onPressed: _isSubmitting || !canSubmit
                          ? null
                          : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Submit',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  )
                : ElevatedButton(
                    onPressed: () => setState(() => _currentQuestionIndex++),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3498DB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: const Text(
                      'Next',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsView() {
    // Calculate max score properly
    int maxScore = 0;

    for (var question in _shuffledQuestions) {
      if (question['type'] == 'integrated-role-play-scenario') {
        maxScore += (question['points'] as int? ?? 20);
      } else {
        maxScore += 1;
      }
    }

    final percentage = maxScore > 0 ? (_score / maxScore * 100).round() : 0;

    return Container(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(
                  percentage >= 70 ? Icons.celebration : Icons.info_outline,
                  size: 64,
                  color: percentage >= 70 ? Colors.green : Colors.orange,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Assessment Complete!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Score: $_score / $maxScore',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3498DB),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$percentage%',
                  style: TextStyle(
                    fontSize: 20,
                    color: percentage >= 70 ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    // ✅ Fix: Navigate to the correct module based on assessment ID
                    onPressed: () => Navigator.of(context).pushReplacementNamed(
                      _getModuleRouteFromAssessmentId(widget.assessmentId),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3498DB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: const Text(
                      'Back to Module',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Add this helper method to the _ModuleAssessmentPageState class:
  String _getModuleRouteFromAssessmentId(String assessmentId) {
    // Map assessment IDs to their corresponding module routes
    switch (assessmentId) {
      case 'module_1_final':
        return '/module1';
      case 'module_2_final':
        return '/module2';
      case 'module_3_final':
        return '/module3';
      case 'module_4_final':
        return '/module4';
      case 'module_5_final':
        return '/module5';
      default:
        // Fallback: try to extract module number from assessment ID
        final RegExp modulePattern = RegExp(r'module_(\d+)_');
        final match = modulePattern.firstMatch(assessmentId);
        if (match != null) {
          final moduleNumber = match.group(1);
          return '/module$moduleNumber';
        }
        // Ultimate fallback to module 1
        return '/module1';
    }
  }
}
