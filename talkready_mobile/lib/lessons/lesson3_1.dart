// lesson3_1.dart
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:logger/logger.dart';
import 'dart:async';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../lessons/common_widgets.dart';

// ... (ParsedFeedbackCard remains the same) ...
class ParsedFeedbackCard extends StatelessWidget {
  final Map<String, dynamic> feedbackData;
  final String? scenarioLabel;
  const ParsedFeedbackCard(
      {super.key, required this.feedbackData, this.scenarioLabel});

  @override
  Widget build(BuildContext context) {
    final score = feedbackData['score'] ?? 'N/A';
    final text = feedbackData['text'] as String? ?? "No feedback text.";
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (scenarioLabel != null)
              Text(scenarioLabel!,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColorDark)),
            const SizedBox(height: 4),
            Text("AI Score: $score/5",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: (score is num && score >= 3)
                        ? Colors.green.shade700
                        : (score is num && score >= 0)
                            ? Colors.orange.shade800
                            : Colors.grey)),
            const SizedBox(height: 4),
            HtmlFormattedText(htmlString: text),
          ],
        ),
      ),
    );
  }
}

class buildLesson3_1 extends StatefulWidget {
  // ... (Constructor remains the same)
  final BuildContext parentContext;
  final int currentSlide;
  final CarouselSliderController carouselController;
  final YoutubePlayerController youtubeController;
  final Key? youtubePlayerKey;
  final bool showActivitySectionInitially;
  final VoidCallback onShowActivitySection;
  final Function(Map<String, String> userTextAnswers, int timeSpent,
      int attemptNumberForSubmission) onSubmitAnswers;
  final Function(int) onSlideChanged;
  final int initialAttemptNumber;
  final bool displayFeedback;
  final Map<String, dynamic>? aiFeedbackData;
  final int? overallAIScoreForDisplay;
  final int? maxPossibleAIScoreForDisplay;

  const buildLesson3_1({
    super.key,
    required this.parentContext,
    required this.currentSlide,
    required this.carouselController,
    required this.youtubeController,
    this.youtubePlayerKey,
    required this.showActivitySectionInitially,
    required this.onShowActivitySection,
    required this.onSubmitAnswers,
    required this.onSlideChanged,
    required this.initialAttemptNumber,
    required this.displayFeedback,
    this.aiFeedbackData,
    this.overallAIScoreForDisplay,
    this.maxPossibleAIScoreForDisplay,
  });

  @override
  _Lesson3_1State createState() => _Lesson3_1State();
}

class _Lesson3_1State extends State<buildLesson3_1> {
  final Logger _logger = Logger();
  late FlutterTts flutterTts;
  List<dynamic> _voices = []; // To store available voices
  Map<String, String>? _selectedVoice; // To store the voice map for setting

  // ... (other state variables: _videoFinished, _isSubmitting, etc. remain the same) ...
  bool _videoFinished = false;
  bool _isSubmitting = false;
  Timer? _timer;
  int _secondsElapsed = 0;
  late int _currentAttemptForDisplay;
  bool _isLoadingLessonContent = true;
  Map<String, dynamic>? _lessonData;
  late Map<String, TextEditingController> _textControllers;
  Map<int, bool> _showTranscriptFor = {};
  final List<String> _questionLabels = [
    "What was the customer’s issue?",
    "What information did the agent ask for?",
    "What solution did the agent offer?",
    "Was the customer satisfied with the response? (e.g., Yes/No, and why)"
  ];
  final List<Map<String, dynamic>> _staticSlidesDataFallback = [
    {'title': 'Objective (Fallback)', 'content': 'Listen and comprehend.'},
  ];

  @override
  void initState() {
    super.initState();
    flutterTts = FlutterTts();
    _initializeAndConfigureTts();

    _currentAttemptForDisplay = widget.initialAttemptNumber + 1;
    _textControllers = {};
    _fetchLessonContentAndInitialize();
    widget.youtubeController.addListener(_videoListener);

    if (widget.showActivitySectionInitially && !widget.displayFeedback) {
      _startTimer();
    }
  }

