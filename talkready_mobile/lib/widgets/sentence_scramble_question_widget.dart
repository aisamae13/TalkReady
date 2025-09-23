// lib/lessons/sentence_scramble_question_widget.dart
import 'package:flutter/material.dart';

class SentenceScrambleQuestionWidget extends StatefulWidget {
  final Map<String, dynamic> questionData;
  final List<String> currentOrder;
  final bool showResults;
  final ValueChanged<List<String>> onOrderChanged;

  const SentenceScrambleQuestionWidget({
    super.key,
    required this.questionData,
    required this.currentOrder,
    required this.showResults,
    required this.onOrderChanged,
  });

  @override
  State<SentenceScrambleQuestionWidget> createState() =>
      _SentenceScrambleQuestionWidgetState();
}

class _SentenceScrambleQuestionWidgetState
    extends State<SentenceScrambleQuestionWidget> {
  late List<String> _parts;

  @override
  void initState() {
    super.initState();
    _parts = List<String>.from(widget.currentOrder);
  }

  @override
  void didUpdateWidget(covariant SentenceScrambleQuestionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentOrder != oldWidget.currentOrder) {
      _parts = List<String>.from(widget.currentOrder);
    }
  }

  @override
  Widget build(BuildContext context) {
    final correctOrder = List<String>.from(
      widget.questionData['correctOrder'] ?? [],
    );
    bool? isCorrect;
    if (widget.showResults) {
      isCorrect =
          correctOrder.length == _parts.length &&
          List.generate(
            _parts.length,
            (i) => _parts[i] == correctOrder[i],
          ).every((b) => b);
    }

    return Column(
      children: [
        Text(
          widget.questionData['instruction'] as String? ??
              'Arrange the sentence.',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isCorrect == true
                ? Colors.green.shade50
                : isCorrect == false
                ? Colors.red.shade50
                : Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isCorrect == true
                  ? Colors.green
                  : isCorrect == false
                  ? Colors.red
                  : Colors.blue.shade200,
              width: 2,
            ),
          ),
          child: ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            onReorder: (oldIndex, newIndex) {
              if (widget.showResults) return;
              setState(() {
                if (newIndex > oldIndex) newIndex -= 1;
                final item = _parts.removeAt(oldIndex);
                _parts.insert(newIndex, item);
                widget.onOrderChanged(_parts);
              });
            },
            children: _parts.map((part) {
              return Card(
                key: ValueKey(part),
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text(part, textAlign: TextAlign.center),
                  leading: widget.showResults
                      ? null
                      : const Icon(Icons.drag_handle),
                ),
              );
            }).toList(),
          ),
        ),
        if (widget.showResults && isCorrect == false)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Text(
              'Correct Answer: ${correctOrder.join(' ')}',
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
