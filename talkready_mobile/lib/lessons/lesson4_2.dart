// lesson4_2.dart
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:logger/logger.dart';
import 'dart:async';
import '../lessons/common_widgets.dart'; // For buildSlide, HtmlFormattedText, buildScenarioPromptWithInput
// For icons, you might need font_awesome_flutter or similar if not using MaterialIcons directly
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../firebase_service.dart';

// Data structure for AI feedback for a single solution
class SolutionFeedback {
  final String text;
  final double? score; // AI score for the solution (e.g., out of 5)

  SolutionFeedback({required this.text, this.score});

  factory SolutionFeedback.fromJson(Map<String, dynamic> json) {
    return SolutionFeedback(
      text: json['text'] as String? ?? 'No feedback text.',
      score: (json['score'] as num?)?.toDouble(),
    );
  }
}

// Feedback Card Widget specific for Lesson 4.2 (inspired by Lesson4.2.jsx)
class FeedbackCardL4_2 extends StatelessWidget {
  final SolutionFeedback scenarioFeedback;
  final double maxScore; // e.g., 5.0 for individual solution

  const FeedbackCardL4_2({
    super.key,
    required this.scenarioFeedback,
    required this.maxScore,
  });

  // Simplified parsing logic based on common patterns in your JSX.
  // A more robust backend would return structured JSON for feedback sections.
  List<Map<String, dynamic>> _parseFeedbackSections(String rawText) {
    final List<Map<String, dynamic>> parsedSections = [];
    final feedbackCategories = [
      {
        "title": "Effectiveness and Appropriateness of Solution",
        "icon": FontAwesomeIcons.bullseye,
        "color": Colors.blue.shade700
      },
      {
        "title": "Clarity and Completeness",
        "icon": FontAwesomeIcons.search,
        "color": Colors.yellow.shade800
      },
      {
        "title": "Professionalism, Tone, and Empathy",
        "icon": FontAwesomeIcons.handsHelping,
        "color": Colors.green.shade700
      },
      {
        "title": "Grammar and Phrasing",
        "icon": FontAwesomeIcons.spellCheck,
        "color": Colors.purple.shade700
      },
      {
        "title": "Overall Actionable Suggestion",
        "icon": FontAwesomeIcons.solidStar,
        "color": Colors.orange.shade700
      },
    ];

    String remainingText = rawText;
    for (var category in feedbackCategories) {
      final titlePattern =
          "**${category['title']}:**"; // Matches " **Category Title:** "
      final regex = RegExp(
          RegExp.escape(titlePattern) + r'([\s\S]*?)(?=\n\*\*|$)',
          caseSensitive: false,
          multiLine: true);
      final match = regex.firstMatch(remainingText);

      if (match != null &&
          match.group(1) != null &&
          match.group(1)!.trim().isNotEmpty) {
        parsedSections.add({
          'Icon': category['icon'],
          'title': category['title'],
          'color': category['color'],
          'text': match.group(1)!.trim(),
        });
        // Attempt to remove the matched part for the next iteration (simplistic)
        remainingText = remainingText.substring(match.end);
      }
    }
    // If no sections were parsed but raw text exists, show it as general feedback
    if (parsedSections.isEmpty && rawText.trim().isNotEmpty) {
      parsedSections.add({
        'Icon': FontAwesomeIcons.infoCircle,
        'title': 'General Feedback',
        'color': Colors.grey.shade700,
        'text': rawText.trim(),
      });
    }
    return parsedSections;
  }