  Future<void> _initializeAndConfigureTts() async {
    // Get available voices first
    try {
      var voices = await flutterTts.getVoices;
      if (voices != null && voices is List && mounted) {
        setState(() {
          _voices = voices;
        });
        _logger.i("Available TTS Voices: $_voices");
        // Now try to select and set a desired voice
        _setDesiredVoice(
            "en-GB"); // Example: Try to set a British English voice
      }
    } catch (e) {
      _logger.e("Error getting TTS voices: $e");
    }

    // Set general TTS properties
    try {
      await flutterTts.setSpeechRate(0.45);
      await flutterTts.setVolume(1.0);
      await flutterTts.setPitch(1.0);
    } catch (e) {
      _logger.e("Error setting basic TTS properties: $e");
    }
  }

  Future<void> _configureTts() async {
    try {
      await flutterTts
          .stop(); // Stop any ongoing speech before changing settings

      // 1. Set the base language (still important as it can affect pronunciation rules)
      // Even if the accent doesn't change, this helps the TTS engine know how to interpret words.
      // For example, for general clarity, "en-US" is often a good default if specific accents aren't working.
      await flutterTts
          .setLanguage("en-US"); // Or your preferred base English locale

      // 2. Adjust Speech Rate for Clarity
      // Rate is typically 0.0 (slowest) to 1.0 (normal). Values up to 2.0 might be possible.
      // Slower rates (e.g., 0.4 to 0.5) can make speech easier to understand.
      // Experiment to find what sounds best.
      await flutterTts.setSpeechRate(0.5); // Example: A bit slower than normal

      // 3. Adjust Pitch (Optional - can make it sound less robotic or different)
      // Pitch is typically 0.5 (lower) to 2.0 (higher), with 1.0 being normal.
      // Minor adjustments can sometimes improve naturalness.
      await flutterTts.setPitch(0.5); // Example: Normal pitch

      // 4. Ensure Volume is adequate
      await flutterTts.setVolume(1.0); // Max volume

      _logger
          .i("L3.1: Flutter TTS configured with rate and pitch adjustments.");
    } catch (e) {
      _logger.e("L3.1: Error configuring TTS settings: $e");
    }
  }

  Future<void> _setDesiredVoice(String targetLocalePrefix) async {
    // Example: targetLocalePrefix = "en-GB"
    Map<String, String>? foundVoice;
    for (var voiceDyn in _voices) {
      if (voiceDyn is Map) {
        // Convert Map<dynamic, dynamic> to Map<String, String>
        final voiceMap = Map<String, String>.from(
            voiceDyn.map((k, v) => MapEntry(k.toString(), v.toString())));
        final String? locale = voiceMap['locale']?.toLowerCase();
        // final String? name = voiceMap['name']?.toLowerCase(); // You can also filter by name if known

        if (locale != null &&
            locale.startsWith(targetLocalePrefix.toLowerCase())) {
          // Prefer voices that are not network-based if possible, or specific names
          // For simplicity, we take the first one found for the locale.
          foundVoice = voiceMap;
          _logger.i(
              "Found matching voice for locale $targetLocalePrefix: $foundVoice");
          break;
        }
      }
    }

    if (foundVoice != null) {
      try {
        await flutterTts.setVoice(foundVoice);
        setState(() {
          _selectedVoice = foundVoice;
        });
        _logger.i("L3.1: Successfully set TTS Voice to: $foundVoice");
      } catch (e) {
        _logger.e(
            "L3.1: Error setting specific voice $foundVoice: $e. Will try setLanguage as fallback.");
        // Fallback to setLanguage if setVoice fails or specific voice isn't perfect
        await _setLanguageFallback(targetLocalePrefix);
      }
    } else {
      _logger.w(
          "L3.1: No specific voice found for locale '$targetLocalePrefix'. Using setLanguage as fallback.");
      await _setLanguageFallback(targetLocalePrefix);
    }
  }

  Future<void> _setLanguageFallback(String languageCode) async {
    try {
      await flutterTts.setLanguage(languageCode);
      _logger.i("L3.1: TTS Language set to $languageCode as a fallback.");
    } catch (e) {
      _logger
          .e("L3.1: Error setting TTS language $languageCode as fallback: $e");
    }
  }

