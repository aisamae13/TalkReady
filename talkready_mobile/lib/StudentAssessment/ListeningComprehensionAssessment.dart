import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ListeningComprehensionAssessment extends StatefulWidget {
  final Map<String, dynamic> question;
  final Function(Map<String, String> answers) onComplete;

  const ListeningComprehensionAssessment({
    Key? key,
    required this.question,
    required this.onComplete,
  }) : super(key: key);

  @override
  _ListeningComprehensionAssessmentState createState() =>
      _ListeningComprehensionAssessmentState();
}

class _ListeningComprehensionAssessmentState
    extends State<ListeningComprehensionAssessment> {
  // State to manage the audio playback
  bool _isProcessing = false;
  bool _hasListened = false;

  // State to store the user's answers
  final Map<String, TextEditingController> _answerControllers = {};
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    // Initialize a TextEditingController for each question
    for (var q in (widget.question['comprehensionQuestions'] as List)) {
      _answerControllers[q['id']] = TextEditingController();
    }
  }

  @override
  void dispose() {
    // Dispose all controllers to free up resources
    _answerControllers.forEach((_, controller) => controller.dispose());
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _handlePlayAudio() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final response = await http.post(
        Uri.parse('http://192.168.1.2:5001/synthesize-speech'), // IMPORTANT: Use your actual IP
        headers: {'Content-Type': 'application/json'},
        body:
            '{"text": "${widget.question['audioPrompt']['textToSpeak']}"}',
      );

      if (response.statusCode == 200) {
        await _audioPlayer.play(BytesSource(response.bodyBytes));
        _audioPlayer.onPlayerComplete.first.then((_) {
          if (mounted) {
            setState(() {
              _hasListened = true; // Enable questions after audio plays
              _isProcessing = false;
            });
          }
        });
      } else {
        throw Exception('Server responded with status: ${response.statusCode}');
      }
    } catch (error) {
      print("Error playing audio prompt: $error");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("There was an error playing the audio. Please try again."),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isProcessing = false);
      }
    }
  }

  void _handleSubmitAnswers() {
    // Check if all questions have been answered
    final allAnswered = _answerControllers.values.every((c) => c.text.trim().isNotEmpty);
    if (!allAnswered) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please answer all comprehension questions before proceeding."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Create a map of answers from the controllers
    final answers = {
      for (var entry in _answerControllers.entries) entry.key: entry.value.text
    };

    // Pass the answers back to the parent to be saved
    widget.onComplete(answers);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Part 1: Listening Comprehension',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B), // gray-800
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.question['instruction'] ?? '',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          ),
          const SizedBox(height: 24),

          // Audio Playback Section
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: Colors.indigo.shade200),
            ),
            child: Center(
              child: Column(
                children: [
                  Text(
                    'Customer Voicemail',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.indigo.shade800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _handlePlayAudio,
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const FaIcon(FontAwesomeIcons.volumeUp, size: 18),
                    label: Text(_isProcessing ? 'Playing...' : 'Play Customer Message'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade500,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 3,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Comprehension Questions Section
          AnimatedOpacity(
            opacity: _hasListened ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 500),
            child: Visibility(
              visible: _hasListened,
              child: Padding(
                padding: const EdgeInsets.only(top: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Answer the following questions:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._buildQuestionFields(),
                    const SizedBox(height: 32),
                    Center(
                      child: ElevatedButton(
                        onPressed: _handleSubmitAnswers,
                        child: const Text('Submit Answers & Proceed'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade500,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildQuestionFields() {
    final questions = widget.question['comprehensionQuestions'] as List<dynamic>;
    return List.generate(questions.length, (index) {
      final q = questions[index];
      return Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${index + 1}. ${q['questionText']}',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _answerControllers[q['id']],
              decoration: const InputDecoration(
                hintText: 'Your answer here...',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    });
  }
}