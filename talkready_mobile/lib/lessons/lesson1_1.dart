// lib/lessons/lesson1_1.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:logger/logger.dart';
import '../services/unified_progress_service.dart';
import '../StudentAssessment/InteractiveText.dart';
import '../StudentAssessment/PreAssessment.dart';

class Lesson1_1Page extends StatefulWidget {
  const Lesson1_1Page({super.key});

  @override
  State<Lesson1_1Page> createState() => _Lesson1_1PageState();
}

class _Lesson1_1PageState extends State<Lesson1_1Page> {
  final Logger _logger = Logger();
  final UnifiedProgressService _progressService = UnifiedProgressService();
  static const String LESSON_ID = "Lesson-1-1";

  bool _isLoading = true;
  bool _preAssessmentCompleted = false;
  Map<String, dynamic>? _lessonData;
  late YoutubePlayerController _youtubeController;

  // No changes to state variables
  List<Map<String, dynamic>> _activityLog = [];
  bool _activityLogLoading = false;

  @override
  void initState() {
    super.initState();
    _youtubeController = YoutubePlayerController(initialVideoId: '');
    _loadData();
  }

  Future<void> _loadData() async {
    // This function remains the same
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _progressService.getFullLessonContent('lesson_1_1'),
        _progressService.isPreAssessmentCompleted(LESSON_ID),
      ]);

      final lessonData = results[0] as Map<String, dynamic>?;
      final preAssessmentCompleted = results[1] as bool;

      if (mounted) {
        setState(() {
          _lessonData = lessonData;
          _preAssessmentCompleted = preAssessmentCompleted;
          if (lessonData?['video']?['url'] != null) {
            final videoId =
                YoutubePlayer.convertUrlToId(lessonData!['video']['url']) ?? '';
            _youtubeController = YoutubePlayerController(
              initialVideoId: videoId,
              flags: const YoutubePlayerFlags(autoPlay: false),
            );
          }
        });
      }
    } catch (e) {
      _logger.e("Error loading lesson data for 1.1: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _onPreAssessmentComplete() async {
    // This function remains the same
    try {
      await _progressService.markPreAssessmentAsComplete(LESSON_ID);
      if (mounted) setState(() => _preAssessmentCompleted = true);
    } catch (e) {
      _logger.e("Failed to mark pre-assessment as complete: $e");
    }
  }

  // --- THIS IS THE CORRECTED ACTIVITY LOG FUNCTION ---
  Future<void> _showActivityLog() async {
    // Show a loading dialog immediately
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Fetch the data *before* building the main dialog
      final attempts = await _progressService.getLessonAttempts(LESSON_ID);

      if (mounted) {
        Navigator.of(context).pop(); // Close the loading dialog

        // Now show the dialog with the fetched data
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Activity Log for Lesson 1.1'),
            content: attempts.isEmpty
                ? const Text("No attempts found.")
                : SizedBox(
                    width: double.maxFinite,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: attempts.length,
                      itemBuilder: (context, index) {
                        final attempt = attempts[index];
                        final timestamp =
                            attempt['attemptTimestamp'] as DateTime?;
                        return ListTile(
                          title: Text('Attempt ${attempt['attemptNumber']}'),
                          subtitle: Text(
                            'Score: ${attempt['score']} / ${attempt['totalPossiblePoints']}\n'
                            'Time Spent: ${attempt['timeSpent']}s\n'
                            'Date: ${timestamp?.toLocal().toString().substring(0, 16) ?? 'N/A'}',
                          ),
                        );
                      },
                    ),
                  ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      _logger.e("Error fetching activity log: $e");
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog on error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load activity log: $e')),
        );
      }
    }
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
        appBar: AppBar(title: const Text('Lesson 1.1')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_lessonData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lesson 1.1')),
        body: const Center(child: Text('Failed to load lesson content.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lesson 1.1'),
        backgroundColor: const Color(0xFFFF6347),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // --- ADD THE HEADER WIDGET HERE ---
            _buildHeader(),
            const SizedBox(height: 16),
            if (!_preAssessmentCompleted)
              _buildPreAssessment()
            else
              _buildLessonContent(),
          ],
        ),
      ),
    );
  }

  // --- THIS IS THE NEW HEADER WIDGET ---
  Widget _buildHeader() {
    // Attempt to parse the title, with fallbacks
    final fullTitle = _lessonData?['title'] as String? ?? 'Module - Lesson';
    final parts = fullTitle.split(' - ');
    final moduleTitle = parts.isNotEmpty ? parts[0] : 'Module';
    final lessonTitle = parts.length > 1 ? parts[1] : 'Lesson';

    return Column(
      children: [
        Text(
          moduleTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF00568D), // A strong blue color
          ),
        ),
        const SizedBox(height: 4),
        Text(
          lessonTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFF6347), // The lesson's theme color
          ),
        ),
      ],
    );
  }

  Widget _buildPreAssessment() {
    final preAssessmentData =
        _lessonData?['preAssessmentData'] as Map<String, dynamic>?;
    if (preAssessmentData == null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _onPreAssessmentComplete(),
      );
      return const Center(child: CircularProgressIndicator());
    }
    return PreAssessmentWidget(
      assessmentData: preAssessmentData,
      onComplete: _onPreAssessmentComplete,
    );
  }

  Widget _buildLessonContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.history),
            label: const Text('View Activity Log'),
            onPressed: _showActivityLog,
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          icon: Icons.flag,
          title: 'Objective',
          content: Text(
            _lessonData?['objectiveText'] ?? 'Objective not available.',
          ),
        ),
        _buildSectionCard(
          icon: Icons.info_outline,
          title: _lessonData?['introduction']?['heading'] ?? 'Introduction',
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InteractiveTextWithDialog(
                text: _lessonData?['introduction']?['paragraph1'] ?? '',
                definitions: const {
                  'nouns': 'Words that name people, places, things, or ideas.',
                  'pronouns':
                      'Words that replace nouns to avoid repetition and improve flow.',
                },
              ),
              const SizedBox(height: 8),
              Html(data: _lessonData?['introduction']?['paragraph2'] ?? ''),
            ],
          ),
        ),
        _buildSectionCard(
          icon: Icons.videocam,
          title: _lessonData?['video']?['heading'] ?? 'Lesson Video',
          content: Column(
            children: [
              if (_youtubeController.initialVideoId.isNotEmpty)
                YoutubePlayer(
                  controller: _youtubeController,
                  showVideoProgressIndicator: true,
                )
              else
                const Text("Video could not be loaded."),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: Center(
            child: ElevatedButton(
              child: const Text('Proceed to Activity'),
              onPressed: () {
                if (_lessonData != null) {
                  Navigator.pushNamed(
                    context,
                    '/lesson1_1_activity',
                    arguments: {
                      'lessonId': LESSON_ID,
                      'lessonTitle':
                          _lessonData!['lessonId'] ?? 'Lesson 1.1 Activity',
                      'lessonData': _lessonData,
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
    required String title,
    required Widget content,
  }) {
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