  Future<void> _fetchLessonContentAndInitialize() async {
    /* ... remains the same ... */
    setState(() => _isLoadingLessonContent = true);
    await Future.delayed(const Duration(milliseconds: 50));

    final Map<String, dynamic> hardcodedData = {
      'lessonTitle':
          'Lesson 3.1: Listening Comprehension – Understanding Customer Calls',
      'slides': [
        {
          'title': 'Objective',
          'content': 'To develop effective listening comprehension skills...'
        },
        {
          'title': 'Introduction',
          'content': 'Effective listening is more than just hearing words...'
        },
        {
          'title': 'Watch: Mastering Active Listening',
          'content':
              'The following video explains active listening techniques...'
        },
        {
          'title': 'Key Takeaways',
          'content':
              '• Active listening involves focusing on both verbal and non-verbal cues...'
        },
      ],
      'video': {'url': 'nMC16FZhsUM'},
      'activity': {
        'title': 'Listening Activity',
        'instructions':
            'Listen to each call script carefully, then answer the questions based on what you heard.',
        'scripts': {
          '1':
              "Customer: Hi, I received the wrong item in my order. Agent: I'm really sorry about that. Can you please provide the order number? Customer: It's 784512. Agent: Thank you. I’ll arrange a replacement right away. Customer: Thanks.",
          '2':
              "Customer: My internet has been disconnected for two days. Agent: I apologize for the inconvenience. Can I have your account ID? Customer: Sure, it's 56102. Agent: I’ve reported the issue and a technician will visit tomorrow. Customer: Great, thanks.",
          '3':
              "Customer: I was charged twice for the same bill. Agent: I see. Can I verify your billing date and amount? Customer: April 3rd, \$39.99. Agent: I’ll process the refund today. Customer: Thank you.",
        },
      },
    };
    _lessonData = hardcodedData;
    _initializeTextControllers();
    _logger.i("L3.1: Hardcoded content loaded.");
    if (mounted) setState(() => _isLoadingLessonContent = false);
  }

  void _initializeTextControllers() {
    /* ... remains the same ... */
    _textControllers.forEach((_, controller) => controller.dispose());
    _textControllers.clear();
    for (int callNum = 1; callNum <= 3; callNum++) {
      for (int qNum = 1; qNum <= 4; qNum++) {
        _textControllers['call${callNum}_q${qNum}'] = TextEditingController();
      }
      _showTranscriptFor[callNum] = false;
    }
  }

  // Your _playScript method will then use these settings:
  Future<void> _playScript(String scriptText) async {
    try {
      await flutterTts.stop();
      // The settings applied in _configureTts should persist for subsequent .speak() calls.
      // However, some platforms might reset some settings. If you find settings are not sticking,
      // you might need to re-apply rate/pitch/language directly before each speak call,
      // though this is usually not necessary if configured once after initialization.
      // Example:
      // await flutterTts.setSpeechRate(0.45);

      int result = await flutterTts.speak(scriptText);
      if (result == 1) {
        // 1 indicates success
        _logger.i("L3.1: TTS speaking script.");
      } else {
        _logger.w("L3.1: TTS speak command failed.");
      }
    } catch (e) {
      _logger.e("L3.1: Error during TTS speak: $e");
    }
  }

  @override
  void didUpdateWidget(covariant buildLesson3_1 oldWidget) {
    /* ... same as before ... */
    super.didUpdateWidget(oldWidget);
    if (widget.youtubeController != oldWidget.youtubeController) {
      oldWidget.youtubeController.removeListener(_videoListener);
      widget.youtubeController.addListener(_videoListener);
    }
    if (widget.showActivitySectionInitially &&
        !oldWidget.showActivitySectionInitially &&
        !widget.displayFeedback) {
      _logger.i("L3.1 didUpdateWidget: Resetting for new attempt.");
      _currentAttemptForDisplay = widget.initialAttemptNumber + 1;
      _textControllers.forEach((_, controller) => controller.clear());
      _showTranscriptFor.updateAll((key, value) => false);
      _resetTimer();
      _startTimer();
    } else if (!widget.showActivitySectionInitially &&
        oldWidget.showActivitySectionInitially) {
      _stopTimer();
    }
    if (widget.displayFeedback &&
        !oldWidget.displayFeedback &&
        _timer?.isActive == true) {
      _logger.i(
          "L3.1 didUpdateWidget: displayFeedback became true. Stopping timer.");
      _stopTimer();
    }
    if (widget.initialAttemptNumber != oldWidget.initialAttemptNumber &&
        widget.showActivitySectionInitially &&
        !widget.displayFeedback) {
      _logger.i(
          "L3.1 didUpdateWidget: initialAttemptNumber changed. Resetting for new attempt.");
      _currentAttemptForDisplay = widget.initialAttemptNumber + 1;
      _textControllers.forEach((_, controller) => controller.clear());
      _showTranscriptFor.updateAll((key, value) => false);
      _resetTimer();
      _startTimer();
    }
  }

