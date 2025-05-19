import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logger/logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VocabularyBuildingPracticeScreen extends StatefulWidget {
  final String accentLocale;
  final String userName;
  final int timeGoalSeconds;
  final String userId;

  const VocabularyBuildingPracticeScreen({
    super.key,
    required this.accentLocale,
    required this.userName,
    required this.timeGoalSeconds,
    required this.userId,
  });

  @override
  State<VocabularyBuildingPracticeScreen> createState() => _VocabularyBuildingPracticeScreenState();
}

final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 2,
    errorMethodCount: 8,
    lineLength: 120,
    colors: true,
    printEmojis: true,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
);

class _VocabularyBuildingPracticeScreenState extends State<VocabularyBuildingPracticeScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _currentWord = '';
  String _difficultyLevel = 'Beginner';
  String? _userSentence;
  String? _correctUsage;
  String? _explanation;
  String? _suggestions;
  String? _revisedSentence;
  bool _isLoading = false;
  int _remainingSeconds = 0;
  Timer? _timer;
  double _score = 0.0;
  int _totalAttempts = 0;
  int _correctAttempts = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final FocusNode _textFieldFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.timeGoalSeconds;
    final allowedDifficulties = ['Beginner', 'Intermediate', 'Advanced'];
    if (!allowedDifficulties.contains(_difficultyLevel)) {
      _difficultyLevel = 'Beginner';
    }
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _textFieldFocusNode.addListener(() {
      if (_textFieldFocusNode.hasFocus) {
        _scrollToBottom();
      }
    });
    _startTimer();
    _loadNewWord();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        timer.cancel();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Time's up for today's practice!")),
          );
          Navigator.pop(context);
        }
      }
    });
  }

  Future<void> _loadNewWord() async {
    setState(() {
      _isLoading = true;
      _userSentence = null;
      _correctUsage = null;
      _explanation = null;
      _suggestions = null;
      _revisedSentence = null;
      _controller.clear();
    });

    try {
      final wordData = await _fetchWordFromOpenAI(_difficultyLevel);
      setState(() {
        _currentWord = wordData['word']!;
        _difficultyLevel = wordData['difficulty']!;
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      logger.e('Error loading new word: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load new word. Please check your internet or app settings.')),
      );
      setState(() {
        _currentWord = 'resilient';
        _difficultyLevel = 'Beginner';
      });
      _scrollToBottom();
    }
  }

  Future<Map<String, String>> _fetchWordFromOpenAI(String difficulty) async {
    if (dotenv.env.isEmpty) {
      logger.e('DotEnv not initialized or empty');
      throw Exception('Environment variables not loaded. Please check app configuration.');
    }

    final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      logger.e('OpenAI API key missing in .env file');
      throw Exception('OpenAI API key missing.');
    }

    try {
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': [
            {
              'role': 'system',
              'content': 'You are a vocabulary building assistant for English learners. Provide a vocabulary word and its difficulty level. The difficulty level must be one of: Beginner, Intermediate, Advanced. Adjust the complexity of the word based on the difficulty level. Format the response as:\nWord: [vocabulary word]\nDifficulty: [Beginner/Intermediate/Advanced]\nDo not use markdown symbols like asterisks (**), bold, or italics in the response. Ensure the text is clean, precise, and straightforward.',
            },
            {'role': 'user', 'content': 'Generate a vocabulary word for difficulty level: $difficulty'},
          ],
          'max_tokens': 100,
          'temperature': 0.5,
        }),
      );

      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes, allowMalformed: true);
        final data = jsonDecode(responseBody);
        String rawResponse = data['choices'][0]['message']['content'].trim();
        rawResponse = _cleanText(rawResponse);

        final lines = rawResponse.split('\n');
        if (lines.length < 2) {
          logger.e('Invalid response format from OpenAI: Expected 2 lines but got ${lines.length}');
          throw Exception('Invalid response format from OpenAI');
        }

        final word = lines[0].replaceFirst('Word: ', '').trim().isNotEmpty
            ? lines[0].replaceFirst('Word: ', '').trim()
            : 'resilient';

        String rawDifficulty = lines[1].replaceFirst('Difficulty: ', '').trim();
        rawDifficulty = rawDifficulty.replaceAll(RegExp(r'^[-\s]+'), '').trim();
        final allowedDifficulties = ['Beginner', 'Intermediate', 'Advanced'];
        final difficultyLevel = allowedDifficulties.contains(rawDifficulty)
            ? rawDifficulty
            : 'Beginner';

        logger.i('Fetched word: $word, difficulty: $difficultyLevel');
        return {
          'word': word,
          'difficulty': difficultyLevel,
        };
      } else {
        logger.e('Failed to fetch word: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to fetch word: ${response.statusCode}');
      }
    } catch (e) {
      logger.e('Error fetching word from OpenAI: $e');
      rethrow;
    }
  }

  Future<void> _checkVocabularyUsage() async {
    if (_controller.text.isEmpty || _remainingSeconds <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a sentence or check your remaining time.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _userSentence = _controller.text.trim();
    });

    try {
      final feedbackData = await _getVocabularyFeedback(_userSentence!, _currentWord);
      setState(() {
        _correctUsage = feedbackData['correctUsage'];
        _explanation = feedbackData['explanation'];
        _suggestions = feedbackData['suggestions'];
        _revisedSentence = feedbackData['revisedSentence'];
        _isLoading = false;
        _totalAttempts++;
        if (_correctUsage?.contains('Yes') == true) {
          _correctAttempts++;
        }
        _score = (_totalAttempts > 0) ? (_correctAttempts / _totalAttempts) * 100 : 0;
        _animationController.forward(from: 0);
      });
      logger.i('After attempt: totalAttempts=$_totalAttempts, correctAttempts=$_correctAttempts, score=$_score');
      await _saveVocabularyProgress();
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      logger.e('Error checking vocabulary usage: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to check sentence. Please try again.')),
      );
      _scrollToBottom();
    }
  }

  Future<Map<String, String>> _getVocabularyFeedback(String userSentence, String targetWord) async {
    if (dotenv.env.isEmpty) {
      logger.e('DotEnv not initialized or empty');
      throw Exception('Environment variables not loaded. Please check app configuration.');
    }

    final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      logger.e('OpenAI API key missing in .env file');
      throw Exception('OpenAI API key missing.');
    }

    try {
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': [
            {
              'role': 'system',
              'content': 'You are a vocabulary building assistant. Evaluate the usage of the word "$targetWord" in the user\'s sentence: "$userSentence". Provide feedback in the following format:\nCorrect usage: [Yes/No]\nExplanation: [Explain why the usage is correct or incorrect, including grammar, context, and meaning. Keep this section concise and avoid newlines within this section.]\nSuggestions: [Provide suggestions to improve the sentence if incorrect, or enhance it if correct. Keep this section concise and avoid newlines within this section.]\nRevised Sentence: [Provide a revised version of the sentence if applicable. Keep this section concise and avoid newlines within this section.]\nEnsure each section starts with the exact label (e.g., "Correct usage:") and is on a new line. Do not use markdown symbols like asterisks (**), bold, or italics in the response. Ensure the text is clean, precise, and straightforward, with no extra newlines within each section.',
            },
            {'role': 'user', 'content': 'Evaluate the usage of "$targetWord" in this sentence: "$userSentence"'},
          ],
          'max_tokens': 500,
          'temperature': 0.5,
        }),
      );

      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes, allowMalformed: true);
        final data = jsonDecode(responseBody);
        String rawFeedback = data['choices'][0]['message']['content'].trim();
        rawFeedback = _cleanText(rawFeedback);

        logger.i('Raw OpenAI feedback:\n$rawFeedback');

        final lines = rawFeedback.split('\n');
        if (lines.length < 4) {
          logger.e('Invalid feedback format from OpenAI: Expected at least 4 lines but got ${lines.length}');
          throw Exception('Invalid feedback format from OpenAI');
        }

        Map<String, String> feedback = {};
        String currentKey = '';
        StringBuffer currentValue = StringBuffer();

        for (String line in lines) {
          if (line.startsWith('Correct usage:') ||
              line.startsWith('Explanation:') ||
              line.startsWith('Suggestions:') ||
              line.startsWith('Revised Sentence:')) {
            if (currentKey.isNotEmpty) {
              feedback[currentKey] = currentValue.toString().trim();
            }
            if (line.startsWith('Correct usage:')) {
              currentKey = 'correctUsage';
              currentValue = StringBuffer(line.replaceFirst('Correct usage: ', ''));
            } else if (line.startsWith('Explanation:')) {
              currentKey = 'explanation';
              currentValue = StringBuffer(line.replaceFirst('Explanation: ', ''));
            } else if (line.startsWith('Suggestions:')) {
              currentKey = 'suggestions';
              currentValue = StringBuffer(line.replaceFirst('Suggestions: ', ''));
            } else if (line.startsWith('Revised Sentence:')) {
              currentKey = 'revisedSentence';
              currentValue = StringBuffer(line.replaceFirst('Revised Sentence: ', ''));
            }
          } else {
            if (currentValue.isNotEmpty) {
              currentValue.write(' $line');
            }
          }
        }
        if (currentKey.isNotEmpty) {
          feedback[currentKey] = currentValue.toString().trim();
        }

        if (!feedback.containsKey('correctUsage') ||
            !feedback.containsKey('explanation') ||
            !feedback.containsKey('suggestions') ||
            !feedback.containsKey('revisedSentence')) {
          logger.e('Incomplete feedback: Missing one or more required fields');
          throw Exception('Incomplete feedback from OpenAI');
        }

        logger.i('Parsed feedback: $feedback');
        return feedback;
      } else {
        logger.e('Failed to get feedback: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to get feedback: ${response.statusCode}');
      }
    } catch (e) {
      logger.e('Error getting vocabulary feedback: $e');
      rethrow;
    }
  }

  Future<void> _saveVocabularyProgress() async {
    try {
      final vocabRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('vocabulary');

      // Save individual attempt
      await vocabRef.add({
        'word': _currentWord,
        'difficulty': _difficultyLevel,
        'correct': _correctUsage?.contains('Yes') == true,
        'userSentence': _userSentence,
        'revisedSentence': _revisedSentence,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update summary
      final summaryRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('vocabulary')
          .doc('summary');
      await summaryRef.set({
        'totalAttempts': FieldValue.increment(1),
        'correctAttempts': _correctUsage?.contains('Yes') == true
            ? FieldValue.increment(1)
            : FieldValue.increment(0),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      logger.i('Saved vocabulary progress for word: $_currentWord');
    } catch (e) {
      logger.e('Error saving vocabulary progress: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save progress. Please try again.')),
      );
    }
  }

  String _cleanText(String text) {
    return text
        .replaceAll('â€™', "'")
        .replaceAll('â€', '"')
        .replaceAll('Ã©', 'é')
        .replaceAll('âˆ™', "'")
        .trim();
  }

  void _nextWord() {
    setState(() {
      _userSentence = null;
      _correctUsage = null;
      _explanation = null;
      _suggestions = null;
      _revisedSentence = null;
      _controller.clear();
    });
    logger.i('Moving to next word: totalAttempts=$_totalAttempts, correctAttempts=$_correctAttempts, score=$_score');
    _loadNewWord();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _animationController.dispose();
    _scrollController.dispose();
    _textFieldFocusNode.dispose();
    super.dispose();
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text(
          'Vocab Practice',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.blue.shade800,
        elevation: 4,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back to Chat',
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer, size: 16, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    _formatTime(_remainingSeconds),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Build Your Vocabulary, ${widget.userName}!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Create a sentence using the given word.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    'Difficulty: ',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: DropdownButton<String>(
                      value: _difficultyLevel,
                      underline: const SizedBox(),
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.blue),
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.blue.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Beginner',
                          child: Text('Beginner'),
                        ),
                        DropdownMenuItem(
                          value: 'Intermediate',
                          child: Text('Intermediate'),
                        ),
                        DropdownMenuItem(
                          value: 'Advanced',
                          child: Text('Advanced'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _difficultyLevel = value;
                          });
                          _loadNewWord();
                        }
                      },
                      dropdownColor: Colors.white,
                      focusColor: Colors.blue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 4,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vocabulary Word:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _currentWord,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _controller,
                focusNode: _textFieldFocusNode,
                cursorColor: Colors.blue,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Write a sentence using the word above...',
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Colors.blue, width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton.icon(
                  onPressed: _checkVocabularyUsage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                  icon: const Icon(Icons.check, size: 20, color: Colors.white),
                  label: const Text(
                    'Check Usage',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              if (_isLoading)
                const Center(child: CircularProgressIndicator(color: Colors.blue)),
              if (_userSentence != null && !_isLoading && _correctUsage != null) ...[
                const SizedBox(height: 20),
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star,
                              size: 20,
                              color: _score >= 80 ? Colors.green : Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Accuracy Score: ',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800,
                              ),
                            ),
                            Text(
                              '${_score.toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _score >= 80 ? Colors.green : Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Your Sentence:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        elevation: 3,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            _userSentence!,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Feedback:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        elevation: 3,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Icon(
                                _correctUsage?.contains('Yes') == true ? Icons.check_circle : Icons.cancel,
                                color: _correctUsage?.contains('Yes') == true ? Colors.green : Colors.red,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Correct Usage: $_correctUsage',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: _correctUsage?.contains('Yes') == true ? Colors.green : Colors.red,
                                    letterSpacing: 0.3,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        elevation: 3,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info,
                                color: Colors.blue,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Explanation: $_explanation',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                    letterSpacing: 0.3,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        elevation: 3,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.lightbulb,
                                color: Colors.orange,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Suggestions: $_suggestions',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                    letterSpacing: 0.3,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_revisedSentence != null && _revisedSentence!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Card(
                          elevation: 3,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.edit,
                                  color: Colors.green,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Revised Sentence: $_revisedSentence',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87,
                                      letterSpacing: 0.3,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: _nextWord,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade800,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                          ),
                          icon: const Icon(Icons.refresh, size: 20, color: Colors.white),
                          label: const Text(
                            'Next Word',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}