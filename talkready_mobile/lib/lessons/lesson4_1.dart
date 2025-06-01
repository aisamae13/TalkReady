import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:logger/logger.dart';
import '../lessons/common_widgets.dart'; // Assuming buildSlide and HtmlFormattedText are here
import 'dart:async';
import '../firebase_service.dart';

// Data structure for AI feedback for a single scenario
class ScenarioFeedback {
  final String text;
  final double? score; // AI score for the scenario (e.g., out of 2.5)

  ScenarioFeedback({required this.text, this.score});

  factory ScenarioFeedback.fromJson(Map<String, dynamic> json) {
    return ScenarioFeedback(
      text: json['text'] as String? ?? 'No feedback text.',
      score: (json['score'] as num?)?.toDouble(),
    );
  }
}

class buildLesson4_1 extends StatefulWidget {
  final int currentSlide; // Still passed by module4.dart
  final CarouselSliderController
      carouselController; // Still passed by module4.dart
  final YoutubePlayerController?
      youtubeController; // Still passed by module4.dart (nullable)
  final int initialAttemptNumber; // Still passed by module4.dart
  final Function(int) onSlideChanged; // Still passed by module4.dart

  // NEW Props based on image_44a717.png and previous refactor plan
  final bool showActivityInitially; // From module4.dart
  final VoidCallback onShowActivitySection; // From module4.dart

  final Future<Map<String, dynamic>?> Function({
    required Map<String, String> scenarioAnswers,
    // lessonId can be implicit if the handler in module4.dart is specific to L4.1
    required String lessonId,
  }) onEvaluateScenarios;

  final Future<void> Function({
    required String lessonIdFirestoreKey, // e.g., "Lesson 4.1"
    required int attemptNumber,
    required int timeSpent,
    required Map<String, String> scenarioResponses,
    required Map<String, dynamic> aiFeedbackForScenarios,
    required double overallAIScore,
    Map<String, String>? reflectionResponses,
    required bool isUpdate,
  }) onSaveAttempt;

  final Future<void> Function({
    required String lessonIdFirestoreKey,
    required int attemptNumber,
    required Map<String, String> submittedScenarioResponses,
    required Map<String, dynamic> aiFeedbackForScenarios,
    required double originalOverallAIScore,
    required Map<String, String> reflectionResponses,
  }) onSaveReflection;

  // REMOVE old/unused props if they were for a different (e.g., MCQ) structure:
  // final BuildContext context; // No longer passed if not needed directly
  // final bool showActivity; // Replaced by showActivityInitially if semantics differ
  // final List<List<String>> selectedAnswers;
  // final List<bool?> isCorrectStates;
  // final List<String?> errorMessages;
  // final Function(int, bool) onAnswerChanged;
  // final Function(List<Map<String, dynamic>> questionsData, int timeSpent, int attemptNumber) onSubmitAnswers;
  // final Function(int questionIndex, List<String> selectedWords) onWordsSelected;

  const buildLesson4_1({
    super.key,
    required this.currentSlide,
    required this.carouselController,
    this.youtubeController, // Nullable
    required this.initialAttemptNumber,
    required this.onSlideChanged,
    required this.showActivityInitially, // Added
    required this.onShowActivitySection, // Added
    required this.onEvaluateScenarios, // Added
    required this.onSaveAttempt, // Added
    required this.onSaveReflection, // Added
  });

  @override
  _Lesson4_1State createState() => _Lesson4_1State();
}

class _Lesson4_1State extends State<buildLesson4_1> {
  final FirebaseService _firebaseService = FirebaseService();
  final Logger _logger = Logger();
  bool _isStudied = false; // Tracks if user has gone through study material
  bool _showActivityArea = false; // True when activity or results are shown
  bool _showResultsView = false; // True when AI feedback is displayed
  bool _isLoadingAI = false;
  Timer? _timer;
  int _secondsElapsed = 0;
  late int _currentAttemptNumberForUI; // UI display: initialAttemptNumber + 1

