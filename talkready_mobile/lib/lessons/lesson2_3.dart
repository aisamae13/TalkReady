// lesson2_3.dart

import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:logger/logger.dart';
import '../lessons/common_widgets.dart'; // For buildSlide and HtmlFormattedText
import 'dart:async';
import '../widgets//parsed_feedback_card.dart';

// import '../firebase_service.dart'; // Not strictly needed for fully hardcoded content

class buildLesson2_3 extends StatefulWidget {
  final BuildContext parentContext;
  final int currentSlide;
  final CarouselSliderController carouselController;
  final YoutubePlayerController youtubeController;
  final Key? youtubePlayerKey;
  final bool showActivitySection;
  final VoidCallback onShowActivitySection;

  final Function(
    Map<String, String> userScenarioAnswers,
    int timeSpent,
    int attemptNumberForSubmission,
  ) onSubmitAnswers;

  final Function(int) onSlideChanged;
  final int initialAttemptNumber;

  final bool displayFeedback;
  final Map<String, dynamic>? aiFeedbackData;
  final int? overallAIScoreForDisplay;
  final int? maxPossibleAIScoreForDisplay;

  const buildLesson2_3({
    super.key,
    required this.parentContext,
    required this.currentSlide,
    required this.carouselController,
    required this.youtubeController,
    required this.showActivitySection,
    required this.onShowActivitySection,
    required this.onSubmitAnswers,
    required this.onSlideChanged,
    required this.initialAttemptNumber,
    required this.displayFeedback,
    this.youtubePlayerKey,
    this.aiFeedbackData,
    this.overallAIScoreForDisplay,
    this.maxPossibleAIScoreForDisplay,
  });

  @override
  _Lesson2_3State createState() => _Lesson2_3State();
}

class _Lesson2_3State extends State<buildLesson2_3> {
  final Logger _logger = Logger();

  bool _videoFinished = false;
  bool _isSubmitting = false;
  Timer? _timer;
  int _secondsElapsed = 0;
  late int _currentAttemptForDisplay;

  bool _isLoadingLessonContent = true;
  Map<String, dynamic>? _lessonData;
  List<dynamic> _activityPrompts = [];
  late Map<String, TextEditingController> _textControllers;

