// lesson2_2.dart

import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:logger/logger.dart';
import '../lessons/common_widgets.dart'; // For buildSlide
import 'dart:async';
import '../firebase_service.dart'; // Your FirebaseService

class buildLesson2_2 extends StatefulWidget {
  final BuildContext parentContext;
  final int currentSlide;
  final CarouselSliderController carouselController;
  final YoutubePlayerController youtubeController;

  // VV ADD THIS LINE VV
  final Key? youtubePlayerKey;
  // ^^ ADD THIS LINE ^^

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

  const buildLesson2_2({
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
    this.aiFeedbackData,
    this.overallAIScoreForDisplay,
    this.maxPossibleAIScoreForDisplay,
    this.youtubePlayerKey,
  });

  @override
  _Lesson2_2State createState() => _Lesson2_2State();
}

class _Lesson2_2State extends State<buildLesson2_2> {
  final Logger _logger = Logger();
  // final FirebaseService _firebaseService = FirebaseService(); // Not strictly needed for hardcoded content

  bool _videoFinished = false;
  bool _isSubmitting = false;
  Timer? _timer;
  int _secondsElapsed = 0;
  late int _currentAttemptForDisplay;

  bool _isLoadingLessonContent = true;
  Map<String, dynamic>? _lessonData;
  List<dynamic> _activityPrompts = [];
  late Map<String, TextEditingController> _textControllers;

