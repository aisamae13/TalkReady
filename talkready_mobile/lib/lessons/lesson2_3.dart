// lib/lessons/lesson2_3.dart
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../services/unified_progress_service.dart';
import '../StudentAssessment/PreAssessment.dart';
import '../widgets/quick_check_quiz_widget.dart';
import '../widgets/ai_feedback_display_card.dart';

class Lesson2_3Page extends StatefulWidget {
  const Lesson2_3Page({super.key});
  @override
  State<Lesson2_3Page> createState() => _Lesson2_3PageState();
}

class _Lesson2_3PageState extends State<Lesson2_3Page> {
  final UnifiedProgressService _progressService = UnifiedProgressService();
  static const String LESSON_ID = "Lesson-2-3";
  static const String FIRESTORE_DOC_ID = "lesson_2_3";

  bool _isLoading = true;
  bool _preAssessmentCompleted = false;
  Map<String, dynamic>? _lessonData;
  late YoutubePlayerController _priceVideoController;
  late YoutubePlayerController _timeDateVideoController;
  int _attemptNumber = 0;
  List<Map<String, dynamic>> _activityLog = [];

  @override
  void initState() {
    super.initState();
    _priceVideoController = YoutubePlayerController(initialVideoId: '');
    _timeDateVideoController = YoutubePlayerController(initialVideoId: '');
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

          // Safely initialize video controllers
          final priceVideoId =
              YoutubePlayer.convertUrlToId(
                _lessonData?['videos']?['priceVideo']?['url'] ?? '',
              ) ??
              '';
          _priceVideoController = YoutubePlayerController(
            initialVideoId: priceVideoId,
            flags: const YoutubePlayerFlags(autoPlay: false),
          );

          final timeDateVideoId =
              YoutubePlayer.convertUrlToId(
                _lessonData?['videos']?['timeAndDateVideo']?['url'] ?? '',
              ) ??
              '';
          _timeDateVideoController = YoutubePlayerController(
            initialVideoId: timeDateVideoId,
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
        'lessonId': LESSON_ID, // "Lesson-2-3"
        'lessonData': _lessonData,
        'activityLog': _activityLog,
      },
    );
  }

  Widget _buildLogEntry(Map<String, dynamic> log) {
    final attemptNum = log['attemptNumber'] ?? 0;
    final score = log['score'] ?? 0;
    final maxScore =
        _lessonData?['activity']?['maxPossibleAIScore'] as int? ?? 25;

    // Use the correct keys for Lesson 2.3
    final responses =
        log['detailedResponses']?['scenarioAnswers_L2_3']
            as Map<String, dynamic>? ??
        {};
    final feedback =
        log['detailedResponses']?['scenarioFeedback_L2_3']
            as Map<String, dynamic>? ??
        {};

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ExpansionTile(
        title: Text('Attempt $attemptNum'),
        subtitle: Text('Score: $score / $maxScore'),
        childrenPadding: const EdgeInsets.all(8.0),
        children: [
          if (responses.isEmpty)
            const Text('No detailed answers recorded for this attempt.'),
          ...responses.entries.map((entry) {
            final promptData =
                (_lessonData?['activity']?['prompts'] as List<dynamic>?)
                    ?.firstWhere(
                      (p) => p['name'] == entry.key,
                      orElse: () => null,
                    );

            final answer = entry.value as String;
            final feedbackData = feedback[entry.key] as Map<String, dynamic>?;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (promptData != null)
                    Text(
                      promptData['promptText'] ?? 'Prompt',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  const SizedBox(height: 4),
                  Text('Your Answer: $answer'),
                  if (feedbackData != null)
                    AiFeedbackDisplayCard(feedbackData: feedbackData),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _priceVideoController.dispose();
    _timeDateVideoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lesson 2.3')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_lessonData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lesson 2.3')),
        body: const Center(child: Text('Failed to load lesson content.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_lessonData?['lessonTitle'] ?? 'Lesson 2.3'),
        backgroundColor: const Color(0xFFF4D03F), // Lesson 2.3 Color
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

  // --- THIS IS THE CORRECTED METHOD ---
  // It now includes all the missing sections in the right order.
  Widget _buildLessonContent() {
    return Column(
      children: [
        // 1. Activity Log Button
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.history),
            label: const Text('View Your Activity Log'),
            onPressed: _showActivityLogDialog, // <-- UPDATE THIS LINE
          ),
        ),

        // 2. Objective Section
        _buildSectionCard(
          icon: Icons.flag,
          title: _lessonData?['objective']?['heading'],
          content: Text(_lessonData?['objective']?['paragraph'] ?? ''),
        ),

        // 3. Key Phrases Section
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
                      child: Text(
                        "• ${item.replaceAll(RegExp(r'<[^>]*>'), '')}",
                      ),
                    ),
                  )
                  .toList(),
            ],
          ),
        ),

        // 4. First Video
        _buildSectionCard(
          icon: Icons.videocam,
          title: _lessonData?['videos']?['priceVideo']?['heading'],
          content: YoutubePlayer(controller: _priceVideoController),
        ),

        // 5. Second Video
        _buildSectionCard(
          icon: Icons.videocam,
          title: _lessonData?['videos']?['timeAndDateVideo']?['heading'],
          content: YoutubePlayer(controller: _timeDateVideoController),
        ),

        // 6. Quick Check Quiz
        if (_lessonData?['keyPhraseActivity'] != null)
          QuickCheckQuizWidget(quizData: _lessonData!['keyPhraseActivity']),

        // 7. Proceed to Activity Button
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
                Navigator.pushNamed(
                  context,
                  '/lesson2_3_activity',
                  arguments: {
                    'lessonId': LESSON_ID,
                    'lessonTitle': _lessonData!['lessonTitle'] ?? 'Activity',
                    'lessonData': _lessonData,
                    'attemptNumber': _attemptNumber + 1,
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // --- HELPER WIDGETS (No changes needed here) ---

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
            color: Color(0xFFF4D03F),
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