  // Fallback static slides if main hardcoded data fails (less likely now but good practice)
  final List<Map<String, dynamic>> _staticSlidesDataFallback = [
    {
      'title': 'Objective: Numbers and Dates (Fallback)',
      'content':
          'Learn to correctly say and understand numbers, dates, and prices.',
    },
    {
      'title': 'Conclusion (Fallback)',
      'content':
          'Accurate use of numbers, dates, and times prevents errors. Practice them.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _currentAttemptForDisplay = widget.initialAttemptNumber + 1;
    _textControllers = {};
    _fetchLessonContentAndInitialize();
    widget.youtubeController.addListener(_videoListener);

    if (widget.showActivitySection && !widget.displayFeedback) {
      _startTimer();
    }
  }

  Future<void> _fetchLessonContentAndInitialize() async {
    if (!mounted) return;
    setState(() {
      _isLoadingLessonContent = true;
    });

    // ---- START HARDCODED LESSON 2.3 DATA ----
    final Map<String, dynamic> hardcodedLesson2_3Data = {
      'lessonTitle': 'Lesson 2.3: Numbers and Dates (HC)',
      'slides': [
        {
          'title': 'Objective',
          'content':
              'To help learners use numbers and talk about time, dates, and prices accurately and confidently in real-world customer service interactions.',
        },
        {
          'title': 'Part 1: Using Numbers in Customer Service',
          'content':
              'In a call center setting, numbers are often used to:\n• Share prices – e.g., “It’s \$25.50”\n• Confirm orders – e.g., “Your order number is 135728.”\n• Provide dates/schedules – e.g., “It will arrive on March 15th.”\n• Give time – e.g., “Your appointment is at 3:30 p.m.”\n\n<strong>Vocabulary:</strong>\n• Cardinal numbers – one, two, three\n• Ordinal numbers – first, second, third (used in dates)\n\n<strong>Examples:</strong>\n• "Your total is twenty-nine dollars."\n• "You are speaking with Agent Number 5."\n• "Please hold for two minutes."\n• "Your refund will be processed in 3 to 5 business days."\n\n<strong>Important Pronunciation & ID Tips:</strong>\n• <em>"Teen" vs. "Ty":</em> Clearly distinguish numbers like thir<strong>TEEN</strong> (stress on TEEN) from <strong>THIR</strong>ty (stress on THIR). Mispronouncing these can lead to significant errors.\n• <em>Zero:</em> Can be pronounced as "zero" or "oh" (especially in phone numbers or sequences).\n• <em>Alphanumeric IDs (Order/Account Numbers):</em>\n  • Speak clearly and pace yourself. Pause slightly between groups.\n  • Group numbers (e.g., "123-456-7890" as "one two three, four five six, seven eight nine zero").\n  • Clarify letters if needed (e.g., "B as in Bravo").\n  • Offer to repeat: "Would you like me to repeat that for you?"',
        },
        {
          'title': 'Part 2: Talking About Prices',
          'content':
              '• "It’s \$10." (spoken: "ten dollars")\n• "The shipping fee is \$7.99."\n• "That item costs \$249."\n\n<strong>Tips:</strong>\n• Always say “dollars.”\n• For decimals: “four dollars and seventy-five cents.”\n\n<em>(Content on "How to Talk About Prices" will be covered in the main lesson video or a dedicated segment.)</em>',
        },
        {
          'title': 'Part 3 & 4: Time & Dates',
          'content':
              '<strong>Asking & Telling the Time</strong>\nCommon Questions:\n• "What time is it?"\n• "What time does the shift start?"\n• "When is my appointment?"\n\nCommon Answers:\n• "It’s 8:15 a.m."\n• "The meeting is at 2 o’clock."\n• "Support hours are from 9 a.m. to 6 p.m."\n\n<em>Call Center Format:</em> Use 12-hour format with a.m./p.m. and always confirm time zones if applicable.\n\n<strong>Talking About Dates</strong>\nCall center agents often confirm delivery or appointment dates.\n<em>Format:</em> Month + Day (ordinal) + Year (e.g., April 15th, 2025)\nCommon Questions:\n• "What’s today’s date?"\n• "When will my package arrive?"\n• "Can I schedule it for next Tuesday?"\n\nResponses:\n• "It’s April 15th."\n• "Your order will arrive on June 3rd."\n• "The system was updated on March 28, 2025."\n\n<em>(Content on "Telling Time and Dates in English" will be covered in the main lesson video or a dedicated segment.)</em>',
        },
        {
          'title': 'Watch: Numbers, Dates, and Prices in Action',
          'content':
              'The following video summarizes key concepts for using numbers, dates, and prices effectively in customer service scenarios. Watch it carefully before proceeding to the activity.',
        }
      ],
      'video': {
        // This ID MUST match the 11-character ID you set for lesson 2.3
        // in module2.dart's _hardcodedVideoIdsM2 map.
        'url': 'VIDEO_ID_FOR_2_3_HERE'
      },
      'activity': {
        'title': 'Simulation Activity: Price, Time, and Date',
        'objective':
            'Practice using numbers, time, dates, and prices in call center scenarios.',
        'instructions': {
          'introParagraph':
              'For each prompt, provide a clear, complete answer using appropriate formats:<br/>• <strong>Prices:</strong> Include a dollar sign and say “dollars” (e.g., <em>\$29.99</em> or <em>twenty-nine dollars</em>).<br/>• <strong>Times:</strong> Use the 12-hour format with <em>a.m.</em> or <em>p.m.</em> (e.g., <em>3:30 p.m.</em>).<br/>• <strong>Dates:</strong> Use the format <em>Month Day, Year</em> (e.g., <em>April 15, 2025</em>).<br/>• <strong>Account Numbers:</strong> Use a full number (e.g., <em>135728</em>).<br/><br/><em>Avoid short or incomplete answers — respond as you would in a real call center.</em>'
        },
        'prompts': [
          {
            'name': 'price',
            'label': 'Prompt 1 – Price Confirmation',
            'customerText': 'Customer: “How much is the total for my order?”',
            'agentPrompt': 'Agent: “Your total is (fill in below).”',
            'placeholder': 'e.g., twenty-nine dollars and fifty cents',
          },
          {
            'name': 'delivery',
            'label': 'Prompt 2 – Delivery Date',
            'customerText': 'Customer: “When can I expect my package?”',
            'agentPrompt': 'Agent: “It will arrive on (fill in below).”',
            'placeholder': 'e.g., June 3rd, 2025',
          },
          {
            'name': 'appointment',
            'label': 'Prompt 3 – Time Appointment',
            'customerText': 'Customer: “What time is my appointment?”',
            'agentPrompt': 'Agent: “It’s scheduled for (fill in below).”',
            'placeholder': 'e.g., 3:30 p.m.',
          },
          {
            'name': 'account',
            'label': 'Prompt 4 – Account Number',
            'customerText': 'Customer: “Can you check my account?”',
            'agentPrompt': 'Agent: “Yes, I see it’s (fill in below).”',
            'placeholder': 'e.g., 135728',
          },
          {
            'name': 'billing',
            'label': 'Prompt 5 – Billing Issue',
            'customerText': 'Customer: “I was charged twice!”',
            'agentPrompt':
                'Agent: “I see a charge of (fill in amount and date below).”',
            'placeholder': 'e.g., \$50.00 on May 12, 2025',
          },
        ],
        'maxPossibleAIScore': 25, // 5 prompts * 5 points each
      },
    };
    // ---- END HARDCODED LESSON 2.3 DATA ----

    _lessonData = hardcodedLesson2_3Data;

    if (_lessonData != null) {
      _activityPrompts =
          _lessonData!['activity']?['prompts'] as List<dynamic>? ?? [];
      _textControllers.forEach((_, controller) => controller.dispose());
      _textControllers.clear();
      for (var promptData in _activityPrompts) {
        if (promptData is Map && promptData['name'] is String) {
          _textControllers[promptData['name']] = TextEditingController();
        }
      }
      _logger.i(
          "L2.3 HARDCODED content loaded. Prompts: ${_activityPrompts.length}");
    } else {
      _logger.w("L2.3 hardcoded content is null. Defaulting.");
      _activityPrompts = [];
    }

    if (mounted) {
      setState(() {
        _isLoadingLessonContent = false;
      });
    }
  }

  @override
  void didUpdateWidget(covariant buildLesson2_3 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.youtubeController != oldWidget.youtubeController) {
      oldWidget.youtubeController.removeListener(_videoListener);
      widget.youtubeController.addListener(_videoListener);
    }

    bool shouldResetForNewAttempt = (widget.showActivitySection &&
            !widget.displayFeedback) &&
        ((widget.showActivitySection != oldWidget.showActivitySection &&
                !oldWidget.displayFeedback) ||
            (widget.initialAttemptNumber != oldWidget.initialAttemptNumber));

    if (shouldResetForNewAttempt) {
      _currentAttemptForDisplay = widget.initialAttemptNumber + 1;
      _logger.i("L2.3: Resetting for new attempt $_currentAttemptForDisplay.");
      _textControllers.forEach((_, controller) => controller.clear());
      _resetTimer();
      _startTimer();
    }

    if (!widget.showActivitySection && oldWidget.showActivitySection) {
      _stopTimer();
    }
    if (widget.displayFeedback &&
        !oldWidget.displayFeedback &&
        _timer?.isActive == true) {
      _stopTimer();
    }
  }

