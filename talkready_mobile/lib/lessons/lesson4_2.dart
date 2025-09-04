import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../lessons/common_widgets.dart'; // For buildSlide, HtmlFormattedText, buildScenarioPromptWithInput
import '../firebase_service.dart';

class SolutionFeedback {
  final String text;
  final double? score;
  SolutionFeedback({required this.text, this.score});
  factory SolutionFeedback.fromJson(Map<String, dynamic> json) {
    return SolutionFeedback(
      text: json['text'] as String? ?? 'No feedback text.',
      score: (json['score'] as num?)?.toDouble(),
    );
  }
}

class FeedbackCardL4_2 extends StatelessWidget {
  final SolutionFeedback scenarioFeedback;
  final double maxScore;
  const FeedbackCardL4_2({
    super.key,
    required this.scenarioFeedback,
    required this.maxScore,
  });

  List<Map<String, dynamic>> _parseFeedbackSections(String rawText) {
    final List<Map<String, dynamic>> parsed = [];
    final categories = [
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

    String remaining = rawText;
    for (var cat in categories) {
      final title = cat['title'] as String;
      final pattern = RegExp(
          r'\*\*' + RegExp.escape(title) + r':\*\*([\s\S]*?)(?=\n\*\*[^:]+:\*\*|$)',
          caseSensitive: false);
      final match = pattern.firstMatch(remaining);
      if (match != null && match.groupCount >= 1) {
        final txt = match.group(1)!.trim();
        if (txt.isNotEmpty) {
          parsed.add({
            'Icon': cat['icon'],
            'title': title.replaceAll(':', ''),
            'color': cat['color'],
            'text': txt,
          });
        }
        remaining = remaining.substring(match.end);
      }
    }

    if (parsed.isEmpty && rawText.trim().isNotEmpty) {
      parsed.add({
        'Icon': FontAwesomeIcons.infoCircle,
        'title': 'General Feedback',
        'color': Colors.grey.shade700,
        'text': rawText.trim(),
      });
    }
    return parsed;
  }

  @override
  Widget build(BuildContext context) {
    final score = scenarioFeedback.score ?? 0.0;
    final percentage = maxScore > 0 ? (score / maxScore) * 100 : 0.0;
    Color scoreColor = Colors.red.shade700;
    if (percentage >= 80) {
      scoreColor = Colors.green.shade700;
    } else if (percentage >= 50) scoreColor = Colors.orange.shade700;

    final sections = _parseFeedbackSections(scenarioFeedback.text);

    return Container(
      margin: const EdgeInsets.only(top: 8.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8.0),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 3, offset: const Offset(0, 1))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text("AI Score: ${score.toStringAsFixed(1)} / ${maxScore.toStringAsFixed(1)}",
              style: TextStyle(fontWeight: FontWeight.bold, color: scoreColor, fontSize: 15)),
        ]),
        const SizedBox(height: 6),
        LinearProgressIndicator(value: percentage / 100, backgroundColor: Colors.grey[300], color: scoreColor, minHeight: 6),
        const SizedBox(height: 12),
        if (sections.isEmpty)
          Text("No detailed feedback text.", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey[600]))
        else
          ...sections.map((section) {
            return Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  FaIcon(section['Icon'] as IconData, size: 16, color: section['color'] as Color),
                  const SizedBox(width: 8),
                  Expanded(child: Text(section['title'] as String, style: TextStyle(fontWeight: FontWeight.w600, color: section['color'] as Color, fontSize: 13))),
                ]),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 24.0),
                  child: HtmlFormattedText(htmlString: (section['text'] as String).replaceAll('\n', '<br>')),
                ),
              ]),
            );
          }),
      ]),
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
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isStudied = false;
  bool _showActivityArea = false;
  bool _showResultsView = false;
  bool _isLoadingAI = false;
  bool _isSaveComplete = false;

  Timer? _timer;
  int _secondsElapsed = 0;
  late int _currentAttemptNumberForUI;

  final Map<String, TextEditingController> _textControllers = {};
  final List<Map<String, String>> _solutionPromptsFallback = [
    {
      "name": "solution1",
      "customerProblem": "Customer: “I received the wrong item.”",
      "task": "Politely acknowledge and propose sending the correct item."
    },
    {
      "name": "solution2",
      "customerProblem": "Customer: “My order hasn’t arrived yet, past estimated date.”",
      "task": "Apologize, investigate, offer resolution."
    },
    {
      "name": "solution3",
      "customerProblem": "Customer: “My payment didn’t go through but I was charged.”",
      "task": "Show empathy, check payment, outline steps."
    },
    {
      "name": "solution4",
      "customerProblem": "Customer: “I want to cancel my subscription.”",
      "task": "Explain cancellation and implications or offer to cancel."
    }
  ];

  Map<String, SolutionFeedback> _aiSolutionFeedback = {};
  double? _overallAIScore;
  final double _maxScorePerSolution = 5.0;
  final double _overallDisplayMaxScore = 10.0;

  bool _showReflectionForm = false;
  bool _reflectionSubmitted = false;
  Map<String, String>? _submittedSolutionResponsesForDisplay;

  // UI extras
  bool _showActivityLog = false;
  bool _activityLogLoading = false;
  List<Map<String, dynamic>> _activityLog = [];
  bool _isAudioLoading = false;
  // Slides and lessonData (fetch optional)
  final List<Map<String, dynamic>> _slidesFallback = [
    {
      'title': 'Objective: Providing Solutions',
      'content':
          '• Use polite, helpful phrases to offer solutions to customer concerns.\n• Respond professionally with empathy and confidence.\n• Practice resolving simple service-related scenarios.'
    },
    {
      'title': 'Why Solution-Oriented Language Matters',
      'content':
          'Customers want reassurance that their issue is being handled. Clear solutions increase trust and satisfaction.'
    },
  ];

  Map<String, dynamic>? lessonData;
  bool loadingLesson = false;

  @override
  void initState() {
    super.initState();
    _currentAttemptNumberForUI = widget.initialAttemptNumber + 1;
    _isStudied = widget.showActivityInitially;
    _showActivityArea = widget.showActivityInitially;

    // Initialize controllers for fallback prompts
    for (var p in _solutionPromptsFallback) {
      _textControllers[p['name']!] = TextEditingController();
    }

    // Try fetching lesson document if present in Firestore via FirebaseService
    _fetchLessonData();

    if (_showActivityArea && !_showResultsView) _startTimer();
  }

  Future<void> _fetchLessonData() async {
    // If your app uses a FirebaseService helper to get lesson JSON, integrate here.
    // For now, attempt to load via FirebaseService.getLessonDocument if implemented.
    // Fallback to null (we'll use the fallback in UI).
    try {
      setState(() => loadingLesson = true);
      final doc = await _firebaseService.getLessonDocument?.call('lesson_4_2');
      if (doc != null) {
        setState(() => lessonData = doc);
        // initialize controllers using lessonData.activity if available
        if (lessonData?['activity']?['solutionPrompts'] is List) {
          for (var p in List.from(lessonData!['activity']['solutionPrompts'])) {
            final name = p['name'] ?? p['id'] ?? '';
            if (name.isNotEmpty && !_textControllers.containsKey(name)) {
              _textControllers[name] = TextEditingController();
            }
          }
        }
      }
    } catch (e) {
      _logger.w('No lesson doc or error fetching: $e');
    } finally {
      if (mounted) setState(() => loadingLesson = false);
    }
  }

  @override
  void didUpdateWidget(covariant buildLesson4_2 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialAttemptNumber != oldWidget.initialAttemptNumber) {
      _currentAttemptNumberForUI = widget.initialAttemptNumber + 1;
      if (widget.showActivityInitially && !_showResultsView) _prepareForNewAttempt();
    }
    if (widget.showActivityInitially && !oldWidget.showActivityInitially) {
      _isStudied = true;
      _showActivityArea = true;
      _prepareForNewAttempt();
    }
  }

  void _prepareForNewAttempt() {
    _textControllers.forEach((_, c) => c.clear());
    if (!mounted) return;
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

  void _startTimer() {
    _stopTimer();
    _secondsElapsed = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _secondsElapsed++);
    });
  }

  void _stopTimer() {
    _timer?.cancel();
  }

  String _formatDuration(int totalSeconds) {
    final d = Duration(seconds: totalSeconds);
    return "${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}";
  }

  List<Map<String, String>> get _solutionPrompts {
    if (lessonData != null && lessonData!['activity']?['solutionPrompts'] is List) {
      return List<Map<String, String>>.from(lessonData!['activity']['solutionPrompts']);
    }
    return _solutionPromptsFallback;
  }

  Future<void> _handleCheckSingleSolution(String key) async {
    if (_isLoadingAI) return;
    final answer = _textControllers[key]?.text.trim() ?? '';
    if (answer.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please provide a solution for this scenario.')));
      return;
    }

    setState(() => _isLoadingAI = true);
    try {
      final res = await widget.onEvaluateSolutions(solutionResponses: {key: answer});
      if (res != null && res['aiSolutionFeedback'] is Map) {
        final Map fbMap = res['aiSolutionFeedback'];
        if (fbMap[key] is Map) {
          final parsed = SolutionFeedback.fromJson(Map<String, dynamic>.from(fbMap[key]));
          if (mounted) setState(() => _aiSolutionFeedback[key] = parsed);
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No feedback returned for this solution.')));
      }
    } catch (e) {
      _logger.e('Error checking single solution: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error getting feedback.')));
    } finally {
      if (mounted) setState(() => _isLoadingAI = false);
    }
  }

  Future<void> _playScenarioAudio(List<Map<String, dynamic>> parts) async {
    if (parts.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No audio parts available.')));
      return;
    }
    if (_isAudioLoading) return;
    setState(() => _isAudioLoading = true);
    try {
      final uri = Uri.parse('http://localhost:5000/synthesize-speech');
      final resp = await http.post(uri, headers: {'Content-Type': 'application/json'}, body: json.encode({'parts': parts}));
      if (resp.statusCode != 200) throw Exception('TTS failed: ${resp.statusCode}');
      final bytes = resp.bodyBytes;
      await _audioPlayer.stop();
      await _audioPlayer.play(BytesSource(bytes));
    } catch (e) {
      _logger.e('Audio play error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not play scenario audio.')));
    } finally {
      if (mounted) setState(() => _isAudioLoading = false);
    }
  }

  Future<void> _handleSubmitSolutions() async {
    if (_isLoadingAI || _showResultsView) return;

    final current = <String, String>{};
    bool allFilled = true;
    for (var p in _solutionPrompts) {
      final key = p['name']!;
      current[key] = _textControllers[key]?.text.trim() ?? '';
      if (current[key]!.isEmpty) {
        allFilled = false;
        break;
      }
    }
    if (!allFilled) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please provide a solution for all scenarios.')));
      return;
    }

    final userId = _firebaseService.userId;
    if (userId == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User not authenticated.')));
      return;
    }

    setState(() => _isLoadingAI = true);

    List<dynamic> pastAttempts = [];
    try {
      pastAttempts = await _firebaseServiceTryGetAttempts("Lesson 4.2");
    } catch (e) {
      _logger.e('Failed to fetch past attempts: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not verify past attempts.')));
        setState(() => _isLoadingAI = false);
      }
      return;
    }
    final actualNextAttemptNumber = pastAttempts.length + 1;
    if (mounted) setState(() => _submittedSolutionResponsesForDisplay = Map.from(current));
    _stopTimer();

    try {
      final result = await widget.onEvaluateSolutions(solutionResponses: current);
      if (!mounted) return;
      if (result != null && result['aiSolutionFeedback'] is Map) {
        final Map parsed = {};
        double rawTotal = 0;
        int count = 0;
        (result['aiSolutionFeedback'] as Map).forEach((k, v) {
          if (v is Map) {
            parsed[k] = SolutionFeedback.fromJson(Map<String, dynamic>.from(v));
            final s = (v['score'] as num?)?.toDouble();
            if (s != null) {
              rawTotal += s;
              count++;
            }
          }
        });

        double scaledOverall = 0;
        if (count > 0) {
          scaledOverall = (rawTotal / (count * _maxScorePerSolution)) * _overallDisplayMaxScore;
        }

        setState(() {
          _aiSolutionFeedback = Map<String, SolutionFeedback>.from(parsed.map((k, v) => MapEntry(k as String, v as SolutionFeedback)));
          _overallAIScore = double.parse(scaledOverall.toStringAsFixed(1));
          _showResultsView = true;
          _showReflectionForm = true;
        });

        await widget.onSaveAttempt(
          lessonIdFirestoreKey: "Lesson 4.2",
          attemptNumber: actualNextAttemptNumber,
          timeSpent: _secondsElapsed,
          solutionResponses: current,
          aiSolutionFeedback: result['aiSolutionFeedback'] ?? {},
          overallAIScore: _overallAIScore ?? 0.0,
          reflectionResponses: {},
          isUpdate: false,
        );

        if (mounted) {
          setState(() {
            _currentAttemptNumberForUI = actualNextAttemptNumber;
            _isSaveComplete = true;
          });
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) setState(() => _isSaveComplete = false);
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error evaluating solutions: ${result?['error'] ?? 'Unknown'}')));
          setState(() => _submittedSolutionResponsesForDisplay = null);
        }
      }
    } catch (e) {
      _logger.e('Exception evaluating solutions: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exception: $e')));
        setState(() => _submittedSolutionResponsesForDisplay = null);
      }
    } finally {
      if (mounted) setState(() => _isLoadingAI = false);
    }
  }

  Future<List<dynamic>> _firebaseServiceTryGetAttempts(String lessonKey) async {
    try {
      return await _firebaseService.getDetailedLessonAttempts(lessonKey);
    } catch (_) {
      return [];
    }
  }

  Future<void> _handleSubmitReflections() async {
    if (_isLoadingAI || _reflectionSubmitted) return;
    final current = <String, String>{};
    bool any = false;
    if (lessonData?['activity']?['reflectionQuestions'] is List) {
      for (var q in List.from(lessonData!['activity']['reflectionQuestions'])) {
        final name = q['name'];
        final val = _textControllers[name]?.text.trim() ?? '';
        current[name] = val;
        if (val.isNotEmpty) any = true;
      }
    } else {
      // fallback keys
      for (var k in _textControllers.keys) {
        if (k.startsWith('reflection')) {
          final v = _textControllers[k]!.text.trim();
          current[k] = v;
          if (v.isNotEmpty) any = true;
        }
      }
    }

    if (!any) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill at least one reflection or skip.')));
      return;
    }

    setState(() => _isLoadingAI = true);
    try {
      await widget.onSaveReflection(
        lessonIdFirestoreKey: "Lesson 4.2",
        attemptNumber: _currentAttemptNumberForUI,
        submittedSolutionResponses: _submittedSolutionResponsesForDisplay ?? {},
        aiSolutionFeedback: _aiSolutionFeedback.map((k, v) => MapEntry(k, {'text': v.text, 'score': v.score})),
        originalOverallAIScore: _overallAIScore ?? 0.0,
        reflectionResponses: current,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reflection submitted successfully!')));
        setState(() {
          _reflectionSubmitted = true;
          _showReflectionForm = false;
        });
      }
    } catch (e) {
      _logger.e('Error submitting reflection: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoadingAI = false);
    }
  }

  Future<void> _fetchActivityLog() async {
    setState(() {
      _activityLogLoading = true;
      _showActivityLog = true;
    });
    try {
      final userId = _firebaseService.userId;
      if (userId == null) {
        setState(() {
          _activityLog = [];
          _activityLogLoading = false;
        });
        return;
      }
      final attempts = await _firebaseServiceTryGetAttempts("Lesson 4.2");
      final formatted = attempts.map<Map<String, dynamic>>((a) {
        return {
          'attemptNumber': a['attemptNumber'],
          'timeSpent': a['timeSpent'],
          'aiFeedback': a['aiSolutionFeedback'] ?? {},
          'solutionResponses': a['solutionResponses'] ?? {},
          'attemptTimestamp': a['attemptTimestamp'],
          'score': a['overallAIScore'] ?? a['score'],
        };
      }).toList();
      if (mounted) setState(() => _activityLog = List<Map<String, dynamic>>.from(formatted));
    } catch (e) {
      _logger.e('Activity log fetch error: $e');
      if (mounted) setState(() => _activityLog = []);
    } finally {
      if (mounted) setState(() => _activityLogLoading = false);
    }
  }

  @override
  void dispose() {
    _textControllers.forEach((_, c) => c.dispose());
    _audioPlayer.dispose();
    _stopTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slides = (lessonData != null && lessonData!['slides'] is List) ? List<Map<String, dynamic>>.from(lessonData!['slides']) : _slidesFallback;
    final prompts = _solutionPrompts;

    Widget studyView = Column(children: [
      CarouselSlider(
        carouselController: widget.carouselController,
        items: slides.map((s) => buildSlide(title: s['title'] as String, content: s['content'] as String, slideIndex: slides.indexOf(s))).toList(),
        options: CarouselOptions(
          height: 250,
          enlargeCenterPage: false,
          enableInfiniteScroll: false,
          initialPage: widget.currentSlide,
          onPageChanged: (idx, reason) => widget.onSlideChanged(idx),
          viewportFraction: 0.95,
        ),
      ),
      const SizedBox(height: 12),
      if (widget.youtubeController != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: SizedBox(height: 240, child: YoutubePlayer(controller: widget.youtubeController!, showVideoProgressIndicator: true)),
        ),
      const SizedBox(height: 12),
      ElevatedButton(
        onPressed: () {
          setState(() {
            _isStudied = true;
            _showActivityArea = true;
            widget.onShowActivitySection();
            _prepareForNewAttempt();
          });
        },
        child: const Text("I've Finished Studying – Proceed to Activity"),
      ),
    ])
    ;

    // Activity input view
    Widget activityInput = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Activity: Providing Solutions', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Theme.of(context).colorScheme.secondary)),
        IconButton(icon: const Icon(Icons.list_alt), onPressed: _fetchActivityLog, tooltip: 'Activity Log'),
      ]),
      Text('Attempt Number: $_currentAttemptNumberForUI', style: Theme.of(context).textTheme.titleMedium),
      Text('Time Elapsed: ${_formatDuration(_secondsElapsed)}', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 14),
      ...prompts.map((prompt) {
        final key = prompt['name']!;
        final customerProblem = prompt['customerProblem'] ?? '';
        final task = prompt['task'] ?? '';
        final feedback = _aiSolutionFeedback[key];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(customerProblem, style: Theme.of(context).textTheme.titleSmall)),
                  IconButton(
                    icon: const Icon(Icons.volume_up),
                    onPressed: () async {
                      // If lessonData has parts for TTS, send them, otherwise send the text
                      final parts = (prompt['parts'] is List)
                          ? List<Map<String, dynamic>>.from(prompt['parts'] as List)
                          : [{'text': customerProblem}];
                      await _playScenarioAudio(parts);
                    },
                  ),
                  ElevatedButton(
                    onPressed: _isLoadingAI ? null : () => _handleCheckSingleSolution(key),
                    child: const Text('Check'),
                  ),
                ]),
                const SizedBox(height: 6),
                Text(task, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                TextField(
                  controller: _textControllers[key],
                  decoration: InputDecoration(hintText: 'Your solution response...', border: const OutlineInputBorder(), filled: true, fillColor: Colors.grey[50]),
                  maxLines: 4,
                  enabled: !_isLoadingAI,
                ),
                if (feedback != null) ...[
                  const SizedBox(height: 8),
                  FeedbackCardL4_2(scenarioFeedback: feedback, maxScore: _maxScorePerSolution),
                ],
              ]),
            ),
          ),
        );
      }),
      const SizedBox(height: 16),
      _isLoadingAI ? const Center(child: CircularProgressIndicator()) : SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _handleSubmitSolutions, child: const Text('Submit Solutions for Feedback'))),
    ]);

    // Results & reflection view
    Widget resultsView = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Feedback on Your Solutions', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.green)),
        if (_overallAIScore != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text("Overall AI Score: ${_overallAIScore?.toStringAsFixed(1)} / $_overallDisplayMaxScore", style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.purple)),
          ),
        ...prompts.map((p) {
          final key = p['name']!;
          final fb = _aiSolutionFeedback[key];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Recap for: "${p['customerProblem']}"', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  Text('Your solution: "${_submittedSolutionResponsesForDisplay?[key] ?? _textControllers[key]?.text ?? ''}"', style: const TextStyle(fontStyle: FontStyle.italic)),
                  if (fb != null)
                    FeedbackCardL4_2(scenarioFeedback: fb, maxScore: _maxScorePerSolution)
                  else
                    const Text('Feedback not available.', style: TextStyle(fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          );
        }),
        if (_showReflectionForm && !_reflectionSubmitted) ...[
          const SizedBox(height: 20),
          Text('Discussion & Reflection (Optional)', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          // render reflection questions if present in lessonData
          if (lessonData?['activity']?['reflectionQuestions'] is List)
            ...List.from(lessonData!['activity']['reflectionQuestions']).map<Widget>((q) {
              final name = q['name'];
              final question = q['question'];
              if (!_textControllers.containsKey(name)) _textControllers[name] = TextEditingController();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(question ?? '', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 6),
                    TextField(controller: _textControllers[name], maxLines: 3, decoration: const InputDecoration(hintText: 'Your thoughts... (Optional)', border: OutlineInputBorder())),
                  ],
                ),
              );
            })
        ] else if (_reflectionSubmitted) ...[
          const SizedBox(height: 12),
          Center(child: Text('Reflection saved or skipped for this attempt.', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
        ],
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
              onPressed: _showReflectionForm && !_reflectionSubmitted ? _handleSubmitReflections : null,
              child: const Text('Submit Reflection'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _reflectionSubmitted = true;
                  _showReflectionForm = false;
                });
              },
              child: const Text('Skip Reflection'),
            ),
          ],
        ),
      ],
    );

    // Return the widget tree directly
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // header/back link is handled by page that embeds this widget; keep content only
              if (!_isStudied && !widget.showActivityInitially)
                studyView
              else if (_showActivityArea && !_showResultsView)
                activityInput
              else if (_showActivityArea && _showResultsView)
                resultsView,
              const SizedBox(height: 24),
            ],
          ),
        ),
        if (_isLoadingAI)
          Positioned.fill(
            child: Container(
              color: Colors.black45,
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
        if (_isSaveComplete)
          Positioned.fill(
            child: Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.check_circle, color: Colors.green, size: 64),
                      SizedBox(height: 12),
                      Text('Attempt Saved Successfully!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      SizedBox(height: 6),
                      Text('You may continue or review your activity log.')
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (_showActivityLog)
          Positioned.fill(
            child: Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 900),
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('Activity Log', style: Theme.of(context).textTheme.headlineSmall),
                          ),
                          IconButton(
                            onPressed: () => setState(() => _showActivityLog = false),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      if (_activityLogLoading)
                        const Center(child: CircularProgressIndicator())
                      else
                        Expanded(
                          child: _activityLog.isEmpty
                              ? const Center(child: Text('No activity recorded for this lesson yet.'))
                              : ListView.builder(
                                  itemCount: _activityLog.length,
                                  itemBuilder: (ctx, i) {
                                    final item = _activityLog[i];
                                    final Map aiFb = item['aiFeedback'] ?? {};
                                    final Map solResp = item['solutionResponses'] ?? {};
                                    return Card(
                                      margin: const EdgeInsets.symmetric(vertical: 8),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text('Attempt ${item['attemptNumber']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.end,
                                                  children: [
                                                    Text('Overall Score: ${item['score'] ?? 'N/A'}'),
                                                    Text('Time: ${item['timeSpent'] ?? 'N/A'}s')
                                                  ],
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            ...prompts.map((p) {
                                              final name = p['name']!;
                                              final userAns = solResp[name];
                                              final fb = aiFb[name];
                                              return Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 6),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text('Prompt: "${p['customerProblem']}"', style: const TextStyle(fontWeight: FontWeight.w600)),
                                                    const SizedBox(height: 4),
                                                    Text('Your Answer:', style: const TextStyle(fontStyle: FontStyle.italic)),
                                                    Container(
                                                      width: double.infinity,
                                                      padding: const EdgeInsets.all(8),
                                                      color: Colors.grey[100],
                                                      child: Text(userAns?.toString() ?? '(No answer)'),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    if (fb != null && fb['text'] != null)
                                                      FeedbackCardL4_2(
                                                        scenarioFeedback: SolutionFeedback.fromJson(Map<String, dynamic>.from(fb)),
                                                        maxScore: _maxScorePerSolution,
                                                      )
                                                    else
                                                      const Text('No AI feedback for this solution.', style: TextStyle(fontStyle: FontStyle.italic)),
                                                  ],
                                                ),
                                              );
                                            }),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => setState(() => _showActivityLog = false),
                        child: const Text('Close Log'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}