import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class GrammarPracticePage extends StatefulWidget {
  const GrammarPracticePage({Key? key}) : super(key: key);

  @override
  State<GrammarPracticePage> createState() => _GrammarPracticePageState();
}

class _GrammarPracticePageState extends State<GrammarPracticePage> {
  final Logger _logger = Logger();
  final _user = FirebaseAuth.instance.currentUser;

  bool _isLoading = true;
  bool _isLoadingQuestions = false;
  List<Map<String, dynamic>> _questions = [];
  int _currentQuestionIndex = 0;
  int? _selectedAnswer;
  bool _hasAnswered = false;
  bool _showExplanation = false;

  // Session data
  int _correctAnswers = 0;
  int _totalAnswered = 0;
  DateTime? _sessionStartTime;
  List<Map<String, dynamic>> _sessionResults = [];

  // Settings
  String _selectedDifficulty = 'beginner';
  String _selectedCategory = 'general';

  // Backend configuration
  static const String _backendUrl = 'https://talkready-backend.onrender.com';

  @override
  void initState() {
    super.initState();
    _sessionStartTime = DateTime.now();
    _showDifficultySelection();
  }

  void _showDifficultySelection() {
    setState(() => _isLoading = false);
  }

  Future<void> _loadQuestions() async {
    setState(() => _isLoadingQuestions = true);

    try {
      _logger.i('Loading grammar questions...');

      final response = await http
          .post(
            Uri.parse('$_backendUrl/generate-grammar-questions'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'difficulty': _selectedDifficulty,
              'category': _selectedCategory,
              'count': 5,
            }),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw Exception('Request timed out'),
          );

      if (response.statusCode != 200) {
        throw Exception('Failed to load questions: ${response.statusCode}');
      }

      final data = json.decode(response.body);

      if (data['success'] != true || data['questions'] == null) {
        throw Exception('Invalid response format');
      }

      setState(() {
        _questions = List<Map<String, dynamic>>.from(data['questions']);
        _isLoadingQuestions = false;
        _currentQuestionIndex = 0;
        _sessionStartTime = DateTime.now();
      });

      _logger.i('Loaded ${_questions.length} grammar questions');
    } catch (e) {
      _logger.e('Error loading questions: $e');
      setState(() => _isLoadingQuestions = false);
      _showErrorDialog('Failed to load questions: ${e.toString()}');
    }
  }

  void _selectAnswer(int index) {
    if (_hasAnswered) return;

    setState(() {
      _selectedAnswer = index;
    });
  }

  Future<void> _submitAnswer() async {
    if (_selectedAnswer == null || _hasAnswered) return;

    final currentQuestion = _questions[_currentQuestionIndex];
    final correctAnswer = currentQuestion['correctAnswer'] as int;
    final isCorrect = _selectedAnswer == correctAnswer;

    setState(() {
      _hasAnswered = true;
      _showExplanation = true;
      _totalAnswered++;

      if (isCorrect) {
        _correctAnswers++;
      }

      // Record result
      _sessionResults.add({
        'questionId': currentQuestion['id'],
        'question': currentQuestion['question'],
        'userAnswer': _selectedAnswer,
        'correctAnswer': correctAnswer,
        'isCorrect': isCorrect,
        'grammarPoint': currentQuestion['grammarPoint'],
        'timestamp': DateTime.now().toIso8601String(),
      });
    });

    _logger.i(
      'Answer submitted: ${isCorrect ? 'Correct' : 'Incorrect'} ($_correctAnswers/$_totalAnswered)',
    );
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _selectedAnswer = null;
        _hasAnswered = false;
        _showExplanation = false;
      });
    } else {
      _completeSession();
    }
  }

  Future<void> _completeSession() async {
    final accuracy = _totalAnswered > 0
        ? ((_correctAnswers / _totalAnswered) * 100).round()
        : 0;

    // Save session to backend
    try {
      final duration = DateTime.now().difference(_sessionStartTime!).inSeconds;

      _logger.i('Saving grammar session...');

      final response = await http
          .post(
            Uri.parse('$_backendUrl/save-grammar-session'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'userId': _user?.uid,
              'sessionData': {
                'startedAt': _sessionStartTime!.toIso8601String(),
                'difficulty': _selectedDifficulty,
                'category': _selectedCategory,
                'questionsAttempted': _totalAnswered,
                'questionsCorrect': _correctAnswers,
                'accuracy': accuracy.toDouble(),
                'results': _sessionResults,
                'duration': duration,
              },
            }),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Save timed out'),
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _logger.i('Grammar session saved: ${data['sessionId']}');
        }
      }
    } catch (e) {
      _logger.e('Failed to save session: $e');
      // Continue to show results even if save fails
    }

    _showSessionComplete(accuracy);
  }

  void _showSessionComplete(int accuracy) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🎉 Session Complete!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Great job, ${_user?.displayName?.split(' ')[0] ?? 'there'}!',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildStatRow(
              'Questions Answered',
              '$_totalAnswered/${_questions.length}',
            ),
            _buildStatRow(
              'Correct Answers',
              '$_correctAnswers/$_totalAnswered',
            ),
            _buildStatRow('Accuracy', '$accuracy%'),
            _buildStatRow('Session Time', _getSessionDuration()),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _resetSession();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Practice Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _getSessionDuration() {
    if (_sessionStartTime == null) return '0m';
    final duration = DateTime.now().difference(_sessionStartTime!);
    return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
  }

  void _resetSession() {
    setState(() {
      _currentQuestionIndex = 0;
      _selectedAnswer = null;
      _hasAnswered = false;
      _showExplanation = false;
      _correctAnswers = 0;
      _totalAnswered = 0;
      _sessionResults.clear();
      _questions.clear();
    });
    _showDifficultySelection();
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _questions.isEmpty) {
      return _buildSetupScreen();
    }

    return _buildQuizScreen();
  }

  Widget _buildSetupScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('✍️ Grammar Practice'),
        backgroundColor: Colors.orange,
      ),
      body: _isLoadingQuestions
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.orange),
                  SizedBox(height: 16),
                  Text('Generating questions...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Grammar Practice',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Test your grammar knowledge with multiple-choice questions. Get instant feedback and explanations!',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Difficulty Selection
                  const Text(
                    'Select Difficulty',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildDifficultyButton(
                    'beginner',
                    'Beginner',
                    'Basic grammar rules',
                    Icons.star_border,
                  ),
                  const SizedBox(height: 8),
                  _buildDifficultyButton(
                    'intermediate',
                    'Intermediate',
                    'Complex structures',
                    Icons.star_half,
                  ),
                  const SizedBox(height: 8),
                  _buildDifficultyButton(
                    'advanced',
                    'Advanced',
                    'Advanced grammar',
                    Icons.star,
                  ),
                  const SizedBox(height: 24),

                  // Category Selection
                  const Text(
                    'Select Category',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildCategoryDropdown(),
                  const SizedBox(height: 32),

                  // Start Button
                  ElevatedButton.icon(
                    onPressed: _loadQuestions,
                    icon: const Icon(Icons.play_arrow, size: 28),
                    label: const Text(
                      'Start Practice',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDifficultyButton(
    String value,
    String title,
    String subtitle,
    IconData icon,
  ) {
    final isSelected = _selectedDifficulty == value;

    return InkWell(
      onTap: () => setState(() => _selectedDifficulty = value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange.shade50 : Colors.white,
          border: Border.all(
            color: isSelected ? Colors.orange : Colors.grey.shade300,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.orange : Colors.grey,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.orange : Colors.black,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Colors.orange),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCategory,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down),
          items: const [
            DropdownMenuItem(value: 'general', child: Text('General Grammar')),
            DropdownMenuItem(value: 'verb_tenses', child: Text('Verb Tenses')),
            DropdownMenuItem(
              value: 'subject_verb_agreement',
              child: Text('Subject-Verb Agreement'),
            ),
            DropdownMenuItem(
              value: 'articles',
              child: Text('Articles (a/an/the)'),
            ),
            DropdownMenuItem(
              value: 'prepositions',
              child: Text('Prepositions'),
            ),
            DropdownMenuItem(value: 'modal_verbs', child: Text('Modal Verbs')),
            DropdownMenuItem(
              value: 'conditionals',
              child: Text('Conditionals'),
            ),
            DropdownMenuItem(value: 'word_order', child: Text('Word Order')),
            DropdownMenuItem(
              value: 'common_errors',
              child: Text('Common Errors'),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() => _selectedCategory = value);
            }
          },
        ),
      ),
    );
  }

  Widget _buildQuizScreen() {
    final currentQuestion = _questions[_currentQuestionIndex];
    final options = List<String>.from(currentQuestion['options']);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Grammar Practice'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '${_currentQuestionIndex + 1}/${_questions.length}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Progress bar
            LinearProgressIndicator(
              value: (_currentQuestionIndex + 1) / _questions.length,
              backgroundColor: Colors.grey[300],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
              minHeight: 8,
            ),
            const SizedBox(height: 24),

            // Score display
            // ✅ NEW CODE (responsive, no overflow)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: _buildScoreChip(
                    'Correct',
                    _correctAnswers,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildScoreChip('Total', _totalAnswered, Colors.blue),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildScoreChip(
                    'Accuracy',
                    _totalAnswered > 0
                        ? ((_correctAnswers / _totalAnswered) * 100).round()
                        : 0,
                    Colors.orange,
                    suffix: '%',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Question card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ✅ NEW CODE (responsive, wraps text)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            currentQuestion['grammarPoint'] ?? 'Grammar',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade700,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      currentQuestion['question'],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Options
            ...List.generate(options.length, (index) {
              return _buildOptionButton(
                index,
                options[index],
                currentQuestion['correctAnswer'] as int,
              );
            }),
            const SizedBox(height: 24),

            // Submit/Next button
            if (!_hasAnswered)
              ElevatedButton(
                onPressed: _selectedAnswer != null ? _submitAnswer : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Submit Answer',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              )
            else
              ElevatedButton(
                onPressed: _nextQuestion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _currentQuestionIndex < _questions.length - 1
                      ? 'Next Question →'
                      : 'Complete Session',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            // Explanation
            if (_showExplanation) ...[
              const SizedBox(height: 24),
              _buildExplanationCard(currentQuestion),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScoreChip(
    String label,
    int value,
    Color color, {
    String suffix = '',
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color, width: 2),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$value$suffix',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionButton(int index, String text, int correctAnswer) {
    final isSelected = _selectedAnswer == index;
    final isCorrect = index == correctAnswer;
    final showResult = _hasAnswered;

    Color backgroundColor = Colors.white;
    Color borderColor = Colors.grey.shade300;
    Color textColor = Colors.black;

    if (showResult) {
      if (isCorrect) {
        backgroundColor = Colors.green.shade50;
        borderColor = Colors.green;
        textColor = Colors.green.shade900;
      } else if (isSelected && !isCorrect) {
        backgroundColor = Colors.red.shade50;
        borderColor = Colors.red;
        textColor = Colors.red.shade900;
      }
    } else if (isSelected) {
      backgroundColor = Colors.orange.shade50;
      borderColor = Colors.orange;
      textColor = Colors.orange.shade900;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: showResult ? null : () => _selectAnswer(index),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border.all(color: borderColor, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: backgroundColor,
                  border: Border.all(color: borderColor, width: 2),
                ),
                child: Center(
                  child: Text(
                    String.fromCharCode(65 + index), // A, B, C, D
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 16,
                    color: textColor,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
              if (showResult && isCorrect)
                const Icon(Icons.check_circle, color: Colors.green),
              if (showResult && isSelected && !isCorrect)
                const Icon(Icons.cancel, color: Colors.red),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExplanationCard(Map<String, dynamic> question) {
    final isCorrect = _selectedAnswer == question['correctAnswer'];

    return Card(
      elevation: 4,
      color: isCorrect ? Colors.green.shade50 : Colors.orange.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isCorrect ? Colors.green : Colors.orange,
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isCorrect ? Icons.check_circle : Icons.lightbulb,
                  color: isCorrect ? Colors.green : Colors.orange,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  isCorrect ? '✅ Correct!' : '💡 Explanation',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isCorrect
                        ? Colors.green.shade900
                        : Colors.orange.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              question['explanation'] ?? 'No explanation available.',
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
