// lib/lessons/lesson2_2.dart
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../services/unified_progress_service.dart';
import '../StudentAssessment/PreAssessment.dart';
import '../widgets/quick_check_quiz_widget.dart';
import '../widgets/ai_feedback_display_card.dart';

class Lesson2_2Page extends StatefulWidget {
  const Lesson2_2Page({super.key});
  @override
  State<Lesson2_2Page> createState() => _Lesson2_2PageState();
}

class _Lesson2_2PageState extends State<Lesson2_2Page> {
  final UnifiedProgressService _progressService = UnifiedProgressService();
  static const String LESSON_ID = "Lesson-2-2";
  static const String FIRESTORE_DOC_ID = "lesson_2_2";

  bool _isLoading = true;
  bool _preAssessmentCompleted = false;
  Map<String, dynamic>? _lessonData;
  late YoutubePlayerController _youtubeController;
  int _attemptNumber = 0;
  List<Map<String, dynamic>> _activityLog = [];

  @override
  void initState() {
    super.initState();
    _youtubeController = YoutubePlayerController(initialVideoId: '');
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _progressService.getFullLessonContent(FIRESTORE_DOC_ID),
        _progressService.isPreAssessmentCompleted(LESSON_ID),
        _progressService.getLessonAttempts(LESSON_ID),
      ]);

      if (mounted) {
        setState(() {
          _lessonData = results[0] as Map<String, dynamic>?;
          _preAssessmentCompleted = results[1] as bool;
          _activityLog = results[2] as List<Map<String, dynamic>>;
          _attemptNumber = _activityLog.length;

          final videoId =
              YoutubePlayer.convertUrlToId(
                _lessonData?['video']?['url'] ?? '',
              ) ??
              '';
          _youtubeController = YoutubePlayerController(
            initialVideoId: videoId,
            flags: const YoutubePlayerFlags(autoPlay: false),
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onPreAssessmentComplete() async {
    await _progressService.markPreAssessmentAsComplete(LESSON_ID);
    if (mounted) setState(() => _preAssessmentCompleted = true);
  }

  void _showActivityLogDialog() {
    Navigator.pushNamed(
      context,
      '/lesson_activity_log',
      arguments: {
        'lessonId': LESSON_ID, // "Lesson-2-2"
        'lessonData': _lessonData,
        'activityLog': _activityLog,
      },
    );
  }

  Widget _buildLogEntry(Map<String, dynamic> log) {
    final attemptNum = log['attemptNumber'] ?? 0;
    final score = log['score'] ?? 0;
    final maxScore =
        _lessonData?['activity']?['maxPossibleAIScore'] as int? ?? 10;
    final responses =
        log['detailedResponses']?['scenarioAnswers_L2_2']
            as Map<String, dynamic>? ??
        {};
    final feedback =
        log['detailedResponses']?['scenarioFeedback_L2_2']
            as Map<String, dynamic>? ??
        {};

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ExpansionTile(
        title: Text('Attempt $attemptNum'),
        subtitle: Text('Score: $score / $maxScore'),
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: responses.entries.map((entry) {
                final scenarioKey = entry.key;
                final answer = entry.value as String;
                final feedbackData =
                    feedback[scenarioKey] as Map<String, dynamic>?;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Response:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      Text(answer),
                      if (feedbackData != null)
                        AiFeedbackDisplayCard(feedbackData: feedbackData),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _youtubeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lesson 2.2')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_lessonData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lesson 2.2')),
        body: const Center(child: Text('Failed to load lesson content.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_lessonData?['lessonTitle'] ?? 'Lesson 2.2'),
        backgroundColor: const Color(0xFF48C9B0), // Lesson 2.2 Color
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            if (!_preAssessmentCompleted)
              PreAssessmentWidget(
                assessmentData: _lessonData!['preAssessmentData'],
                onComplete: _onPreAssessmentComplete,
              )
            else
              _buildLessonContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Text(
          _lessonData?['moduleTitle'] ?? '',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF00568D),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _lessonData?['lessonTitle'] ?? '',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF48C9B0),
          ),
        ),
      ],
    );
  }

  Widget _buildLessonContent() {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.history),
            label: const Text('View Your Activity Log'),
            onPressed: _showActivityLogDialog,
          ),
        ),
        _buildSectionCard(
          icon: Icons.flag,
          title: 'Objective',
          content: Text(_lessonData?['objective']?['paragraph'] ?? ''),
        ),
        _buildSectionCard(
          icon: Icons.vpn_key,
          title: _lessonData?['keyPhrases']?['heading'],
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_lessonData?['keyPhrases']?['introParagraph'] ?? ''),
              const SizedBox(height: 8),
              ...?(_lessonData?['keyPhrases']?['listItems'] as List<dynamic>?)
                  ?.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(left: 16.0, top: 4.0),
                      child: Text("• $item"),
                    ),
                  )
                  .toList(),
            ],
          ),
        ),
        _buildSectionCard(
          icon: Icons.videocam,
          title: _lessonData?['video']?['heading'],
          content: YoutubePlayer(controller: _youtubeController),
        ),
        if (_lessonData?['keyPhraseActivity'] != null)
          QuickCheckQuizWidget(quizData: _lessonData!['keyPhraseActivity']),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: Center(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Start the Activity'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              onPressed: () {
                if (_lessonData != null) {
                  Navigator.pushNamed(
                    context,
                    '/lesson2_2_activity',
                    arguments: {
                      'lessonId': LESSON_ID,
                      'lessonTitle':
                          _lessonData!['lessonTitle'] ?? 'Lesson 2.2 Activity',
                      'lessonData': _lessonData,
                      'attemptNumber': _attemptNumber + 1,
                    },
                  );
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    String? title,
    required Widget content,
  }) {
    if (title == null) return const SizedBox.shrink();
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            content,
          ],
        ),
      ),
    );
  }
}
