// In lesson1_2.dart

import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:logger/logger.dart';
import '../lessons/common_widgets.dart'; // For buildSlide

class buildLesson1_2 extends StatefulWidget {
  // Props for study material part
  final int currentSlide;
  final CarouselSliderController carouselController;
  final YoutubePlayerController youtubeController;
  final bool showActivity;
  final VoidCallback onShowActivity;
  final Function(int) onSlideChanged;

  // Props for MCQ activity part
  final Map<String, dynamic>? currentQuestionData;
  final String? selectedAnswerForCurrentQuestion;
  final bool isFlagged;
  final bool? showResultsForCurrentQuestion;
  final String? errorMessageForCurrentQuestion;
  final int questionIndex;
  final int totalQuestions;
  final Function(String questionId, String selectedOption) onOptionSelected;
  final Function(String questionId) onToggleFlag;
  final VoidCallback onPreviousQuestion;
  final VoidCallback onNextQuestion;
  final VoidCallback onSubmitAnswersFromLesson;
  final bool isSubmitting;
  final bool isFirstQuestion;
  final bool isLastQuestion;
  final int secondsElapsed;
  final int initialAttemptNumber;

  const buildLesson1_2({
    super.key,
    required this.currentSlide,
    required this.carouselController,
    required this.youtubeController,
    required this.showActivity,
    required this.onShowActivity,
    required this.onSlideChanged,
    // Activity Props
    this.currentQuestionData,
    this.selectedAnswerForCurrentQuestion,
    required this.isFlagged,
    this.showResultsForCurrentQuestion,
    this.errorMessageForCurrentQuestion,
    required this.questionIndex,
    required this.totalQuestions,
    required this.onOptionSelected,
    required this.onToggleFlag,
    required this.onPreviousQuestion,
    required this.onNextQuestion,
    required this.onSubmitAnswersFromLesson,
    required this.isSubmitting,
    required this.isFirstQuestion,
    required this.isLastQuestion,
    required this.secondsElapsed,
    required this.initialAttemptNumber,
  });

  @override
  _Lesson1_2State createState() => _Lesson1_2State();
}

class _Lesson1_2State extends State<buildLesson1_2> {
  final Logger _logger = Logger();
  bool _videoFinished = false;

  // Hardcoded study slides for Lesson 1.2 (as per your original lesson1_2.dart)
  // Ideally, this also comes from _currentLessonData in module1.dart if structure allows
  final List<Map<String, String>> _studySlides = [
    {
      'title': 'Objective: Mastering Simple Sentences',
      'content':
          'By the end of this lesson, you will be able to form simple sentences correctly and identify sentence types in call center scenarios.',
    },
    {
      'title': 'Introduction to Simple Sentences',
      'content':
          'Simple sentences contain one independent clause (a subject and a verb). They are fundamental for clear communication in call centers.\n'
              'Structure: Subject + Verb + (Object/Complement)\n'
              'Example: "I help." (Subject: I, Verb: help)\n'
              'Example: "The customer needs assistance." (Subject: The customer, Verb: needs, Object: assistance)',
    },
    {
      'title': 'Types of Simple Sentences',
      'content': '• Declarative: Makes a statement. Ends with a period (.).\n'
          '  Example: "The agent resolved the issue."\n'
          '• Interrogative: Asks a question. Ends with a question mark (?).\n'
          '  Example: "Can I help you?"\n'
          '• Imperative: Gives a command or makes a request. Ends with a period (.) or exclamation mark (!).\n'
          '  Example: "Please hold the line."\n'
          '• Exclamatory: Expresses strong emotion. Ends with an exclamation mark (!).\n'
          '  Example: "Thank you so much!"',
    },
    {
      'title': 'Call Center Examples',
      'content': '• Declarative: "Your account is updated."\n'
          '• Interrogative: "Do you have your account number?"\n'
          '• Imperative: "Please provide your name."\n'
          '• Exclamatory: "That’s great news!"\n'
          'Using varied sentence types makes conversations engaging.',
    },
    {
      'title': 'Conclusion',
      'content':
          'You learned to form simple sentences and identify their types. This skill is crucial for effective and professional communication in call centers. Practice using these sentence structures in your interactions.',
    },
  ];

  @override
  void initState() {
    super.initState();
    widget.youtubeController.addListener(_videoListener);
  }