  @override
  Widget build(BuildContext context) {
    final score = scenarioFeedback.score ?? 0.0;
    final percentage = maxScore > 0 ? (score / maxScore) * 100 : 0.0;
    Color scoreColor = Colors.red.shade700;
    if (percentage >= 80)
      scoreColor = Colors.green.shade700;
    else if (percentage >= 50) scoreColor = Colors.orange.shade700;

    final sections = _parseFeedbackSections(scenarioFeedback.text);

    return Container(
      margin: const EdgeInsets.only(top: 8.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8.0),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 3,
              offset: const Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "AI Score: ${score.toStringAsFixed(1)} / ${maxScore.toStringAsFixed(1)}",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: scoreColor,
                    fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 5),
          LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: Colors.grey[300],
            color: scoreColor,
            minHeight: 6,
          ),
          const SizedBox(height: 12),
          if (sections.isEmpty)
            Text("No detailed feedback text.",
                style: TextStyle(
                    fontStyle: FontStyle.italic, color: Colors.grey[600]))
          else
            ...sections.map((section) {
              return Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        FaIcon(section['Icon'] as IconData?,
                            size: 16, color: section['color'] as Color?),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            section['title'] as String,
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: section['color'] as Color?,
                                fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 24.0), // Indent text
                      child: HtmlFormattedText(
                          htmlString: (section['text'] as String)
                              .replaceAll('\n', '<br>')),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }
}

class buildLesson4_2 extends StatefulWidget {
  final int currentSlide;
  final CarouselSliderController carouselController;
  final YoutubePlayerController? youtubeController;
  final int initialAttemptNumber;
  final Function(int) onSlideChanged;
  final bool showActivityInitially;
  final VoidCallback onShowActivitySection;

  final Future<Map<String, dynamic>?> Function({
    required Map<String, String> solutionResponses,
  }) onEvaluateSolutions;

  final Future<void> Function({
    required String lessonIdFirestoreKey,
    required int attemptNumber,
    required int timeSpent,
    required Map<String, String> solutionResponses,
    required Map<String, dynamic> aiSolutionFeedback,
    required double overallAIScore,
    Map<String, String>? reflectionResponses,
    required bool isUpdate,
  }) onSaveAttempt;

  final Future<void> Function({
    required String lessonIdFirestoreKey,
    required int attemptNumber,
    required Map<String, String> submittedSolutionResponses,
    required Map<String, dynamic> aiSolutionFeedback,
    required double originalOverallAIScore,
    required Map<String, String> reflectionResponses,
  }) onSaveReflection;

  const buildLesson4_2({
    super.key,
    required this.currentSlide,
    required this.carouselController,
    this.youtubeController,
    required this.initialAttemptNumber,
    required this.onSlideChanged,
    required this.showActivityInitially,
    required this.onShowActivitySection,
    required this.onEvaluateSolutions,
    required this.onSaveAttempt,
    required this.onSaveReflection,
  });

  @override
  _Lesson4_2State createState() => _Lesson4_2State();
}

class _Lesson4_2State extends State<buildLesson4_2> {
  final FirebaseService _firebaseService = FirebaseService();
  final Logger _logger = Logger();
  bool _isStudied = false;
  bool _showActivityArea = false;
  bool _showResultsView = false;
  bool _isLoadingAI = false;
  Timer? _timer;
  int _secondsElapsed = 0;
  late int _currentAttemptNumberForUI;

  final Map<String, TextEditingController> _textControllers = {};
  final List<Map<String, String>> _solutionPrompts = [
    // From Lesson4.2.jsx
    {
      "name": "solution1",
      "customerProblem": "Customer: “I received the wrong item.”",
      "task":
          "Your Task: Politely acknowledge the issue and propose a clear solution to send the correct item."
    },
    {
      "name": "solution2",
      "customerProblem":
          "Customer: “My order hasn’t arrived yet, and it’s past the estimated delivery date.”",
      "task":
          "Your Task: Apologize for the delay, explain how you will investigate, and offer a potential resolution or next steps."
    },
    {
      "name": "solution3",
      "customerProblem":
          "Customer: “My payment didn’t go through, but I was still charged.”",
      "task":
          "Your Task: Show empathy, explain how you'll check the payment status, and outline how you'll resolve the incorrect charge."
    },
    {
      "name": "solution4",
      "customerProblem":
          "Customer: “I want to cancel my subscription, but I can’t find the option online.”",
      "task":
          "Your Task: Assist the customer by explaining the cancellation process or offering to do it for them, ensuring they understand any implications."
    }
  ];
  final List<Map<String, String>> _reflectionQuestions = [
    // From Lesson4.2.jsx
    {
      "name": "reflection1",
      "question":
          "Which solution prompt did you find most challenging to respond to, and why?"
    },
    {
      "name": "reflection2",
      "question":
          "How confident did you feel in providing clear and effective solutions for these scenarios?"
    },
    {
      "name": "reflection3",
      "question":
          "What is one key aspect of providing a good solution that you will focus on in future interactions?"
    }
  ];

