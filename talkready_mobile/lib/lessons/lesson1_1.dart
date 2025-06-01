// In lesson1_1.dart

import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart'; // Keep if study slides are here
import 'package:youtube_player_flutter/youtube_player_flutter.dart'; // Keep for video
import 'package:logger/logger.dart';
import '../lessons/common_widgets.dart'; // For buildSlide, if still used

// Timer might be managed in module1.dart and just displayed here, or still managed here
import 'dart:async';

class buildLesson1_1 extends StatefulWidget {
  // Props for study material part (can remain similar)
  final BuildContext context; // Not typically needed as a direct prop
  final int currentSlide;
  final CarouselSliderController carouselController;
  final YoutubePlayerController youtubeController;
  final bool showActivity; // Controlled by Module1Page
  final VoidCallback onShowActivity; // Callback to Module1Page
  final Function(int) onSlideChanged; // For study material carousel

  // Props for activity part (NEW/MODIFIED)
  final Map<String, dynamic>? currentQuestionData; // Single question to display
  final String? selectedAnswerForCurrentQuestion;
  final bool isFlagged;
  final bool? showResultsForCurrentQuestion; // null, true, or false
  final String? errorMessageForCurrentQuestion;
  final int questionIndex; // 0-based index of the current question
  final int totalQuestions;
  final Function(String questionId, String selectedOption) onOptionSelected;
  final Function(String questionId) onToggleFlag;
  final VoidCallback onPreviousQuestion;
  final VoidCallback onNextQuestion;
  final VoidCallback onSubmitAnswersFromLesson; // Simplified submission trigger
  final bool isSubmitting; // To disable buttons during submission
  final bool isFirstQuestion;
  final bool isLastQuestion;
  final int secondsElapsed; // For displaying timer

  // initialAttemptNumber might still be useful for display "Attempt X" in activity UI
  final int initialAttemptNumber;

  const buildLesson1_1({
    super.key,
    required this.context,
    required this.currentSlide,
    required this.carouselController,
    required this.youtubeController,
    required this.showActivity,
    required this.onShowActivity,
    required this.onSlideChanged,
    // Activity Props
    this.currentQuestionData, // Nullable if no questions or activity not started
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

    // These are no longer directly needed by lesson1_1 if Module1Page handles all answer state
    // required this.selectedAnswers, // This was List<List<String>> for old format
    // required this.isCorrectStates,
    // required this.errorMessages,
    // required this.onAnswerChanged, // Replaced by onOptionSelected
    // required this.onSubmitAnswers, // Replaced by onSubmitAnswersFromLesson
    // required this.onWordsSelected, // For old format
  });

  @override
  _Lesson1_1State createState() => _Lesson1_1State();
}

class _Lesson1_1State extends State<buildLesson1_1> {
  final Logger _logger = Logger();
  bool _videoFinished = false; // For enabling "Proceed to Activity"

  // Timer logic might still reside here if it's started when activity becomes visible,
  // or could be fully managed by module1.dart.
  // For now, let's assume secondsElapsed is passed for display.
  // If lesson1_1 starts/stops its own timer, it would need Timer _timer;
  // and its own _startTimer, _stopTimer, _resetTimer.

  @override
  void initState() {
    super.initState();
    // Listener for video finished (if this widget still handles the video directly)
    widget.youtubeController.addListener(_videoListener);
    // If timer is managed here:
    // if (widget.showActivity) { _startTimer(); }
  }

