import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

final Logger _logger = Logger();

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
  required List<String> words,
  required List<String> correctAnswer,
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
    words: words,
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

Widget buildMCQQuestion({
  required String question,
  required List<String> options,
  required String correctAnswer,
  required String explanation,
  required int questionIndex,
  required List<String> selectedAnswers,
  required bool? isCorrect,
  required String? errorMessage,
  required ValueChanged<List<String>> onSelectionChanged,
  required ValueChanged<bool> onAnswerChanged,
}) {
  return buildInteractiveQuestion(
    question: question,
    type: 'mcq',
    words: options,
    correctAnswer: [correctAnswer],
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
  final List<String> words;
  final List<String> correctAnswer;
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
    required this.words,
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

class _InteractiveQuestionWidgetState extends State<_InteractiveQuestionWidget> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
      lowerBound: 0.97,
      upperBound: 1.03,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<String> options;
    bool isSingleSelection = widget.type == 'word_selection';

    final int maxSelections = isSingleSelection
        ? 1
        : widget.correctAnswer.length;

    if (widget.type == 'sentence_type') {
      options = ['declarative', 'interrogative', 'imperative', 'exclamatory'];
    } else {
      options = widget.words;
    }

    final normalizedCorrectAnswers = widget.correctAnswer.map((ans) => ans.toLowerCase()).toList();

    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 500),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          gradient: widget.isCorrect == true
              ? LinearGradient(
                  colors: [Colors.green[50]!, Colors.green[100]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : widget.isCorrect == false
                  ? LinearGradient(
                      colors: [Colors.red[50]!, Colors.red[100]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : LinearGradient(
                      colors: [Colors.blue[50]!, Colors.grey[50]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.isCorrect == true
                ? Colors.green.withOpacity(0.5)
                : widget.isCorrect == false
                    ? Colors.red.withOpacity(0.5)
                    : Colors.grey.withOpacity(0.2),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black12.withOpacity(0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.question,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF00568D),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10.0,
              runSpacing: 10.0,
              children: options.map((option) {
                final normalizedOption = option.toLowerCase();
                final isSelected = widget.selectedAnswers.contains(normalizedOption);
                final isThisOptionCorrect = normalizedCorrectAnswers.contains(normalizedOption);

                bool displayAsCorrect = widget.isCorrect == true && isSelected && isThisOptionCorrect;
                bool displayAsIncorrect = widget.isCorrect == false && isSelected && !isThisOptionCorrect;

                return ScaleTransition(
                  scale: isSelected ? _pulseController : AlwaysStoppedAnimation(1.0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      gradient: displayAsCorrect
                          ? LinearGradient(colors: [Colors.green[200]!, Colors.green[50]!])
                          : displayAsIncorrect
                              ? LinearGradient(colors: [Colors.red[200]!, Colors.red[50]!])
                              : isSelected
                                  ? LinearGradient(colors: [Colors.blue[100]!, Colors.blue[50]!])
                                  : null,
                      color: displayAsCorrect
                          ? Colors.green.withOpacity(0.18)
                          : displayAsIncorrect
                              ? Colors.red.withOpacity(0.18)
                              : isSelected
                                  ? Colors.blue.withOpacity(0.13)
                                  : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: displayAsCorrect
                            ? Colors.green
                            : displayAsIncorrect
                                ? Colors.red
                                : isSelected
                                    ? Colors.blue
                                    : Colors.grey[300]!,
                        width: displayAsCorrect || displayAsIncorrect ? 2 : 1,
                      ),
                      boxShadow: [
                        if (isSelected)
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.10),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        splashColor: Colors.blueAccent.withOpacity(0.18),
                        onTap: () {
                          setState(() {
                            final newSelections = List<String>.from(widget.selectedAnswers);
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
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('You can only select up to $maxSelections answer(s).'),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            }
                            _logger.d('Question ${widget.questionIndex}: newSelections=$newSelections');
                            widget.onSelectionChanged(newSelections);

                            bool allSelectedAreCorrect = newSelections.every((sel) => normalizedCorrectAnswers.contains(sel));
                            bool allCorrectAreSelected = normalizedCorrectAnswers.every((correct) => newSelections.contains(correct));
                            bool currentOverallCorrectness = newSelections.isNotEmpty && allSelectedAreCorrect && allCorrectAreSelected && newSelections.length == normalizedCorrectAnswers.length;

                            widget.onAnswerChanged(currentOverallCorrectness);
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                child: isSelected
                                    ? Icon(Icons.check_circle, color: Colors.blue[700], size: 20, key: ValueKey(true))
                                    : Icon(Icons.circle_outlined, color: Colors.grey[400], size: 20, key: ValueKey(false)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  option,
                                  style: TextStyle(
                                    color: displayAsCorrect
                                        ? Colors.green[900]
                                        : displayAsIncorrect
                                            ? Colors.red[900]
                                            : isSelected
                                                ? Colors.blue[900]
                                                : Colors.black87,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            if (widget.isCorrect != null) ...[
              const SizedBox(height: 12),
              AnimatedOpacity(
                opacity: 1.0,
                duration: const Duration(milliseconds: 400),
                child: Row(
                  children: [
                    Icon(
                      widget.isCorrect! ? Icons.celebration : Icons.error_outline,
                      color: widget.isCorrect! ? Colors.green : Colors.red,
                      size: 24,
                    ),
                    if (widget.isCorrect!)
                      const Padding(
                        padding: EdgeInsets.only(left: 4.0),
                        child: Text('🎉', style: TextStyle(fontSize: 22)),
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.isCorrect! ? widget.explanation : (widget.errorMessage ?? 'Please try again.'),
                        style: TextStyle(
                          fontSize: 14,
                          color: widget.isCorrect! ? Colors.green[800] : Colors.red[800],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}