// Enhanced Lesson 2.2 with Firestore meta, pre-assessment gating, activity log,
// interactive definitions, key phrase mini MCQ. Public constructor unchanged.

import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:logger/logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../lessons/common_widgets.dart';
import '../firebase_service.dart';
import '../widgets/parsed_feedback_card.dart';
import '../StudentAssessment/RolePlayScenarioQuestion.dart';
import '../StudentAssessment/AiFeedbackData.dart';

class buildLesson2_2 extends StatefulWidget {
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

  // Existing fields
  bool _videoFinished = false;
  bool _isSubmitting = false;
  Timer? _timer;
  int _secondsElapsed = 0;
  late int _currentAttemptForDisplay;

  bool _isLoadingLessonContent = true;
  Map<String, dynamic>? _lessonData;
  List<dynamic> _activityPrompts = [];
  late Map<String, TextEditingController> _textControllers;

  // New enhancements
  static const String _lessonDocId = 'lesson_2_2';
  static const String _preAssessmentKey = 'Lesson-2-2';
  bool _preAssessmentCompleted = true;
  bool _checkingPreAssessment = true;

  // Activity log
  bool _showActivityLog = false;
  bool _activityLogLoading = false;
  List<Map<String, dynamic>> _activityLog = [];

  // Key phrase mini-activity
  Map<String, String> _keyPhraseAnswers = {};
  bool _showKeyPhraseResults = false;

  // Interactive definitions base
  final Map<String, String> _baseDefinitions = {
    'polite': 'Showing good manners toward others.',
    'clarify': 'To make a statement or situation less confused.',
    'probe': 'Ask further questions to gain more detail.',
    'verify': 'Confirm the truth or accuracy.',
    'assist': 'Help or support.',
  };

  // Fallback slides
  final List<Map<String, dynamic>> _staticSlidesDataFallback = [
    {
      'title': 'Objective: Asking for Information Politely (Fallback)',
      'content':
          'Learn polite techniques for gathering information from customers.'
    },
    {
      'title': 'Polite Question Forms (Fallback)',
      'content':
          '• Could you... • Would you mind... • May I...'
    },
    {
      'title': 'Explaining Need (Fallback)',
      'content': 'Explain why information is needed to build trust.'
    },
    {
      'title': 'Clarifying (Fallback)',
      'content': 'Active listening and clarification improve accuracy.'
    },
    {
      'title': 'Video Intro (Fallback)',
      'content': 'Watch how probing questions improve outcomes.'
    },
  ];

  @override
  void initState() {
    super.initState();
    _currentAttemptForDisplay = widget.initialAttemptNumber + 1;
    _textControllers = {};
    _fetchLessonContent();
    widget.youtubeController.addListener(_videoListener);
    if (widget.showActivitySection && !widget.displayFeedback) {
      _startTimer();
    }
  }