  // Fallback static slides if Firestore fetch fails (original from your code)
  final List<Map<String, dynamic>> _staticSlidesDataFallback = [
    {
      'title': 'Objective: Asking for Information Politely (Fallback)',
      'content':
          'Learn phrases and techniques for asking for information from customers in a polite and professional manner.',
    },
    {
      'title': 'Using Polite Question Forms (Fallback)',
      'content':
          '• Use "Could you," "Would you mind," or "May I" for requests.\n  Example: "Could you please provide your account number?"',
    },
    {
      'title': 'Explaining Why Information is Needed (Fallback)',
      'content':
          '• Briefly explain why you need certain information to build trust.\n  Example: "May I have your date of birth to verify your account?"',
    },
    {
      'title': 'Active Listening and Clarification (Fallback)',
      'content':
          '• Listen carefully to the customer\'s responses.\n• Ask clarifying questions if needed.\n  Example: "Could you please repeat that?"',
    },
    {
      'title': 'Conclusion (Fallback)',
      'content':
          'Asking for information politely and clearly is key to efficient customer service. Practice these techniques.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _currentAttemptForDisplay = widget.initialAttemptNumber + 1;
    _textControllers = {};
    _fetchLessonContentAndInitialize(); // Will use hardcoded data
    widget.youtubeController.addListener(_videoListener);

    if (widget.showActivitySection && !widget.displayFeedback) {
      _startTimer();
    }
  }

  final YoutubePlayerController _controller = YoutubePlayerController(
    initialVideoId: 'bQ90ZCNFuq0', // correct video ID for lesson 2.1
    flags: YoutubePlayerFlags(
      autoPlay: false,
      mute: false,
    ),
  );

  Future<void> _fetchLessonContentAndInitialize() async {
    if (!mounted) return;
    setState(() {
      _isLoadingLessonContent = true;
    });

    // ---- START HARDCODED LESSON 2.2 DATA ----
    final Map<String, dynamic> hardcodedLesson2_2Data = {
      'lessonTitle': 'Lesson 2.2: Asking for Information (HC)', // From JSX
      'slides': [
        {
          'title': 'Objective', // From JSX
          'content':
              'By the end of this lesson, learners will be able to confidently ask for information in customer service scenarios, using common questions that will help them effectively engage with customers.', // From JSX
        },
        {
          'title': 'Introduction', // From JSX
          'content':
              'In a call center environment, asking the right questions is crucial to understanding the customer\'s issue and providing appropriate assistance. The ability to ask clear, polite, and professional questions ensures that customers feel heard and that their problems are addressed efficiently.', // From JSX
        },
        {
          'title': 'Key Phrases for Getting Customer Information', // From JSX
          'content': 'Based on "36 English Phrases for Professional Customer Service," here are some effective ways to request information:\n\n' // From JSX
              '• "Absolutely. Could I please get your full name to check that order for you?"\n' // From JSX
              '• "Great. Could you please give me your customer/account number?"\n' // From JSX
              '• "No problem. Do you happen to have the order number so I can bring it up?"\n' // From JSX
              '• "I see. Could you please give me the account number listed on the invoice?"', // From JSX
        },
        {
          'title': 'More Common Questions in Customer Service', // From JSX
          'content': '1. "How can I assist you today?" – A polite and professional opening.\n' // From JSX
              '2. "What is the issue you are experiencing?" – Helps focus on the customer’s concern.\n' // From JSX
              '3. "Could you explain the problem a bit more?" – Encourages clarification.', // From JSX
          // You can add more items here if your JSX has them
        },
        // This slide can represent the point where the video is introduced.
        // The actual video player appears after the last slide in the Flutter UI.
        {
          'title':
              'Watch: How to Ask Probing Questions', // From JSX Video Section
          'content':
              'The following video will demonstrate techniques for asking effective probing questions in customer service scenarios.'
        }
      ],
      'video': {
        // The JSX file had "https://www.youtube.com/embed/bQ90ZCNFuq0" which is not a direct playable ID.
        // Using a known valid public YouTube ID for testing.
        'url':
            'bQ90ZCNFuq0' // Example: Google I/O 2011 Keynote. Replace if you have a specific Lesson 2.2 video.
      },
      'activity': {
        'title': 'Interactive Activity: Asking for Information', // From JSX
        'objective':
            'Practice asking clear, polite, and professional questions to gather necessary information from customers.', // From JSX (used as instructions intro)
        'instructions': {
          'introParagraph':
              'For each scenario, respond as a call center agent. Your response should include at least <strong>three appropriate questions</strong> to help understand and address the customer\'s situation. Focus on being polite and professional.' // From JSX instructions
        },
        'prompts': [
          // From activityPrompts_L2_2 in JSX
          {
            'name': 'scenario1', // Matches JSX and desired key for consistency
            'label': 'Scenario 1: Broken Item', // From JSX
            'customerText':
                'Customer: "I need help with my recent purchase. The item I received is broken."', // From JSX
            'agentPrompt':
                'Agent Prompt: Ask at least 3 relevant questions to understand the problem and gather details about the broken item and order.', // From JSX
          },
          {
            'name': 'scenario2', // Matches JSX and desired key for consistency
            'label': 'Scenario 2: Slow Internet', // From JSX
            'customerText':
                'Customer: "My internet has been very slow for the past few days."', // From JSX
            'agentPrompt':
                'Agent Prompt: Ask at least 3 probing questions to diagnose the issue with the slow internet.', // From JSX
          },
        ],
        'maxPossibleAIScore':
            10, // Assuming 2 prompts, 5 points each, as per web example
      },
    };

    _lessonData = hardcodedLesson2_2Data;
    // ---- END HARDCODED LESSON 2.2 DATA ----

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
          "L2.2 HARDCODED content loaded. Prompts: ${_activityPrompts.length}");
    } else {
      _logger.w("L2.2 hardcoded content is null. Defaulting to empty prompts.");
      _activityPrompts = [];
    }

