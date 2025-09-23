// lib/lessons/find_and_click_question_widget.dart
import 'package:flutter/material.dart';

class FindAndClickQuestionWidget extends StatelessWidget {
  final Map<String, dynamic> questionData;
  final List<String> selectedWords;
  final bool showResults;
  final ValueChanged<String> onWordSelected;

  const FindAndClickQuestionWidget({
    super.key,
    required this.questionData,
    required this.selectedWords,
    required this.showResults,
    required this.onWordSelected,
  });

  @override
  Widget build(BuildContext context) {
    final sentence = questionData['sentence'] as String? ?? '';
    final words = sentence.split(' ');
    final correctWords = List<String>.from(questionData['correctWords'] ?? []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          questionData['instruction'] as String? ?? 'Select the correct words.',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Wrap(
            spacing: 8.0,
            runSpacing: 12.0,
            alignment: WrapAlignment.center,
            children: words.map((word) {
              final isSelected = selectedWords.contains(word);
              final isCorrect = correctWords.contains(word);

              Color backgroundColor = Colors.grey.shade200;
              Color textColor = Colors.black87;
              BoxBorder? border;

              if (showResults) {
                if (isSelected && isCorrect) {
                  backgroundColor = Colors.green.shade100;
                  textColor = Colors.green.shade900;
                  border = Border.all(color: Colors.green, width: 2);
                } else if (isSelected && !isCorrect) {
                  backgroundColor = Colors.red.shade100;
                  textColor = Colors.red.shade900;
                  border = Border.all(color: Colors.red, width: 2);
                } else if (!isSelected && isCorrect) {
                  backgroundColor = Colors.green.shade50;
                  border = Border.all(
                    color: Colors.green.shade200,
                    style: BorderStyle.solid,
                  );
                }
              } else if (isSelected) {
                backgroundColor = Colors.blue.shade100;
                textColor = Colors.blue.shade900;
                border = Border.all(color: Colors.blue, width: 2);
              }

              return GestureDetector(
                onTap: showResults ? null : () => onWordSelected(word),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(8),
                    border: border,
                  ),
                  child: Text(
                    word,
                    style: TextStyle(fontSize: 18, color: textColor),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