  @override
  void didUpdateWidget(covariant buildLesson1_2 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.youtubeController != oldWidget.youtubeController) {
      oldWidget.youtubeController.removeListener(_videoListener);
      widget.youtubeController.addListener(_videoListener);
    }
    if (widget.showActivity && !oldWidget.showActivity) {
      _videoFinished = false;
    }
  }

  @override
  void dispose() {
    // Parent (module1.dart) now manages the main YouTube controller's listener lifecycle
    super.dispose();
  }

  void _videoListener() {
    if (!mounted) return;
    if (widget.youtubeController.value.playerState == PlayerState.ended &&
        !_videoFinished) {
      setState(() {
        _videoFinished = true;
      });
      _logger.i('Video finished in Lesson 1.2 (Refactored)');
    }
  }

  String _formatDuration(int totalSeconds) {
    final duration = Duration(seconds: totalSeconds);
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Widget _buildMCQOption(String optionText, String questionId) {
    bool isSelected = widget.selectedAnswerForCurrentQuestion == optionText;
    Color? tileColor;
    Color borderColor = Colors.grey.shade300;
    Widget? trailingIcon;
    FontWeight titleFontWeight = FontWeight.normal;

    if (widget.showResultsForCurrentQuestion != null) {
      // Results are active
      bool isCorrectAnswerFromData =
          widget.currentQuestionData!['correctAnswer'] == optionText;

      if (isSelected) {
        // User selected this option
        if (widget.showResultsForCurrentQuestion == true) {
          // And it was correct
          tileColor = Colors.green.shade50;
          borderColor = Colors.green.shade400;
          trailingIcon = const Icon(Icons.check_circle, color: Colors.green);
          titleFontWeight = FontWeight.bold;
        } else {
          // And it was incorrect
          tileColor = Colors.red.shade50;
          borderColor = Colors.red.shade400;
          trailingIcon = const Icon(Icons.cancel, color: Colors.red);
          titleFontWeight = FontWeight.normal;
        }
      } else if (isCorrectAnswerFromData) {
        // This option was correct, but user didn't select it
        borderColor = Colors.green.shade300;
        titleFontWeight = FontWeight.bold;
      }
    }

    return Card(
      elevation:
          isSelected && widget.showResultsForCurrentQuestion == null ? 3 : 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
            color: borderColor,
            width: isSelected && widget.showResultsForCurrentQuestion == null
                ? 2
                : 1.5),
      ),
      margin: const EdgeInsets.symmetric(vertical: 5.0),
      child: RadioListTile<String>(
        title: Text(optionText,
            style: TextStyle(fontWeight: titleFontWeight, fontSize: 16)),
        value: optionText,
        groupValue: widget.selectedAnswerForCurrentQuestion,
        onChanged: (widget.showResultsForCurrentQuestion != null ||
                widget.isSubmitting)
            ? null
            : (String? value) {
                if (value != null) {
                  widget.onOptionSelected(questionId, value);
                }
              },
        activeColor: Theme.of(context).primaryColor,
        tileColor: tileColor,
        controlAffinity: ListTileControlAffinity.trailing,
        secondary: trailingIcon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> slidesToShow = _studySlides;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Study Material Section ---
        if (!widget.showActivity) ...[
          Text(
            (widget.currentQuestionData?['parentLessonTitle'] as String?) ??
                'Lesson 1.2: Simple Sentences',
            style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00568D)),
          ),
          const SizedBox(height: 16),
          if (slidesToShow.isNotEmpty) ...[
            CarouselSlider(
              items: slidesToShow.asMap().entries.map((entry) {
                return buildSlide(
                  title: entry.value['title']!,
                  content: entry.value['content']!,
                  slideIndex: entry.key,
                );
              }).toList(),
              carouselController: widget.carouselController,
              options: CarouselOptions(
                height: 300.0,
                enlargeCenterPage: true,
                enableInfiniteScroll: false,
                initialPage: widget.currentSlide,
                onPageChanged: (index, reason) => widget.onSlideChanged(index),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: slidesToShow.asMap().entries.map((entry) {
                return GestureDetector(
                  onTap: () =>
                      widget.carouselController.animateToPage(entry.key),
                  child: Container(
                    width: 8.0,
                    height: 8.0,
                    margin: const EdgeInsets.symmetric(
                        vertical: 10.0, horizontal: 2.0),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : const Color(0xFF00568D))
                          .withOpacity(
                              widget.currentSlide == entry.key ? 0.9 : 0.4),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 16),
          if (widget.youtubeController.initialVideoId.isNotEmpty) ...[
            const Text('Watch the Video',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00568D))),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: YoutubePlayer(
                  controller: widget.youtubeController,
                  showVideoProgressIndicator: true),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _videoFinished ? widget.onShowActivity : null,
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00568D),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[400]),
                child: const Text('Proceed to Activity'),
              ),
            ),
            if (!_videoFinished)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text('Please watch the video to the end to proceed.',
                    style: TextStyle(color: Colors.red, fontSize: 14),
                    textAlign: TextAlign.center),
              ),
          ],
        ],

        // --- MCQ Activity Section ---
        if (widget.showActivity && widget.currentQuestionData != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Attempt: ${widget.initialAttemptNumber + 1}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500)),
                Text('Time: ${_formatDuration(widget.secondsElapsed)}',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: widget.secondsElapsed < 60
                            ? Colors.red.shade700
                            : Colors.black54)),
              ],
            ),
          ),
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.symmetric(vertical: 10.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Question ${widget.questionIndex + 1} of ${widget.totalQuestions}',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColorDark),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                            widget.isFlagged ? Icons.flag : Icons.flag_outlined,
                            color: widget.isFlagged
                                ? Colors.amber.shade700
                                : Colors.grey.shade600,
                            size: 26),
                        tooltip: widget.isFlagged
                            ? "Unflag Question"
                            : "Flag Question for Review",
                        onPressed: (widget.showResultsForCurrentQuestion !=
                                    null ||
                                widget.isSubmitting)
                            ? null
                            : () => widget.onToggleFlag(
                                widget.currentQuestionData!['id'].toString()),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Text(
                    widget.currentQuestionData!['promptText'] ??
                        'Question text not available.',
                    style: const TextStyle(
                        fontSize: 18,
                        height: 1.4,
                        fontWeight: FontWeight.normal),
                  ),
                  const SizedBox(height: 20),
                  if (widget.currentQuestionData!['options'] is List)
                    ...(widget.currentQuestionData!['options'] as List<dynamic>)
                        .map((option) {
                      final optionText = option.toString();
                      return _buildMCQOption(optionText,
                          widget.currentQuestionData!['id'].toString());
                    }).toList(),
                  if (widget.showResultsForCurrentQuestion != null &&
                      widget.errorMessageForCurrentQuestion != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: widget.showResultsForCurrentQuestion == true
                                ? Colors.green.shade50
                                : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color:
                                    widget.showResultsForCurrentQuestion == true
                                        ? Colors.green.shade300
                                        : Colors.red.shade300)),
                        child: Text(
                          widget.errorMessageForCurrentQuestion!,
                          style: TextStyle(
                            color: widget.showResultsForCurrentQuestion == true
                                ? Colors.green.shade800
                                : Colors.red.shade800,
                            fontSize: 14.5,
                            fontWeight:
                                widget.showResultsForCurrentQuestion == true
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.arrow_back_ios, size: 16),
                label: const Text('Previous'),
                onPressed: widget.isFirstQuestion || widget.isSubmitting
                    ? null
                    : widget.onPreviousQuestion,
              ),
              if (widget.isLastQuestion &&
                  widget.showResultsForCurrentQuestion == null)
                ElevatedButton.icon(
                  icon: widget.isSubmitting
                      ? const SizedBox.shrink()
                      : const Icon(Icons.check_circle_outline),
                  label: widget.isSubmitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white)))
                      : const Text('Submit All'),
                  onPressed: widget.isSubmitting
                      ? null
                      : widget.onSubmitAnswersFromLesson,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white),
                )
              else if (!widget.isLastQuestion &&
                  widget.showResultsForCurrentQuestion == null)
                ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_forward_ios, size: 16),
                  label: const Text('Next'),
                  onPressed: widget.isSubmitting ? null : widget.onNextQuestion,
                ),
            ],
          ),
        ],
        if (widget.showActivity &&
            widget.currentQuestionData == null &&
            widget.totalQuestions > 0)
          const Center(
              child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text("Loading question..."))),
        if (widget.showActivity &&
            widget.totalQuestions == 0 &&
            widget.currentQuestionData == null)
          const Center(
              child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text("No questions available for this activity.",
                      style: TextStyle(fontSize: 16, color: Colors.orange)))),
      ],
    );
  }
}
