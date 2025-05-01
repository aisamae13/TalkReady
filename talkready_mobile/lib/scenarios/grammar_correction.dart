import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GrammarCorrectionScreen extends StatefulWidget {
  final String accentLocale;
  final String userName;
  final int timeGoalSeconds;

  const GrammarCorrectionScreen({
    super.key,
    required this.accentLocale,
    required this.userName,
    required this.timeGoalSeconds,
  });

  @override
  State<GrammarCorrectionScreen> createState() => _GrammarCorrectionScreenState();
}

class _GrammarCorrectionScreenState extends State<GrammarCorrectionScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  String? _userSentence;
  String? _correctedSentence;
  String? _explanation;
  bool _isLoading = false;
  int _remainingSeconds = 0;
  Timer? _timer;
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.timeGoalSeconds;
    _startTimer();

    // Initialize animation for feedback section
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

  Future<void> _checkGrammar() async {
    if (_controller.text.isEmpty || _remainingSeconds <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a sentence or check your remaining time.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _userSentence = _controller.text;
      _correctedSentence = null;
      _explanation = null;
    });

    try {
      // Use OpenAI to correct the sentence
      String corrected = await _getCorrectedSentence(_controller.text);
      // Use OpenAI to explain the correction and provide recommendations
      String explanation = await _getCorrectionExplanation(_controller.text, corrected);

      setState(() {
        _correctedSentence = corrected;
        _explanation = explanation;
        _isLoading = false;
      });
      _animationController.forward(from: 0);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

 Future<String> _getCorrectedSentence(String input) async {
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
          'content': 'You are a grammar correction assistant. Correct the following sentence for grammatical errors and return only the corrected sentence without any additional text or symbols.',
        },
        {'role': 'user', 'content': input},
      ],
      'max_tokens': 100,
      'temperature': 0.5,
    }),
  );

  if (response.statusCode == 200) {
    final responseBody = utf8.decode(response.bodyBytes, allowMalformed: true); // Explicit UTF-8 decoding
    final data = jsonDecode(responseBody);
    String corrected = data['choices'][0]['message']['content'].trim();
    return _cleanText(corrected); // Clean the text before returning
  } else {
    throw Exception('Failed to correct sentence: ${response.statusCode}');
  }
}

Future<String> _getCorrectionExplanation(String original, String corrected) async {
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
          'content': 'You are a grammar correction assistant. Analyze the grammatical errors in the original sentence and explain how they were corrected in the revised sentence. Provide a concise explanation in a numbered list format without any heading. Then, under the heading "Recommendations or Things to Improve:", provide specific, actionable recommendations for improving the sentence in a numbered list format. Do not use markdown symbols like asterisks (**), bold, or italics in the response. Ensure the text is clean, precise, and straightforward.',
        },
        {'role': 'user', 'content': 'Original: "$original"\nCorrected: "$corrected"'},
      ],
      'max_tokens': 500, // Increased from 300 to ensure full response
      'temperature': 0.5,
    }),
  );

  if (response.statusCode == 200) {
    final responseBody = utf8.decode(response.bodyBytes, allowMalformed: true); // Explicit UTF-8 decoding
    final data = jsonDecode(responseBody);
    String explanation = data['choices'][0]['message']['content'].trim();
    return _cleanText(explanation); // Clean the text before returning
  } else {
    throw Exception('Failed to get explanation: ${response.statusCode}');
  }
}

  void _nextSentence() {
    setState(() {
      _controller.clear();
      _userSentence = null;
      _correctedSentence = null;
      _explanation = null;
    });
    _animationController.reset();
  }

  String _cleanText(String text) {
  return text
      .replaceAll('â€™', "'") // Replace curly apostrophe with straight apostrophe
      .replaceAll('â€', '"')  // Replace malformed quotes
      .replaceAll('Ã©', 'e')   // Replace malformed accented characters
      .replaceAll('âˆ™', "'") // Replace the specific symbol seen in the screenshot
      .trim();
}

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
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
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Grammar Fix',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.blue.shade800,
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
              'Improve Your Grammar, ${widget.userName}!',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Type a sentence below and tap "Check Grammar" to get real-time corrections and tips.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _controller,
              cursorColor: Colors.blue, // Set cursor color to blue
              decoration: InputDecoration(
                hintText: 'Enter your sentence...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.blue),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              minLines: 1,
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator(color: Colors.blue)),
            if (_userSentence != null && !_isLoading) ...[
              SlideTransition(
                position: _slideAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: const Text(
                            'Your Sentence:',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                            softWrap: true,
                          ),
                        ),
                        const Icon(Icons.edit, color: Colors.blue, size: 24),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          _userSentence!,
                          style: const TextStyle(fontSize: 16, color: Colors.black87),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: const Text(
                            "TalkReady Bot's Suggested Correction:",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                            softWrap: true,
                          ),
                        ),
                        if (_correctedSentence != null)
                          const Icon(Icons.check_circle, color: Colors.green, size: 24),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          _correctedSentence ?? '',
                          style: const TextStyle(fontSize: 16, color: Colors.green, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
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
                            _explanation != null && _explanation!.contains('Recommendations or Things to Improve:')
                                ? _explanation!.split('Recommendations or Things to Improve:')[0].trim()
                                : _explanation ?? '',
                            style: const TextStyle(fontSize: 14, color: Colors.black87),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Recommendations or Things to Improve:',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        elevation: 2,
                        color: Colors.blue.shade50,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            _explanation != null && _explanation!.contains('Recommendations or Things to Improve:')
                                ? _explanation!.split('Recommendations or Things to Improve:')[1].trim()
                                : 'No recommendations available.',
                            style: const TextStyle(fontSize: 14, color: Colors.black87),
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: _nextSentence,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.refresh, size: 20, color: Colors.white),
                        label: const Text('Next Sentence', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _checkGrammar,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        label: const Text('Check Grammar', style: TextStyle(fontSize: 16)),
        icon: const Icon(Icons.check),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}