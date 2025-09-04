// Enhanced Lesson 1.3 with pre‑assessment gating, activity log, interactive definitions.
// Public API (constructor params) intentionally unchanged.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:logger/logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../lessons/common_widgets.dart';
import '../StudentAssessment/InteractiveText.dart'; // Add this import

class buildLesson1_3 extends StatefulWidget {
  // Study props (unchanged)
  final int currentSlide;
  final CarouselSliderController carouselController;
  final YoutubePlayerController youtubeController;
  final bool showActivity;
  final VoidCallback onShowActivity;
  final Function(int) onSlideChanged;
  final List<Map<String, String>>? studySlides; // Optional dynamic slides
  final String? lessonTitle;

  // Activity props (unchanged)
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

  const buildLesson1_3({
    super.key,
    required this.currentSlide,
    required this.carouselController,
    required this.youtubeController,
    required this.showActivity,
    required this.onShowActivity,
    required this.onSlideChanged,
    this.studySlides,
    this.lessonTitle,
    // Activity props
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
  State<buildLesson1_3> createState() => _Lesson1_3State();
}

class _Lesson1_3State extends State<buildLesson1_3> {
  final Logger _logger = Logger();

  // Video gate
  bool _videoFinished = false;

  // Study phase
  bool _hasStudied = false;

  // Firestore lesson meta
  bool _loadingLessonMeta = true;
  Map<String, dynamic>? _lessonData;

  // Pre-assessment
  bool _preAssessmentCompleted = true; // set true until we confirm gating
  static const String _lessonDocId = 'lesson_1_3';
  static const String _preAssessmentKey = 'Lesson-1-3';

  // Activity log
  bool _showActivityLog = false;
  bool _activityLogLoading = false;
  List<Map<String, dynamic>> _activityLog = [];

  // Interactive definitions (fallback if not supplied in Firestore)
  final Map<String, String> _defaultDefinitions = {
    'tense': 'A grammatical category indicating time reference.',
    'present': 'Indicates an action happening now or habitually.',
    'simple': 'Basic form without auxiliaries.',
    'subject': 'The doer or topic of the sentence.',
    'verb': 'The action or state of being.',
    'habitual': 'An action done regularly.'
  };

  @override
  void initState() {
    super.initState();
    widget.youtubeController.addListener(_videoListener);
    _fetchLessonMeta();
    _checkPreAssessmentStatus();
  }

  @override
  void didUpdateWidget(covariant buildLesson1_3 oldWidget) {
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

  // ---------------- Video Listener ----------------
  void _videoListener() {
    if (!mounted) return;
    if (widget.youtubeController.value.playerState == PlayerState.ended && !_videoFinished) {
      setState(() => _videoFinished = true);
      _logger.i('Lesson 1.3 video finished.');
    }
  }

  // ---------------- Firestore Lesson Meta ----------------
  Future<void> _fetchLessonMeta() async {
    setState(() => _loadingLessonMeta = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('lessons').doc(_lessonDocId).get();
      if (doc.exists) {
        final data = doc.data();
        setState(() {
          _lessonData = data;
          // Only gate if preAssessmentData actually exists
          if (data?['preAssessmentData'] != null) {
            _preAssessmentCompleted = false; // will be corrected by status check
          }
          _loadingLessonMeta = false;
        });
        // Re-run pre-assessment status after fetch in case gating field just appeared
        _checkPreAssessmentStatus();
      } else {
        setState(() {
          _lessonData = null;
          _loadingLessonMeta = false;
        });
      }
    } catch (e) {
      _logger.e('Error fetching lesson1_3 meta: $e');
      if (mounted) {
        setState(() {
          _lessonData = null;
          _loadingLessonMeta = false;
        });
      }
    }
  }

  // ---------------- Pre-Assessment ----------------
  Future<void> _checkPreAssessmentStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final prog = await FirebaseFirestore.instance.collection('userProgress').doc(user.uid).get();
      if (prog.exists) {
        final map = (prog.data()?['preAssessmentsCompleted'] as Map<String, dynamic>?) ?? {};
        if (mounted) {
          setState(() {
            _preAssessmentCompleted =
                map[_preAssessmentKey] == true || _lessonData?['preAssessmentData'] == null;
          });
        }
      }
    } catch (e) {
      _logger.w('Pre-assessment status check failed: $e');
    }
  }

  Future<void> _markPreAssessmentComplete() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Login required.')));
      return;
    }
    try {
      await FirebaseFirestore.instance.collection('userProgress').doc(user.uid).set({
        'preAssessmentsCompleted': {_preAssessmentKey: true}
      }, SetOptions(merge: true));
      if (mounted) setState(() => _preAssessmentCompleted = true);
    } catch (e) {
      _logger.e('Error marking pre-assessment complete: $e');
    }
  }

  Widget _preAssessmentGate() {
    if (_lessonData?['preAssessmentData'] == null) return const SizedBox();
    if (_preAssessmentCompleted) return const SizedBox();
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Pre-Assessment',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF00568D))),
          const SizedBox(height: 10),
            Text(
              (_lessonData?['preAssessmentData']?['instruction'] ??
                      'Complete this quick pre-assessment before continuing.')
                  .toString(),
              style: const TextStyle(fontSize: 14),
            ),
          const SizedBox(height: 16),
          ElevatedButton(
              onPressed: _markPreAssessmentComplete,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00568D), foregroundColor: Colors.white),
              child: const Text('Mark as Complete'))
        ]),
      ),
    );
  }

  // ---------------- Activity Log ----------------
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
      final prog =
          await FirebaseFirestore.instance.collection('userProgress').doc(user.uid).get();
      List<Map<String, dynamic>> logs = [];
      if (prog.exists) {
        final attemptsMap = prog.data()?['lessonAttempts'] as Map<String, dynamic>? ?? {};
        final arr = attemptsMap[_preAssessmentKey] as List<dynamic>? ?? [];
        logs = arr.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        // Ensure attemptNumber sort ascending
        logs.sort((a, b) {
          final aN = (a['attemptNumber'] ?? 0) as num;
          final bN = (b['attemptNumber'] ?? 0) as num;
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
      _logger.e('Activity log fetch error: $e');
      if (mounted) {
        setState(() {
          _activityLog = [];
          _activityLogLoading = false;
        });
      }
    }
  }

  void _closeActivityLog() => setState(() => _showActivityLog = false);

  Widget _activityLogOverlay() {
    return Positioned.fill(
      child: Material(
        color: Colors.black54,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(
                    children: [
                      const Icon(Icons.history, color: Color(0xFF00568D)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('Activity Log - Lesson 1.3',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF00568D))),
                      ),
                      IconButton(
                          tooltip: 'Close',
                          onPressed: _closeActivityLog,
                          icon: const Icon(Icons.close))
                    ],
                  ),
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
                                separatorBuilder: (_, __) =>
                                    Divider(color: Colors.grey.shade200),
                                itemBuilder: (_, i) {
                                  final a = _activityLog[i];
                                  final ts = a['timestamp'] ?? a['attemptTimestamp'];
                                  DateTime? dt;
                                  if (ts is Timestamp) dt = ts.toDate();
                                  return ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                        'Attempt ${a['attemptNumber'] ?? '-'} - Score ${a['score'] ?? '-'}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600)),
                                    subtitle: Text(
                                        'Time Spent: ${a['timeSpent'] ?? a['timeSpentSeconds'] ?? '—'}s\n${dt != null ? dt.toLocal().toString() : ''}',
                                        style: const TextStyle(fontSize: 12, height: 1.3)),
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
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- Utilities ----------------
  String _fmt(int s) {
    final d = Duration(seconds: s);
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final sec = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  // ---------------- MCQ Option ----------------
  Widget _buildMCQOption(String optionText, String questionId) {
    bool isSelected = widget.selectedAnswerForCurrentQuestion == optionText;
    Color? tileColor;
    Color borderColor = Colors.grey.shade300;
    Widget? trailingIcon;
    FontWeight titleFontWeight = FontWeight.normal;

    if (widget.showResultsForCurrentQuestion != null &&
        widget.currentQuestionData != null) {
      bool isCorrect =
          widget.currentQuestionData!['correctAnswer'] == optionText;
      if (isSelected) {
        if (widget.showResultsForCurrentQuestion == true) {
          tileColor = Colors.green.shade50;
          borderColor = Colors.green.shade400;
          trailingIcon =
              const Icon(Icons.check_circle, color: Colors.green);
          titleFontWeight = FontWeight.bold;
        } else {
          tileColor = Colors.red.shade50;
            borderColor = Colors.red.shade400;
          trailingIcon = const Icon(Icons.cancel, color: Colors.red);
        }
      } else if (isCorrect) {
        borderColor = Colors.green.shade300;
        titleFontWeight = FontWeight.bold;
        trailingIcon =
            Icon(Icons.check_circle_outline, color: Colors.green.shade600);
      }
    }

    return Card(
      elevation: isSelected && widget.showResultsForCurrentQuestion == null ? 3 : 1.5,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
              color: borderColor,
              width: isSelected && widget.showResultsForCurrentQuestion == null
                  ? 2
                  : 1.5)),
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: RadioListTile<String>(
        title: Text(optionText,
            style: TextStyle(fontWeight: titleFontWeight, fontSize: 16)),
        value: optionText,
        groupValue: widget.selectedAnswerForCurrentQuestion,
        onChanged: (widget.showResultsForCurrentQuestion != null ||
                widget.isSubmitting)
            ? null
            : (v) {
                if (v != null) widget.onOptionSelected(questionId, v);
              },
        activeColor: Theme.of(context).primaryColor,
        tileColor: tileColor,
        secondary: trailingIcon,
        controlAffinity: ListTileControlAffinity.trailing,
      ),
    );
  }

  // ---------------- Interactive Intro ----------------
  Widget _interactiveIntro(String text, {Map<String, String>? defs}) {
    final definitions = {..._defaultDefinitions, ...?defs};
    return InteractiveTextWithDialog(
      text: text,
      definitions: definitions,
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

  // ---------------- Study Section ----------------
  Widget _studySection() {
    final slides = widget.studySlides ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.lessonTitle ?? 'Lesson 1.3: Present Simple Tense',
          style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF00568D)),
        ),
        const SizedBox(height: 16),
        if (slides.isNotEmpty)
          Column(
            children: [
              CarouselSlider(
                items: slides
                    .asMap()
                    .entries
                    .map((entry) => buildSlide(
                          title: entry.value['title'] ?? '',
                          content: entry.value['content'] ?? '',
                          slideIndex: entry.key,
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
                children: slides
                    .asMap()
                    .entries
                    .map((e) => GestureDetector(
                          onTap: () =>
                              widget.carouselController.animateToPage(e.key),
                          child: Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 2),
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF00568D).withOpacity(
                                    widget.currentSlide == e.key ? 0.9 : 0.35)),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 20),
            ],
          ),
        if (_lessonData?['introduction'] != null)
          Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _lessonData!['introduction']['heading'] ??
                          'Introduction',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00568D)),
                    ),
                    const SizedBox(height: 10),
                    if (_lessonData!['introduction']['paragraph1'] != null)
                      _interactiveIntro(
                        _lessonData!['introduction']['paragraph1'],
                        defs: (_lessonData!['introduction']['definitions']
                                as Map?)
                            ?.cast<String, String>(),
                      ),
                    if (_lessonData!['introduction']['paragraph2'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          _lessonData!['introduction']['paragraph2'],
                          style: const TextStyle(height: 1.5),
                        ),
                      ),
                  ]),
            ),
          ),
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
                      disabledBackgroundColor: Colors.grey.shade400,
                      foregroundColor: Colors.white),
                  child: const Text('Proceed to Activity'),
                ),
              ),
              if (!_videoFinished)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Please watch the full video to proceed.',
                    style: TextStyle(color: Colors.red, fontSize: 13),
                  ),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 28, vertical: 14)),
                child: const Text("I've Finished Studying – Proceed to Activity")),
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
                  disabledBackgroundColor: Colors.grey),
            ),
          ),
      ],
    );
  }

  // ---------------- Activity Section ----------------
  Widget _activitySection() {
    final q = widget.currentQuestionData;
    if (q == null && widget.totalQuestions > 0) {
      return const Center(
          child: Padding(
        padding: EdgeInsets.all(16),
        child: Text('Loading question...'),
      ));
    }
    if (widget.totalQuestions == 0) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No questions available.',
            style: TextStyle(color: Colors.orange)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Attempt + Timer
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Attempt: ${widget.initialAttemptNumber + 1}',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w500)),
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
          margin: const EdgeInsets.symmetric(vertical: 10),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Expanded(
                  child: Text(
                    'Question ${widget.questionIndex + 1} of ${widget.totalQuestions}',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColorDark),
                  ),
                ),
                IconButton(
                  icon: Icon(
                      widget.isFlagged
                          ? Icons.flag
                          : Icons.flag_outlined,
                      color: widget.isFlagged
                          ? Colors.amber.shade700
                          : Colors.grey.shade600,
                      size: 26),
                  tooltip: widget.isFlagged
                      ? 'Unflag Question'
                      : 'Flag Question for Review',
                  onPressed: (widget.showResultsForCurrentQuestion != null ||
                          widget.isSubmitting || q == null)
                      ? null
                      : () => widget.onToggleFlag(q['id'].toString()),
                ),
              ]),
              const Divider(height: 24),
              Text(
                q?['promptText'] ??
                    q?['text'] ??
                    'Question text not available.',
                style: const TextStyle(fontSize: 18, height: 1.4),
              ),
              const SizedBox(height: 20),
              if (q != null &&
                  q['options'] is List &&
                  q['type'] == 'multiple-choice')
                ...(q['options'] as List<dynamic>)
                    .map((o) => _buildMCQOption(o.toString(), q['id'].toString()))
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
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(
                      'Feedback: ${q?['explanation'] ?? 'Review your answer.'}',
                      style: const TextStyle(
                          fontSize: 14, fontStyle: FontStyle.italic)),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.arrow_back_ios, size: 16),
              label: const Text('Previous'),
              onPressed: widget.isFirstQuestion ||
                      widget.isSubmitting ||
                      widget.showResultsForCurrentQuestion != null
                  ? null
                  : widget.onPreviousQuestion,
            ),
            if (widget.isLastQuestion &&
                widget.showResultsForCurrentQuestion == null)
              ElevatedButton.icon(
                icon: widget.isSubmitting
                    ? const SizedBox.shrink()
                    : const Icon(Icons.check_circle_outline),
                label: widget.isSubmitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white)))
                    : const Text('Submit All'),
                onPressed: widget.isSubmitting
                    ? null
                    : widget.onSubmitAnswersFromLesson,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white),
              )
            else if (!widget.isLastQuestion &&
                widget.showResultsForCurrentQuestion == null)
              ElevatedButton.icon(
                icon: const Icon(Icons.arrow_forward_ios, size: 16),
                label: const Text('Next'),
                onPressed: widget.isSubmitting ? null : widget.onNextQuestion,
              ),
          ],
        ),
        if (widget.showResultsForCurrentQuestion != null &&
            widget.isLastQuestion)
          const SizedBox(height: 12),
      ],
    );
  }

  // ---------------- Build ----------------
  @override
  Widget build(BuildContext context) {
    if (_loadingLessonMeta) {
      return const Center(
          child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Loading lesson data...')
          ],
        ),
      ));
    }

    // If Firestore doc missing we still allow study slides from parent.
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
            ],
          ),
        ),
        if (_showActivityLog) _activityLogOverlay(),
      ],
    );
  }
}