  // State for scenario and reflection responses
  final Map<String, TextEditingController> _textControllers = {};
  final List<String> _scenarioKeys = [
    'scenario1',
    'scenario2',
    'scenario3',
    'scenario4'
  ];
  final List<String> _reflectionKeys = [
    'reflection1',
    'reflection2',
    'reflection3'
  ];

  // State for AI feedback and scores
  Map<String, ScenarioFeedback> _aiFeedbackForScenarios = {};
  double? _overallAIScore; // e.g., out of 10
  final double _maxPossibleAIScorePerScenario = 2.5; // As per Lesson4.1.jsx

  bool _showReflectionForm = false;
  bool _reflectionSubmitted = false;
  Map<String, String>? _submittedScenarioResponsesForDisplay;

  // Slides based on Lesson4.1.jsx content
  final List<Map<String, dynamic>> _slides = [
    {
      'title': 'Objective',
      'content':
          '• Use polite and professional phrases to ask customers to repeat or clarify information.\n• Respond naturally when you don’t understand a customer during a call.\n• Practice these skills in simulated role-play conversations.',
    },
    {
      'title': 'Why Clarification Matters',
      'content':
          'In a call center, background noise, unclear speech, or unfamiliar accents can make it hard to understand the customer. Agents must ask for clarification politely and confidently to ensure accuracy and professionalism.\n\n• Ensures accurate understanding of the issue.\n• Prevents costly mistakes.\n• Builds trust through respectful communication.',
    },
    {
      'title': 'Key Phrases for Clarification',
      'content': // Using HTML for table structure
          '<table><thead><tr><th>Situation</th><th>Clarification Phrase</th></tr></thead><tbody>'
              '<tr><td>Didn’t catch what was said</td><td>“Sorry, can you say that again?”</td></tr>'
              '<tr><td>Didn’t understand fully</td><td>“I didn’t quite get that. Could you repeat it?”</td></tr>'
              '<tr><td>Need spelling</td><td>“Could you spell that for me, please?”</td></tr>'
              '<tr><td>Need to confirm detail</td><td>“Just to confirm, did you say [repeat info]?”</td></tr>'
              '<tr><td>Need more info</td><td>“Could you explain that a little more?”</td></tr>'
              '<tr><td>Heard multiple things</td><td>“Could you clarify what you meant by...?”</td></tr></tbody></table>',
    },
    {
      'title':
          'Call Center Examples', // Combined with Video slide in JSX, but can be separate
      'content': '• <strong>Customer:</strong> “I’m calling about the problem with my serv—”<br /><strong>Agent:</strong> “I’m sorry, could you repeat that last part?”\n\n'
          '• <strong>Customer:</strong> “My email is jen_matsuba87@gmail.com.”<br /><strong>Agent:</strong> “Could you spell that for me to make sure I got it right?”\n\n'
          '• <strong>Customer:</strong> “I placed the order on the 15th.”<br /><strong>Agent:</strong> “Just to confirm — you placed the order on March 15th, correct?”',
    },
    {
      'title': 'Lesson Summary',
      'content':
          'Asking for clarification politely and effectively is crucial in call center environments. These strategies help ensure clear understanding, build trust, and prevent mistakes. With practice, these techniques will become natural, enhancing your confidence and communication skills.',
    },
  ];

  final List<Map<String, String>> _rolePlayScenarios = [
    {
      'key': 'scenario1',
      'text':
          '“Yes, my order was… [muffled] … and I need to change the delivery.”'
    },
    {'key': 'scenario2', 'text': '“My email is zlaytsev_b12@yahoo.com.”'},
    {'key': 'scenario3', 'text': '“The item number is 47823A.”'},
    {
      'key': 'scenario4',
      'text':
          '“Yeah I called yesterday and they said it’d be fixed in two days but it’s not.”'
    },
  ]; //

  final List<Map<String, String>> _reflectionQuestions = [
    {
      'key': 'reflection1',
      'question':
          'Which phrases for clarification felt most natural for you to imagine saying?'
    },
    {
      'key': 'reflection2',
      'question':
          'Which clarification situations or phrases do you think would be most challenging in a real call?'
    },
    {
      'key': 'reflection3',
      'question':
          'How important do you think tone of voice is when asking for clarification, and why?'
    },
  ]; //