    if (mounted) {
      setState(() {
        _isLoadingLessonContent = false;
      });
    }
  }

  @override
  void didUpdateWidget(covariant buildLesson2_2 oldWidget) {
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
      _logger
          .i("L2.2: Resetting for new attempt ${_currentAttemptForDisplay}.");
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
      _logger.i('Video finished in Lesson 2.2');
    }
  }

  void _startTimer() {
    _stopTimer();
    _secondsElapsed = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _secondsElapsed++);
    });
    _logger.i('Timer started for L2.2. Attempt: $_currentAttemptForDisplay.');
  }

  void _stopTimer() {
    _timer?.cancel();
    _logger.i('Timer stopped for L2.2. Elapsed: $_secondsElapsed s.');
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

    // Check if all answers are provided
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
      // Do not set _isSubmitting to true if validation fails
      return;
    }

    setState(() {
      _isSubmitting = true;
    });
    _stopTimer();

    Map<String, String> currentAnswers = {};
    _textControllers.forEach((key, controller) {
      currentAnswers[key] = controller.text.trim();
    });

    try {
      await widget.onSubmitAnswers(
          currentAnswers, _secondsElapsed, widget.initialAttemptNumber);
    } catch (e) {
      _logger.e("Error in onSubmitAnswers callback for Lesson 2.2: $e");
      if (mounted) {
        ScaffoldMessenger.of(widget.parentContext).showSnackBar(
            SnackBar(content: Text('Submission error: $e. Please try again.')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingLessonContent) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_lessonData == null) {
      // Removed && _activityPrompts.isEmpty for clarity as _lessonData null implies prompts would be too
      return const Center(
          child: Text(
              "Error: Hardcoded lesson data for L2.2 is missing. Check implementation."));
    }

    final String lessonTitle =
        _lessonData!['lessonTitle'] as String? ?? 'Lesson 2.2 (Error)';
    List<dynamic> fetchedSlidesData =
        _lessonData!['slides'] as List<dynamic>? ?? [];
    if (fetchedSlidesData.isEmpty) {
      fetchedSlidesData =
          _staticSlidesDataFallback; // Use fallback if hardcoded slides are empty
    }

    // final String videoIdFromData =
    //     _lessonData!['video']?['url'] as String? ?? '';

    // // Similar logic to lesson2_1.dart for video loading, primarily handled by module2.dart
    // // This block in the child can act as a fallback or for specific child-driven loads if needed.
    // if (widget.youtubeController.metadata.videoId != videoIdFromData &&
    //     videoIdFromData.isNotEmpty &&
    //     videoIdFromData !=
    //         'dQw4w9WgXcQ' /* Avoid reloading the specific placeholder used here if that's what module2 also uses */) {
    //   _logger.i(
    //       "Lesson2_2 build: Attempting to load videoIdFromData: '$videoIdFromData' into controller. Current: '${widget.youtubeController.metadata.videoId}'");
    //   Future.microtask(() {
    //     try {
    //       widget.youtubeController.load(videoIdFromData);
    //     } catch (e) {
    //       _logger.e("Error trying to load video in buildLesson2_2: $e");
    //     }
    //   });
    // } else if (videoIdFromData.isEmpty) {
    //   _logger.w("Lesson2_2 build: videoIdFromData is empty.");
    // }

    final String activityTitle =
        _lessonData!['activity']?['title'] as String? ??
            'Interactive Scenarios (Error)';
    String activityInstructions = '';
    final instructionsMap =
        _lessonData!['activity']?['instructions'] as Map<String, dynamic>?;
    if (instructionsMap != null &&
        instructionsMap['introParagraph'] is String) {
      activityInstructions = instructionsMap['introParagraph'] as String;
    } else if (_lessonData!['activity']?['objective'] is String) {
      activityInstructions = _lessonData!['activity']?['objective'] as String;
    } else {
      activityInstructions = 'Type your responses to the following scenarios.';
    }

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
              key: ValueKey('carousel_l2_2_${fetchedSlidesData.hashCode}'),
              carouselController: widget.carouselController,
              items: fetchedSlidesData.map((slide) {
                return buildSlide(
                  title: slide['title'] as String? ?? 'Slide Title',
                  content: slide['content'] as String? ?? 'Slide Content',
                  slideIndex: fetchedSlidesData.indexOf(slide),
                );
              }).toList(),
              options: CarouselOptions(
                height: 250.0,
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
            Text("No slides available for this lesson (hardcoded)."),
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
                key: widget.youtubePlayerKey, // USE THE KEY HERE
                controller: widget.youtubeController,
                showVideoProgressIndicator: true,
                onReady: () => _logger
                    .i("L2.2 Player Ready (from buildLesson2_2 hardcoded)"),
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
          ] else if (widget.currentSlide >=
              (fetchedSlidesData.isNotEmpty
                  ? fetchedSlidesData.length - 1
                  : 0)) ...[
            const Text("No video configured for this lesson (hardcoded).",
                style: TextStyle(color: Colors.orange)),
            if (!widget.showActivitySection) ...[
              const SizedBox(height: 16),
              SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                      onPressed: widget.onShowActivitySection,
                      child: const Text('Proceed to Activity (No Video)'))),
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
                        child: Text(
                            "No activity prompts defined for L2.2 (hardcoded)."))),

              ..._activityPrompts.map((promptData) {
                final String promptName = promptData['name'] as String? ??
                    'unknown_prompt_l22_${_activityPrompts.indexOf(promptData)}';
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
                      "No TextEditingController for L2.2 prompt name: $promptName");
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
                            child: Text("Customer: \"$customerText\"",
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
                          hintText: 'Type your questions for $promptLabel...',
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        keyboardType: TextInputType.multiline,
                        maxLines: 4,
                        minLines: 3,
                        textInputAction: TextInputAction.newline,
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
                      'Overall AI Score: ${widget.overallAIScoreForDisplay} / ${widget.maxPossibleAIScoreForDisplay}',
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
                        child: Text(
                            "No prompts to display feedback for L2.2 (hardcoded)."))),

              ..._activityPrompts.map((promptData) {
                final String promptName = promptData['name'] as String? ??
                    'unknown_prompt_l22_${_activityPrompts.indexOf(promptData)}';
                final String promptLabel =
                    promptData['label'] as String? ?? 'Scenario';
                final feedbackForThisPrompt =
                    widget.aiFeedbackData![promptName] as Map<String, dynamic>?;

                String userAnswer =
                    _textControllers[promptName]?.text.trim() ?? '';
                if (userAnswer.isEmpty) {
                  // IMPORTANT: This key 'scenarioAnswers_L2_2' must match how module2.dart structures the feedback payload for Lesson 2.2
                  final Map<String, dynamic>? allAnswersFromParent =
                      widget.aiFeedbackData!['scenarioAnswers_L2_2']
                          as Map<String, dynamic>?;
                  userAnswer = allAnswersFromParent?[promptName] as String? ??
                      'Not available';
                }

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(promptLabel,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF00568D))),
                        const SizedBox(height: 6),
                        Text("Your Answer:",
                            style: Theme.of(context).textTheme.labelLarge),
                        Text(
                            userAnswer.isNotEmpty
                                ? userAnswer
                                : '(No answer provided)',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey[700])),
                        const SizedBox(height: 12),
                        if (feedbackForThisPrompt != null) ...[
                          Text(
                            'AI Feedback (Score: ${feedbackForThisPrompt['score'] ?? 'N/A'}):',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blueAccent),
                          ),
                          const SizedBox(height: 4),
                          HtmlFormattedText(
                              // Defined at the bottom
                              htmlString:
                                  feedbackForThisPrompt['text'] as String? ??
                                      'No feedback text.'),
                        ] else
                          const Text('AI Feedback: Not available.',
                              style: TextStyle(color: Colors.grey)),
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
                  onPressed: () {
                    widget.onShowActivitySection();
                  },
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

