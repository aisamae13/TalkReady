// lib/widgets/quick_check_quiz_widget.dart
import 'package:flutter/material.dart';

class QuickCheckQuizWidget extends StatefulWidget {
  final Map<String, dynamic> quizData;

  const QuickCheckQuizWidget({super.key, required this.quizData});

  @override
  State<QuickCheckQuizWidget> createState() => _QuickCheckQuizWidgetState();
}

class _QuickCheckQuizWidgetState extends State<QuickCheckQuizWidget> {
  final Map<String, String> _answers = {};
  bool _showResults = false;
  late final List<Map<String, dynamic>> _questions;

  @override
  void initState() {
    super.initState();
    _questions = List<Map<String, dynamic>>.from(
      widget.quizData['questions'] ?? [],
    );
  }

  void _checkAnswers() {
    setState(() => _showResults = true);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: Color(0xFF00568D),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.quizData['title'] ?? 'Quick Check',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            ..._questions.asMap().entries.map((entry) {
              int idx = entry.key;
              Map<String, dynamic> q = entry.value;
              return _buildQuestion(q, idx + 1);
            }).toList(),
            if (!_showResults)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: ElevatedButton(
                    onPressed: _checkAnswers,
                    child: const Text('Check My Answers'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestion(Map<String, dynamic> question, int questionNumber) {
    final questionId = question['id'] as String;
    final prompt = question['promptText'] as String;
    final options = List<String>.from(question['options'] ?? []);
    final correctAnswer = question['correctAnswer'] as String;
    final userAnswer = _answers[questionId];

    Color? getTileColor() {
      if (!_showResults) return null;
      if (userAnswer == null) return Colors.grey[200];
      return userAnswer == correctAnswer ? Colors.green[100] : Colors.red[100];
    }

    Widget? getSubtitle() {
      if (!_showResults || userAnswer == null) return null;
      if (userAnswer == correctAnswer) {
        return const Text('Correct!', style: TextStyle(color: Colors.green));
      } else {
        return Text(
          'Correct answer: $correctAnswer',
          style: const TextStyle(color: Colors.red),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$questionNumber. $prompt',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          ...options.map((opt) {
            return RadioListTile<String>(
              title: Text(opt),
              value: opt,
              groupValue: userAnswer,
              onChanged: _showResults
                  ? null
                  : (val) => setState(() => _answers[questionId] = val!),
              tileColor: getTileColor(),
              subtitle: userAnswer == opt ? getSubtitle() : null,
            );
          }).toList(),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