  // Firestore (with fallback hardcoded dataset)
  Future<void> _fetchLessonContent() async {
    setState(() => _isLoadingLessonContent = true);
    Map<String, dynamic>? firestoreData;
    try {
      final doc =
          await FirebaseFirestore.instance.collection('lessons').doc(_lessonDocId).get();
      if (doc.exists) {
        firestoreData = doc.data();
        _logger.i('Lesson2_2 Firestore data loaded.');
      } else {
        _logger.w('Lesson2_2 Firestore doc missing. Using fallback.');
      }
    } catch (e) {
      _logger.e('Lesson2_2 Firestore fetch error: $e');
    }

    final Map<String, dynamic> hardcodedLesson2_2Data = {
      'lessonTitle': 'Lesson 2.2: Asking for Information (HC)',
      'slides': [
        {
          'title': 'Objective',
          'content':
              'Confidently ask for information in customer service scenarios.'
        },
        {
          'title': 'Introduction',
          'content':
              'Asking clear, polite, professional questions ensures efficiency.'
        },
        {
          'title': 'Key Phrases',
          'content':
              '• "Could I get your full name?"\n• "Could you provide the account number?"\n• "Do you have the order number?"'
        },
        {
          'title': 'More Common Questions',
          'content':
              '1. How can I assist you today?\n2. What issue are you experiencing?\n3. Could you explain the problem a bit more?'
        },
        {
          'title': 'Watch: Probing Questions',
          'content':
              'Video demonstration of effective probing questions.'
        }
      ],
      'video': {'url': 'bQ90ZCNFuq0'},
      'activity': {
        'title': 'Interactive Activity: Asking for Information',
        'objective':
            'Practice asking clear, polite, professional questions.',
        'instructions': {
          'introParagraph':
              'Respond as an agent. Include at least three relevant questions.'
        },
        'prompts': [
          {
            'name': 'scenario1',
            'label': 'Scenario 1: Broken Item',
            'customerText':
                'Customer: "The item I received is broken."',
            'agentPrompt':
                'Ask at least 3 relevant questions about the order and issue.'
          },
          {
            'name': 'scenario2',
            'label': 'Scenario 2: Slow Internet',
            'customerText':
                'Customer: "My internet has been very slow for days."',
            'agentPrompt':
                'Ask at least 3 probing questions to diagnose the issue.'
          },
        ],
        'maxPossibleAIScore': 10,
      },
    };

    _lessonData = firestoreData ?? hardcodedLesson2_2Data;

    _activityPrompts =
        _lessonData?['activity']?['prompts'] as List<dynamic>? ?? [];
    _textControllers.forEach((_, c) => c.dispose());
    _textControllers.clear();
    for (final p in _activityPrompts) {
      if (p is Map && p['name'] is String) {
        _textControllers[p['name']] = TextEditingController();
      }
    }

    // Key phrase mini activity setup
    final kp = _lessonData?['keyPhraseActivity'];
    if (kp is Map &&
        kp['questions'] is List &&
        (kp['questions'] as List).isNotEmpty) {
      _keyPhraseAnswers = {
        for (final q in (kp['questions'] as List))
          if (q is Map && q['id'] is String) q['id']: ''
      };
    }

    setState(() => _isLoadingLessonContent = false);
    _checkPreAssessmentStatus();
  }

  // Pre-assessment
  Future<void> _checkPreAssessmentStatus() async {
    setState(() => _checkingPreAssessment = true);
    final hasPre = _lessonData?['preAssessmentData'] != null;
    if (!hasPre) {
      _preAssessmentCompleted = true;
      _checkingPreAssessment = false;
      setState(() {});
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _preAssessmentCompleted = false;
      _checkingPreAssessment = false;
      setState(() {});
      return;
    }
    try {
      final prog = await FirebaseFirestore.instance
          .collection('userProgress')
          .doc(user.uid)
          .get();
      if (prog.exists) {
        final map =
            (prog.data()?['preAssessmentsCompleted'] as Map<String, dynamic>?) ??
                {};
        _preAssessmentCompleted = map[_preAssessmentKey] == true;
      } else {
        _preAssessmentCompleted = false;
      }
    } catch (e) {
      _logger.w('Pre-assessment status error: $e');
      _preAssessmentCompleted = true; // fail-open
    }
    _checkingPreAssessment = false;
    setState(() {});
  }