  Map<String, SolutionFeedback> _aiSolutionFeedback = {};
  double?
      _overallAIScore; // Calculated from individual solution scores, scaled 0-10
  final double _maxScorePerSolution =
      5.0; // As per server.js for /evaluate-solutions
  final double _overallDisplayMaxScore = 10.0;

  bool _showReflectionForm = false;
  bool _reflectionSubmitted = false;
  Map<String, String>? _submittedSolutionResponsesForDisplay;

  final List<Map<String, dynamic>> _slides = [
    {
      'title': 'Objective: Providing Solutions',
      'content':
          '• Use polite, helpful phrases to offer solutions to customer concerns.\n• Respond professionally to customer inquiries with empathy and confidence.\n• Practice resolving simple service-related scenarios through simulated calls.'
    },
    {
      'title': 'Why Solution-Oriented Language Matters',
      'content':
          'In a call center, simply listening to the problem is not enough. You must provide clear, confident, and customer-friendly solutions. Customers want reassurance that their issue is being handled.\n\n• Shows understanding and ownership.\n• Improves customer trust and satisfaction.\n• Prevents misunderstandings.'
    },
    {
      'title': 'Key Phrases for Offering Solutions',
      'content':
          '<table><thead><tr><th>Purpose</th><th>Example Phrase</th></tr></thead><tbody><tr><td>Acknowledge issue</td><td>“I understand. Let me take care of that for you.”</td></tr><tr><td>Offer help</td><td>“I can help with that.” / “Let me check that for you.”</td></tr><tr><td>Set expectation</td><td>“This will take a few minutes.”</td></tr><tr><td>Give result or answer</td><td>“I’ve processed your refund successfully.”</td></tr><tr><td>Offer next step</td><td>“You should receive a confirmation email shortly.”</td></tr><tr><td>Ask for confirmation</td><td>“Does that solution work for you?”</td></tr></tbody></table>'
    },
    {
      'title': 'Example Customer Service Dialogues',
      'content':
          '<strong>Scenario 1 – Missing Item</strong><br>Customer: “I ordered two items, but only one arrived.”<br>Agent: “I’m sorry to hear that. Let me check your order... I see the second item is delayed. I’ll arrange to have it shipped immediately.”<br><br><strong>Scenario 2 – Account Issue</strong><br>Customer: “I can’t log into my account.”<br>Agent: “I understand. I’ll reset your password and send you a link now. Please check your email.”<br><br><strong>Scenario 3 – Billing Concern</strong><br>Customer: “Why was I charged twice?”<br>Agent: “You’re right, I see a duplicate charge. I’ve submitted a refund request — it should reflect within 3–5 business days.”'
    },
  ];

  @override
  void initState() {
    super.initState();
    _currentAttemptNumberForUI = widget.initialAttemptNumber + 1;
    _isStudied = widget.showActivityInitially;
    _showActivityArea = widget.showActivityInitially;

    for (var prompt in _solutionPrompts) {
      _textControllers[prompt['name']!] = TextEditingController();
    }
    for (var reflection in _reflectionQuestions) {
      _textControllers[reflection['name']!] = TextEditingController();
    }

    if (_showActivityArea && !_showResultsView) {
      _startTimer();
    }
  }

