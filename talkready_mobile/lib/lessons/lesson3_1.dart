// lib/lessons/lesson3_1.dart
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../services/unified_progress_service.dart';
import '../widgets/listen_and_identify_widget.dart';
import '../widgets/ai_feedback_display_card.dart';

class Lesson3_1Page extends StatefulWidget {
  const Lesson3_1Page({super.key});

  @override
  State<Lesson3_1Page> createState() => _Lesson3_1PageState();
}

class _Lesson3_1PageState extends State<Lesson3_1Page> {
  final Logger _logger = Logger();
  final UnifiedProgressService _progressService = UnifiedProgressService();
  final String _lessonId = "Lesson-3-1";
  final String _firestoreDocId = "lesson_3_1";

  // State
  bool _isLoading = true;
  Map<String, dynamic>? _lessonData;
  bool _isPreAssessmentComplete = false;
  late YoutubePlayerController _videoController;
  List<Map<String, dynamic>> _activityLog = [];
  int _attemptNumber = 0;

  @override
  void initState() {
    super.initState();
    _videoController = YoutubePlayerController(initialVideoId: '');
    _loadInitialData();
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _progressService.getFullLessonContent(_firestoreDocId),
        _progressService.isPreAssessmentCompleted(_lessonId),
        _progressService.getLessonAttempts(_lessonId),
      ]);

      if (mounted) {
        final lessonData = results[0] as Map<String, dynamic>?;
        final isPreAssessmentDone = results[1] as bool;
        final attempts = results[2] as List<Map<String, dynamic>>;

        setState(() {
          _lessonData = lessonData;
          _isPreAssessmentComplete = isPreAssessmentDone;
          _activityLog = attempts;
          _attemptNumber = attempts.length;

          // **FIX:** Correctly access the video URL from the lesson data
          final videoUrl = lessonData?['video']?['url'] as String?;
          if (videoUrl != null) {
            final videoId = YoutubePlayer.convertUrlToId(videoUrl) ?? '';
            _videoController = YoutubePlayerController(
              initialVideoId: videoId,
              flags: const YoutubePlayerFlags(autoPlay: false),
            );
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      _logger.e('Error loading initial data for Lesson 3.1: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onPreAssessmentComplete() async {
    try {
      await _progressService.markPreAssessmentAsComplete(_lessonId);
      if (mounted) {
        setState(() => _isPreAssessmentComplete = true);
      }
    } catch (e) {
      _logger.e("Failed to save pre-assessment status: $e");
    }
  }

  void _showActivityLogDialog() {
    Navigator.pushNamed(
      context,
      '/lesson_activity_log',
      arguments: {
        'lessonId': _lessonId,
        'lessonData': _lessonData,
        'activityLog': _activityLog,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_lessonData == null) {
      return const Scaffold(
        body: Center(child: Text('Failed to load lesson content')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_lessonData?['lessonTitle'] ?? 'Lesson 3.1'),
        backgroundColor: const Color(0xFF32CD32),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _isPreAssessmentComplete
                ? _buildStudyMaterial()
                : _buildPreAssessment(),
          ],
        ),
      ),
    );
  }

  Widget _buildPreAssessment() {
    final preAssessmentData = _lessonData?['preAssessmentData'];
    if (preAssessmentData == null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => setState(() => _isPreAssessmentComplete = true),
      );
      return const Center(child: CircularProgressIndicator());
    }
    return ListenAndIdentifyWidget(
      assessmentData: preAssessmentData,
      onComplete: _onPreAssessmentComplete,
    );
  }

  // **FIX:** This method now includes all the missing sections
  Widget _buildStudyMaterial() {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.history),
            label: const Text('View Your Activity Log'),
            // **FIX:** Changed from _showActivityLog to _showActivityLogDialog
            onPressed: _showActivityLogDialog,
          ),
        ),
        _buildSectionCard(
          icon: Icons.flag,
          title: _lessonData?['objective']?['heading'] ?? 'Objective',
          content: Text(_lessonData?['objective']?['paragraph'] ?? ''),
        ),
        _buildSectionCard(
          icon: Icons.info_outline,
          title: _lessonData?['introduction']?['heading'] ?? 'Introduction',
          content: Text(_lessonData?['introduction']?['paragraph1'] ?? ''),
        ),
        if (_videoController.initialVideoId.isNotEmpty)
          _buildSectionCard(
            icon: Icons.videocam,
            title: _lessonData?['video']?['heading'] ?? 'Watch and Learn',
            content: YoutubePlayer(controller: _videoController),
          ),
        _buildSectionCard(
          icon: Icons.list_alt,
          title: _lessonData?['keyTakeaways']?['heading'] ?? 'Key Takeaways',
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children:
                List<String>.from(
                      _lessonData?['keyTakeaways']?['listItems'] ?? [],
                    )
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "• ",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Expanded(child: Text(item)),
                          ],
                        ),
                      ),
                    )
                    .toList(),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Start the Activity'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            // **FIX:** Corrected the onPressed callback
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/lesson3_1_activity',
                arguments: {
                  'lessonId': _lessonId,
                  'lessonTitle':
                      _lessonData?['lessonTitle'] ?? 'Listening Activity',
                  'lessonData': _lessonData,
                  'attemptNumber': _attemptNumber + 1,
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // --- HELPER WIDGETS ---

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
          _lessonData?['lessonTitle'] ?? 'Lesson 3.1',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF32CD32),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required Widget content,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor, size: 28),
                const SizedBox(width: 12),
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
            const Divider(height: 24),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildLogEntry(Map<String, dynamic> log) {
    final attemptNum = log['attemptNumber'] ?? 0;
    final score = log['score'] ?? 0;
    final maxScore =
        _lessonData?['activity']?['maxPossibleAIScore'] as int? ?? 60;
    final responses =
        log['detailedResponses']?['answers'] as Map<String, dynamic>? ?? {};
    final feedback =
        log['detailedResponses']?['feedbackForAnswers']
            as Map<String, dynamic>? ??
        {};
    final questionSets = List<Map<String, dynamic>>.from(
      _lessonData?['activity']?['questionSets'] ?? [],
    );

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ExpansionTile(
        title: Text('Attempt $attemptNum'),
        subtitle: Text('Score: $score / $maxScore'),
        childrenPadding: const EdgeInsets.all(12),
        children: questionSets.expand((set) {
          final callId = set['callId'];
          return (set['questions'] as List<dynamic>).map((question) {
            final qId = question['id'];
            final userAnswer = responses[qId];
            final feedbackData = feedback[qId] as Map<String, dynamic>?;
            if (userAnswer == null) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${callId.replaceAll('call', 'Call ')} - ${question['text']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text('Your Answer: $userAnswer'),
                  if (feedbackData != null)
                    AiFeedbackDisplayCard(feedbackData: feedbackData),
                ],
              ),
            );
          });
        }).toList(),
      ),
    );
  }
}
