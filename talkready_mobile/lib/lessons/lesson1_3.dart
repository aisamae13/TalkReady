// In lesson1_3.dart

import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:logger/logger.dart';
import '../lessons/common_widgets.dart'; // For buildSlide

class buildLesson1_3 extends StatefulWidget {
  // Props for study material part
  final int currentSlide;
  final CarouselSliderController carouselController;
  final YoutubePlayerController youtubeController;
  final bool showActivity;
  final VoidCallback onShowActivity;
  final Function(int) onSlideChanged;
  final List<Map<String, String>>? studySlides; // Dynamic slides from module1
  final String? lessonTitle; // Dynamic lesson title from module1

  // Props for MCQ activity part (similar to lesson1_1.dart and lesson1_2.dart)
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

  const buildLesson1_3({
    super.key,
    required this.currentSlide,
    required this.carouselController,
    required this.youtubeController,
    required this.showActivity,
    required this.onShowActivity,
    required this.onSlideChanged,
    this.studySlides,
    this.lessonTitle,
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
  _Lesson1_3State createState() => _Lesson1_3State();
}

class _Lesson1_3State extends State<buildLesson1_3> {
  final Logger _logger = Logger();
  bool _videoFinished = false;

  // Hardcoded study slides are removed. Data should come from widget.studySlides.

  @override
  void initState() {
    super.initState();
    widget.youtubeController.addListener(_videoListener);
  }

  @override
  void didUpdateWidget(covariant buildLesson1_3 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.youtubeController != oldWidget.youtubeController) {
      oldWidget.youtubeController.removeListener(_videoListener);
      widget.youtubeController.addListener(_videoListener);
    }
    if (widget.showActivity && !oldWidget.showActivity) {
      // Reset video finished state if activity is shown again (e.g. after try again)
      _videoFinished = false;
    }
  }

  @override
  void dispose() {
    // Parent (module1.dart) now manages the main YouTube controller's listener lifecycle
    // So, no need to remove listener here if module1 does it for the controller it passes.
    // However, if this widget's specific listener logic is an issue, it can be removed.
    // For now, assuming module1 handles the main controller. If issues, uncomment:
    // widget.youtubeController.removeListener(_videoListener);
    super.dispose();
  }

  void _videoListener() {
    if (!mounted) return;
    if (widget.youtubeController.value.playerState == PlayerState.ended &&
        !_videoFinished) {
      setState(() {
        _videoFinished = true;
      });
      _logger.i('Video finished in Lesson 1.3 (MCQ Version)');
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
          titleFontWeight =
              FontWeight.normal; // Keep normal for incorrect selected
        }
      } else if (isCorrectAnswerFromData) {
        // This option was correct, but user didn't select it
        borderColor =
            Colors.green.shade300; // Highlight border of correct answer
        titleFontWeight = FontWeight.bold; // Make correct answer text bold
        // Optionally, add a more subtle hint that this was the correct one
        trailingIcon =
            Icon(Icons.check_circle_outline, color: Colors.green.shade600);
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
            ? null // Disable if results are shown or submitting
            : (String? value) {
                if (value != null) {
                  widget.onOptionSelected(questionId, value);
                }
              },
        activeColor: Theme.of(context).primaryColor,
        tileColor: tileColor,
        controlAffinity:
            ListTileControlAffinity.trailing, // Radio button to the right
        secondary: trailingIcon, // Shows check/cross or hint after results
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> slidesToDisplay = widget.studySlides ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Study Material Section ---
        if (!widget.showActivity) ...[
          Text(
            widget.lessonTitle ??
                'Lesson 1.3: Present Simple Tense', // Default title
            style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00568D)),
          ),
          const SizedBox(height: 16),
          if (slidesToDisplay.isNotEmpty) ...[
            CarouselSlider(
              items: slidesToDisplay.asMap().entries.map((entry) {
                return buildSlide(
                  title: entry.value['title']!,
                  content: entry.value['content']!,
                  slideIndex: entry.key,
                );
              }).toList(),
              carouselController: widget.carouselController,
              options: CarouselOptions(
                height: 300.0, // Adjust as needed
                enlargeCenterPage: true,
                enableInfiniteScroll: false,
                initialPage: widget.currentSlide,
                onPageChanged: (index, reason) => widget.onSlideChanged(index),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: slidesToDisplay.asMap().entries.map((entry) {
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
          // Video player
          if (widget.youtubeController.initialVideoId.isNotEmpty) ...[
            const Text('Watch the Video',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00568D))),
            const SizedBox(height: 8),
            SizedBox(
              height: 200, // Adjust as needed
              child: YoutubePlayer(
                controller: widget.youtubeController,
                showVideoProgressIndicator: true,
              ),
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
          ] else if (slidesToDisplay
              .isEmpty) // If no slides and no video, allow proceeding
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.onShowActivity,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00568D),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Proceed to Activity'),
              ),
            ),
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
                        color: widget.secondsElapsed < 60 &&
                                widget.secondsElapsed >
                                    0 // Example styling for timer
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
                            ? null // Disable if results shown or submitting
                            : () => widget.onToggleFlag(
                                widget.currentQuestionData!['id'].toString()),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  // Use 'promptText' from Firestore for MCQ question text
                  Text(
                    widget.currentQuestionData!['promptText'] ??
                        'Question text not available.',
                    style: const TextStyle(
                        fontSize: 18,
                        height: 1.4, // Line height
                        fontWeight: FontWeight.normal),
                  ),
                  const SizedBox(height: 20),
                  // Build MCQ options from currentQuestionData
                  if (widget.currentQuestionData!['options'] is List)
                    ...(widget.currentQuestionData!['options'] as List<dynamic>)
                        .map((option) {
                      final optionText = option.toString();
                      return _buildMCQOption(optionText,
                          widget.currentQuestionData!['id'].toString());
                    }).toList(),

                  // Display feedback message if results are shown
                  if (widget.showResultsForCurrentQuestion != null &&
                      widget.errorMessageForCurrentQuestion != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: widget.showResultsForCurrentQuestion == true
                                ? Colors
                                    .green.shade50 // Correct answer background
                                : Colors
                                    .red.shade50, // Incorrect answer background
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
                                ? Colors.green.shade800 // Correct text color
                                : Colors.red.shade800, // Incorrect text color
                            fontSize: 14.5,
                            fontWeight:
                                widget.showResultsForCurrentQuestion == true
                                    ? FontWeight.w600 // Bold for correct
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
          // Navigation and Submit Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.arrow_back_ios, size: 16),
                label: const Text('Previous'),
                onPressed: widget.isFirstQuestion ||
                        widget.isSubmitting ||
                        widget.showResultsForCurrentQuestion != null
                    ? null // Disable if first, submitting, or results shown
                    : widget.onPreviousQuestion,
              ),
              if (widget.isLastQuestion &&
                  widget.showResultsForCurrentQuestion == null)
                ElevatedButton.icon(
                  icon: widget.isSubmitting
                      ? const SizedBox.shrink() // No icon when submitting
                      : const Icon(Icons.check_circle_outline),
                  label: widget.isSubmitting
                      ? const SizedBox(
                          // Show progress indicator when submitting
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

        // Loading and No Questions States
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
