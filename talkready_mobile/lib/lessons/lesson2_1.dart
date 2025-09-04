// lesson2_1.dart

import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:logger/logger.dart';
// Assuming common_widgets.dart contains buildSlide. If HtmlFormattedText is also there,
// you might not need the local definition at the bottom of this file.
// For this example, I'll assume buildSlide is from common_widgets.dart and HtmlFormattedText is defined below.
import '../lessons/common_widgets.dart'; // For buildSlide
import 'dart:async';
// firebase_service.dart is not directly used when hardcoding, but keeping the import
// as other parts of your app structure might expect it.
import '../firebase_service.dart';
import '../widgets/parsed_feedback_card.dart';
import '../StudentAssessment/InteractiveText.dart';
import '../StudentAssessment/RolePlayScenarioQuestion.dart';
import '../StudentAssessment/AiFeedbackData.dart';

class buildLesson2_1 extends StatefulWidget {
  final BuildContext parentContext; // Renamed from context to avoid conflict
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
  final int initialAttemptNumber; // Count of previously completed attempts

  final bool displayFeedback;
  final Map<String, dynamic>? aiFeedbackData;
  final int? overallAIScoreForDisplay;
  final int? maxPossibleAIScoreForDisplay;

  const buildLesson2_1({
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
  _Lesson2_1State createState() => _Lesson2_1State();
}

class _Lesson2_1State extends State<buildLesson2_1> {
  final Logger _logger = Logger();
  // FirebaseService instance might not be strictly needed for hardcoded version,
  // but kept for consistency if other minor Firebase interactions were present.
  // final FirebaseService _firebaseService = FirebaseService();

  bool _videoFinished = false;
  bool _isSubmitting = false;
  Timer? _timer;
  int _secondsElapsed = 0;
  late int _currentAttemptForDisplay;

  bool _isLoadingLessonContent = true;
  Map<String, dynamic>? _lessonData;
  List<dynamic> _activityPrompts = [];
  late Map<String, TextEditingController> _textControllers;

  // Fallback static slides data (original from your code) - used if hardcoded _lessonData['slides'] is empty
  final List<Map<String, dynamic>> _staticSlidesDataFallback = [
    {
      'title': 'Objective: Mastering Greetings and Introductions (Fallback)',
      'content':
          'Learn to use common greetings and introductions appropriately in call center interactions to build rapport with customers.',
    },
    {
      'title': 'Common Greetings (Fallback)',
      'content':
          '• "Good morning/afternoon/evening."\n• "Hello, thank you for calling [Company Name]."',
    },
    {
      'title': 'Introducing Yourself and the Company (Fallback)',
      'content':
          '• "My name is [Your Name], and I\'m calling from [Company Name]."\n• "This is [Your Name] from [Company Name]."',
    },
    {
      'title': 'Responding to Customer Greetings (Fallback)',
      'content':
          '• If the customer greets you first, respond politely.\n  Example: Customer: "Good morning." Agent: "Good morning! How can I help you?"',
    },
    {
      'title': 'Conclusion (Fallback)',
      'content':
          'Clear and polite greetings set a positive tone for the entire call. Practice them well!',
    },
  ];

  @override
  void initState() {
    super.initState();
    _currentAttemptForDisplay = widget.initialAttemptNumber + 1;
    _textControllers = {};
    _fetchLessonContentAndInitialize(); // This will now use hardcoded data
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

    // Simulate a brief delay, as if fetching data
    // await Future.delayed(const Duration(milliseconds: 50));

    // ---- START HARDCODED LESSON 2.1 DATA ----
    final Map<String, dynamic> hardcodedLesson2_1Data = {
      'lessonTitle': 'Lesson 2.1: Greetings & Introductions (HC)',
      'slides': [
        {
          'title': 'Objective: Mastering Greetings',
          'content':
              'Learn to use common greetings and introductions appropriately.',
        },
        {
          'title': 'Key Phrases for Greetings',
          'content':
              '• "Good morning/afternoon/evening."\n• "Hello, [Customer Name], thank you for calling [Company Name]."\n• "Hi, this is [Your Name] speaking. How may I help you?"',
        },
        {
          'title': 'Self-Introduction Essentials',
          'content':
              '1. State your name clearly.\n2. Mention your company.\n3. Offer assistance (e.g., "How can I help you today?").',
        },
        {
          'title': 'Video: Greetings in Action',
          'content':
              'Watch the upcoming video to see these phrases used in realistic call center scenarios.',
        }
      ],
      'video': {
        // Use a KNOWN, PUBLICLY ACCESSIBLE, 11-CHARACTER YouTube video ID
        'url':
            'LRJXMKZ4wOw' // Example: Google I/O Keynote. Replace if you have a specific one for testing.
        // Alternative test ID: 'dQw4w9WgXcQ'
      },
      'activity': {
        'title': 'Activity: Role-Play Greetings (HC)',
        'objective':
            'Practice basic greetings and introducing yourself in a call center setting.', // Added from web version
        'instructions': {
          // Added from web version
          'introParagraph':
              'For each scenario, write a short, polite response that includes: <strong>A proper greeting</strong>, <strong>A self-introduction</strong> (e.g., "My name is [Agent\'s Name]"), and <strong>A helpful follow-up</strong> (e.g., "How may I assist you today?").'
        },
        'prompts': [
          {
            'name': 'scenario1', // Changed name to be more specific
            'label': 'Scenario 1: Standard Greeting',
            'customerText': 'Customer: "Hello?"',
            'agentPrompt': 'Your response (greeting, intro, offer help):',
            // 'agentSampleResponse': 'Sample: "Good morning! My name is [Agent\'s Name], how can I assist you today?"' // As per web
          },
          {
            'name': 'scenario2', // Changed name
            'label': 'Scenario 2: Customer Needs Help',
            'customerText': 'Customer: "Hello, I need help with my order."',
            'agentPrompt':
                'Your response (greeting, intro, acknowledge need, offer help):',
            // 'agentSampleResponse': 'Sample: "Hello! I\'m [Agent\'s Name], I\'d be happy to assist you with your order. Could you please provide your order number?"' // As per web
          },
        ],
        'maxPossibleAIScore':
            10, // As per web example for lesson_2_1 activity data
      },
      // Include other fields if your buildLesson2_1's build method accesses them directly from _lessonData
      // 'moduleId': 'module2',
      // 'moduleTitle': 'Module 2: Vocabulary & Everyday Conversations',
    };

    _lessonData = hardcodedLesson2_1Data;
    // ---- END HARDCODED LESSON 2.1 DATA ----

    if (_lessonData != null) {
      _activityPrompts =
          _lessonData!['activity']?['prompts'] as List<dynamic>? ?? [];
      _textControllers.forEach((_, controller) => controller.dispose());
      _textControllers.clear(); // Clear before re-populating
      for (var promptData in _activityPrompts) {
        if (promptData is Map && promptData['name'] is String) {
          _textControllers[promptData['name']] = TextEditingController();
        }
      }
      _logger.i(
          "L2.1 HARDCODED content loaded. Prompts: ${_activityPrompts.length}");
    } else {
      _logger.w(
          "L2.1 hardcoded content is null (this should not happen). Defaulting to empty prompts.");
      _activityPrompts = [];
    }

    if (mounted) {
      setState(() {
        _isLoadingLessonContent = false;
      });
    }
  }

  @override
  void didUpdateWidget(covariant buildLesson2_1 oldWidget) {
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
      _logger.i(
          "L2.1: Resetting for new attempt $_currentAttemptForDisplay. Clearing text fields and timer.");
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
      _logger.i('Video finished in Lesson 2.1');
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
    _logger.i('Timer started for L2.1. Attempt: $_currentAttemptForDisplay.');
  }

  void _stopTimer() {
    _timer?.cancel();
    _logger.i('Timer stopped for L2.1. Elapsed: $_secondsElapsed s.');
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
    setState(() {
      _isSubmitting = true;
    });
    _stopTimer();

    Map<String, String> currentAnswers = {};
    _textControllers.forEach((key, controller) {
      currentAnswers[key] = controller.text.trim();
    });

    // Check if all answers are provided
    bool allAnswered = _activityPrompts.every((prompt) {
      final promptName = prompt['name'] as String?;
      return promptName != null &&
          currentAnswers[promptName]?.isNotEmpty == true;
    });

    if (!allAnswered) {
      if (mounted) {
        ScaffoldMessenger.of(widget.parentContext).showSnackBar(const SnackBar(
            content: Text('Please answer all scenarios before submitting.')));
      }
      setState(() {
        _isSubmitting = false;
      });
      // Optionally restart timer or leave it stopped based on desired UX
      // _startTimer();
      return;
    }

    try {
      await widget.onSubmitAnswers(
          currentAnswers, _secondsElapsed, widget.initialAttemptNumber);
    } catch (e) {
      _logger.e("Error during onSubmitAnswers callback for Lesson 2.1: $e");
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

  Widget _aiFeedbackWidget() {
    if (!widget.displayFeedback || widget.aiFeedbackData == null) {
      return const SizedBox.shrink();
    }
    final map = widget.aiFeedbackData!;
    if (map.isEmpty) return const SizedBox.shrink();

    final overallScore = widget.overallAIScoreForDisplay;
    final maxScore = widget.maxPossibleAIScoreForDisplay;

    final cards = map.entries
        .where((e) => e.value is Map<String, dynamic>)
        .map((e) => ParsedFeedbackCard(
              feedbackData: e.value as Map<String, dynamic>,
              scenarioLabel: e.key,
            ))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (overallScore != null && maxScore != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              'AI Score: $overallScore / $maxScore',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ...cards,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingLessonContent) {
      return const Center(child: CircularProgressIndicator());
    }
    // With hardcoding, _lessonData should not be null after _fetchLessonContentAndInitialize
    if (_lessonData == null) {
      return const Center(
          child: Text(
              "Error: Hardcoded lesson data is null. Check implementation."));
    }

    final String lessonTitle =
        _lessonData!['lessonTitle'] as String? ?? 'Lesson 2.1 (Error)';
    // Use _staticSlidesDataFallback if _lessonData['slides'] is missing or not a list,
    // or if the list is empty.
    List<dynamic> fetchedSlidesData =
        _lessonData!['slides'] as List<dynamic>? ?? [];
    if (fetchedSlidesData.isEmpty) {
      fetchedSlidesData = _staticSlidesDataFallback;
    }

    // final String videoIdFromData =
    //     _lessonData!['video']?['url'] as String? ?? '';

    // // This logic attempts to load the video ID into the controller passed from module2.dart
    // // module2.dart is primarily responsible for initializing and loading the _youtubeController
    // // This block can act as a secondary load if the ID changes or wasn't initially set,
    // // but ensure it doesn't conflict with module2.dart's controller management.
    // if (widget.youtubeController.metadata.videoId != videoIdFromData &&
    //     videoIdFromData.isNotEmpty &&
    //     videoIdFromData !=
    //         'LRJXMKZ4wOw' /* Avoid reloading the placeholder if that's what module2 also uses as fallback */) {
    //   _logger.i(
    //       "Lesson2_1 build: Attempting to load videoIdFromData: '$videoIdFromData' into controller. Current controller videoId: '${widget.youtubeController.metadata.videoId}'");
    //   // It's generally safer for the parent (module2.dart) to handle all .load() calls
    //   // to avoid race conditions or unexpected behavior.
    //   // Consider if this load call is necessary here or if module2.dart ensures the correct video is loaded.
    //   // For debugging the player, this explicit load here with the hardcoded ID can be useful.
    //   Future.microtask(() {
    //     try {
    //       widget.youtubeController.load(videoIdFromData);
    //     } catch (e) {
    //       _logger.e("Error trying to load video in buildLesson2_1: $e");
    //     }
    //   });
    // } else if (videoIdFromData.isEmpty) {
    //   _logger.w(
    //       "Lesson2_1 build: videoIdFromData is empty. YouTube player might show an error if not already handled by module2.dart.");
    // }

    final String activityTitle =
        _lessonData!['activity']?['title'] as String? ??
            'Interactive Scenarios';

    // Consolidate fetching instructions text
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
              key: ValueKey(
                  'carousel_${fetchedSlidesData.hashCode}'), // Add a key if items change
              carouselController: widget.carouselController,
              items: fetchedSlidesData.map((slide) {
                return buildSlide(
                  // Assuming buildSlide is in common_widgets.dart
                  title: slide['title'] as String? ?? 'Slide Title (Error)',
                  content:
                      slide['content'] as String? ?? 'Slide Content (Error)',
                  slideIndex: fetchedSlidesData.indexOf(slide),
                );
              }).toList(),
              options: CarouselOptions(
                  height: 250.0,
                  viewportFraction: 0.9,
                  enlargeCenterPage: false,
                  enableInfiniteScroll: false,
                  initialPage: widget
                      .currentSlide, // Ensure carousel starts at the correct slide
                  onPageChanged: (index, reason) {
                    // Check if the widget is still mounted before calling setState or callbacks
                    if (mounted) {
                      widget.onSlideChanged(index);
                    }
                  }),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: fetchedSlidesData.asMap().entries.map((entry) {
                return GestureDetector(
                  onTap: () => widget.carouselController
                      .animateToPage(entry.key), // Use animateToPage
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
          // Show video only if current slide is the last one (or meets your condition) AND videoId is present
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
                onReady: () => _logger
                    .i("L2.1 Player Ready (from buildLesson2_1 hardcoded)"),
                onEnded: (_) =>
                    _videoListener(), // _videoListener updates _videoFinished state
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
                        disabledBackgroundColor: Colors.grey[300],
                      ),
                      child: const Text('Proceed to Activity'))),
              if (!_videoFinished)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Please watch the video to the end to proceed.',
                    style: TextStyle(color: Colors.red, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ] else if (widget.currentSlide >=
              (fetchedSlidesData.isNotEmpty
                  ? fetchedSlidesData.length - 1
                  : 0)) ...[
            const Text("No video configured for this lesson (hardcoded).",
                style: TextStyle(color: Colors.orange)),
            // If no video, allow proceeding directly if it's the last slide phase
            if (!widget.showActivitySection) ...[
              const SizedBox(height: 16),
              SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                      onPressed: widget
                          .onShowActivitySection, // Allow proceeding if no video
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
            // Use HtmlFormattedText for instructions if they contain HTML
            HtmlFormattedText(htmlString: activityInstructions),
            // Text(activityInstructions, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 16),

            if (!widget.displayFeedback) ...[
              // Input Mode
              if (_activityPrompts.isEmpty && !_isLoadingLessonContent)
                const Center(
                    child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child:
                            Text("No activity prompts defined (hardcoded)."))),

              ..._activityPrompts.map((promptData) {
                final String promptName = promptData['name'] as String? ??
                    'unknown_prompt_${_activityPrompts.indexOf(promptData)}';
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
                      "No TextEditingController for prompt name: $promptName");
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
                          padding: const EdgeInsets.only(top: 4.0, bottom: 2.0),
                          child: Text("Customer: \"$customerText\"",
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                      fontStyle: FontStyle.italic,
                                      color: Colors.grey[700])),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(agentTask,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Colors.blueAccent)),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          hintText: 'Type your response for $promptLabel...',
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        keyboardType: TextInputType.multiline,
                        maxLines: 3,
                        minLines: 2,
                        textInputAction: TextInputAction.newline,
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00568D),
                    disabledBackgroundColor: Colors.grey,
                  ),
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
                            "No prompts were loaded to display feedback for (hardcoded)."))),

              ..._activityPrompts.map((promptData) {
                final String promptName = promptData['name'] as String? ??
                    'unknown_prompt_${_activityPrompts.indexOf(promptData)}';
                final String promptLabel =
                    promptData['label'] as String? ?? 'Scenario';
                final feedbackForThisPrompt =
                    widget.aiFeedbackData![promptName] as Map<String, dynamic>?;

                // Try to get user answer from controller first (if they just submitted)
                // Fallback to data from parent if it's a previously loaded attempt
                String userAnswer =
                    _textControllers[promptName]?.text.trim() ?? '';
                if (userAnswer.isEmpty) {
                  // This key 'scenarioAnswers_L2_1' must match what module2.dart sets in _aiFeedbackForCurrentLessonAttempt
                  // when re-displaying feedback for a previous attempt.
                  // For now, we directly access the feedback map for answers if available from parent.
                  // A more robust way would be for module2.dart to also pass down the user answers for the attempt being displayed.
                  final Map<String, dynamic>? allAnswersFromParent =
                      widget.aiFeedbackData!['scenarioAnswers_L2_1']
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
                              // Defined at the bottom of this file
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
              }),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    // Signal parent (module2.dart) to reset for a new attempt
                    // This will set showActivitySection=true, displayFeedback=false
                    // and potentially update initialAttemptNumber in module2.dart
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

// Definition of HtmlFormattedText (as provided in your original lesson2_1.dart and lesson2_3.dart)
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
        .replaceAll('<strong>', '') // Simple removal for bold
        .replaceAll('</strong>', '')
        .replaceAll('<h4>', '')
        .replaceAll('</h4>', '\n') // Add newline after h4
        .replaceAll('<ul>', '')
        .replaceAll('</ul>', '')
        .replaceAll('<li>', '• ') // Simple bullet point
        .replaceAll('</li>', '\n')
        .replaceAll(RegExp(r'<span.*?>'), '') // Remove span tags
        .replaceAll('</span>', '')
        // Handle specific formatting like "📚 Vocabulary Used:" or "💡 Tip:"
        .replaceAllMapped(RegExp(r'(📚 Vocabulary Used:|💡 Tip:)\s*'),
            (match) => '\n${match.group(1)}\n  ') // Add newlines and indent
        .replaceAllMapped(
            RegExp(
                r'(- Greeting Appropriateness:|- Self-introduction Clarity:|- Tone and Politeness:|- Grammar Accuracy:|- Suggestion for Improvement:)\s*'),
            (match) => '\n${match.group(1)}\n  ') // Add newlines and indent
        .replaceAll(RegExp(r'<[^>]*>'), ''); // Basic catch-all for other tags

    // Trim leading/trailing newlines that might result from replacements
    // and ensure paragraphs are separated by a single newline, trim whitespace from lines.
    displayText = displayText
        .trim()
        .split('\n')
        .map((s) => s.trim()) // Trim each line
        .where((s) => s.isNotEmpty) // Remove empty lines
        .join('\n'); // Join back with single newlines

    return Text(displayText,
        style: const TextStyle(fontSize: 14, height: 1.5)); // Added line height
  }
}