  Future<void> _markPreAssessmentComplete() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(widget.parentContext)
          .showSnackBar(const SnackBar(content: Text('Login required.')));
      return;
    }
    try {
      await FirebaseFirestore.instance
          .collection('userProgress')
          .doc(user.uid)
          .set({
        'preAssessmentsCompleted': {_preAssessmentKey: true}
      }, SetOptions(merge: true));
      setState(() => _preAssessmentCompleted = true);
    } catch (e) {
      _logger.e('Mark pre-assessment error: $e');
    }
  }

  Widget _preAssessmentGate() {
    if (_checkingPreAssessment) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_lessonData?['preAssessmentData'] == null ||
        _preAssessmentCompleted) {
      return const SizedBox();
    }
    final pre = _lessonData!['preAssessmentData'];
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Pre-Assessment',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00568D))),
          const SizedBox(height: 10),
          Text(
            (pre['instruction'] ??
                    'Complete this quick pre-assessment before continuing.')
                .toString(),
            style: const TextStyle(fontSize: 14),
          ),
            const SizedBox(height: 16),
          ElevatedButton(
              onPressed: _markPreAssessmentComplete,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00568D),
                  foregroundColor: Colors.white),
              child: const Text('Mark as Complete'))
        ]),
      ),
    );
  }

  // Activity Log
  Future<void> _loadActivityLog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(widget.parentContext)
          .showSnackBar(const SnackBar(content: Text('Login required.')));
      return;
    }
    setState(() {
      _showActivityLog = true;
      _activityLogLoading = true;
    });
    try {
      final prog = await FirebaseFirestore.instance
          .collection('userProgress')
          .doc(user.uid)
          .get();
      List<Map<String, dynamic>> logs = [];
      if (prog.exists) {
        final attemptsMap =
            prog.data()?['lessonAttempts'] as Map<String, dynamic>? ?? {};
        final arr = attemptsMap[_preAssessmentKey] as List<dynamic>? ?? [];
        logs = arr.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        logs.sort((a, b) {
          final aN = (a['attemptNumber'] ?? 0) as num;
          final bN = (b['attemptNumber'] ?? 0) as num;
          return aN.compareTo(bN);
        });
      }
      setState(() {
        _activityLog = logs;
        _activityLogLoading = false;
      });
    } catch (e) {
      _logger.e('Activity log error: $e');
      setState(() {
        _activityLog = [];
        _activityLogLoading = false;
      });
    }
  }

  void _closeActivityLog() =>
      setState(() => _showActivityLog = false);

  Widget _activityLogOverlay() {
    return Positioned.fill(
      child: Material(
        color: Colors.black54,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640, maxHeight: 620),
            child: Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.history, color: Color(0xFF00568D)),
                      const SizedBox(width: 8),
                      const Expanded(
                          child: Text('Activity Log - Lesson 2.2',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF00568D)))),
                      IconButton(
                          onPressed: _closeActivityLog,
                          icon: const Icon(Icons.close))
                    ]),
                    const Divider(),
                    Expanded(
                      child: _activityLogLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _activityLog.isEmpty
                              ? const Center(
                                  child: Text('No attempts yet.',
                                      style: TextStyle(color: Colors.grey)))
                              : ListView.separated(
                                  itemCount: _activityLog.length,
                                  separatorBuilder: (_, __) => Divider(
                                      color: Colors.grey.shade200, height: 16),
                                  itemBuilder: (_, i) {
                                    final a = _activityLog[i];
                                    final ts = a['timestamp'] ??
                                        a['attemptTimestamp'];
                                    DateTime? dt;
                                    if (ts is Timestamp) dt = ts.toDate();
                                    return ExpansionTile(
                                      tilePadding: EdgeInsets.zero,
                                      title: Text(
                                          'Attempt ${a['attemptNumber'] ?? '-'} - Score ${a['score'] ?? '-'}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600)),
                                      subtitle: Text(
                                          'Time Spent: ${a['timeSpent'] ?? a['timeSpentSeconds'] ?? '—'}s • ${dt != null ? dt.toLocal().toString() : ''}',
                                          style: const TextStyle(fontSize: 12)),
                                      children: [
                                        if (_lessonData?['activity']
                                                ?['prompts']
                                            is List)
                                          ...((_lessonData?['activity']
                                                      ?['prompts'] as List)
                                                  .cast()
                                                  .whereType<Map>())
                                              .map((p) {
                                            final name = p['name'] ?? '';
                                            final label = p['label'] ?? name;
                                            final userAnswer =
                                                a['detailedResponses']
                                                        ?['scenarioAnswers_L2_2']
                                                    ?[name];
                                            final fb =
                                                a['detailedResponses']
                                                        ?['scenarioFeedback_L2_2']
                                                    ?[name];
                                            return Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 6),
                                              child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(label,
                                                        style: const TextStyle(
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold)),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      userAnswer ??
                                                          '(No answer)',
                                                      style: const TextStyle(
                                                          fontStyle:
                                                              FontStyle.italic),
                                                    ),
                                                    if (fb != null)
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(top: 4),
                                                        child: Text(
                                                          (fb['text'] ??
                                                                  'No feedback')
                                                              .toString(),
                                                          style:
                                                              const TextStyle(
                                                                  fontSize: 12,
                                                                  color: Colors
                                                                      .blueGrey),
                                                        ),
                                                      )
                                                  ]),
                                            );
                                          })
                                      ],
                                    );
                                  },
                                ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _closeActivityLog,
                        icon: const Icon(Icons.close),
                        label: const Text('Close'),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Video
  void _videoListener() {
    if (widget.youtubeController.value.playerState == PlayerState.ended &&
        !_videoFinished) {
      setState(() => _videoFinished = true);
      _logger.i('Video finished L2.2');
    }
  }

  // Timer
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

  void _stopTimer() => _timer?.cancel();
  void _resetTimer() => setState(() => _secondsElapsed = 0);

  String _formatDuration(int s) {
    final d = Duration(seconds: s);
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final sec = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  // Scenario submission
  void _handleSubmit() async {
    if (!mounted) return;
    final allAnswered = _activityPrompts.every((p) {
      final name = p['name'] as String?;
      if (name == null) return false;
      return _textControllers[name]?.text.trim().isNotEmpty == true;
    });
    if (!allAnswered) {
      ScaffoldMessenger.of(widget.parentContext).showSnackBar(const SnackBar(
          content: Text('Please answer all scenarios before submitting.')));
      return;
    }
    setState(() => _isSubmitting = true);
    _stopTimer();

    final answers = <String, String>{};
    _textControllers.forEach((k, c) => answers[k] = c.text.trim());
    try {
      await widget.onSubmitAnswers(
          answers, _secondsElapsed, widget.initialAttemptNumber);
    } catch (e) {
      _logger.e('Submit error L2.2: $e');
      ScaffoldMessenger.of(widget.parentContext).showSnackBar(
          SnackBar(content: Text('Submission error: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // Key phrase mini activity
  void _onKeyPhraseTap(String qId, String opt) {
    if (_showKeyPhraseResults) return;
    setState(() {
      _keyPhraseAnswers[qId] = opt;
    });
  }

  Widget _buildKeyPhraseQuestion(Map q, int idx) {
    final id = q['id']?.toString() ?? 'q$idx';
    final prompt = q['promptText']?.toString() ?? 'Question';
    final options = (q['options'] as List?)?.cast<String>() ?? [];
    final correct = q['correctAnswer']?.toString();
    final selected = _keyPhraseAnswers[id];
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${idx + 1}. $prompt',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(height: 10),
              ...options.map((opt) {
                final isSel = selected == opt;
                bool isCorrect = false;
                bool isIncorrect = false;
                if (_showKeyPhraseResults) {
                  if (opt == correct) {
                    isCorrect = true;
                  } else if (isSel && opt != correct) {
                    isIncorrect = true;
                  }
                }
                Color border = Colors.grey.shade300;
                Color? tile;
                Icon? trailing;
                if (isCorrect) {
                  border = Colors.green;
                  tile = Colors.green.shade50;
                  trailing =
                      const Icon(Icons.check_circle, color: Colors.green);
                } else if (isIncorrect) {
                  border = Colors.red;
                  tile = Colors.red.shade50;
                  trailing =
                      const Icon(Icons.cancel, color: Colors.red);
                } else if (isSel) {
                  border = Theme.of(context).primaryColor;
                }
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: border, width: 1.2),
                      color: tile),
                  child: ListTile(
                    dense: true,
                    title: Text(opt),
                    trailing: trailing,
                    onTap: () => _onKeyPhraseTap(id, opt),
                  ),
                );
              })
            ]),
      ),
    );
  }

  Widget _buildKeyPhraseActivity() {
    final kp = _lessonData?['keyPhraseActivity'];
    if (kp is! Map) return const SizedBox();
    final qs = (kp['questions'] as List?) ?? [];
    if (qs.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(kp['title']?.toString() ?? 'Key Phrase Check',
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00568D))),
        if (kp['instruction'] is String)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(kp['instruction'],
                style:
                    const TextStyle(fontSize: 13, color: Colors.black87)),
          ),
        const SizedBox(height: 10),
        ...qs.asMap().entries.map((e) => _buildKeyPhraseQuestion(
            e.value as Map, e.key)),
        const SizedBox(height: 10),
        if (!_showKeyPhraseResults)
          Center(
            child: ElevatedButton(
              onPressed: () {
                final allAnswered = qs.every((q) =>
                    _keyPhraseAnswers[(q as Map)['id']]?.isNotEmpty == true);
                if (!allAnswered) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content:
                          Text('Answer all key phrase questions first.')));
                  return;
                }
                setState(() => _showKeyPhraseResults = true);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00568D),
                  foregroundColor: Colors.white),
              child: const Text('Check My Answers'),
            ),
          )
        else
          Center(
            child: TextButton(
              onPressed: () {
                setState(() {
                  _showKeyPhraseResults = false;
                  _keyPhraseAnswers.updateAll((key, value) => '');
                });
              },
              child: const Text('Retry Key Phrase Activity'),
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  // Interactive text
  Widget _interactiveText(String text, {Map<String, dynamic>? defsDynamic}) {
    final merged = {
      ..._baseDefinitions,
      ...?defsDynamic?.map((k, v) => MapEntry(k.toString(), v.toString()))
    };
    final words = text.split(' ');
    final spans = <TextSpan>[];
    for (var i = 0; i < words.length; i++) {
      final raw = words[i];
      final clean = raw.toLowerCase().replaceAll(RegExp(r'[^\w]'), '');
      if (merged.containsKey(clean)) {
        spans.add(TextSpan(
            text: raw,
            style: const TextStyle(
                color: Color(0xFF00568D),
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.underline),
            recognizer: TapGestureRecognizer()
              ..onTap =
                  () => _showDefinitionDialog(clean, merged[clean] ?? '')));
      } else {
        spans.add(TextSpan(text: raw));
      }
      if (i != words.length - 1) spans.add(const TextSpan(text: ' '));
    }
    return RichText(
        text: TextSpan(
            style: const TextStyle(
                fontSize: 14, height: 1.5, color: Colors.black87),
            children: spans));
  }

  void _showDefinitionDialog(String w, String def) {
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
              title: Text(w.toUpperCase()),
              content: Text(def),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'))
              ],
            ));
  }

  @override
  void didUpdateWidget(covariant buildLesson2_2 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.youtubeController != oldWidget.youtubeController) {
      oldWidget.youtubeController.removeListener(_videoListener);
      widget.youtubeController.addListener(_videoListener);
    }
    final shouldResetForNewAttempt = (widget.showActivitySection &&
            !widget.displayFeedback) &&
        ((widget.showActivitySection != oldWidget.showActivitySection &&
                !oldWidget.displayFeedback) ||
            (widget.initialAttemptNumber != oldWidget.initialAttemptNumber));
    if (shouldResetForNewAttempt) {
      _currentAttemptForDisplay = widget.initialAttemptNumber + 1;
      _textControllers.forEach((_, c) => c.clear());
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
    _textControllers.forEach((_, c) => c.dispose());
    _stopTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingLessonContent) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_lessonData == null) {
      return const Center(
          child: Text('Lesson 2.2 content unavailable (fallback failed).'));
    }

    final title = _lessonData!['lessonTitle']?.toString() ?? 'Lesson 2.2';
    List<dynamic> slides =
        _lessonData!['slides'] as List<dynamic>? ?? [];
    if (slides.isEmpty) slides = _staticSlidesDataFallback;

    final activityTitle =
        _lessonData!['activity']?['title']?.toString() ??
            'Interactive Scenarios';

    String activityInstructions = '';
    final instructionsMap =
        _lessonData!['activity']?['instructions'] as Map<String, dynamic>?;
    if (instructionsMap != null &&
        instructionsMap['introParagraph'] is String) {
      activityInstructions =
          instructionsMap['introParagraph'] as String;
    } else if (_lessonData!['activity']?['objective'] is String) {
      activityInstructions =
          _lessonData!['activity']?['objective'] as String;
    } else {
      activityInstructions =
          'Type your responses to the following scenarios.';
    }

    final keyPhrases = _lessonData?['keyPhrases'] as Map<String, dynamic>?;

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _preAssessmentGate(),

                if (!widget.showActivitySection) ...[
                  Text(title,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                              color: const Color(0xFF00568D),
                              fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  if (slides.isNotEmpty) ...[
                    CarouselSlider(
                      key: ValueKey('carousel_l2_2_${slides.hashCode}'),
                      carouselController: widget.carouselController,
                      items: slides.map((slide) {
                        return buildSlide(
                          title: slide['title']?.toString() ??
                              'Slide Title',
                          content: slide['content']?.toString() ??
                              'Slide Content',
                          slideIndex: slides.indexOf(slide),
                        );
                      }).toList(),
                      options: CarouselOptions(
                          height: 250,
                          viewportFraction: 0.9,
                          enlargeCenterPage: false,
                          enableInfiniteScroll: false,
                          initialPage: widget.currentSlide,
                          onPageChanged: (i, _) =>
                              widget.onSlideChanged(i)),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: slides.asMap().entries.map((e) {
                        return GestureDetector(
                          onTap: () => widget.carouselController
                              .animateToPage(e.key),
                          child: Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: widget.currentSlide == e.key
                                  ? const Color(0xFF00568D)
                                  : Colors.grey,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (widget.currentSlide >=
                      (slides.isNotEmpty ? slides.length - 1 : 0))
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Watch the Video',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                    color: const Color(0xFF00568D))),
                        const SizedBox(height: 8),
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: YoutubePlayer(
                            key: widget.youtubePlayerKey,
                            controller: widget.youtubeController,
                            showVideoProgressIndicator: true,
                            onReady: () =>
                                _logger.i('L2.2 Player Ready'),
                            onEnded: (_) => _videoListener(),
                          ),
                        ),
                        if (!widget.showActivitySection) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                  onPressed: _videoFinished
                                      ? widget.onShowActivitySection
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                      disabledBackgroundColor:
                                          Colors.grey[300]),
                                  child:
                                      const Text('Proceed to Activity'))),
                          if (!_videoFinished)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                'Please watch the video to proceed.',
                                style: TextStyle(
                                    color: Colors.red, fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                      ],
                    ),
                  const SizedBox(height: 24),
                  if (keyPhrases != null &&
                      keyPhrases['heading'] != null) ...[
                    Text(keyPhrases['heading'].toString(),
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00568D))),
                    const SizedBox(height: 8),
                    if (keyPhrases['introParagraph'] is String)
                      _interactiveText(
                        keyPhrases['introParagraph'] as String,
                        defsDynamic:
                            keyPhrases['definitions'] as Map<String, dynamic>?,
                      ),
                    if (keyPhrases['listItems'] is List &&
                        (keyPhrases['listItems'] as List).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.blue.shade100),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children:
                                (keyPhrases['listItems'] as List)
                                    .map((e) => Padding(
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  vertical: 4),
                                          child: Text('• ${e.toString()}',
                                              style: const TextStyle(
                                                  fontSize: 13.5,
                                                  height: 1.4)),
                                        ))
                                    .toList(),
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                  ],
                  _buildKeyPhraseActivity(),
                  if (!_videoFinished)
                    Align(
                      alignment: Alignment.center,
                      child: OutlinedButton(
                          onPressed: widget.onShowActivitySection,
                          child:
                              const Text('Skip Video & Start Activity')),
                    ),
                ],

                if (widget.showActivitySection) ...[
                  const SizedBox(height: 8),
                  Text(activityTitle,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(color: Colors.orange)),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Attempt: $_currentAttemptForDisplay',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium),
                        if (!widget.displayFeedback)
                          Text('Time: ${_formatDuration(_secondsElapsed)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium),
                      ],
                    ),
                  ),
                  HtmlFormattedText(htmlString: activityInstructions),
                  const SizedBox(height: 16),
                  if (!widget.displayFeedback) ...[
                    if (_activityPrompts.isEmpty &&
                        !_isLoadingLessonContent)
                      const Center(
                          child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No activity prompts defined.'),
                      )),
                    ..._activityPrompts.map((promptData) {
                      final name = promptData['name'] as String? ??
                          'scenario';
                      final label =
                          promptData['label'] as String? ?? 'Scenario';
                      final customerText =
                          promptData['customerText'] as String? ?? '';
                      final agentTask =
                          promptData['agentPrompt'] as String? ??
                              'Your response:';
                      final controller =
                          _textControllers[name];
                      if (controller == null) return const SizedBox();
                      return Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 10),
                        child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(label,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                          fontWeight:
                                              FontWeight.bold)),
                              if (customerText.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(
                                      top: 4, bottom: 2),
                                  child: Text(
                                      'Customer: "$customerText"',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                              fontStyle:
                                                  FontStyle.italic,
                                              color: Colors
                                                  .grey[700])),
                                ),
                              Padding(
                                padding:
                                    const EdgeInsets.only(top: 4),
                                child: Text(agentTask,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                            color: Colors.blueAccent)),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: controller,
                                decoration: InputDecoration(
                                  border: const OutlineInputBorder(),
                                  hintText:
                                      'Type your questions for $label...',
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                ),
                                keyboardType: TextInputType.multiline,
                                maxLines: 4,
                                minLines: 3,
                              ),
                            ]),
                      );
                    }),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed:
                            _isSubmitting ? null : _handleSubmit,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00568D),
                            disabledBackgroundColor: Colors.grey),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(
                                            Colors.white)))
                            : const Text('Submit for AI Feedback',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 16)),
                      ),
                    ),
                  ],
                  if (widget.displayFeedback &&
                      widget.aiFeedbackData != null) ...[
                    if (widget.overallAIScoreForDisplay != null &&
                        widget.maxPossibleAIScoreForDisplay != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 16),
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
                    if (_activityPrompts.isEmpty &&
                        !_isLoadingLessonContent)
                      const Center(
                          child: Padding(
                        padding: EdgeInsets.all(16),
                        child:
                            Text('No prompts loaded for feedback.'),
                      )),
                    ..._activityPrompts.map((promptData) {
                      final name = promptData['name'] as String? ??
                          'scenario';
                      final label =
                          promptData['label'] as String? ?? 'Scenario';
                      final feedbackForPrompt =
                          widget.aiFeedbackData![name]
                              as Map<String, dynamic>?;

                      String userAnswer =
                          _textControllers[name]?.text.trim() ?? '';
                      if (userAnswer.isEmpty) {
                        final allAnswersParent =
                            widget.aiFeedbackData!['scenarioAnswers_L2_2']
                                as Map<String, dynamic>?;
                        userAnswer =
                            allAnswersParent?[name] as String? ??
                                'Not available';
                      }

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(label,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color:
                                                const Color(0xFF00568D))),
                                const SizedBox(height: 6),
                                Text('Your Answer:',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge),
                                Text(
                                  userAnswer.isNotEmpty
                                      ? userAnswer
                                      : '(No answer provided)',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                          fontStyle: FontStyle.italic,
                                          color: Colors.grey[700]),
                                ),
                                const SizedBox(height: 12),
                                if (feedbackForPrompt != null) ...[
                                  Text(
                                    'AI Feedback (Score: ${feedbackForPrompt['score'] ?? 'N/A'}):',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blueAccent),
                                  ),
                                  const SizedBox(height: 4),
                                  HtmlFormattedText(
                                      htmlString:
                                          feedbackForPrompt['text']
                                                  as String? ??
                                              'No feedback text.'),
                                ] else
                                  const Text(
                                      'AI Feedback: Not available.',
                                      style: TextStyle(
                                          color: Colors.grey)),
                              ]),
                        ),
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
                            style: TextStyle(
                                color: Colors.white, fontSize: 16)),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 28),
                Center(
                  child: OutlinedButton.icon(
                      onPressed: _loadActivityLog,
                      icon: const Icon(Icons.history),
                      label: const Text('View Activity Log')),
                ),
                const SizedBox(height: 40),
              ]),
        ),
        if (_showActivityLog) _activityLogOverlay(),
      ],
    );
  }

  Widget _aiFeedbackWidget() {
    if (!widget.displayFeedback || widget.aiFeedbackData == null) {
      return const SizedBox.shrink();
    }
    final data = widget.aiFeedbackData!;
    if (data.isEmpty) return const SizedBox.shrink();

    final overallScore = widget.overallAIScoreForDisplay;
    final maxScore = widget.maxPossibleAIScoreForDisplay;

    final list = data.entries
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
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'AI Score: $overallScore / $maxScore',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ...list,
      ],
    );
  }
}

// HTML-lite formatter
class HtmlFormattedText extends StatelessWidget {
  final String htmlString;
  const HtmlFormattedText({super.key, required this.htmlString});

  @override
  Widget build(BuildContext context) {
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
        .replaceAll(RegExp(r'<[^>]*>'), '');
    displayText = displayText
        .trim()
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .join('\n');
    return Text(displayText,
        style: const TextStyle(fontSize: 14, height: 1.5));
  }
}