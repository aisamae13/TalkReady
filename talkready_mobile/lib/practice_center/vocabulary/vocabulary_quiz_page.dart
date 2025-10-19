import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class VocabularyQuizPage extends StatefulWidget {
  const VocabularyQuizPage({Key? key}) : super(key: key);

  @override
  State<VocabularyQuizPage> createState() => _VocabularyQuizPageState();
}

class _VocabularyQuizPageState extends State<VocabularyQuizPage> {
  final Logger _logger = Logger();
  final _user = FirebaseAuth.instance.currentUser;

  bool _isLoading = true;
  bool _isLoadingQuiz = false;
  List<Map<String, dynamic>> _words = [];
  List<Map<String, dynamic>> _questions = [];
  int _currentQuestionIndex = 0;
  int? _selectedAnswer;
  bool _hasAnswered = false;
  bool _showExplanation = false;

  // Session tracking
  int _correctAnswers = 0;
  int _totalAnswered = 0;
  DateTime? _sessionStartTime;
  List<Map<String, dynamic>> _sessionResults = [];

  // Settings
  String _selectedDifficulty = 'beginner';
  String _selectedCategory = 'general';
  String _selectedQuizType = 'definition_match';

  static const String _backendUrl = 'https://talkready-backend.onrender.com';

  // ✅ NEW CODE (shows dialog after build completes)
  @override
  void initState() {
    super.initState();
    _sessionStartTime = DateTime.now();

    // Show dialog AFTER the first frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showSettingsDialog();
    });
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Quiz Settings'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedDifficulty,
                decoration: const InputDecoration(
                  labelText: 'Difficulty',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'beginner', child: Text('Beginner')),
                  DropdownMenuItem(
                    value: 'intermediate',
                    child: Text('Intermediate'),
                  ),
                  DropdownMenuItem(value: 'advanced', child: Text('Advanced')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedDifficulty = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'general', child: Text('General')),
                  DropdownMenuItem(
                    value: 'customer_service',
                    child: Text('Customer Service'),
                  ),
                  DropdownMenuItem(
                    value: 'technical_terms',
                    child: Text('Technical Terms'),
                  ),
                  DropdownMenuItem(
                    value: 'business_vocabulary',
                    child: Text('Business Vocabulary'),
                  ),
                  DropdownMenuItem(
                    value: 'phone_etiquette',
                    child: Text('Phone Etiquette'),
                  ),
                  DropdownMenuItem(
                    value: 'problem_solving',
                    child: Text('Problem Solving'),
                  ),
                  DropdownMenuItem(
                    value: 'payment_and_billing',
                    child: Text('Payment & Billing'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedCategory = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedQuizType,
                decoration: const InputDecoration(
                  labelText: 'Quiz Type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'definition_match',
                    child: Text('Match Definitions'),
                  ),
                  DropdownMenuItem(
                    value: 'fill_in_blank',
                    child: Text('Fill in the Blank'),
                  ),
                  DropdownMenuItem(
                    value: 'synonym_match',
                    child: Text('Match Synonyms'),
                  ),
                  DropdownMenuItem(
                    value: 'usage_context',
                    child: Text('Correct Usage'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedQuizType = value);
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _loadWordsAndGenerateQuiz();
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Quiz'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  // Add loading state variable
  String _loadingMessage = 'Preparing your quiz...';

  Future<void> _loadWordsAndGenerateQuiz() async {
    if (!mounted) return;
    setState(() {
      _isLoadingQuiz = true;
      _loadingMessage = 'Waking up the AI...'; // ✅ First message
    });

    try {
      _logger.i('Generating vocabulary quiz session...');

      // ✅ Update message after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _isLoadingQuiz) {
          setState(() => _loadingMessage = 'Generating vocabulary words...');
        }
      });

      // ✅ Update message after 10 seconds
      Future.delayed(const Duration(seconds: 10), () {
        if (mounted && _isLoadingQuiz) {
          setState(() => _loadingMessage = 'Creating quiz questions...');
        }
      });

      // ✅ Update message after 20 seconds
      Future.delayed(const Duration(seconds: 20), () {
        if (mounted && _isLoadingQuiz) {
          setState(() => _loadingMessage = 'Almost ready...');
        }
      });

      final response = await http
          .post(
            Uri.parse('$_backendUrl/generate-vocabulary-quiz-session'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'difficulty': _selectedDifficulty,
              'category': _selectedCategory,
              'quizType': _selectedQuizType,
              'wordCount': 5, // ✅ REDUCED from 10 to 5
              'questionCount': 5, // Keep 5 questions
            }),
          )
          .timeout(const Duration(seconds: 60)); // ✅ Shorter timeout

      if (!mounted) return;

      if (response.statusCode != 200) {
        throw Exception('Failed to generate quiz');
      }

      final data = json.decode(response.body);
      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Unknown error');
      }

      if (!mounted) return;

      setState(() {
        _words = List<Map<String, dynamic>>.from(data['words'] ?? []);
        _questions = List<Map<String, dynamic>>.from(data['questions'] ?? []);
        _isLoadingQuiz = false;
        _isLoading = false;
        _currentQuestionIndex = 0;
        _sessionStartTime = DateTime.now();
      });

      _logger.i(
        'Loaded ${_words.length} words and ${_questions.length} questions',
      );
    } catch (e) {
      _logger.e('Error loading quiz: $e');

      if (!mounted) return;

      setState(() {
        _isLoadingQuiz = false;
        _isLoading = false;
      });

      if (e.toString().contains('TimeoutException')) {
        _showError(
          'Quiz generation timed out (90s). Backend may be cold-starting. Please try again.',
        );
      } else {
        _showError('Failed to load quiz: ${e.toString()}');
      }
    }
  }

  void _selectAnswer(int index) {
    if (_hasAnswered) return;
    setState(() => _selectedAnswer = index);
  }

  void _submitAnswer() {
    if (_selectedAnswer == null || _hasAnswered) return;

    final currentQuestion = _questions[_currentQuestionIndex];

    // ✅ FIXED: Safely convert correctAnswer to int
    final correctAnswerRaw = currentQuestion['correctAnswer'];
    final correctAnswer = correctAnswerRaw is int
        ? correctAnswerRaw
        : int.tryParse(correctAnswerRaw.toString()) ?? 0;

    final isCorrect = _selectedAnswer == correctAnswer;

    setState(() {
      _hasAnswered = true;
      _showExplanation = true;
      _totalAnswered++;

      if (isCorrect) {
        _correctAnswers++;
      }

      _sessionResults.add({
        'questionId': currentQuestion['id'],
        'targetWord': currentQuestion['targetWord'],
        'userAnswer': _selectedAnswer,
        'correctAnswer': correctAnswer,
        'isCorrect': isCorrect,
        'timestamp': DateTime.now().toIso8601String(),
      });
    });

    _logger.i(
      'Answer: ${isCorrect ? 'Correct' : 'Wrong'} ($_correctAnswers/$_totalAnswered)',
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

    // Save session
    try {
      final duration = DateTime.now().difference(_sessionStartTime!).inSeconds;

      await http
          .post(
            Uri.parse('$_backendUrl/save-vocabulary-quiz-session'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'userId': _user?.uid,
              'sessionData': {
                'startedAt': _sessionStartTime!.toIso8601String(),
                'quizType': _selectedQuizType,
                'difficulty': _selectedDifficulty,
                'category': _selectedCategory,
                'questionsAttempted': _totalAnswered,
                'questionsCorrect': _correctAnswers,
                'accuracy': accuracy.toDouble(),
                'wordsReviewed': _words.map((w) => w['word']).toList(),
                'results': _sessionResults,
                'duration': duration,
              },
            }),
          )
          .timeout(const Duration(seconds: 10));

      _logger.i('Quiz session saved');
    } catch (e) {
      _logger.e('Failed to save session: $e');
    }

    _showSessionComplete(accuracy);
  }

  void _showSessionComplete(int accuracy) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🎉 Quiz Complete!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Well done, ${_user?.displayName?.split(' ')[0] ?? 'there'}!',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _buildStatRow('Questions', '$_totalAnswered/${_questions.length}'),
            _buildStatRow('Correct', '$_correctAnswers/$_totalAnswered'),
            _buildStatRow('Accuracy', '$accuracy%'),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
            child: const Text('Take Another Quiz'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
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
      _words.clear();
    });
    _showSettingsDialog();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _isLoadingQuiz) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Vocabulary Quiz'),
          backgroundColor: Colors.purple,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.purple),
              const SizedBox(height: 24),
              Text(
                _loadingMessage, // ✅ Dynamic message
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'This may take 30-60 seconds...',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              // ✅ Add animated dots
              const SizedBox(
                width: 50,
                child: LinearProgressIndicator(
                  color: Colors.purple,
                  backgroundColor: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('🎯 Vocabulary Quiz'),
          backgroundColor: Colors.purple,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('No quiz available'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _showSettingsDialog,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    final currentQuestion = _questions[_currentQuestionIndex];
    final options = List<String>.from(currentQuestion['options']);

    return Scaffold(
      appBar: AppBar(
        title: const Text('🎯 Vocabulary Quiz'),
        backgroundColor: Colors.purple,
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
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.purple),
              minHeight: 8,
            ),
            const SizedBox(height: 24),

            // Score
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildScoreChip('Correct', _correctAnswers, Colors.green),
                _buildScoreChip('Total', _totalAnswered, Colors.blue),
                _buildScoreChip(
                  'Accuracy',
                  _totalAnswered > 0
                      ? ((_correctAnswers / _totalAnswered) * 100).round()
                      : 0,
                  Colors.purple,
                  suffix: '%',
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
                    if (currentQuestion['targetWord'] != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Word: ${currentQuestion['targetWord']}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple.shade700,
                          ),
                        ),
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

            // ✅ NEW CODE
            ...List.generate(options.length, (index) {
              return _buildOptionButton(
                index,
                options[index],
                currentQuestion['correctAnswer'], // ✅ No cast - method handles it
              );
            }),
            const SizedBox(height: 24),

            // Submit/Next button
            if (!_hasAnswered)
              ElevatedButton(
                onPressed: _selectedAnswer != null ? _submitAnswer : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
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
                      : 'Complete Quiz',
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
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color, width: 2),
          ),
          child: Text(
            '$value$suffix',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionButton(int index, String text, dynamic correctAnswer) {
    // ✅ Changed to dynamic
    final isSelected = _selectedAnswer == index;

    // ✅ FIXED: Safely convert correctAnswer to int
    final correctAnswerInt = correctAnswer is int
        ? correctAnswer
        : int.tryParse(correctAnswer.toString()) ?? 0;

    final isCorrect = index == correctAnswerInt;
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
      backgroundColor = Colors.purple.shade50;
      borderColor = Colors.purple;
      textColor = Colors.purple.shade900;
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
                    String.fromCharCode(65 + index),
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
      color: isCorrect ? Colors.green.shade50 : Colors.purple.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isCorrect ? Colors.green : Colors.purple,
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
                  color: isCorrect ? Colors.green : Colors.purple,
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
                        : Colors.purple.shade900,
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