// Definition of HtmlFormattedText (as provided in your original files)
// If this is in common_widgets.dart and imported, you can remove this local definition.
class HtmlFormattedText extends StatelessWidget {
  final String htmlString;
  const HtmlFormattedText({super.key, required this.htmlString});

  @override
  Widget build(BuildContext context) {
    // Basic replacement for display. For proper HTML, use flutter_html package.
    String displayText = htmlString
        .replaceAll('<br/>', '\n')
        .replaceAll('<br>', '\n')
        .replaceAll('<strong>', '')
        .replaceAll('</strong>', '')
        .replaceAll('<h4>', '')
        .replaceAll('</h4>', '\n')
        .replaceAll('<ul>', '')
        .replaceAll('</ul>', '')
        .replaceAll('<li>', '• ')
        .replaceAll('</li>', '\n')
        .replaceAll(RegExp(r'<span.*?>'), '')
        .replaceAll('</span>', '')
        .replaceAllMapped(RegExp(r'(📚 Vocabulary Used:|💡 Tip:)\s*'),
            (match) => '\n${match.group(1)}\n  ')
        .replaceAllMapped(
            RegExp(
                r'(- Greeting Appropriateness:|- Self-introduction Clarity:|- Tone and Politeness:|- Grammar Accuracy:|- Suggestion for Improvement:|- Format & Unit Accuracy:|- Clarity for Customer Understanding:)\s*'),
            (match) => '\n${match.group(1)}\n  ')
        .replaceAll(RegExp(r'<[^>]*>'), '');

    displayText = displayText
        .trim()
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .join('\n');

    return Text(displayText, style: const TextStyle(fontSize: 14, height: 1.5));
  }
}
