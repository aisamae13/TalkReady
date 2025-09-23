// lib/lessons/lesson3_2.dart
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../services/unified_progress_service.dart';
import '../widgets/listen_and_identify_widget.dart';
import '../widgets/ai_feedback_display_card.dart';

class Lesson3_2Page extends StatefulWidget {
  const Lesson3_2Page({super.key});

  @override
  State<Lesson3_2Page> createState() => _Lesson3_2PageState();
}

class _Lesson3_2PageState extends State<Lesson3_2Page> {
  final Logger _logger = Logger();
  final UnifiedProgressService _progressService = UnifiedProgressService();
  final String _lessonId = "Lesson-3-2"; // ✅ Consistent format
  final String _firestoreDocId = "lesson_3_2";

  // State variables
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

          // Initialize video controller
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
      _logger.e('Error loading initial data for Lesson 3.2: $e');
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
        title: Text(_lessonData?['lessonTitle'] ?? 'Lesson 3.2'),
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

  Widget _buildStudyMaterial() {
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

        // **FIX:** Show full objective content with bullet points
        _buildSectionCard(
          icon: Icons.flag,
          title: _lessonData?['objective']?['heading'] ?? 'Objective',
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_lessonData?['objective']?['paragraph'] != null)
                Text(
                  _lessonData!['objective']['paragraph'],
                  style: const TextStyle(fontSize: 16, height: 1.4),
                ),
              if (_lessonData?['objective']?['points'] != null) ...[
                const SizedBox(height: 12),
                ...List<String>.from(_lessonData!['objective']['points']).map(
                  (point) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "• ",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            point,
                            style: const TextStyle(fontSize: 15),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // **FIX:** Show full introduction content
        _buildSectionCard(
          icon: Icons.info_outline,
          title: _lessonData?['introduction']?['heading'] ?? 'Introduction',
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_lessonData?['introduction']?['paragraph'] != null)
                Text(
                  _lessonData!['introduction']['paragraph'],
                  style: const TextStyle(fontSize: 16, height: 1.4),
                ),
              if (_lessonData?['introduction']?['paragraph1'] != null)
                Text(
                  _lessonData!['introduction']['paragraph1'],
                  style: const TextStyle(fontSize: 16, height: 1.4),
                ),
              if (_lessonData?['introduction']?['focusPoints'] != null) ...[
                const SizedBox(height: 16),
                Text(
                  _lessonData!['introduction']['focusPoints']['heading'] ??
                      'Focus Points:',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
                const SizedBox(height: 8),
                ...List<String>.from(
                  _lessonData!['introduction']['focusPoints']['points'] ?? [],
                ).map(
                  (point) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "• ",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            point.replaceAll(
                              RegExp(r'<[^>]*>'),
                              '',
                            ), // Remove HTML tags
                            style: const TextStyle(fontSize: 15),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // **FIX:** Video section (if exists)
        if (_videoController.initialVideoId.isNotEmpty)
          _buildSectionCard(
            icon: Icons.videocam,
            title: _lessonData?['video']?['heading'] ?? 'Watch and Learn',
            content: YoutubePlayer(controller: _videoController),
          ),

        // **FIX:** Show full key takeaways
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
                            const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item,
                                style: const TextStyle(
                                  fontSize: 15,
                                  height: 1.3,
                                ),
                              ),
                            ),
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
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/lesson3_2_activity',
                arguments: {
                  'lessonId': _lessonId,
                  'lessonTitle':
                      _lessonData?['lessonTitle'] ?? 'Speaking Practice',
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
          _lessonData?['lessonTitle'] ?? 'Lesson 3.2',
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
}