  @override
  void dispose() {
    // ... (youtube listener, text controllers, timer disposals remain the same) ...
    widget.youtubeController.removeListener(_videoListener);
    _textControllers.forEach((_, controller) => controller.dispose());
    _stopTimer();
    flutterTts.stop();
    _logger.i("L3.1: Disposed");
    super.dispose();
  }

  void _videoListener() {
    /* ... same as before ... */
    if (widget.youtubeController.value.playerState == PlayerState.ended &&
        !_videoFinished) {
      if (mounted) setState(() => _videoFinished = true);
      _logger.i('L3.1 Video finished.');
    }
  }

  void _startTimer() {
    /* ... same as before ... */
    _stopTimer();
    _secondsElapsed = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _secondsElapsed++);
    });
    _logger.i('L3.1 Timer started. Attempt: $_currentAttemptForDisplay.');
  }

  void _stopTimer() {
    /* ... same as before ... */
    _timer?.cancel();
    _logger.i('L3.1 Timer stopped. Elapsed: $_secondsElapsed s.');
  }

  void _resetTimer() {
    /* ... same as before ... */ if (mounted)
      setState(() => _secondsElapsed = 0);
  }

  String _formatDuration(int totalSeconds) {
    /* ... same as before ... */
    final duration = Duration(seconds: totalSeconds);
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _handleSubmit() async {
    /* ... same as before ... */
    if (!mounted) return;
    _logger.i("L3.1: Submit button pressed.");

    bool allAnswered = !_textControllers.values
        .any((controller) => controller.text.trim().isEmpty);
    if (!allAnswered) {
      ScaffoldMessenger.of(widget.parentContext).showSnackBar(
          const SnackBar(content: Text('Please answer all questions.')));
      return;
    }
    setState(() => _isSubmitting = true);
    _stopTimer();
    Map<String, String> currentAnswers = {};
    _textControllers.forEach((key, controller) {
      currentAnswers[key] = controller.text.trim();
    });
    await widget.onSubmitAnswers(
        currentAnswers, _secondsElapsed, widget.initialAttemptNumber + 1);
    if (mounted) setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    /* ... Your existing build method structure remains the same ... */
    if (_isLoadingLessonContent || _lessonData == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final String lessonTitle =
        _lessonData!['lessonTitle'] as String? ?? 'Lesson 3.1';
    List<dynamic> slides =
        _lessonData!['slides'] as List<dynamic>? ?? _staticSlidesDataFallback;
    if (slides.isEmpty) slides = _staticSlidesDataFallback;

    final String activityTitle =
        _lessonData!['activity']?['title'] as String? ?? 'Activity';
    final String activityInstructions =
        _lessonData!['activity']?['instructions'] as String? ?? '';
    final Map<String, dynamic> activityScripts =
        _lessonData!['activity']?['scripts'] as Map<String, dynamic>? ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(lessonTitle,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF00568D), fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (!widget.showActivitySectionInitially || !widget.displayFeedback)
            CarouselSlider(
              /* ... existing Carousel for slides ... */
              key: ValueKey('carousel_l3_1_${slides.hashCode}'),
              carouselController: widget.carouselController,
              items: slides
                  .map((slide) => buildSlide(
                        title: slide['title'] as String? ?? 'Slide',
                        content: slide['content'] as String? ?? '',
                        slideIndex: slides.indexOf(slide),
                      ))
                  .toList(),
              options: CarouselOptions(
                height: 250.0,
                viewportFraction: 0.9,
                enlargeCenterPage: false,
                enableInfiniteScroll: false,
                initialPage: widget.currentSlide,
                onPageChanged: (index, reason) => widget.onSlideChanged(index),
              ),
            ),
          if (!widget.showActivitySectionInitially || !widget.displayFeedback)
            Row(
              /* ... Carousel dots ... */
              mainAxisAlignment: MainAxisAlignment.center,
              children: slides.asMap().entries.map((entry) {
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
                            : Colors.grey),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 16),
          if (widget.currentSlide >= slides.length - 1 ||
              widget.showActivitySectionInitially) ...[
            if (!widget.showActivitySectionInitially ||
                !widget.displayFeedback) ...[
              Text('Watch: Mastering Active Listening',
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
                  onReady: () => _logger.i("L3.1 Player Ready"),
                  onEnded: (_) => _videoListener(),
                ),
              ),
            ],
            if (!widget.showActivitySectionInitially) ...[
              const SizedBox(height: 16),
              SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                      onPressed:
                          _videoFinished ? widget.onShowActivitySection : null,
                      child: const Text('Proceed to Activity'))),
              if (!_videoFinished)
                const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Text('Please watch the video to proceed.',
                        style: TextStyle(color: Colors.red),
                        textAlign: TextAlign.center)),
            ],
          ],
          if (widget.showActivitySectionInitially) ...[
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
              ...List.generate(3, (callIndex) {
                int callNum = callIndex + 1;
                String scriptText =
                    activityScripts[callNum.toString()] as String? ??
                        "Script not found.";
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Call $callNum Scenario",
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold)),
                            TextButton.icon(
                              icon: const FaIcon(FontAwesomeIcons.volumeUp,
                                  size: 16),
                              label: const Text("Play Script"),
                              onPressed: () => _playScript(scriptText),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...List.generate(4, (qIndex) {
                          String questionKey = "call${callNum}_q${qIndex + 1}";
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_questionLabels[qIndex],
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                            color: Theme.of(context)
                                                .primaryColorDark)),
                                const SizedBox(height: 4),
                                TextField(
                                  controller: _textControllers[questionKey],
                                  decoration: InputDecoration(
                                    border: const OutlineInputBorder(),
                                    hintText: "Your answer for Q${qIndex + 1}",
                                    filled: true,
                                    fillColor: Colors.grey[50],
                                  ),
                                  maxLines: 2,
                                ),
                              ],
                            ),
                          );
                        }),
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
                    onPressed: _isSubmitting ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00568D)),
                    child: _isSubmitting
                        ? const CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white))
                        : const Text('Submit All Answers',
                            style:
                                TextStyle(color: Colors.white, fontSize: 16)),
                  )),
            ],
            if (widget.displayFeedback && widget.aiFeedbackData != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                    child: Text(
                        'Overall Score: ${widget.overallAIScoreForDisplay ?? 'N/A'} / ${widget.maxPossibleAIScoreForDisplay ?? (3 * 4 * 5)}',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                                color: Colors.purple,
                                fontWeight: FontWeight.bold))),
              ),
              ...List.generate(activityScripts.keys.length, (callIndex) {
                int callNum = callIndex + 1;
                String scriptKey = callNum.toString();
                String scriptText = activityScripts[scriptKey] as String? ??
                    "Script not found.";
                return ExpansionTile(
                  title: Text("Call $callNum Feedback & Transcript",
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  initiallyExpanded: callIndex == 0,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextButton.icon(
                            icon: FaIcon(
                                _showTranscriptFor[callNum] == true
                                    ? FontAwesomeIcons.eyeSlash
                                    : FontAwesomeIcons.eye,
                                size: 16),
                            label: Text(_showTranscriptFor[callNum] == true
                                ? "Hide Transcript"
                                : "Show Transcript"),
                            onPressed: () {
                              setState(() => _showTranscriptFor[callNum] =
                                  !(_showTranscriptFor[callNum] ?? false));
                            },
                          ),
                          if (_showTranscriptFor[callNum] == true)
                            Container(
                              padding: const EdgeInsets.all(10),
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(4),
                                  border:
                                      Border.all(color: Colors.grey.shade300)),
                              width: double.infinity,
                              child: Text(scriptText,
                                  style: const TextStyle(
                                      fontStyle: FontStyle.italic,
                                      color: Colors.black87,
                                      height: 1.4)),
                            ),
                          const SizedBox(height: 10),
                          ...List.generate(_questionLabels.length, (qIndex) {
                            String questionKey =
                                "call${callNum}_q${qIndex + 1}";
                            final feedbackDataForQuestion =
                                widget.aiFeedbackData![questionKey]
                                        as Map<String, dynamic>? ??
                                    {
                                      'score': 'N/A',
                                      'text': 'Feedback not available.'
                                    };
                            final userAnswer =
                                _textControllers[questionKey]?.text ?? "N/A";
                            return ParsedFeedbackCard(
                                scenarioLabel:
                                    "Q${qIndex + 1}: ${_questionLabels[qIndex]}\nYour Answer: $userAnswer",
                                feedbackData: feedbackDataForQuestion);
                          })
                        ],
                      ),
                    ),
                  ],
                );
              }),
              const SizedBox(height: 24),
              SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                      onPressed: widget.onShowActivitySection,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green),
                      child: const Text('Try Again',
                          style:
                              TextStyle(color: Colors.white, fontSize: 16)))),
            ],
          ],
        ],
      ),
    );
  }
}
