// lib/lessons/lesson1_3.dart
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'dart:async';
import 'package:flutter_html/flutter_html.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../services/unified_progress_service.dart';
import '../StudentAssessment/InteractiveText.dart';
import '../StudentAssessment/PreAssessment.dart';

class Lesson1_3Page extends StatefulWidget {
  const Lesson1_3Page({super.key});
  @override
  State<Lesson1_3Page> createState() => _Lesson1_3PageState();
}

class _Lesson1_3PageState extends State<Lesson1_3Page> {
  final Logger _logger = Logger();
  final UnifiedProgressService _progressService = UnifiedProgressService();
  static const String LESSON_ID = "Lesson-1-3";
  static const String FIRESTORE_DOC_ID = "lesson_1_3";
  bool _isLoading = true;
  bool _preAssessmentCompleted = false;
  Map<String, dynamic>? _lessonData;
  late YoutubePlayerController _youtubeController;

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
      _logger.e("Error loading lesson data for 1.3: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onPreAssessmentComplete() async {
    await _progressService.markPreAssessmentAsComplete(LESSON_ID);
    if (mounted) setState(() => _preAssessmentCompleted = true);
  }

  Future<void> _showActivityLog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final attempts = await _progressService.getLessonAttempts(LESSON_ID);
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Activity Log for Lesson 1.3'),
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
                      final maxScore =
                          attempt['totalPossiblePoints'] ??
                          _lessonData?['activity']?['maxScore'] ??
                          'N/A';

                      return ListTile(
                        title: Text('Attempt ${attempt['attemptNumber']}'),
                        subtitle: Text(
                          'Score: ${attempt['score']} / $maxScore\n'
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
    } catch (e) {
      _logger.e("Error fetching activity log for 1.3: $e");
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _youtubeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return Scaffold(
        appBar: AppBar(title: const Text('Lesson 1.3')),
        body: const Center(child: CircularProgressIndicator()),
      );
    if (_lessonData == null)
      return Scaffold(
        appBar: AppBar(title: const Text('Lesson 1.3')),
        body: const Center(child: Text('Failed to load content.')),
      );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lesson 1.3'),
        backgroundColor: const Color(0xFF32CD32),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
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

  // The helper widgets (_buildHeader, _buildPreAssessment, etc.) can be copied from lesson1_2.dart
  // and adapted for Lesson 1.3's data structure. For brevity, only the key parts are shown.

  Widget _buildHeader() {
    /* ... copy from lesson1_2.dart and adapt color ... */
    final fullTitle = _lessonData?['title'] as String? ?? 'Module - Lesson';
    final parts = fullTitle.split(' - ');
    return Column(
      children: [
        Text(
          parts.isNotEmpty ? parts[0] : 'Module',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF00568D),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          parts.length > 1 ? parts[1] : 'Lesson',
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
    final introduction =
        _lessonData?['introduction'] as Map<String, dynamic>? ?? {};
    final definitions =
        introduction['definitions'] as Map<String, dynamic>? ?? {};
    final structure = _lessonData?['structure'] as Map<String, dynamic>? ?? {};

    return Column(
      children: [
        Center(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.history),
            label: const Text('View Activity Log'),
            onPressed: _showActivityLog,
          ),
        ), // Add _showActivityLog logic here
        const SizedBox(height: 16),
        _buildSectionCard(
          icon: Icons.flag,
          title: 'Objective',
          content: Text(_lessonData?['objectiveDescription'] ?? ''),
        ),
        _buildSectionCard(
          icon: Icons.info_outline,
          title: introduction['heading'] ?? 'Introduction',
          content: InteractiveTextWithDialog(
            text: introduction['paragraph1'] ?? '',
            definitions: definitions.map(
              (k, v) => MapEntry(k.toString(), v.toString()),
            ),
          ),
        ),
        _buildSectionCard(
          icon: Icons.account_tree,
          title: structure['heading'] ?? 'Structure',
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List<String>.from(structure['listItems'] ?? [])
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Html(data: '• $item'),
                  ),
                )
                .toList(),
          ),
        ),
        _buildSectionCard(
          icon: Icons.videocam,
          title: _lessonData?['video']?['heading'] ?? 'Video',
          content: YoutubePlayer(
            controller: _youtubeController,
            showVideoProgressIndicator: true,
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
                    '/lesson1_3_activity',
                    arguments: {
                      'lessonId': LESSON_ID,
                      'lessonTitle':
                          _lessonData!['lessonId'] ?? 'Lesson 1.3 Activity',
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
