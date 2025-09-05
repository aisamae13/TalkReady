//8-29-2025

import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:logger/logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../firebase_service.dart';
import '../lessons/common_widgets.dart';
import '../StudentAssessment/InteractiveText.dart'; // Add this import
import '../StudentAssessment/PreAssessment.dart';

class buildLesson1_2 extends StatefulWidget {
  // Study props (unchanged)
  final int currentSlide;
  final CarouselSliderController carouselController;
  final YoutubePlayerController youtubeController;
  final bool showActivity;
  final VoidCallback onShowActivity;
  final Function(int) onSlideChanged;

  // Activity props (unchanged, parent-managed)
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

  const buildLesson1_2({
    super.key,
    required this.currentSlide,
    required this.carouselController,
    required this.youtubeController,
    required this.showActivity,
    required this.onShowActivity,
    required this.onSlideChanged,
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
  State<buildLesson1_2> createState() => _Lesson1_2State();
}

class _Lesson1_2State extends State<buildLesson1_2> {
  final Logger _logger = Logger();
  final FirebaseService _firebaseService = FirebaseService();

  // Video gate
  bool _videoFinished = false;

  // Internal enhancements (do NOT change parent API)
  bool _hasStudied = false;
  bool _loadingLessonMeta = true;
  bool _preAssessmentCompleted = true;
  bool _showActivityLog = false;
  bool _activityLogLoading = false;
  List<Map<String, dynamic>> _activityLog = [];
  Map<String, dynamic>? _lessonData;

  static const String _lessonDocId = 'lesson_1_2';
  static const String _preAssessmentKey = 'Lesson-1-2';

  // Study slides (fallback)
  final List<Map<String, String>> _staticSlides = [
    {
      'title': 'Objective: Mastering Simple Sentences',
      'content':
          'Form simple sentences correctly; identify sentence types in call center scenarios.'
    },
    {
      'title': 'Structure',
      'content':
          'Simple sentence = Subject + Verb (+ Object/Complement). Example: "The customer needs help."'
    },
    {
      'title': 'Types',
      'content':
          'Declarative, Interrogative, Imperative, Exclamatory. Variety improves engagement.'
    },
  ];

  // Definitions for interactive intro
  final Map<String, String> _definitions = {
    'declarative': 'A sentence that makes a statement.',
    'interrogative': 'A sentence that asks a question.',
    'imperative': 'A sentence that gives a command or request.',
    'exclamatory': 'A sentence expressing strong emotion.',
    'subject': 'The doer or topic of the sentence.',
    'verb': 'The action or state of being.',
  };

  @override
  void initState() {
    super.initState();
    widget.youtubeController.addListener(_videoListener);
    _fetchLessonMeta();
    _checkPreAssessmentStatus();
  }

  @override
  void didUpdateWidget(covariant buildLesson1_2 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.youtubeController != widget.youtubeController) {
      oldWidget.youtubeController.removeListener(_videoListener);
      widget.youtubeController.addListener(_videoListener);
    }
  }

  @override
  void dispose() {
    widget.youtubeController.removeListener(_videoListener);
    super.dispose();
  }

  void _videoListener() {
    if (!mounted) return;
    if (widget.youtubeController.value.playerState == PlayerState.ended &&
        !_videoFinished) {
      setState(() => _videoFinished = true);
      _logger.i('Lesson1.2 video finished.');
    }
  }

  Future<void> _fetchLessonMeta() async {
    setState(() => _loadingLessonMeta = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('lessons')
          .doc(_lessonDocId)
          .get();
      if (doc.exists) {
        final data = doc.data();
        setState(() {
          _lessonData = data;
          // Gate only if preAssessment data actually present
          if (_lessonData?['preAssessmentData'] == null) {
            _preAssessmentCompleted = true;
          }
          _loadingLessonMeta = false;
        });
      } else {
        setState(() {
          _lessonData = null;
          _loadingLessonMeta = false;
        });
      }
    } catch (e) {
      _logger.e('Error fetching lesson1_2 meta: $e');
      if (mounted) {
        setState(() {
          _lessonData = null;
          _loadingLessonMeta = false;
        });
      }
    }
  }

  Future<void> _checkPreAssessmentStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final prog = await FirebaseFirestore.instance
          .collection('userProgress')
          .doc(user.uid)
          .get();
      if (prog.exists) {
        final map =
            (prog.data()?['preAssessmentsCompleted'] as Map<String, dynamic>?) ??
                {};
        if (mounted) {
          setState(() {
            _preAssessmentCompleted = map[_preAssessmentKey] == true ||
                _lessonData?['preAssessmentData'] == null;
          });
        }
      }
    } catch (e) {
      _logger.w('Pre-assessment check failed: $e');
    }
  }

  Future<void> _markPreAssessmentComplete() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('userProgress')
          .doc(user.uid)
          .set({
        'preAssessmentsCompleted': {_preAssessmentKey: true}
      }, SetOptions(merge: true));
      if (mounted) setState(() => _preAssessmentCompleted = true);
    } catch (e) {
      _logger.e('Error marking pre-assessment complete: $e');
    }
  }

  Future<void> _loadActivityLog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Login required.')));
      return;
    }
    setState(() {
      _showActivityLog = true;
      _activityLogLoading = true;
    });
    try {
      final up = await FirebaseFirestore.instance
          .collection('userProgress')
          .doc(user.uid)
          .get();
      List<Map<String, dynamic>> logs = [];
      if (up.exists) {
        final attemptsMap =
            up.data()?['lessonAttempts'] as Map<String, dynamic>? ?? {};
        final arr = attemptsMap[_preAssessmentKey] as List<dynamic>? ?? [];
        logs = arr.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        logs.sort((a, b) {
          final aN = a['attemptNumber'] ?? 0;
            final bN = b['attemptNumber'] ?? 0;
          return aN.compareTo(bN);
        });
      }
      if (mounted) {
        setState(() {
          _activityLog = logs;
          _activityLogLoading = false;
        });
      }
    } catch (e) {
      _logger.e('Activity log error: $e');
      if (mounted) {
        setState(() {
          _activityLog = [];
          _activityLogLoading = false;
        });
      }
    }
  }

  void _closeActivityLog() {
    setState(() => _showActivityLog = false);
  }

  String _fmt(int s) {
    final d = Duration(seconds: s);
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final sec = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  // ===== UI helpers =====
  Widget _buildMCQOption(String optionText, String questionId) {
    final sel = widget.selectedAnswerForCurrentQuestion == optionText;
    Color border = Colors.grey.shade300;
    Color? fill;
    Widget? icon;

    if (widget.showResultsForCurrentQuestion != null &&
        widget.currentQuestionData != null) {
      final correct =
          widget.currentQuestionData!['correctAnswer'] == optionText;
      if (sel) {
        final ok = widget.showResultsForCurrentQuestion == true;
        fill = ok ? Colors.green.shade50 : Colors.red.shade50;
        border = ok ? Colors.green : Colors.red;
        icon = Icon(ok ? Icons.check_circle : Icons.cancel,
            color: ok ? Colors.green : Colors.red);
      } else if (correct) {
        border = Colors.green;
        icon = const Icon(Icons.check_circle_outline, color: Colors.green);
      }
    }

    return Card(
      elevation: sel && widget.showResultsForCurrentQuestion == null ? 3 : 1,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: border, width: sel ? 2 : 1)),
      child: RadioListTile<String>(
        title: Text(optionText),
        value: optionText,
        groupValue: widget.selectedAnswerForCurrentQuestion,
        onChanged: (widget.showResultsForCurrentQuestion != null ||
                widget.isSubmitting)
            ? null
            : (v) {
                if (v != null) widget.onOptionSelected(questionId, v);
              },
        activeColor: Theme.of(context).primaryColor,
        tileColor: fill,
        secondary: icon,
      ),
    );
  }

  Widget _buildSentenceScramble(Map<String, dynamic> q) {
    final parts = (q['parts'] as List?)?.cast<String>() ?? [];
    // No parent API for ordering; show static chips
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Arrange (display only – parent API not wired)',
            style: TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
            runSpacing: 8,
          children: parts
              .map((p) => Chip(
                    label: Text(p),
                    backgroundColor: Colors.blue.shade50,
                    side: BorderSide(color: Colors.blue.shade200),
                  ))
              .toList(),
        ),
        if (widget.showResultsForCurrentQuestion != null &&
            q['correctOrder'] is List)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Correct order: ${(q['correctOrder'] as List).join(' ')}',
              style: const TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: Colors.green),
            ),
          )
      ],
    );
  }

  Widget _interactiveIntro(String text) {
    return InteractiveTextWithDialog(
      text: text,
      definitions: _definitions,
      baseTextStyle: const TextStyle(
        fontSize: 16,
        height: 1.5,
        color: Colors.black87,
      ),
      clickableTextStyle: const TextStyle(
        color: Color(0xFF2563EB),
        fontSize: 16,
        fontWeight: FontWeight.bold,
        decoration: TextDecoration.underline,
        height: 1.5,
      ),
    );
  }

  Widget _preAssessmentGate() {
    if (_lessonData?['preAssessmentData'] == null) return const SizedBox();
    if (_preAssessmentCompleted) return const SizedBox();
    return Card(
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
            const Text(
                'Complete this short pre-assessment before proceeding.'),
            const SizedBox(height: 16),
            ElevatedButton(
                onPressed: _markPreAssessmentComplete,
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00568D),
                    foregroundColor: Colors.white),
                child: const Text('Mark as Complete'))
          ]),
        ));
  }

  Widget _studySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Lesson 1.2: Simple Sentences',
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00568D))),
        const SizedBox(height: 14),
        CarouselSlider(
          items: _staticSlides
              .asMap()
              .entries
              .map((e) => buildSlide(
                    title: e.value['title'] ?? '',
                    content: e.value['content'] ?? '',
                    slideIndex: e.key,
                  ))
              .toList(),
          carouselController: widget.carouselController,
          options: CarouselOptions(
            height: 300,
            enlargeCenterPage: true,
            enableInfiniteScroll: false,
            initialPage: widget.currentSlide,
            onPageChanged: (i, _) => widget.onSlideChanged(i),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _staticSlides
              .asMap()
              .entries
              .map((e) => GestureDetector(
                    onTap: () =>
                        widget.carouselController.animateToPage(e.key),
                    child: Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 3),
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF00568D).withOpacity(
                              widget.currentSlide == e.key ? 0.9 : 0.35)),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 20),
        if (_lessonData?['introduction'] != null)
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child:
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  _lessonData!['introduction']['heading'] ??
                      'Introduction',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00568D)),
                ),
                const SizedBox(height: 10),
                if (_lessonData!['introduction']['paragraph1'] != null)
                  _interactiveIntro(
                      _lessonData!['introduction']['paragraph1']),
                if (_lessonData!['introduction']['paragraph2'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      _lessonData!['introduction']['paragraph2'],
                      style: const TextStyle(fontSize: 16, height: 1.5),
                    ),
                  ),
              ]),
            ),
          ),
        const SizedBox(height: 20),
        if (widget.youtubeController.initialVideoId.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Watch the Video',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00568D))),
              const SizedBox(height: 8),
              SizedBox(
                height: 200,
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
                          disabledBackgroundColor: Colors.grey.shade400),
                      child: const Text('Proceed to Activity'))),
              if (!_videoFinished)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('Watch the full video to continue.',
                      style: TextStyle(color: Colors.red, fontSize: 13)),
                ),
            ],
          ),
        const SizedBox(height: 24),
        if (!_hasStudied)
          Center(
            child: ElevatedButton(
                onPressed: () => setState(() => _hasStudied = true),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00568D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 14)),
                child:
                    const Text("I've Finished Studying – Proceed to Activity")),
          )
        else
          Center(
              child: ElevatedButton.icon(
                  onPressed: _videoFinished ? widget.onShowActivity : null,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start Activity'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey)))
      ],
    );
  }

  Widget _activitySection() {
    final q = widget.currentQuestionData;
    if (q == null && widget.totalQuestions > 0) {
      return const Center(child: Text('Loading question...'));
    }
    if (widget.totalQuestions == 0) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No questions available for this activity.',
            style: TextStyle(color: Colors.orange)),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Attempt: ${widget.initialAttemptNumber + 1}',
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          Text('Time: ${_fmt(widget.secondsElapsed)}',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: widget.secondsElapsed < 60
                      ? Colors.red.shade700
                      : Colors.black87)),
        ]),
      ),
      Card(
        elevation: 2,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(
                child: Text(
                    'Question ${widget.questionIndex + 1} of ${widget.totalQuestions}',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColorDark)),
              ),
              IconButton(
                icon: Icon(
                    widget.isFlagged ? Icons.flag : Icons.flag_outlined,
                    color: widget.isFlagged
                        ? Colors.amber.shade700
                        : Colors.grey.shade600),
                tooltip: widget.isFlagged
                    ? 'Unflag Question'
                    : 'Flag Question for Review',
                onPressed: widget.showResultsForCurrentQuestion != null
                    ? null
                    : () => widget.onToggleFlag(q!['id'].toString()),
              )
            ]),
            const Divider(height: 24),
            Text(
              q?['promptText'] ??
                  q?['text'] ??
                  'Question text not available.',
              style: const TextStyle(fontSize: 18, height: 1.4),
            ),
            const SizedBox(height: 18),
            if (q != null && q['type'] == 'sentence-scramble')
              _buildSentenceScramble(q)
            else if (q != null &&
                q['options'] is List &&
                q['type'] == 'multiple-choice')
              ...(q['options'] as List<dynamic>)
                  .map((o) =>
                      _buildMCQOption(o.toString(), q['id'].toString()))
                  ,
            if (widget.errorMessageForCurrentQuestion != null &&
                widget.showResultsForCurrentQuestion == false)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(widget.errorMessageForCurrentQuestion!,
                    style: const TextStyle(color: Colors.red)),
              ),
            if (widget.showResultsForCurrentQuestion == true)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Correct! ${q?['explanation'] ?? ''}',
                  style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
              ),
          ]),
        ),
      ),
      const SizedBox(height: 18),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        ElevatedButton(
            onPressed: (widget.isFirstQuestion ||
                    widget.showResultsForCurrentQuestion != null)
                ? null
                : widget.onPreviousQuestion,
            child: const Text('Previous')),
        if (widget.isLastQuestion &&
            widget.showResultsForCurrentQuestion == null)
          ElevatedButton(
              onPressed:
                  widget.isSubmitting ? null : widget.onSubmitAnswersFromLesson,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white),
              child: widget.isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white)))
                  : const Text('Submit All'))
        else if (!widget.isLastQuestion &&
            widget.showResultsForCurrentQuestion == null)
          ElevatedButton(
              onPressed: widget.onNextQuestion, child: const Text('Next')),
      ]),
      if (widget.showResultsForCurrentQuestion != null &&
          widget.isLastQuestion)
        const SizedBox(height: 12),
    ]);
  }

  Widget _activityLogOverlay() {
    return Positioned.fill(
      child: Material(
        color: Colors.black54,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child:
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Expanded(
                      child: Text('Activity Log',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00568D))),
                    ),
                    IconButton(
                        onPressed: _closeActivityLog,
                        tooltip: 'Close',
                        icon: const Icon(Icons.close))
                  ]),
                  const Divider(),
                  Expanded(
                    child: _activityLogLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _activityLog.isEmpty
                            ? const Center(
                                child: Text('No attempts recorded.'))
                            : ListView.separated(
                                itemCount: _activityLog.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 16),
                                itemBuilder: (_, i) {
                                  final log = _activityLog[i];
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          'Attempt ${log['attemptNumber'] ?? (i + 1)}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      Text(
                                          'Score: ${log['score'] ?? '—'} / ${log['totalScore'] ?? '—'}'),
                                      Text(
                                          'Time Spent: ${log['timeSpent'] ?? '—'}s'),
                                      if (log['attemptTimestamp'] != null)
                                        Text('${log['attemptTimestamp']}',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey)),
                                    ],
                                  );
                                }),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                        onPressed: _closeActivityLog,
                        child: const Text('Close')),
                  )
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingLessonMeta) {
      return const Center(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text('Loading lesson data...')
        ],
      ));
    }

    if (_lessonData == null) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('Unable to load Lesson 1.2 content.',
              style: TextStyle(color: Colors.red)),
          const SizedBox(height: 10),
          ElevatedButton(onPressed: _fetchLessonMeta, child: const Text('Retry'))
        ]),
      );
    }

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _preAssessmentGate(),
              if (_preAssessmentCompleted && !widget.showActivity)
                _studySection(),
              if (widget.showActivity) _activitySection(),
              const SizedBox(height: 24),
              Center(
                child: OutlinedButton.icon(
                    onPressed: _loadActivityLog,
                    icon: const Icon(Icons.history),
                    label: const Text('View Activity Log')),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Back to Course Outline',
                        style: TextStyle(
                            fontSize: 15, color: Color(0xFF00568D)))),
              ),
            ],
          ),
        ),
        if (_showActivityLog) _activityLogOverlay(),
      ],
    );
  }
}