  @override
  void didUpdateWidget(covariant buildLesson1_1 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.youtubeController != oldWidget.youtubeController) {
      oldWidget.youtubeController.removeListener(_videoListener);
      widget.youtubeController.addListener(_videoListener);
    }
    // If timer is managed here:
    // if (widget.showActivity && !oldWidget.showActivity) { /* _resetTimer(); _startTimer(); */ }
    // else if (!widget.showActivity && oldWidget.showActivity) { /* _stopTimer(); */ }
  }

  @override
  void dispose() {
    widget.youtubeController.removeListener(_videoListener);
    // If timer is managed here: /* _stopTimer(); */
    super.dispose();
  }

  void _videoListener() {
    if (widget.youtubeController.value.playerState == PlayerState.ended &&
        !_videoFinished) {
      if (mounted) {
        setState(() {
          _videoFinished = true;
        });
      }
      _logger.i('Video finished in Lesson 1.1 (New Structure)');
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
    Color borderColor = Colors.grey;
    Widget? trailingIcon;

    if (widget.showResultsForCurrentQuestion != null) {
      // Results are active
      bool isCorrectAnswer =
          widget.currentQuestionData!['correctAnswer'] == optionText;
      if (isSelected) {
        tileColor = widget.showResultsForCurrentQuestion == true
            ? Colors.green.shade100
            : Colors.red.shade100;
        borderColor = widget.showResultsForCurrentQuestion == true
            ? Colors.green
            : Colors.red;
        trailingIcon = Icon(
          widget.showResultsForCurrentQuestion == true
              ? Icons.check_circle
              : Icons.cancel,
          color: widget.showResultsForCurrentQuestion == true
              ? Colors.green
              : Colors.red,
        );
      } else if (isCorrectAnswer) {
        // Highlight correct answer if not selected
        borderColor = Colors.green;
        // Optionally, add a subtle hint that this was the correct one
        trailingIcon =
            const Icon(Icons.check_circle_outline, color: Colors.green);
      }
    }

    return Card(
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: borderColor, width: isSelected ? 2 : 1),
      ),
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: RadioListTile<String>(
        title: Text(optionText),
        value: optionText,
        groupValue: widget.selectedAnswerForCurrentQuestion,
        onChanged: (widget.showResultsForCurrentQuestion !=
                null) // Disable if results are shown
            ? null
            : (String? value) {
                if (value != null) {
                  widget.onOptionSelected(questionId, value);
                }
              },
        activeColor: Theme.of(context).primaryColor,
        tileColor: tileColor,
        secondary: trailingIcon, // Shows check or cross after results
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Study Material Section (Similar to before) ---
        if (!widget.showActivity) ...[
          const Text(
            'Lesson 1.1: Pronouns and Nouns', // This title can also come from fetched data via module1.dart
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00568D)),
          ),
          const SizedBox(height: 16),
          // Carousel for study slides (if lesson1_1 still manages its own slides passed by module1)
          // Or, module1.dart passes only the current lesson's study content directly.
          // For now, assuming common_widgets.buildSlide is still used if slides are part of _currentLessonData.
          // If _currentLessonData contains a 'slides' list:
          if (widget.currentQuestionData ==
                  null && // Example condition: show slides if no activity question yet
              _Lesson1_1State_StaticData
                  .slides.isNotEmpty) // Using placeholder static data for now
            CarouselSlider(
              items: _Lesson1_1State_StaticData.slides
                  .asMap()
                  .entries
                  .map((entry) {
                return buildSlide(
                  // From common_widgets.dart
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
          // Dots for carousel
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children:
                _Lesson1_1State_StaticData.slides.asMap().entries.map((entry) {
              // Using placeholder
              return GestureDetector(
                onTap: () => widget.carouselController.animateToPage(entry.key),
                child: Container(
                  width: 8.0,
                  height: 8.0,
                  margin: const EdgeInsets.symmetric(
                      vertical: 10.0, horizontal: 2.0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Color(0xFF00568D))
                        .withOpacity(
                            widget.currentSlide == entry.key ? 0.9 : 0.4),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // Video player (if lesson1_1 still manages its own video section)
          if (widget.youtubeController.initialVideoId.isNotEmpty) ...[
            // Check if videoId is valid
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

        // --- Activity Section (NEW STRUCTURE) ---
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
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Card(
            elevation: 3,
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
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                            widget.isFlagged ? Icons.flag : Icons.flag_outlined,
                            color:
                                widget.isFlagged ? Colors.orange : Colors.grey),
                        tooltip: widget.isFlagged
                            ? "Unflag Question"
                            : "Flag Question",
                        onPressed: widget.showResultsForCurrentQuestion !=
                                null // Disable if results shown
                            ? null
                            : () => widget.onToggleFlag(
                                widget.currentQuestionData!['id'].toString()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.currentQuestionData!['text'] ?? // Use 'text'
                        widget.currentQuestionData!['promptText'] ??
                        'Question text not available.',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 16),
                  if (widget.currentQuestionData!['options'] is List)
                    ...(widget.currentQuestionData!['options'] as List<dynamic>)
                        .map((option) {
                      final optionText = option.toString();
                      return _buildMCQOption(optionText,
                          widget.currentQuestionData!['id'].toString());
                    }).toList(),
                  if (widget.errorMessageForCurrentQuestion != null &&
                      widget.showResultsForCurrentQuestion == false)
                    Padding(
                      padding: const EdgeInsets.only(top: 10.0),
                      child: Text(
                        "Incorrect. ${widget.errorMessageForCurrentQuestion!}",
                        style: const TextStyle(color: Colors.red, fontSize: 14),
                      ),
                    ),
                  if (widget.showResultsForCurrentQuestion == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 10.0),
                      child: Text(
                        "Correct! ${widget.currentQuestionData!['explanation'] ?? ''}",
                        style: const TextStyle(
                            color: Colors.green,
                            fontSize: 14,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Navigation and Submit Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton(
                onPressed: widget.isFirstQuestion ||
                        widget.showResultsForCurrentQuestion != null
                    ? null
                    : widget.onPreviousQuestion,
                child: const Text('Previous'),
              ),
              if (widget.isLastQuestion &&
                  widget.showResultsForCurrentQuestion == null)
                ElevatedButton(
                  onPressed: widget.isSubmitting
                      ? null
                      : widget.onSubmitAnswersFromLesson,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white),
                  child: widget.isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white)))
                      : const Text('Submit All'),
                )
              else if (!widget.isLastQuestion &&
                  widget.showResultsForCurrentQuestion == null)
                ElevatedButton(
                  onPressed: widget.onNextQuestion,
                  child: const Text('Next'),
                ),
            ],
          ),
          if (widget.showResultsForCurrentQuestion != null &&
              widget
                  .isLastQuestion) // Show "Try Again" or "Next Lesson" options from module1
            const SizedBox(
                height:
                    20), // Placeholder for module1's buttons (Try Again / Next Lesson)
        ],
        if (widget.showActivity &&
            widget.currentQuestionData == null &&
            widget.totalQuestions > 0)
          const Center(child: Text("Loading question...")),
        if (widget.showActivity && widget.totalQuestions == 0)
          const Center(
              child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text("No questions available for this activity yet.",
                style: TextStyle(fontSize: 16, color: Colors.orange)),
          )),
      ],
    );
  }
}

// Placeholder for static slide data if you still want to have some fallback or default study material
// In a real scenario, this would also be fetched from _currentLessonData in module1.dart
class _Lesson1_1State_StaticData {
  static final List<Map<String, String>> slides = [
    {
      'title': 'Objective: Understanding Pronouns and Nouns',
      'content':
          'In this lesson, you will learn to identify pronouns and nouns...',
    },
    // ... other slides
  ];
}
