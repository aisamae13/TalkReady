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

// NOTE: Public API kept identical to the ORIGINAL (only original required params)
// so existing Module1Page code continues to compile.
class buildLesson1_1 extends StatefulWidget {
  // ORIGINAL PROPS (unchanged)
  final BuildContext context;
  final int currentSlide;
  final CarouselSliderController carouselController;
  final YoutubePlayerController youtubeController;
  final bool showActivity;
  final VoidCallback onShowActivity;
  final Function(int) onSlideChanged;

  // Activity props (from original refactor)
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

  const buildLesson1_1({
    super.key,
    required this.context,
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
  State<buildLesson1_1> createState() => _Lesson1_1State();
}

class _Lesson1_1State extends State<buildLesson1_1> {
  final Logger _logger = Logger();
  final FirebaseService _firebaseService = FirebaseService();

  // Video gate
  bool _videoFinished = false;

  // Enhanced (internal) study + assessment state (does NOT alter parent API)
  bool _hasStudied = false;
  bool _loadingLessonData = true;
  bool _preAssessmentCompleted = true; // default true if no preAssessment
  Map<String, dynamic>? _lessonData;

  // Internal Activity Log modal (optional)
  bool _showActivityLog = false;
  bool _activityLogLoading = false;
  List<Map<String, dynamic>> _activityLog = [];

  // Local interactive-intro definitions
  final Map<String, String> _definitions = {
    'nouns': 'Words that name people, places, things, or ideas.',
    'pronouns':
        'Words that replace nouns to avoid repetition and improve flow.'
  };

  static const String _firestoreLessonDocId = 'lesson_1_1';
  static const String _preAssessmentProgressKey = 'Lesson-1-1';

  @override
  void initState() {
    super.initState();
    widget.youtubeController.addListener(_videoListener);
    _loadLessonContent();
    _checkPreAssessmentStatus();
  }

  @override
  void didUpdateWidget(covariant buildLesson1_1 oldWidget) {
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
    if (widget.youtubeController.value.playerState == PlayerState.ended &&
        !_videoFinished) {
      if (!mounted) return;
      setState(() => _videoFinished = true);
      _logger.i('Lesson1.1 video completed.');
    }
  }

  Future<void> _loadLessonContent() async {
    setState(() => _loadingLessonData = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('lessons')
          .doc(_firestoreLessonDocId)
          .get();
      if (doc.exists) {
        setState(() {
          _lessonData = doc.data();
          _loadingLessonData = false;
          // If there IS a preAssessment payload, only then gate with completion flag.
          if (_lessonData?['preAssessmentData'] != null) {
            // Keep existing _preAssessmentCompleted value (fetched separately).
          } else {
            _preAssessmentCompleted = true;
          }
        });
      } else {
        setState(() {
          _lessonData = null;
          _loadingLessonData = false;
        });
      }
    } catch (e) {
      _logger.e("Error loading lesson 1.1 content: $e");
      if (mounted) {
        setState(() {
          _lessonData = null;
          _loadingLessonData = false;
        });
      }
    }
  }

  Future<void> _checkPreAssessmentStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final progressDoc = await FirebaseFirestore.instance
          .collection('userProgress')
          .doc(user.uid)
          .get();
      if (progressDoc.exists) {
        final data = progressDoc.data();
        final preMap =
            (data?['preAssessmentsCompleted'] as Map<String, dynamic>?) ?? {};
        if (mounted) {
          setState(
              () => _preAssessmentCompleted = preMap[_preAssessmentProgressKey] == true);
        }
      }
    } catch (e) {
      _logger.w("Unable to check pre-assessment status: $e");
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
        'preAssessmentsCompleted': {_preAssessmentProgressKey: true}
      }, SetOptions(merge: true));
      if (mounted) {
        setState(() => _preAssessmentCompleted = true);
      }
    } catch (e) {
      _logger.e("Error marking pre-assessment complete: $e");
    }
  }

  Future<void> _loadActivityLog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Login required.")));
      return;
    }
    setState(() {
      _showActivityLog = true;
      _activityLogLoading = true;
    });
    try {
      // Reuse existing service if you want richer log; fallback simple attempt array:
      final userProgressDoc = await FirebaseFirestore.instance
          .collection('userProgress')
          .doc(user.uid)
          .get();
      List<Map<String, dynamic>> logs = [];
      if (userProgressDoc.exists) {
        final lessonAttempts =
            userProgressDoc.data()?['lessonAttempts'] as Map<String, dynamic>?;
        final attemptsArr =
            lessonAttempts?[_preAssessmentProgressKey] as List<dynamic>? ?? [];
        logs = attemptsArr
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
      logs.sort((a, b) {
        final at = a['attemptNumber'] ?? 0;
        final bt = b['attemptNumber'] ?? 0;
        return at.compareTo(bt);
      });
      if (mounted) {
        setState(() {
          _activityLog = logs;
          _activityLogLoading = false;
        });
      }
    } catch (e) {
      _logger.e("Error loading activity log: $e");
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

  String _formatDuration(int totalSeconds) {
    final d = Duration(seconds: totalSeconds);
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ===== UI BUILD HELPERS =====

  Widget _buildMCQOption(String optionText, String questionId) {
    final isSelected = widget.selectedAnswerForCurrentQuestion == optionText;
    Color? tileColor;
    Color borderColor = Colors.grey;
    Widget? trailing;

    if (widget.showResultsForCurrentQuestion != null &&
        widget.currentQuestionData != null) {
      final bool isCorrect =
          widget.currentQuestionData!['correctAnswer'] == optionText;
      if (isSelected) {
        final correct = widget.showResultsForCurrentQuestion == true;
        tileColor = correct ? Colors.green.shade100 : Colors.red.shade100;
        borderColor = correct ? Colors.green : Colors.red;
        trailing = Icon(
          correct ? Icons.check_circle : Icons.cancel,
          color: correct ? Colors.green : Colors.red,
        );
      } else if (isCorrect) {
        borderColor = Colors.green;
        trailing = const Icon(Icons.check_circle_outline, color: Colors.green);
      }
    }

    return Card(
      elevation: isSelected ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: borderColor, width: isSelected ? 2 : 1),
      ),
      child: RadioListTile<String>(
        title: Text(optionText),
        value: optionText,
        groupValue: widget.selectedAnswerForCurrentQuestion,
        onChanged: (widget.showResultsForCurrentQuestion != null)
            ? null
            : (v) {
                if (v != null) widget.onOptionSelected(questionId, v);
              },
        activeColor: Theme.of(context).primaryColor,
        tileColor: tileColor,
        secondary: trailing,
      ),
    );
  }

  Widget _buildFindAndClickQuestion(Map<String, dynamic> q) {
    final id = q['id'].toString();
    final text = q['text'] ?? q['promptText'] ?? '';
    // Parent currently does NOT supply multi-select answers; to extend this safely,
    // we show a read-only note instead of breaking the contract.
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border:
            Border.all(color: Theme.of(context).dividerColor.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text.isEmpty
            ? '(Find-and-click question text missing)'
            : text,
        style: const TextStyle(fontSize: 16),
      ),
    );
  }

  Widget _buildInteractiveDefinitionsParagraph(String text) {
    return InteractiveTextWithDialog(
      text: text,
      definitions: _definitions,
      baseTextStyle: const TextStyle(
        color: Colors.black87,
        fontSize: 16,
        height: 1.5,
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

  Widget _buildPreAssessmentGate() {
    if (_lessonData?['preAssessmentData'] == null) {
      return const SizedBox.shrink();
    }
    if (_preAssessmentCompleted) return const SizedBox.shrink();
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pre-Assessment',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00568D))),
            const SizedBox(height: 12),
            const Text(
                'Please complete this quick pre-assessment before proceeding.'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _markPreAssessmentComplete,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00568D),
                  foregroundColor: Colors.white),
              child: const Text('Mark as Complete'),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStudySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Lesson 1.1: Pronouns and Nouns',
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00568D))),
        const SizedBox(height: 16),
        // Slides (fallback static)
        if (widget.currentQuestionData == null &&
            _Lesson1_1State_StaticData.slides.isNotEmpty)
          Column(
            children: [
              CarouselSlider(
                items: _Lesson1_1State_StaticData.slides
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
                  height: 280,
                  enlargeCenterPage: true,
                  enableInfiniteScroll: false,
                  initialPage: widget.currentSlide,
                  onPageChanged: (i, _) => widget.onSlideChanged(i),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _Lesson1_1State_StaticData.slides
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
                                  widget.currentSlide == e.key ? 0.9 : 0.35),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ),
        const SizedBox(height: 12),
        // Introduction with interactive definitions if lessonData is available
        if (_lessonData?['introduction'] != null)
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                      _buildInteractiveDefinitionsParagraph(
                          _lessonData!['introduction']['paragraph1']),
                    if (_lessonData!['introduction']['paragraph2'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _lessonData!['introduction']['paragraph2'],
                          style: const TextStyle(fontSize: 16, height: 1.5),
                        ),
                      ),
                  ]),
            ),
          ),
        const SizedBox(height: 16),
        // Video
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
                    disabledBackgroundColor: Colors.grey.shade400,
                  ),
                  child: const Text('Proceed to Activity'),
                ),
              ),
              if (!_videoFinished)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('Please watch the video to the end to proceed.',
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 14)),
              child: const Text("I've Finished Studying – Proceed to Activity"),
            ),
          ),
        if (_hasStudied)
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

  Widget _buildActivitySection() {
    final q = widget.currentQuestionData;
    if (q == null && widget.totalQuestions > 0) {
      return const Center(child: Text('Loading question...'));
    }
    if (widget.totalQuestions == 0) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No questions available for this activity yet.',
              style: TextStyle(color: Colors.orange)),
        ),
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
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            Text('Time: ${_formatDuration(widget.secondsElapsed)}',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          ]),
        ),
        Card(
          elevation: 3,
          margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header + flag
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                            child: Text(
                                'Question ${widget.questionIndex + 1} of ${widget.totalQuestions}',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(context).colorScheme.primary))),
                        IconButton(
                          tooltip:
                              widget.isFlagged ? 'Unflag Question' : 'Flag Question',
                          icon: Icon(
                              widget.isFlagged
                                  ? Icons.flag
                                  : Icons.flag_outlined,
                              color: widget.isFlagged
                                  ? Colors.orange
                                  : Colors.grey),
                          onPressed: widget.showResultsForCurrentQuestion != null
                              ? null
                              : () => widget
                                  .onToggleFlag(q!['id'].toString()),
                        )
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      q?['text'] ?? q?['promptText'] ?? 'Question text not available.',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 14),
                    if (q != null && q['type'] == 'find-and-click')
                      _buildFindAndClickQuestion(q)
                    else if (q != null &&
                        q['options'] is List &&
                        q['type'] == 'multiple-choice')
                      ...(q['options'] as List<dynamic>)
                          .map((o) => _buildMCQOption(
                              o.toString(), q['id'].toString()))
                          ,
                    if (widget.errorMessageForCurrentQuestion != null &&
                        widget.showResultsForCurrentQuestion == false)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          'Incorrect. ${widget.errorMessageForCurrentQuestion!}',
                          style:
                              const TextStyle(color: Colors.red, fontSize: 14),
                        ),
                      ),
                    if (widget.showResultsForCurrentQuestion == true)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
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
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
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
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white)))
                      : const Text('Submit All'))
            else if (!widget.isLastQuestion &&
                widget.showResultsForCurrentQuestion == null)
              ElevatedButton(
                  onPressed: widget.onNextQuestion, child: const Text('Next')),
          ],
        ),
        if (widget.showResultsForCurrentQuestion != null &&
            widget.isLastQuestion)
          const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildActivityLogModal() {
    return Positioned.fill(
      child: Material(
        color: Colors.black54,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text('Activity Log',
                                style: TextStyle(
                                    fontSize: 20,
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
                            ? const Center(
                                child: CircularProgressIndicator(),
                              )
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
                                              "Attempt ${log['attemptNumber'] ?? (i + 1)}",
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                          Text(
                                              "Score: ${log['score'] ?? '—'} / ${log['totalScore'] ?? '—'}"),
                                          Text(
                                              "Time Spent: ${log['timeSpent'] ?? '—'}s"),
                                          if (log['attemptTimestamp'] != null)
                                            Text(
                                              log['attemptTimestamp']
                                                  .toString(),
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey),
                                            ),
                                        ],
                                      );
                                    }),
                      ),
                      const SizedBox(height: 8),
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
    if (_loadingLessonData) {
      return const Center(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text('Loading lesson content...')
        ],
      ));
    }

    if (_lessonData == null) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text(
            'Unable to load Lesson 1.1 data.',
            style: TextStyle(color: Colors.red),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
              onPressed: _loadLessonContent, child: const Text('Retry'))
        ]),
      );
    }

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pre-assessment gate (if not completed)
              _buildPreAssessmentGate(),
              if (_preAssessmentCompleted && !widget.showActivity)
                _buildStudySection(),
              if (widget.showActivity) _buildActivitySection(),
              const SizedBox(height: 24),
              Center(
                child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Back to Course Outline',
                        style: TextStyle(
                            fontSize: 15, color: Color(0xFF00568D)))),
              ),
              const SizedBox(height: 12),
              Center(
                child: OutlinedButton.icon(
                  onPressed: _loadActivityLog,
                  icon: const Icon(Icons.history),
                  label: const Text('View Activity Log'),
                ),
              ),
            ],
          ),
        ),
        if (_showActivityLog) _buildActivityLogModal(),
      ],
    );
  }
}

// Fallback static slides
class _Lesson1_1State_StaticData {
  static final List<Map<String, String>> slides = [
    {
      'title': 'Objective: Understanding Pronouns and Nouns',
      'content':
          'In this lesson, you will learn to identify pronouns and nouns...',
    },
    {
      'title': 'Why Pronouns Matter',
      'content':
          'Pronouns help avoid repetition and make sentences flow more naturally.'
    },
  ];
}