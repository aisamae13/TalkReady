import 'package:flutter/material.dart';

Widget buildSlide({
  required String title,
  required String content,
  required int slideIndex,
}) {
  final List<Color> bubbleColors = [
    Colors.blue[50]!,
    Colors.green[50]!,
    Colors.orange[50]!,
  ];

  List<InlineSpan> contentSpans = [];
  RegExp exp = RegExp(r'\bExample\b');
  int lastIndex = 0;

  for (final match in exp.allMatches(content)) {
    if (match.start > lastIndex) {
      contentSpans.add(TextSpan(text: content.substring(lastIndex, match.start)));
    }
    contentSpans.add(TextSpan(
      text: content.substring(match.start, match.end),
      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange),
    ));
    lastIndex = match.end;
  }

  if (lastIndex < content.length) {
    contentSpans.add(TextSpan(text: content.substring(lastIndex)));
  }

  return Container(
    padding: const EdgeInsets.all(16),
    margin: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(
      color: bubbleColors[slideIndex % bubbleColors.length],
      borderRadius: BorderRadius.circular(12),
      boxShadow: const [
        BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
      ],
    ),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00568D)),
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 16, color: Colors.black87),
              children: contentSpans,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget buildInteractiveQuestion({
  required String question,
  required String type,
  required String correctAnswer,
  required String explanation,
  required int questionIndex,
  required List<String> selectedAnswers,
  required bool? isCorrect,
  required String? errorMessage,
  required ValueChanged<List<String>> onSelectionChanged,
  required ValueChanged<bool> onAnswerChanged,
}) {
  return _InteractiveQuestionWidget(
    question: question,
    type: type,
    correctAnswer: correctAnswer,
    explanation: explanation,
    questionIndex: questionIndex,
    selectedAnswers: selectedAnswers,
    isCorrect: isCorrect,
    errorMessage: errorMessage,
    onSelectionChanged: onSelectionChanged,
    onAnswerChanged: onAnswerChanged,
  );
}

class _InteractiveQuestionWidget extends StatefulWidget {
  final String question;
  final String type;
  final String correctAnswer;
  final String explanation;
  final int questionIndex;
  final List<String> selectedAnswers;
  final bool? isCorrect;
  final String? errorMessage;
  final ValueChanged<List<String>> onSelectionChanged;
  final ValueChanged<bool> onAnswerChanged;

  const _InteractiveQuestionWidget({
    required this.question,
    required this.type,
    required this.correctAnswer,
    required this.explanation,
    required this.questionIndex,
    required this.selectedAnswers,
    required this.isCorrect,
    required this.errorMessage,
    required this.onSelectionChanged,
    required this.onAnswerChanged,
  });

  @override
  _InteractiveQuestionWidgetState createState() => _InteractiveQuestionWidgetState();
}

class _InteractiveQuestionWidgetState extends State<_InteractiveQuestionWidget> {
  @override
  Widget build(BuildContext context) {
    List<String> options;
    bool isSingleSelection = widget.type == 'sentence_type';

    // Calculate the maximum number of selections allowed
    final int maxSelections = isSingleSelection
        ? 1
        : widget.correctAnswer.split(', ').length;

    // Split the question at the first period to separate the instruction from the sentence
    final questionParts = widget.question.split('.');
    String sentenceToAnalyze = widget.question; // Default to full question
    if (questionParts.length > 1) {
      sentenceToAnalyze = questionParts.sublist(1).join('.').trim();
    }

    if (widget.type == 'sentence_type') {
      options = ['declarative', 'interrogative', 'imperative', 'exclamatory'];
    } else {
      options = sentenceToAnalyze
          .replaceAll(RegExp(r'[^\w\s]'), '')
          .split(' ')
          .where((word) => word.isNotEmpty)
          .toList();

      // Group multi-word answers (e.g., "XYZ Corp")
      final correctAnswerParts = widget.correctAnswer.split(', ').map((e) => e.toLowerCase()).toList();
      final displayOptions = <String>[];
      int i = 0;
      while (i < options.length) {
        String word = options[i];
        bool foundMultiWord = false;
        for (String correctPart in correctAnswerParts) {
          if (correctPart.contains(' ')) {
            final parts = correctPart.split(' ');
            if (i + parts.length <= options.length) {
              final potentialPhrase = options.sublist(i, i + parts.length).join(' ').toLowerCase();
              if (potentialPhrase == correctPart) {
                displayOptions.add(options.sublist(i, i + parts.length).join(' '));
                i += parts.length;
                foundMultiWord = true;
                break;
              }
            }
          }
        }
        if (!foundMultiWord) {
          displayOptions.add(word);
          i++;
        }
      }
      options = displayOptions;
    }

    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 500),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.question,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: options.map((option) {
                final isSelected = widget.selectedAnswers.contains(option.toLowerCase());
                final isCorrectAnswer = widget.isCorrect == true &&
                    widget.correctAnswer.toLowerCase().split(', ').contains(option.toLowerCase());
                final isIncorrect = widget.isCorrect == false &&
                    isSelected &&
                    !widget.correctAnswer.toLowerCase().split(', ').contains(option.toLowerCase());

                return TextButton(
                  onPressed: () {
                    setState(() {
                      final newSelections = List<String>.from(widget.selectedAnswers);
                      final normalizedOption = option.toLowerCase();
                      if (isSingleSelection) {
                        newSelections.clear();
                        if (!isSelected) {
                          newSelections.add(normalizedOption);
                        }
                      } else {
                        if (newSelections.contains(normalizedOption)) {
                          newSelections.remove(normalizedOption);
                        } else if (newSelections.length < maxSelections) {
                          newSelections.add(normalizedOption);
                        } else {
                          // Optionally show a message to the user
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('You can only select up to $maxSelections answers.'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      }
                      print('newSelections: $newSelections, type: ${newSelections.runtimeType}');
                      widget.onSelectionChanged(newSelections);
                    });
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: isCorrectAnswer
                        ? Colors.green.withOpacity(0.3)
                        : isIncorrect
                            ? Colors.red.withOpacity(0.3)
                            : isSelected
                                ? Colors.blue.withOpacity(0.3)
                                : Colors.grey.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    option,
                    style: TextStyle(
                      color: isCorrectAnswer
                          ? Colors.green[900]
                          : isIncorrect
                              ? Colors.red[900]
                              : isSelected
                                  ? Colors.blue[900]
                                  : Colors.black87,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
            ),
            if (widget.isCorrect != null) ...[
              const SizedBox(height: 8),
              Text(
                widget.isCorrect! ? widget.explanation : widget.errorMessage ?? '',
                style: TextStyle(
                  fontSize: 12,
                  color: widget.isCorrect! ? Colors.green : Colors.red,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}