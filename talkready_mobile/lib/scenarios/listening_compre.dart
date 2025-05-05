import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';

class ListeningComprehensionDrillScreen extends StatefulWidget {
  final String accentLocale;
  final String userName;
  final int timeGoalSeconds;

  const ListeningComprehensionDrillScreen({
    super.key,
    required this.accentLocale,
    required this.userName,
    required this.timeGoalSeconds,
  });

  @override
  State<ListeningComprehensionDrillScreen> createState() => _ListeningComprehensionDrillScreenState();
}

class _ListeningComprehensionDrillScreenState extends State<ListeningComprehensionDrillScreen> with SingleTickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();
  static const String _ttsServerUrl = 'https://c360-175-176-32-217.ngrok-free.app/tts';
  String? _currentSentence;
  List<String>? _answerOptions;
  String? _correctAnswer;
  String? _selectedAnswer;
  List<String>? _explanation;
  bool _isLoading = false;
  bool _isPlaying = false;
  int _remainingSeconds = 0;
  Timer? _timer;
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  String _difficulty = 'Easy';

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.timeGoalSeconds;
    _startTimer();
    _initializeTts();
    _generateNewQuestion();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  Future<void> _initializeTts() async {
    try {
      await _flutterTts.setLanguage(widget.accentLocale);
      await _flutterTts.setPitch(0.7);
      await _flutterTts.setSpeechRate(0.6);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error initializing TTS: $e')),
      );
    }
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
            const SnackBar(content: Text('Time’s up for today’s practice!')),
          );
          Navigator.pop(context);
        }
      }
    });
  }

  Future<void> _generateNewQuestion() async {
    if (_remainingSeconds <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Time’s up! Please try again tomorrow.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _currentSentence = null;
      _answerOptions = null;
      _correctAnswer = null;
      _selectedAnswer = null;
      _explanation = null;
    });

    try {
      final questionData = await _getListeningQuestion();
      setState(() {
        _currentSentence = questionData['sentence'];
        _answerOptions = List<String>.from(questionData['options']);
        _correctAnswer = questionData['correct'];
        _explanation = List<String>.from(questionData['explanation']);
        _isLoading = false;
      });
      _animationController.forward(from: 0);
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<Map<String, dynamic>> _getListeningQuestion() async {
    final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      throw Exception('OpenAI API key missing.');
    }

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
            'content': '''
You are a listening comprehension assistant for non-native English speakers. Generate a listening comprehension question at a ${_difficulty.toLowerCase()} difficulty level. Provide:
1. A sentence in English (5-10 words for Easy, 8-12 words for Medium, 10-15 words for Hard).
2. Four answer options (one correct, three incorrect distractors).
3. An explanation of why the correct option is right and others are wrong in a concise numbered list format (using simple language).

Difficulty guidelines:
- Easy: Simple vocabulary and grammar (e.g., "The dog runs.").
- Medium: Slightly more complex sentences (e.g., "The dog runs in the park every morning.").
- Hard: Complex sentences with varied vocabulary (e.g., "The dog, which is very energetic, runs swiftly in the park every morning.").

Return the response in JSON format:
{
  "sentence": "The sentence",
  "options": ["Option 1", "Option 2", "Option 3", "Option 4"],
  "correct": "The correct option",
  "explanation": ["Explanation point 1", "Explanation point 2", "Explanation point 3", "Explanation point 4"]
}
Ensure the sentence, options, and explanation are clear and appropriate for the difficulty level.
''',
          },
        ],
        'max_tokens': 300,
        'temperature': 0.6,
      }),
    );

    if (response.statusCode == 200) {
      final responseBody = utf8.decode(response.bodyBytes, allowMalformed: true);
      final data = jsonDecode(responseBody);

      print('Open AI raw response: $data');

      final content = data['choices'][0]['message']['content'];

      Map<String, dynamic> questionData;
      if (content is String) {
        questionData = jsonDecode(content);
      } else if (content is List) {
        throw Exception('Unexpected response format: content is a list, not a JSON string');
      } else {
        throw Exception('Unexpected content type: ${content.runtimeType}');
      }

      questionData['sentence'] = _cleanText(questionData['sentence']);
      questionData['options'] = questionData['options'].map((opt) => _cleanText(opt)).toList();
      questionData['correct'] = _cleanText(questionData['correct']);
      questionData['explanation'] = questionData['explanation'].map((exp) => _cleanText(exp)).toList();
      return questionData;
    } else {
      throw Exception('Failed to generate question: ${response.statusCode}');
    }
  }

  Future<void> _playAudio(String text) async {
    if (!mounted) return;
    setState(() => _isPlaying = true);
    try {
      final response = await http.post(
        Uri.parse(_ttsServerUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': text,
          'locale': widget.accentLocale,
        }),
      );
      if (response.statusCode == 200) {
        await _audioPlayer.play(BytesSource(response.bodyBytes));
      } else {
        await _flutterTts.speak(text);
      }
    } catch (e) {
      try {
        await _flutterTts.speak(text);
      } catch (ttsError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('TTS error: $ttsError')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPlaying = false);
      }
    }
  }

  void _stopAudio() async {
    await _audioPlayer.stop();
    await _flutterTts.stop();
    setState(() => _isPlaying = false);
  }

  void _submitAnswer(String answer) {
    setState(() {
      _selectedAnswer = answer;
    });
    _animationController.forward(from: 0);
    if (_currentSentence != null) {
      _playAudio(_currentSentence!); // Optional: Replay audio on answer submission
    }
  }

  void _nextQuestion() {
    setState(() {
      _selectedAnswer = null;
      _currentSentence = null;
      _answerOptions = null;
      _correctAnswer = null;
      _explanation = null;
    });
    _animationController.reset();
    _generateNewQuestion();
  }

  String _cleanText(String text) {
    return text
        .replaceAll('â€™', "'")
        .replaceAll('â€', '"')
        .replaceAll('Ã©', 'e')
        .replaceAll('âˆ™', "'")
        .trim();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopAudio();
    _audioPlayer.dispose();
    _flutterTts.stop();
    _animationController.dispose();
    super.dispose();
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _stopAudio();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Listening Drill',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          backgroundColor: Colors.blue.shade800,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              _stopAudio();
              Navigator.pop(context);
            },
            tooltip: 'Back to Chat',
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: DropdownButton<String>(
                value: _difficulty,
                items: ['Easy', 'Medium', 'Hard'].map((String difficulty) {
                  return DropdownMenuItem<String>(
                    value: difficulty,
                    child: Text(
                      difficulty,
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                }).toList(),
                onChanged: (String? newDifficulty) {
                  if (newDifficulty != null) {
                    setState(() {
                      _difficulty = newDifficulty;
                    });
                    _generateNewQuestion();
                  }
                },
                dropdownColor: Colors.blue.shade800,
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                underline: const SizedBox(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
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
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sharpen Your Listening, ${widget.userName}!',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Listen to the sentence and choose the correct meaning from the options below.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              if (_isLoading)
                const Center(child: CircularProgressIndicator(color: Colors.blue)),
              if (_currentSentence != null && !_isLoading) ...[
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center, // Center the icon
                      children: [
                        IconButton(
                          icon: Icon(
                            _isPlaying ? Icons.stop : Icons.play_arrow,
                            color: Colors.blue,
                            size: 28,
                          ),
                          onPressed: () => _playAudio(_currentSentence!),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'What does the sentence mean?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                ),
                const SizedBox(height: 8),
                ...?_answerOptions?.map((option) {
                  bool isSelected = _selectedAnswer == option;
                  bool isCorrect = _correctAnswer == option;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Card(
                      elevation: isSelected ? 4 : 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      color: isSelected
                          ? (isCorrect ? Colors.green.shade50 : Colors.red.shade50)
                          : Colors.white,
                      child: ListTile(
                        title: Text(
                          option,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                            fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(
                                isCorrect ? Icons.check_circle : Icons.cancel,
                                color: isCorrect ? Colors.green : Colors.red,
                                size: 24,
                              )
                            : null,
                        onTap: _selectedAnswer == null ? () => _submitAnswer(option) : null,
                      ),
                    ),
                  );
                }).toList(),
                if (_selectedAnswer != null) ...[
                  SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        const Text(
                          'Explanation:',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                        ),
                        const SizedBox(height: 8),
                        Card(
                          elevation: 2,
                          color: Colors.yellow.shade50,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              _explanation != null && _explanation!.isNotEmpty
                                  ? _explanation!.join('\n')
                                  : 'No explanation available.',
                              style: const TextStyle(fontSize: 14, color: Colors.black87),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: _nextQuestion,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.refresh, size: 20, color: Colors.white),
                            label: const Text('Next Question', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 80),
            ],
          ),
        ),
        floatingActionButton: _selectedAnswer == null && _currentSentence != null
            ? FloatingActionButton.extended(
                onPressed: () => _playAudio(_currentSentence!),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                label: const Text('Replay Audio', style: TextStyle(fontSize: 16)),
                icon: const Icon(Icons.play_arrow),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              )
            : null,
      ),
    );
  }
}