  @override
  void initState() {
    super.initState();
    _currentAttemptNumberForUI = widget.initialAttemptNumber + 1;
    _isStudied = widget.showActivityInitially;
    _showActivityArea = widget.showActivityInitially;

    // Initialize TextControllers
    for (var scenario in _rolePlayScenarios) {
      _textControllers[scenario['key']!] = TextEditingController();
    }
    for (var reflection in _reflectionQuestions) {
      _textControllers[reflection['key']!] = TextEditingController();
    }

    if (_showActivityArea && !_showResultsView) {
      // if starting directly in activity
      _startTimer();
    }
  }

  void _videoListener() {
    // No explicit _videoFinished state needed if "Proceed to Activity" button is tied to onShowActivity prop
  }

  @override
  void didUpdateWidget(covariant buildLesson4_1 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialAttemptNumber != oldWidget.initialAttemptNumber) {
      _currentAttemptNumberForUI = widget.initialAttemptNumber + 1;
      if (widget.showActivityInitially && !_showResultsView) {
        _prepareForNewAttempt(); // Reset if attempt number changes and we are in activity mode
      }
    }
    if (widget.showActivityInitially && !oldWidget.showActivityInitially) {
      _logger.i(
          "L4.1: showActivitySectionInitially became true. Preparing new attempt.");
      _isStudied = true;
      _showActivityArea = true;
      _prepareForNewAttempt();
    }
  }

  void _prepareForNewAttempt() {
    _textControllers.forEach((key, controller) => controller.clear());
    if (mounted) {
      setState(() {
        _aiFeedbackForScenarios = {};
        _overallAIScore = null;
        _showResultsView = false;
        _secondsElapsed = 0;
        _showReflectionForm = false;
        _reflectionSubmitted = false;
        _submittedScenarioResponsesForDisplay = null;
        _startTimer();
      });
    }
  }

  void _startTimer() {
    _stopTimer();
    _secondsElapsed = 0; // Reset timer for each new attempt start
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _secondsElapsed++);
    });
  }

  void _stopTimer() {
    _timer?.cancel();
  }

  String _formatDuration(int totalSeconds) {
    final duration = Duration(seconds: totalSeconds);
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _handleSubmitScenarios() async {
    if (_isLoadingAI || _showResultsView) return;

    final currentScenarioResponses = <String, String>{};
    bool allScenariosAnswered = true;
    for (var scenario in _rolePlayScenarios) {
      final key = scenario['key']!;
      currentScenarioResponses[key] = _textControllers[key]!.text.trim();
      if (currentScenarioResponses[key]!.isEmpty) {
        allScenariosAnswered = false;
        break;
      }
    }

    if (!allScenariosAnswered) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please provide a response for all scenarios.')),
      );
      return;
    }

    // >>> START OF NEW LOGIC TO DETERMINE CORRECT ATTEMPT NUMBER <<<
    String? userId = _firebaseService.userId;
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User not authenticated.')));
      }
      return;
    }

    setState(() => _isLoadingAI = true); // Set loading early

    List<dynamic> pastDetailedAttempts = [];
    try {
      // Fetch detailed attempts specifically for "Lesson 4.1"
      pastDetailedAttempts =
          await _firebaseService.getDetailedLessonAttempts("Lesson 4.1");
    } catch (e) {
      _logger.e("Error fetching past detailed attempts for Lesson 4.1: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Could not verify past attempts. Please try again.')));
        setState(() => _isLoadingAI = false);
      }
      return;
    }

    final int actualNextAttemptNumber = pastDetailedAttempts.length + 1;
    // >>> END OF NEW LOGIC <<<

    // Keep _submittedScenarioResponsesForDisplay if you use it for UI recap before reflections
    if (mounted) {
      setState(() {
        // _isLoadingAI = true; // Moved up
        _submittedScenarioResponsesForDisplay =
            Map.from(currentScenarioResponses);
      });
    }
    _stopTimer(); // Stop timer before async AI call

    try {
      final result = await widget.onEvaluateScenarios(
        scenarioAnswers: currentScenarioResponses,
        lessonId:
            '4.1', // As per your onEvaluateScenarios signature in module4.dart
      );

      if (!mounted) return;

      if (result != null && result['error'] == null) {
        final Map<String, ScenarioFeedback> parsedFeedback = {};
        if (result['aiFeedbackForScenarios'] is Map) {
          (result['aiFeedbackForScenarios'] as Map).forEach((key, value) {
            if (value is Map) {
              parsedFeedback[key] =
                  ScenarioFeedback.fromJson(value.cast<String, dynamic>());
            }
          });
        }

        // Calculate overallAIScore based on parsedFeedback from AI
        double tempOverallAIScore = 0;
        int evaluatedCount = 0;
        parsedFeedback.forEach((key, feedbackEntry) {
          if (feedbackEntry.score != null) {
            tempOverallAIScore += feedbackEntry.score!;
            evaluatedCount++;
          }
        });
        double finalOverallAIScore = 0;
        if (evaluatedCount > 0) {
          // Assuming each scenario score from AI (e.g., out of 2.5) sums up to a total (e.g., out of 10)
          // If result['overallAIScore'] is provided by the backend, use that directly.
          // Otherwise, if result['overallAIScore'] is the sum (e.g., 0-10), use it:
          finalOverallAIScore =
              (result['overallAIScore'] as num?)?.toDouble() ??
                  tempOverallAIScore;
        }

        if (mounted) {
          setState(() {
            _aiFeedbackForScenarios = parsedFeedback;
            _overallAIScore = finalOverallAIScore;
            _showResultsView = true;
            _showReflectionForm = true;
          });
        }

        // VVV USE actualNextAttemptNumber FOR SAVING VVV
        await widget.onSaveAttempt(
          lessonIdFirestoreKey: "Lesson 4.1",
          attemptNumber:
              actualNextAttemptNumber, // Use the correctly calculated number
          timeSpent: _secondsElapsed,
          scenarioResponses: currentScenarioResponses,
          aiFeedbackForScenarios:
              result['aiFeedbackForScenarios'] ?? {}, // Raw feedback from API
          overallAIScore: _overallAIScore ?? 0.0,
          reflectionResponses: {}, // Reflections are empty at this stage
          isUpdate: false,
        );

        // Update UI attempt number state after successful save
        if (mounted) {
          setState(() {
            _currentAttemptNumberForUI = actualNextAttemptNumber;
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Error evaluating scenarios: ${result?['error'] ?? 'Unknown error'}')),
          );
          setState(() {
            _submittedScenarioResponsesForDisplay = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exception evaluating scenarios: $e')),
        );
        setState(() {
          _submittedScenarioResponsesForDisplay = null;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingAI = false);
    }
  }

  Future<void> _handleSubmitReflection() async {
    if (_isLoadingAI || _reflectionSubmitted) return;

    final currentReflectionResponses = <String, String>{};
    bool anyReflectionFilled = false;
    for (var reflection in _reflectionQuestions) {
      final key = reflection['key']!;
      currentReflectionResponses[key] = _textControllers[key]!.text.trim();
      if (currentReflectionResponses[key]!.isNotEmpty) {
        anyReflectionFilled = true;
      }
    }

    if (!anyReflectionFilled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Please fill in at least one reflection field to submit, or click Skip Reflection.')),
      );
      return;
    }

    setState(() => _isLoadingAI = true);

    try {
      await widget.onSaveAttempt(
        lessonIdFirestoreKey: "Lesson 4.1",
        attemptNumber: _currentAttemptNumberForUI,
        timeSpent: -1, // Or manage time differently for reflection updates
        scenarioResponses: _submittedScenarioResponsesForDisplay ?? {},
        aiFeedbackForScenarios: _aiFeedbackForScenarios.map((key, value) =>
            MapEntry(key, {'text': value.text, 'score': value.score})),
        overallAIScore: _overallAIScore ?? 0.0,
        reflectionResponses: currentReflectionResponses,
        isUpdate: true, // Crucial: This is an update to the existing attempt
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reflection submitted successfully!')),
      );
      setState(() {
        _reflectionSubmitted = true;
        _showReflectionForm = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exception submitting reflection: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingAI = false);
    }
  }

  void _handleSkipReflection() {
    setState(() {
      _reflectionSubmitted = true; // Mark as "done" with reflection phase
      _showReflectionForm = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reflection skipped for this attempt.')),
    );
  }

  @override
  void dispose() {
    _textControllers.forEach((_, controller) => controller.dispose());
    widget.youtubeController?.removeListener(_videoListener);
    _stopTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (!_isStudied && !widget.showActivityInitially) {
      // --- Study Phase ---
      content = Column(
        children: [
          // Study Material Carousel
          CarouselSlider(
            carouselController: widget.carouselController,
            items: _slides
                .map((slide) => buildSlide(
                      title: slide['title'] as String,
                      content: slide['content']
                          as String, // Corrected based on common_widgets.dart
                      slideIndex: _slides.indexOf(slide),
                    ))
                .toList(),
            options: CarouselOptions(
              height: 250.0,
              enlargeCenterPage: false,
              enableInfiniteScroll: false,
              initialPage: widget.currentSlide,
              // MODIFICATION HERE:
              onPageChanged: (index, reason) {
                // Accept both parameters from CarouselSlider
                widget.onSlideChanged(
                    index); // Call your prop with only the index
              },
              viewportFraction: 0.95,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _slides.asMap().entries.map((entry) {
              return GestureDetector(
                onTap: () => widget.carouselController.animateToPage(entry.key),
                child: Container(
                  width: 8.0,
                  height: 8.0,
                  margin: const EdgeInsets.symmetric(
                      vertical: 10.0, horizontal: 2.0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.currentSlide == entry.key
                        ? Theme.of(context).primaryColor
                        : Colors.grey,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // Video Player (Only show on a specific slide, e.g., the last one or a dedicated video slide)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Text("Watch: Asking for Clarification",
                style: Theme.of(context).textTheme.titleLarge),
          ),
          SizedBox(
            height: 250, // Adjust height
            child: YoutubePlayer(
              controller: widget.youtubeController!,
              showVideoProgressIndicator: true,
              onReady: () => _logger.i("L4.1 YT Player Ready"),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => setState(() {
              _isStudied = true;
              _showActivityArea = true;
              _prepareForNewAttempt(); // This will also start the timer
            }),
            child: const Text("I've Finished Studying – Proceed to Activity"),
          ),
        ],
      );
    } else if (_showActivityArea) {
      if (!_showResultsView) {
        // --- Activity Input Phase ---
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Activity: Clarification Role-Play',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(color: Colors.orange)),
            Text('Attempt Number: $_currentAttemptNumberForUI',
                style: Theme.of(context).textTheme.titleMedium),
            Text('Time Elapsed: ${_formatDuration(_secondsElapsed)}',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Text(
                "Instructions: For each scenario, type your best clarification response.",
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 10),
            ..._rolePlayScenarios.map((scenario) {
              final key = scenario['key']!;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Scenario: Customer says: \"${scenario['text']}\"",
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _textControllers[key],
                      decoration: InputDecoration(
                        hintText: 'Your clarification response...',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      maxLines: 3,
                      enabled: !_isLoadingAI,
                    ),
                  ],
                ),
              );
            }).toList(),
            const SizedBox(height: 20),
            _isLoadingAI
                ? const Center(child: CircularProgressIndicator())
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _handleSubmitScenarios,
                      child: const Text('Submit Scenario Responses'),
                    ),
                  ),
          ],
        );
      } else {
        // --- Results and Reflection Phase ---
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Feedback on Your Scenario Responses',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(color: Colors.green)),
            if (_overallAIScore != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  "Your Total AI Score for Scenarios: ${_overallAIScore?.toStringAsFixed(1)} / 10.0",
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(color: Colors.purple),
                ),
              ),
            ..._rolePlayScenarios.map((scenario) {
              final key = scenario['key']!;
              final feedback = _aiFeedbackForScenarios[key];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          "Recap for Scenario: Customer said: \"${scenario['text']}\"",
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      Text(
                          "Your response was: \"${_submittedScenarioResponsesForDisplay?[key] ?? ''}\"",
                          style: const TextStyle(fontStyle: FontStyle.italic)),
                      if (feedback != null)
                        _FeedbackCardWidget(
                            feedback: feedback,
                            maxScore: _maxPossibleAIScorePerScenario)
                      else
                        const Text("Feedback not available for this scenario.",
                            style: TextStyle(fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
              );
            }).toList(),
            if (_showReflectionForm && !_reflectionSubmitted) ...[
              const SizedBox(height: 24),
              Text('Discussion & Reflection (Optional)',
                  style: Theme.of(context).textTheme.headlineSmall),
              ..._reflectionQuestions.map((reflection) {
                final key = reflection['key']!;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(reflection['question']!,
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _textControllers[key],
                        decoration: InputDecoration(
                          hintText: 'Your thoughts... (Optional)',
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        maxLines: 3,
                        enabled: !_isLoadingAI,
                      ),
                    ],
                  ),
                );
              }).toList(),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: _isLoadingAI ? null : _handleSubmitReflection,
                    child: const Text('Submit Reflection'),
                  ),
                  TextButton(
                    onPressed: _isLoadingAI ? null : _handleSkipReflection,
                    child: const Text('Skip Reflection'),
                  ),
                ],
              ),
            ] else if (_reflectionSubmitted) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  (_textControllers['reflection1']!.text.trim().isNotEmpty ||
                          _textControllers['reflection2']!
                              .text
                              .trim()
                              .isNotEmpty ||
                          _textControllers['reflection3']!
                              .text
                              .trim()
                              .isNotEmpty)
                      ? 'Your reflection has been saved!'
                      : 'Reflection skipped for this attempt.',
                  style: TextStyle(
                      color: Colors.green[700], fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  _prepareForNewAttempt();
                  setState(() {
                    _showActivityArea = true; // Stay in activity
                    _showResultsView = false; // Go back to input
                    _currentAttemptNumberForUI++; // Increment UI attempt number for next try
                  });
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('Try Again'),
              ),
            ),
          ],
        );
      }
    } else {
      // Fallback or initial loading state (should be covered by Module4Page's _isContentLoaded)
      content = const Center(child: Text("Loading lesson content..."));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: content,
    );
  }
}

