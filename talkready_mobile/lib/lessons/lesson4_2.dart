import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../lessons/common_widgets.dart';
import '../firebase_service.dart';
import '../StudentAssessment/PreAssessment.dart'; // Changed from TypingPreAssessment to PreAssessment

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

class InteractivePhrase extends StatefulWidget {
  final String situation;
  final String phrase;

  const InteractivePhrase({
    super.key,
    required this.situation,
    required this.phrase,
  });

  @override
  _InteractivePhraseState createState() => _InteractivePhraseState();
}

class _InteractivePhraseState extends State<InteractivePhrase> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.situation,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ),
                  Icon(_isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
                ],
              ),
            ),
            if (_isExpanded) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Text(
                  widget.phrase,
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.blue.shade800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
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

class _Lesson4_2State extends State<buildLesson4_2> with TickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  final Logger _logger = Logger();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Study and Activity States
  bool _isStudied = false;
  bool _showActivityArea = false;
  bool _showResultsView = false;
  bool _isLoadingAI = false;
  bool _isSaveComplete = false;

  // Pre-assessment state
  bool _isPreAssessmentComplete = false;

  // Timer and attempt tracking
  Timer? _timer;
  int _secondsElapsed = 0;
  late int _currentAttemptNumberForUI;

  // Current scenario tracking (like React's currentScenarioIndex)
  int _currentScenarioIndex = 0;
  bool _isScriptVisible = false;
  bool _isAudioLoading = false;

  // Form controllers and feedback
  final Map<String, TextEditingController> _textControllers = {};
  Map<String, SolutionFeedback> _aiSolutionFeedback = {};
  double? _overallAIScore;
  final double _maxScorePerSolution = 5.0;
  final double _overallDisplayMaxScore = 10.0;

  // Reflection states
  bool _showReflectionForm = false;
  bool _reflectionSubmitted = false;
  Map<String, String>? _submittedSolutionResponsesForDisplay;

  // Activity log states
  bool _showActivityLog = false;
  bool _activityLogLoading = false;
  List<Map<String, dynamic>> _activityLog = [];

  // Lesson data and loading
  Map<String, dynamic>? lessonData;
  bool loadingLesson = false;
  final String firestoreLessonDocumentId = "lesson_4_2";

  // Animation controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _currentAttemptNumberForUI = widget.initialAttemptNumber + 1;
    _isStudied = widget.showActivityInitially;
    _showActivityArea = widget.showActivityInitially;

    // Initialize animation controller
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _fetchLessonData();

    if (_showActivityArea && !_showResultsView) _startTimer();
  }

  Future<void> _fetchLessonData() async {
    try {
      setState(() => loadingLesson = true);
      final doc = await _firebaseService.getLessonDocument?.call(firestoreLessonDocumentId);
      if (doc != null) {
        setState(() => lessonData = doc);
        
        // Check pre-assessment completion
        final userId = _firebaseService.userId;
        if (userId != null && lessonData?['lessonId'] != null) {
          await _checkPreAssessmentStatus(userId, lessonData!['lessonId']);
        }

        // Initialize controllers using lessonData
        if (lessonData?['activity']?['solutionPrompts'] is List) {
          for (var p in List.from(lessonData!['activity']['solutionPrompts'])) {
            final name = p['name'] ?? p['id'] ?? '';
            if (name.isNotEmpty && !_textControllers.containsKey(name)) {
              _textControllers[name] = TextEditingController();
            }
          }
        }

        // Initialize reflection controllers
        if (lessonData?['activity']?['reflectionQuestions'] is List) {
          for (var q in List.from(lessonData!['activity']['reflectionQuestions'])) {
            final name = q['name'] ?? '';
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

  Future<void> _checkPreAssessmentStatus(String userId, String lessonId) async {
    try {
      // Check if pre-assessment is completed via Firebase
      final isComplete = await _firebaseService.getPreAssessmentStatus?.call(userId, lessonId) ?? false;
      if (mounted) setState(() => _isPreAssessmentComplete = isComplete);
    } catch (e) {
      _logger.e('Error checking pre-assessment status: $e');
    }
  }

  void _handlePreAssessmentComplete() async {
    final userId = _firebaseService.userId;
    final progressKey = lessonData?['lessonId'];
    if (userId != null && progressKey != null) {
      try {
        _firebaseService.markPreAssessmentComplete(progressKey);
      } catch (error) {
        _logger.e("Failed to save pre-assessment status: $error");
      }
    }
    setState(() {
      _isPreAssessmentComplete = true;
      _isStudied = true;
    });
    _fadeController.forward();
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
      _currentScenarioIndex = 0;
      _isScriptVisible = false;
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

  List<Map<String, dynamic>> get _solutionPrompts {
    if (lessonData != null && lessonData!['activity']?['solutionPrompts'] is List) {
      return List<Map<String, dynamic>>.from(lessonData!['activity']['solutionPrompts']);
    }
    return [];
  }

  Future<void> _handlePlayScenarioAudio() async {
    if (_isAudioLoading || lessonData == null) return;

    final prompts = _solutionPrompts;
    if (_currentScenarioIndex >= prompts.length) return;

    final currentScenario = prompts[_currentScenarioIndex];
    final parts = currentScenario['parts'] as List?;
    
    if (parts == null || parts.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scenario audio data is missing.')),
        );
      }
      return;
    }

    setState(() => _isAudioLoading = true);
    try {
      // CONFIGURATION: I-setup ang actual server address at port
      final String serverAddress = "192.168.1.2"; // PALITAN NG ACTUAL IP NG SERVER
      final int serverPort = 5001;
      
      final uri = Uri.parse('http://$serverAddress:$serverPort/synthesize-speech');
      _logger.i('Connecting to TTS server at $uri');
      
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'parts': parts}),
      ).timeout(const Duration(seconds: 15)); // Dagdagan ang timeout
    
      if (resp.statusCode != 200) throw Exception('TTS failed: ${resp.statusCode}');
      final bytes = resp.bodyBytes;
      await _audioPlayer.stop();
      await _audioPlayer.play(BytesSource(bytes));
    } catch (e) {
      _logger.e('Audio play error: $e');
      _tryFallbackTTS(currentScenario);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Server unavailable. Using device TTS.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAudioLoading = false);
    }
  }

  // Fallback TTS method
  void _tryFallbackTTS(Map<String, dynamic> scenario) async {
    try {
      final text = scenario['parts']?.map((p) => p['text']).join(' ') ?? 
                   scenario['customerProblem'] ?? '';
      
      final FlutterTts flutterTts = FlutterTts();
      await flutterTts.setLanguage("en-US");
      await flutterTts.setPitch(1.0);
      await flutterTts.setSpeechRate(0.5);
      await flutterTts.setVolume(1.0);
      await flutterTts.speak(text);
    } catch (e) {
      _logger.e('Fallback TTS failed: $e');
    }
  }

  Future<void> _handleCheckSingleSolution() async {
    if (_isLoadingAI) return;
    
    final prompts = _solutionPrompts;
    if (_currentScenarioIndex >= prompts.length) return;
    
    final currentScenario = prompts[_currentScenarioIndex];
    final key = currentScenario['name'] as String;
    final answer = _textControllers[key]?.text.trim() ?? '';
    
    if (answer.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please provide a solution for this scenario.')),
        );
      }
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No feedback returned for this solution.')),
          );
        }
      }
    } catch (e) {
      _logger.e('Error checking single solution: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error getting feedback.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingAI = false);
    }
  }

  Future<void> _handleFinishAndSave() async {
    if (_isLoadingAI || _showResultsView) return;

    final userId = _firebaseService.userId;
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not authenticated.')),
        );
      }
      return;
    }

    final current = <String, String>{};
    for (var p in _solutionPrompts) {
      final key = p['name'] as String;
      current[key] = _textControllers[key]?.text.trim() ?? '';
    }

    List<dynamic> pastAttempts = [];
    try {
      pastAttempts = await _firebaseServiceTryGetAttempts("Lesson 4.2");
    } catch (e) {
      _logger.e('Failed to fetch past attempts: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not verify past attempts.')),
        );
      }
      return;
    }

    final actualNextAttemptNumber = pastAttempts.length + 1;
    if (mounted) setState(() => _submittedSolutionResponsesForDisplay = Map.from(current));
    _stopTimer();

    setState(() => _isLoadingAI = true);

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
          _aiSolutionFeedback = Map<String, SolutionFeedback>.from(
            parsed.map((k, v) => MapEntry(k as String, v as SolutionFeedback)),
          );
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
          
          // Navigate back after 3 seconds like in React
          Timer(const Duration(seconds: 3), () {
            if (mounted) {
              Navigator.of(context).pushReplacementNamed('/courseoutline/intermediate/module4/landingpage');
            }
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error evaluating solutions: ${result?['error'] ?? 'Unknown'}')),
          );
          setState(() => _submittedSolutionResponsesForDisplay = null);
        }
      }
    } catch (e) {
      _logger.e('Exception evaluating solutions: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exception: $e')),
        );
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
    }

    if (!any) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill at least one reflection or skip.')),
        );
      }
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reflection submitted successfully!')),
        );
        setState(() {
          _reflectionSubmitted = true;
          _showReflectionForm = false;
        });
      }
    } catch (e) {
      _logger.e('Error submitting reflection: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
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

  Future<Map<String, dynamic>?> _fetchUserProgress(String? userId) async {
  try {
    final user = _firebaseService.userId;
    if (user == null) return null;
    
    final prog = await FirebaseFirestore.instance
        .collection('userProgress')
        .doc(userId)
        .get();
        
    if (prog.exists) {
      _logger.i('User progress fetched successfully');
      return prog.data();
    } else {
      _logger.w('No user progress found');
      return null;
    }
  } catch (e) {
    _logger.e('Error fetching user progress: $e');
    return null;
  }
}

  @override
  void dispose() {
    _textControllers.forEach((_, c) => c.dispose());
    _audioPlayer.dispose();
    _stopTimer();
    _fadeController.dispose();
    super.dispose();
  }

  Widget _buildStudyView() {
    if (loadingLesson) {
      return const Center(child: CircularProgressIndicator());
    }

    // Pre-assessment phase - Now using the full PreAssessment component
    if (!_isPreAssessmentComplete && lessonData?['preAssessmentData'] != null) {
      return PreAssessment(
        onComplete: _handlePreAssessmentComplete,
        assessmentData: lessonData!['preAssessmentData'],
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(children: [
        // Objective Section
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const FaIcon(FontAwesomeIcons.book, color: Colors.blue, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    lessonData?['objective']?['heading'] ?? 'Objective',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.blue.shade700),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              if (lessonData?['objective']?['points'] is List)
                ...List.from(lessonData!['objective']['points']).map<Widget>((point) => 
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Expanded(child: Text(point, style: const TextStyle(fontSize: 14))),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Introduction Section
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const FaIcon(FontAwesomeIcons.lightbulb, color: Colors.yellow, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    lessonData?['introduction']?['heading'] ?? 'Why Solution-Oriented Language Matters',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.grey.shade700),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Text(
                lessonData?['introduction']?['paragraph'] ?? '',
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
            ],
          ),
        ),

        // Key Phrases Section
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const FaIcon(FontAwesomeIcons.list, color: Colors.green, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    lessonData?['keyPhrases']?['heading'] ?? 'Key Phrases',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.grey.shade700),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              if (lessonData?['keyPhrases']?['table'] is List)
                ...List.from(lessonData!['keyPhrases']['table']).map<Widget>((row) => 
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InteractivePhrase(
                      situation: row['purpose'] ?? '',
                      phrase: row['phrase'] ?? '',
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Video Section
        if (widget.youtubeController != null)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 240,
                child: YoutubePlayer(
                  controller: widget.youtubeController!,
                  showVideoProgressIndicator: true,
                ),
              ),
            ),
          ),

        // Example Dialogues Section
        Container(
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const FaIcon(FontAwesomeIcons.playCircle, color: Colors.grey, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    lessonData?['exampleDialogues']?['heading'] ?? 'Example Dialogues',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.grey.shade700),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              if (lessonData?['exampleDialogues']?['dialogues'] is List)
                ...List.from(lessonData!['exampleDialogues']['dialogues']).map<Widget>((dialogue) => 
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dialogue['title'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(dialogue['customer'] ?? '', style: const TextStyle(fontSize: 13)),
                        Text(dialogue['agent'] ?? '', style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Proceed to Activity Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              setState(() {
                _isStudied = true;
                _showActivityArea = true;
                widget.onShowActivitySection();
                _prepareForNewAttempt();
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text(
              "I've Finished Studying – Proceed to Activity",
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildActivityView() {
    final prompts = _solutionPrompts;
    if (prompts.isEmpty) return const Center(child: Text('Loading scenarios...'));

    final currentScenario = prompts[_currentScenarioIndex];
    final key = currentScenario['name'] as String;
    final feedback = _aiSolutionFeedback[key];
    final isFeedbackReceived = feedback != null;
    final isLastScenario = _currentScenarioIndex == prompts.length - 1;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Header
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(
          'Activity: Providing Solutions',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Theme.of(context).colorScheme.secondary),
        ),
        IconButton(icon: const Icon(Icons.list_alt), onPressed: _fetchActivityLog, tooltip: 'Activity Log'),
      ]),
      Text('Attempt Number: $_currentAttemptNumberForUI', style: Theme.of(context).textTheme.titleMedium),
      Text('Time Elapsed: ${_formatDuration(_secondsElapsed)}', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 16),

      // Current Scenario Card
      Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Scenario Header with Audio Button
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scenario ${_currentScenarioIndex + 1} of ${prompts.length}: Listen to the customer\'s problem.',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (_isScriptVisible) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '"${currentScenario['parts']?.map((p) => p['text']).join(' ') ?? currentScenario['customerProblem']}"',
                            style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey.shade800),
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () => setState(() => _isScriptVisible = true),
                          child: const Text(
                            'Show Script',
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _isAudioLoading ? Colors.indigo.shade300 : Colors.indigo,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _isAudioLoading ? null : _handlePlayScenarioAudio,
                    icon: _isAudioLoading 
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const FaIcon(FontAwesomeIcons.volumeUp, color: Colors.white, size: 20),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 8),
            Text(
              currentScenario['task'] ?? '',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),

            // Response TextField
            TextField(
              controller: _textControllers[key],
              decoration: InputDecoration(
                hintText: 'Your solution response...',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              maxLines: 4,
              enabled: !_isLoadingAI && !isFeedbackReceived,
            ),

            // Feedback Display
            if (feedback != null) ...[
              const SizedBox(height: 12),
              FeedbackCardL4_2(scenarioFeedback: feedback, maxScore: _maxScorePerSolution),
            ],

            // Navigation Buttons
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              ElevatedButton(
                onPressed: _currentScenarioIndex > 0 
                    ? () => setState(() {
                        _currentScenarioIndex--;
                        _isScriptVisible = false;
                      })
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade200,
                  foregroundColor: Colors.grey.shade700,
                ),
                child: const Text('Previous'),
              ),
              if (!isFeedbackReceived)
                ElevatedButton(
                  onPressed: _isLoadingAI ? null : _handleCheckSingleSolution,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade600),
                  child: _isLoadingAI 
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Check Solution', style: TextStyle(color: Colors.white)),
                )
              else if (isLastScenario)
                ElevatedButton(
                  onPressed: _handleFinishAndSave,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600),
                  child: const Text('Finish & Save Attempt', style: TextStyle(color: Colors.white)),
                )
              else
                ElevatedButton(
                  onPressed: () => setState(() {
                    _currentScenarioIndex++;
                    _isScriptVisible = false;
                  }),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo.shade600),
                  child: const Text('Next Scenario', style: TextStyle(color: Colors.white)),
                ),
            ]),
          ]),
        ),
      )
    ]);
    }

    Widget _buildResultsView() {
      final prompts = _solutionPrompts;
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Feedback on Your Solutions',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.green),
          ),
          if (_overallAIScore != null)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "Overall AI Score: ${_overallAIScore?.toStringAsFixed(1)} / $_overallDisplayMaxScore",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.purple),
              ),
            ),
          
          // Solutions Recap
          ...prompts.map((p) {
            final key = p['name'] as String;
            final fb = _aiSolutionFeedback[key];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recap for: "${p['customerProblem']}"',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your solution: "${_submittedSolutionResponsesForDisplay?[key] ?? _textControllers[key]?.text ?? ''}"',
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                    if (fb != null)
                      FeedbackCardL4_2(scenarioFeedback: fb, maxScore: _maxScorePerSolution)
                    else
                      const Text('Feedback not available.', style: TextStyle(fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
            );
          }),

          // Reflection Form
          if (_showReflectionForm && !_reflectionSubmitted) ...[
            const SizedBox(height: 20),
            Text('Discussion & Reflection (Optional)', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
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
                      TextField(
                        controller: _textControllers[name],
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Your thoughts... (Optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                );
              }),
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
          ] else if (_reflectionSubmitted) ...[
            const SizedBox(height: 12),
            Center(
              child: Text(
                'Reflection saved or skipped for this attempt.',
                style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      );
    }

    @override
    Widget build(BuildContext context) {
      return Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Main Content
                if (!_isStudied && !widget.showActivityInitially)
                  _buildStudyView()
                else if (_showActivityArea && !_showResultsView)
                  _buildActivityView()
                else if (_showActivityArea && _showResultsView)
                  _buildResultsView(),
                const SizedBox(height: 24),
              ],
            ),
          ),

          // Loading Overlay
          if (_isLoadingAI)
            Positioned.fill(
              child: Container(
                color: Colors.black45,
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),

          // Success Overlay
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
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 64),
                        SizedBox(height: 12),
                        Text(
                          'Attempt Saved Successfully!',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 6),
                        Text('Redirecting you back to the module overview...')
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Activity Log Modal
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
                                              ..._solutionPrompts.map((p) {
                                                final name = p['name'] as String;
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