  @override
  void dispose() {
    widget.youtubeController.removeListener(_videoListener);
    _textControllers.forEach((_, controller) => controller.dispose());
    _stopTimer();
    super.dispose();
  }

  void _videoListener() {
    if (widget.youtubeController.value.playerState == PlayerState.ended &&
        !_videoFinished) {
      if (mounted) setState(() => _videoFinished = true);
      _logger.i('Video finished in Lesson 2.3');
    }
  }

  void _startTimer() {
    _stopTimer();
    _secondsElapsed = 0; // Reset timer for new attempt
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _secondsElapsed++);
    });
    _logger.i('Timer started for L2.3. Attempt: $_currentAttemptForDisplay.');
  }

  void _stopTimer() {
    _timer?.cancel();
    _logger.i('Timer stopped for L2.3. Elapsed: $_secondsElapsed s.');
  }

  void _resetTimer() {
    if (mounted) setState(() => _secondsElapsed = 0);
  }

  String _formatDuration(int totalSeconds) {
    final duration = Duration(seconds: totalSeconds);
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _handleSubmit() async {
    if (!mounted) return;

    bool allAnswered = _activityPrompts.every((prompt) {
      final promptName = prompt['name'] as String?;
      return promptName != null &&
          _textControllers[promptName]?.text.trim().isNotEmpty == true;
    });

    if (!allAnswered) {
      if (mounted) {
        ScaffoldMessenger.of(widget.parentContext).showSnackBar(const SnackBar(
            content: Text('Please answer all scenarios before submitting.')));
      }
      return;
    }

    setState(() => _isSubmitting = true);
    _stopTimer();

    Map<String, String> currentAnswers = {};
    _textControllers.forEach((key, controller) {
      currentAnswers[key] = controller.text.trim();
    });

    try {
      await widget.onSubmitAnswers(
          currentAnswers, _secondsElapsed, widget.initialAttemptNumber);
    } catch (e) {
      _logger.e("Error in onSubmitAnswers callback for Lesson 2.3: $e");
      if (mounted) {
        ScaffoldMessenger.of(widget.parentContext).showSnackBar(
            SnackBar(content: Text('Submission error: $e. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingLessonContent || _lessonData == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final String lessonTitle =
        _lessonData!['lessonTitle'] as String? ?? 'Lesson 2.3 (Error)';
    List<dynamic> fetchedSlidesData =
        _lessonData!['slides'] as List<dynamic>? ?? _staticSlidesDataFallback;
    if (fetchedSlidesData.isEmpty)
      fetchedSlidesData = _staticSlidesDataFallback;

    final String activityTitle =
        _lessonData!['activity']?['title'] as String? ??
            'Interactive Scenarios (Error)';
    String activityInstructions = _lessonData!['activity']?['instructions']
            ?['introParagraph'] as String? ??
        _lessonData!['activity']?['objective'] as String? ??
        'Type your responses to the following scenarios.';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(lessonTitle,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF00568D), fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (fetchedSlidesData.isNotEmpty) ...[
            CarouselSlider(
              key: ValueKey('carousel_l2_3_${fetchedSlidesData.hashCode}'),
              carouselController: widget.carouselController,
              items: fetchedSlidesData.map((slide) {
                return buildSlide(
                  title: slide['title'] as String? ?? 'Slide Title',
                  content: slide['content'] as String? ?? 'Slide Content',
                  slideIndex: fetchedSlidesData.indexOf(slide),
                );
              }).toList(),
              options: CarouselOptions(
                height: 280.0, // Adjusted height for potentially longer content
                viewportFraction: 0.9,
                enlargeCenterPage: false,
                enableInfiniteScroll: false,
                initialPage: widget.currentSlide,
                onPageChanged: (index, reason) {
                  if (mounted) widget.onSlideChanged(index);
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: fetchedSlidesData.asMap().entries.map((entry) {
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
                      color: widget.currentSlide == entry.key
                          ? const Color(0xFF00568D)
                          : Colors.grey,
                    ),
                  ),
                );
              }).toList(),
            ),
          ] else
            Text("No slides available for this lesson."),
          const SizedBox(height: 16),
          if (widget.currentSlide >=
              (fetchedSlidesData.isNotEmpty
                  ? fetchedSlidesData.length - 1
                  : 0)) ...[
            Text('Watch the Video',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(color: const Color(0xFF00568D))),
            const SizedBox(height: 8),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: YoutubePlayer(
                key: widget.youtubePlayerKey,
                controller: widget.youtubeController,
                showVideoProgressIndicator: true,
                onReady: () => _logger.i("L2.3 Player Ready"),
                onEnded: (_) => _videoListener(),
              ),
            ),
            if (!widget.showActivitySection) ...[
              const SizedBox(height: 16),
              SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                      onPressed:
                          _videoFinished ? widget.onShowActivitySection : null,
                      style: ElevatedButton.styleFrom(
                          disabledBackgroundColor: Colors.grey[300]),
                      child: const Text('Proceed to Activity'))),
              if (!_videoFinished)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text('Please watch the video to the end to proceed.',
                      style: TextStyle(color: Colors.red, fontSize: 14),
                      textAlign: TextAlign.center),
                ),
            ],
          ],
          if (widget.showActivitySection) ...[
            const SizedBox(height: 24),
            Text(activityTitle,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(color: Colors.orange)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Attempt: $_currentAttemptForDisplay',
                      style: Theme.of(context).textTheme.titleMedium),
                  if (!widget.displayFeedback)
                    Text('Time: ${_formatDuration(_secondsElapsed)}',
                        style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
            HtmlFormattedText(htmlString: activityInstructions),
            const SizedBox(height: 16),
            if (!widget.displayFeedback) ...[
              // Input Mode
              if (_activityPrompts.isEmpty && !_isLoadingLessonContent)
                const Center(
                    child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text("No activity prompts defined."))),

              ..._activityPrompts.map((promptData) {
                final String promptName = promptData['name'] as String? ??
                    'unknown_prompt_l23_${_activityPrompts.indexOf(promptData)}';
                final String promptLabel =
                    promptData['label'] as String? ?? 'Scenario';
                final String customerText =
                    promptData['customerText'] as String? ?? '';
                final String agentTask =
                    promptData['agentPrompt'] as String? ?? 'Your response:';
                final TextEditingController? controller =
                    _textControllers[promptName];

                if (controller == null) {
                  _logger.w(
                      "No TextEditingController for L2.3 prompt name: $promptName");
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(promptLabel,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      if (customerText.isNotEmpty)
                        Padding(
                            padding:
                                const EdgeInsets.only(top: 4.0, bottom: 2.0),
                            child: Text(customerText,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                        fontStyle: FontStyle.italic,
                                        color: Colors.grey[700]))),
                      Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(agentTask,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: Colors.blueAccent))),
                      const SizedBox(height: 6),
                      TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          hintText: promptData['placeholder'] as String? ??
                              'Type your response for $promptLabel...',
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        keyboardType: TextInputType
                            .text, // Changed from multiline for single line inputs
                        maxLines: 1, // For price, date, time, account number
                        minLines: 1,
                        textInputAction: TextInputAction
                            .next, // Or TextInputAction.done for the last one
                      ),
                    ],
                  ),
                );
              }).toList(),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00568D),
                      disabledBackgroundColor: Colors.grey),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white)))
                      : const Text('Submit for AI Feedback',
                          style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
            ],
            if (widget.displayFeedback && widget.aiFeedbackData != null) ...[
              // Feedback Display Mode
              if (widget.overallAIScoreForDisplay != null &&
                  widget.maxPossibleAIScoreForDisplay != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(
                    child: Text(
                      'Overall AI Score: ${widget.overallAIScoreForDisplay}',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                              color: Colors.purple,
                              fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

              if (_activityPrompts.isEmpty && !_isLoadingLessonContent)
                const Center(
                    child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text("No prompts to display feedback for."))),

              ..._activityPrompts.map((promptData) {
                final String promptName = promptData['name'] as String? ??
                    'unknown_prompt_l23_${_activityPrompts.indexOf(promptData)}';
                final String promptLabel =
                    promptData['label'] as String? ?? 'Scenario';
                final IconData? promptIcon = promptData['icon'] as IconData?;
                // Accessing feedback using 'answers' and 'feedbackForEachAnswer' keys
                final Map<String, dynamic>? allAnswersFromParent =
                    widget.aiFeedbackData!['answers'] as Map<String, dynamic>?;
                final String userAnswer =
                    _textControllers[promptName]?.text.trim() ??
                        (widget.aiFeedbackData?['answers']?[promptName]
                            as String?) ?? // Fallback for re-display from log
                        'Not available';

                final Map<String, dynamic>? allFeedbackFromParent =
                    widget.aiFeedbackData!['feedbackForEachAnswer']
                        as Map<String, dynamic>?;
                final feedbackForThisPrompt =
                    widget.aiFeedbackData?[promptName] as Map<String, dynamic>?;

                return Card(
                  // This is the outer card for EACH prompt+feedback set
                  // ... your existing Card styling ...
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Display prompt label and user's answer as before
                        Row(
                          children: [
                            if (promptIcon != null)
                              FaIcon(promptIcon,
                                  size: 18, color: const Color(0xFF00568D)),
                            if (promptIcon != null) const SizedBox(width: 8),
                            Expanded(
                                child: Text(promptLabel,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF00568D)))),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text("Your Answer:",
                            style: Theme.of(context).textTheme.labelLarge),
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0, bottom: 8.0),
                          child: Text(
                              userAnswer.isNotEmpty
                                  ? userAnswer
                                  : '(No answer provided)',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                      fontStyle: FontStyle.italic,
                                      color: Colors.grey[700])),
                        ),

                        // Use the new ParsedFeedbackCard
                        if (feedbackForThisPrompt != null)
                          ParsedFeedbackCard(
                            feedbackData: feedbackForThisPrompt,
                            // scenarioLabel: promptLabel, // The card can be self-contained without repeating label
                          )
                        else
                          const Padding(
                            padding: EdgeInsets.only(top: 8.0),
                            child: Text('AI Feedback: Not available.',
                                style: TextStyle(
                                    color: Colors.grey,
                                    fontStyle: FontStyle.italic)),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => widget
                      .onShowActivitySection(), // This triggers reset in module2 via callback
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text('Try Again',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// Ensure HtmlFormattedText is available, either from common_widgets.dart or defined locally if needed.
// If it's in common_widgets.dart, this local definition can be removed.
// class HtmlFormattedText extends StatelessWidget { ... } // Assuming it's imported