// Placeholder for Feedback Card Widget (similar to JSX)
class _FeedbackCardWidget extends StatelessWidget {
  final ScenarioFeedback feedback;
  final double maxScore;

  const _FeedbackCardWidget({required this.feedback, required this.maxScore});

  @override
  Widget build(BuildContext context) {
    final score = feedback.score ?? 0.0;
    final percentage = maxScore > 0 ? (score / maxScore) * 100 : 0.0;
    Color scoreColor = Colors.red;
    if (percentage >= 80) {
      scoreColor = Colors.green;
    } else if (percentage >= 50) {
      scoreColor = Colors.orange;
    }

    // This parsing is basic. A more robust way is if AI returns structured JSON.
    // The JSX version had more complex regex parsing. For Dart, if the backend
    // can provide structured feedback (e.g., a list of {title, text, icon_hint}), it's better.
    // For now, just display the raw text.
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[50],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "AI Score: ${score.toStringAsFixed(1)} / ${maxScore.toStringAsFixed(1)}",
            style: TextStyle(
                fontWeight: FontWeight.bold, color: scoreColor, fontSize: 16),
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: Colors.grey[300],
            color: scoreColor,
          ),
          const SizedBox(height: 10),
          Text("Detailed Feedback:",
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          HtmlFormattedText(
              htmlString: feedback.text
                  .replaceAll("\n", "<br>")), // Use HtmlFormattedText
        ],
      ),
    );
  }
}
