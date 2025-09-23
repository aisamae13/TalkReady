// lib/lessons/fill_in_the_blank_question_widget.dart
import 'package:flutter/material.dart';

class FillInTheBlankQuestionWidget extends StatelessWidget {
  final Map<String, dynamic> questionData;
  final bool showResults;
  final String userAnswer; // We still need this for scoring display
  final TextEditingController controller; // Use a controller

  const FillInTheBlankQuestionWidget({
    super.key,
    required this.questionData,
    required this.showResults,
    required this.userAnswer,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final correctAnswers = List<String>.from(
      questionData['correctAnswers'] ?? [],
    );
    bool? isCorrect;
    if (showResults) {
      isCorrect = correctAnswers.any(
        (ans) => ans.toLowerCase() == userAnswer.trim().toLowerCase(),
      );
    }

    return Column(
      children: [
        Text(
          questionData['instruction'] as String? ?? 'Fill in the blank.',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(
                questionData['sentence_start'] as String? ?? '',
                style: const TextStyle(fontSize: 20),
              ),
              SizedBox(
                width: 150,
                child: TextField(
                  controller: controller, // Use the passed-in controller
                  textAlign: TextAlign.center,
                  enabled: !showResults,
                  decoration: InputDecoration(
                    hintText: '(${questionData['verb_base']})',
                    filled: true,
                    fillColor: Colors.white,
                    border: const OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Theme.of(context).primaryColor,
                        width: 2,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: isCorrect == true
                            ? Colors.green
                            : isCorrect == false
                            ? Colors.red
                            : Colors.grey.shade400,
                        width: isCorrect != null ? 2.0 : 1.0,
                      ),
                    ),
                  ),
                ),
              ),
              Text(
                questionData['sentence_end'] as String? ?? '',
                style: const TextStyle(fontSize: 20),
              ),
            ],
          ),
        ),
        if (showResults && isCorrect == false)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Text(
              'Correct Answer: ${correctAnswers.join(" / ")}',
              style: TextStyle(
                color: Colors.green.shade800,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }
}