  @override
  void didUpdateWidget(covariant buildLesson4_2 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialAttemptNumber != oldWidget.initialAttemptNumber) {
      _currentAttemptNumberForUI = widget.initialAttemptNumber + 1;
      if (widget.showActivityInitially && !_showResultsView) {
        _prepareForNewAttempt();
      }
    }
    if (widget.showActivityInitially && !oldWidget.showActivityInitially) {
      _isStudied = true;
      _showActivityArea = true;
      _prepareForNewAttempt();
    }
  }

  void _prepareForNewAttempt() {
    _textControllers.forEach((key, controller) => controller.clear());
    if (mounted) {
      setState(() {
        _aiSolutionFeedback = {};
        _overallAIScore = null;
        _showResultsView = false;
        _secondsElapsed = 0;
        _showReflectionForm = false;
        _reflectionSubmitted = false;
        _submittedSolutionResponsesForDisplay = null;
        _startTimer();
      });
    }
  }

  void _startTimer() {
    /* ... same as L4.1 ... */ _stopTimer();
    _secondsElapsed = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _secondsElapsed++);
    });
  }

  void _stopTimer() {
    /* ... same as L4.1 ... */ _timer?.cancel();
  }

  String _formatDuration(int totalSeconds) {
    /* ... same as L4.1 ... */ final d = Duration(seconds: totalSeconds);
    return "${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}";
  }

  Future<void> _handleSubmitSolutions() async {
    if (_isLoadingAI || _showResultsView) return;

    final currentSolutionResponses = <String, String>{};
    bool allSolutionsFilled = true;
    for (var prompt in _solutionPrompts) {
      final key = prompt['name']!;
      currentSolutionResponses[key] = _textControllers[key]!.text.trim();
      if (currentSolutionResponses[key]!.isEmpty) {
        allSolutionsFilled = false;
        break;
      }
    }

    if (!allSolutionsFilled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please provide a solution for all scenarios.')));
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
      // Fetch detailed attempts specifically for "Lesson 4.2"
      pastDetailedAttempts =
          await _firebaseService.getDetailedLessonAttempts("Lesson 4.2");
    } catch (e) {
      _logger.e("Error fetching past detailed attempts for Lesson 4.2: $e");
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

    if (mounted) {
      setState(() {
        // _isLoadingAI = true; // Moved up
        _submittedSolutionResponsesForDisplay =
            Map.from(currentSolutionResponses);
      });
    }
    _stopTimer();

    try {
      final result = await widget.onEvaluateSolutions(
        solutionResponses: currentSolutionResponses,
        // lessonId might not be needed if onEvaluateSolutions is specific to L4.2
      );

      if (!mounted) return;

      if (result != null &&
          result['error'] == null &&
          result['aiSolutionFeedback'] is Map) {
        final Map<String, SolutionFeedback> parsedFeedback = {};
        double totalRawScore = 0;
        int evaluatedCount = 0;

        (result['aiSolutionFeedback'] as Map).forEach((key, value) {
          if (value is Map) {
            final feedbackEntry =
                SolutionFeedback.fromJson(value.cast<String, dynamic>());
            parsedFeedback[key] = feedbackEntry;
            if (feedbackEntry.score != null) {
              totalRawScore += feedbackEntry.score!;
              evaluatedCount++;
            }
          }
        });

        double scaledOverallScore = 0;
        if (evaluatedCount > 0) {
          // Max possible raw score = evaluatedCount * _maxScorePerSolution (which is 5.0)
          // Scale to overallDisplayMaxScore (which is 10.0)
          scaledOverallScore =
              (totalRawScore / (evaluatedCount * _maxScorePerSolution)) *
                  _overallDisplayMaxScore;
        }

        if (mounted) {
          setState(() {
            _aiSolutionFeedback = parsedFeedback;
            _overallAIScore =
                double.parse(scaledOverallScore.toStringAsFixed(1));
            _showResultsView = true;
            _showReflectionForm = true;
          });
        }

        // VVV IMPORTANT CHANGE HERE VVV
        await widget.onSaveAttempt(
          lessonIdFirestoreKey: "Lesson 4.2",
          attemptNumber:
              actualNextAttemptNumber, // Use the correctly calculated number
          timeSpent: _secondsElapsed,
          solutionResponses: currentSolutionResponses,
          aiSolutionFeedback: result['aiSolutionFeedback'] ?? {},
          overallAIScore: _overallAIScore ?? 0.0,
          reflectionResponses: {}, // Reflections are empty initially
          isUpdate: false,
        );

        if (mounted) {
          setState(() {
            _currentAttemptNumberForUI = actualNextAttemptNumber;
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'Error evaluating solutions: ${result?['error'] ?? 'Unknown error'}')));
          setState(() => _submittedSolutionResponsesForDisplay = null);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Exception evaluating solutions: $e')));
        setState(() => _submittedSolutionResponsesForDisplay = null);
      }
    } finally {
      if (mounted) setState(() => _isLoadingAI = false);
    }
  }

  Future<void> _handleSubmitReflections() async {
    if (_isLoadingAI || _reflectionSubmitted) return;
    final currentReflectionResponses = <String, String>{};
    bool anyReflectionFilled = false;
    for (var reflection in _reflectionQuestions) {
      final key = reflection['name']!;
      currentReflectionResponses[key] = _textControllers[key]!.text.trim();
      if (currentReflectionResponses[key]!.isNotEmpty)
        anyReflectionFilled = true;
    }

    if (!anyReflectionFilled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Please fill in at least one reflection field, or click Skip.')));
      return;
    }
    setState(() => _isLoadingAI = true);
    try {
      await widget.onSaveReflection(
        lessonIdFirestoreKey: "Lesson 4.2",
        attemptNumber: _currentAttemptNumberForUI,
        submittedSolutionResponses: _submittedSolutionResponsesForDisplay ?? {},
        aiSolutionFeedback: _aiSolutionFeedback.map((key, value) =>
            MapEntry(key, {'text': value.text, 'score': value.score})),
        originalOverallAIScore: _overallAIScore ?? 0.0,
        reflectionResponses: currentReflectionResponses,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reflection submitted successfully!')));
      setState(() {
        _reflectionSubmitted = true;
        _showReflectionForm = false;
      });
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Exception submitting reflection: $e')));
    } finally {
      if (mounted) setState(() => _isLoadingAI = false);
    }
  }

  void _handleSkipReflection() {
    setState(() {
      _reflectionSubmitted = true;
      _showReflectionForm = false;
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Reflection skipped.')));
  }

  @override
  void dispose() {
    _textControllers.forEach((_, controller) => controller.dispose());
    widget.youtubeController
        ?.removeListener(() {}); // Simple remove for nullable
    _stopTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (!_isStudied && !widget.showActivityInitially) {
      // --- Study Phase ---
      content = Column(children: [
        if (_slides.isNotEmpty)
          CarouselSlider(
            carouselController: widget.carouselController,
            items: _slides
                .map((slide) => buildSlide(
                    title: slide['title']!,
                    content: slide['content']!,
                    slideIndex: _slides.indexOf(slide)))
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
        if (_slides.isNotEmpty)
          Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _slides
                  .asMap()
                  .entries
                  .map((entry) => GestureDetector(
                      onTap: () =>
                          widget.carouselController.animateToPage(entry.key),
                      child: Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 2),
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: widget.currentSlide == entry.key
                                  ? Theme.of(context).primaryColor
                                  : Colors.grey))))
                  .toList()),
        const SizedBox(height: 16),
        if (widget.youtubeController != null) ...[
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Text("Watch: Providing Effective Solutions",
                  style: Theme.of(context).textTheme.titleLarge)),
          SizedBox(
              height: 250,
              child: YoutubePlayer(
                  controller: widget.youtubeController!,
                  showVideoProgressIndicator: true,
                  onReady: () => _logger.i("L4.2 YT Player Ready"))),
        ],
        const SizedBox(height: 20),
        ElevatedButton(
            onPressed: () => setState(() {
                  _isStudied = true;
                  _showActivityArea = true;
                  widget.onShowActivitySection();
                  _prepareForNewAttempt();
                }),
            child: const Text("I've Finished Studying – Proceed to Activity")),
      ]);
    } else if (_showActivityArea) {
      if (!_showResultsView) {
        // --- Activity Input Phase ---
        content =
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Activity: Providing Solutions',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: Theme.of(context).colorScheme.secondary)),
          Text('Attempt Number: $_currentAttemptNumberForUI',
              style: Theme.of(context).textTheme.titleMedium),
          Text('Time Elapsed: ${_formatDuration(_secondsElapsed)}',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          ..._solutionPrompts
              .map((prompt) => buildScenarioPromptWithInput(
                    promptLabel: "Scenario: ${prompt['customerProblem']}",
                    agentTask: prompt['task'],
                    controller: _textControllers[prompt['name']!]!,
                    isEnabled: !_isLoadingAI,
                  ))
              .toList(),
          const SizedBox(height: 20),
          _isLoadingAI
              ? const Center(child: CircularProgressIndicator())
              : SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                      onPressed: _handleSubmitSolutions,
                      child: const Text('Submit Solutions for Feedback'))),
        ]);
      } else {
        // --- Results and Reflection Phase ---
        content =
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Feedback on Your Solutions',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: Colors.green)),
          if (_overallAIScore != null)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                    "Overall AI Score: ${_overallAIScore?.toStringAsFixed(1)} / $_overallDisplayMaxScore",
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: Colors.purple))),
          ..._solutionPrompts.map((prompt) {
            final key = prompt['name']!;
            final feedback = _aiSolutionFeedback[key];
            return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Recap for: \"${prompt['customerProblem']}\"",
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          Text(
                              "Your solution: \"${_submittedSolutionResponsesForDisplay?[key] ?? ''}\"",
                              style:
                                  const TextStyle(fontStyle: FontStyle.italic)),
                          if (feedback != null)
                            FeedbackCardL4_2(
                                scenarioFeedback: feedback,
                                maxScore: _maxScorePerSolution)
                          else
                            const Text("Feedback not available.",
                                style: TextStyle(fontStyle: FontStyle.italic)),
                        ])));
          }).toList(),
          if (_showReflectionForm && !_reflectionSubmitted) ...[
            const SizedBox(height: 24),
            Text('Discussion & Reflection (Optional)',
                style: Theme.of(context).textTheme.headlineSmall),
            ..._reflectionQuestions.map((reflection) {
              final key = reflection['name']!;
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
                                hintText: 'Your thoughts...',
                                border: const OutlineInputBorder(),
                                filled: true,
                                fillColor: Colors.grey[50]),
                            maxLines: 3,
                            enabled: !_isLoadingAI),
                      ]));
            }).toList(),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              ElevatedButton(
                  onPressed: _isLoadingAI ? null : _handleSubmitReflections,
                  child: const Text('Submit Reflection')),
              TextButton(
                  onPressed: _isLoadingAI ? null : _handleSkipReflection,
                  child: const Text('Skip Reflection')),
            ]),
          ] else if (_reflectionSubmitted)
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
                        : 'Reflection skipped.',
                    style: TextStyle(
                        color: Colors.green[700], fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center)),
          const SizedBox(height: 20),
          SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                  onPressed: () {
                    _prepareForNewAttempt();
                    setState(() {
                      _showActivityArea = true;
                      _showResultsView = false;
                      _currentAttemptNumberForUI++;
                    });
                  },
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text('Try Again'))),
        ]);
      }
    } else {
      content = const Center(child: Text("Loading lesson content..."));
    }

    return SingleChildScrollView(
        padding: const EdgeInsets.all(16.0), child: content);
  }
}
