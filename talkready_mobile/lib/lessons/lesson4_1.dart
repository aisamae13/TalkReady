// lib/lessons/lesson4_1.dart
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../services/unified_progress_service.dart';
import '../widgets/typing_pre_assessment_widget.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Lesson4_1Page extends StatefulWidget {
  const Lesson4_1Page({super.key});

  @override
  State<Lesson4_1Page> createState() => _Lesson4_1PageState();
}

class _Lesson4_1PageState extends State<Lesson4_1Page> {
  final Logger _logger = Logger();
  final UnifiedProgressService _progressService = UnifiedProgressService();
  final String _lessonId = "Lesson-4-1";
  final String _firestoreDocId = "lesson_4_1";

  bool _isLoading = true;
  Map<String, dynamic>? _lessonData;
  bool _isPreAssessmentComplete = false;
  late YoutubePlayerController _videoController;
  List<Map<String, dynamic>> _activityLog = [];
  int _attemptNumber = 0;

  // Audio recording and playback
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Map<String, String> _phraseRecordings =
      {}; // Store recordings for each phrase
  Map<String, Map<String, dynamic>> _speechFeedback = {}; // Store AI feedback
  Map<String, bool> _isPlayingPhrase =
      {}; // Track playing state for each phrase
  Map<String, bool> _isRecordingPhrase =
      {}; // Track recording state for each phrase

  @override
  void initState() {
    super.initState();
    _videoController = YoutubePlayerController(initialVideoId: '');
    _loadInitialData();
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
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
      _logger.e('Error loading initial data for Lesson 4.1: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onPreAssessmentComplete() async {
    try {
      await _progressService.markPreAssessmentAsComplete(_lessonId);
      setState(() {
        _isPreAssessmentComplete = true;
      });
      _logger.i('Pre-assessment completed for $_lessonId');
    } catch (e) {
      _logger.e('Error marking pre-assessment as complete: $e');
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
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF9C27B0)),
              SizedBox(height: 16),
              Text('Loading lesson content...'),
            ],
          ),
        ),
      );
    }

    if (_lessonData == null) {
      return const Scaffold(
        body: Center(child: Text('Failed to load lesson content')),
      );
    }

    if (!_isPreAssessmentComplete) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_lessonData?['lessonTitle'] ?? 'Lesson 4.1'),
          backgroundColor: const Color(0xFF9C27B0),
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              TypingPreAssessmentWidget(
                lessonKey: _lessonId,
                onComplete: _onPreAssessmentComplete,
                // The red underline on 'assessmentData' is now fixed
                assessmentData: _lessonData?['preAssessmentData'],
              ),
            ],
          ),
        ),
      );
    }
    // Show main lesson content
    return Scaffold(
      appBar: AppBar(
        title: Text(_lessonData?['lessonTitle'] ?? 'Lesson 4.1'),
        backgroundColor: const Color(0xFF9C27B0),
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.history, color: Color(0xFF9C27B0)),
                label: const Text(
                  'View Your Activity Log',
                  style: TextStyle(color: Color(0xFF9C27B0)),
                ),
                onPressed: _showActivityLogDialog,
              ),
            ),
            const SizedBox(height: 10),
            _buildSectionCard(
              icon: Icons.flag,
              title: _lessonData?['objective']?['heading'] ?? 'Objective',
              color: const Color(0xFF9C27B0),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_lessonData?['objective']?['points'] != null)
                    ...List<String>.from(
                      _lessonData!['objective']['points'],
                    ).map(
                      (point) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Color(0xFF9C27B0),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                point,
                                style: const TextStyle(
                                  fontSize: 15,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            _buildSectionCard(
              icon: Icons.info_outline,
              title:
                  _lessonData?['introduction']?['heading'] ??
                  'Why Clarification Matters',
              color: const Color(0xFF9C27B0),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_lessonData?['introduction']?['paragraph'] != null)
                    Text(
                      _lessonData!['introduction']['paragraph'],
                      style: const TextStyle(fontSize: 16, height: 1.4),
                    ),
                  const SizedBox(height: 8),
                  ...[
                    'Ensures accurate understanding of the issue.',
                    'Prevents costly mistakes.',
                    'Builds trust through respectful communication.',
                  ].map(
                    (s) => Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.circle,
                            size: 8,
                            color: Color(0xFF9C27B0),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              s,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _buildKeyPhrasesSection(),
            _buildCallCenterExamplesSection(),
            _buildVideoSection(),
            _buildLessonSummarySection(),
            const SizedBox(height: 32),
            Center(
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF9C27B0), Color(0xFF7B1FA2)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF9C27B0).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      '/lesson4_1_activity',
                      arguments: {
                        'lessonId': _lessonId,
                        'lessonTitle':
                            _lessonData?['lessonTitle'] ??
                            'Advanced Customer Service Activity',
                        'lessonData': _lessonData,
                        'attemptNumber': _attemptNumber + 1,
                      },
                    );
                  },
                  icon: const Icon(Icons.play_arrow, size: 24),
                  label: const Text(
                    'Start the Activity',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF9C27B0), Color(0xFF7B1FA2)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9C27B0).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.business_center,
                  size: 28,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _lessonData?['moduleTitle'] ?? 'Module 4',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      _lessonData?['lessonTitle'] ??
                          'Lesson 4.1: Advanced Customer Service Scenarios',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_lessonData?['lessonDescription'] != null) ...[
            const SizedBox(height: 16),
            Text(
              _lessonData!['lessonDescription'],
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required Widget content,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              content,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeyPhrasesSection() {
    final keyPhrases =
        _lessonData?['keyPhrases']?['table'] as List<dynamic>? ?? [];

    // Fallback key phrases if not found in lesson data
    final defaultKeyPhrases = [
      {
        'situation': "Didn't catch what was said",
        'phrase': "Sorry, can you say that again?",
      },
      {
        'situation': "Didn't understand fully",
        'phrase': "I didn't quite get that. Could you repeat it?",
      },
      {
        'situation': "Need spelling",
        'phrase': "Could you spell that for me, please?",
      },
      {
        'situation': "Need to confirm detail",
        'phrase': "Just to confirm, did you say [repeat info]?",
      },
      {
        'situation': "Need more info",
        'phrase': "Could you explain that a little more?",
      },
      {
        'situation': "Heard multiple things",
        'phrase': "Could you clarify what you meant by...?",
      },
    ];

    final phrasesToUse = keyPhrases.isNotEmpty ? keyPhrases : defaultKeyPhrases;

    return _buildSectionCard(
      icon: Icons.list,
      title: 'Key Phrases for Clarification',
      color: const Color(0xFF009688),
      content: Column(
        children: phrasesToUse.map<Widget>((row) {
          final phraseId = 'phrase_${phrasesToUse.indexOf(row)}';
          final situation = row['situation'] ?? '';
          final phrase = row['phrase'] ?? '';

          return _buildInteractivePhraseCard(
            phraseId: phraseId,
            situation: situation,
            phrase: phrase,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInteractivePhraseCard({
    required String phraseId,
    required String situation,
    required String phrase,
  }) {
    final isRecording = _isRecordingPhrase[phraseId] ?? false;
    final isPlayingTTS = _isPlayingPhrase[phraseId] ?? false;
    final hasRecording = _phraseRecordings.containsKey(phraseId);
    final hasFeedback = _speechFeedback.containsKey(phraseId);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2F1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF009688).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Situation and Phrase
          Text(
            situation,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF00796B),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              '"$phrase"',
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF009688),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Action Buttons Row 1
          Row(
            children: [
              // Listen Button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isPlayingTTS
                      ? null
                      : () => _playTTSAudio(phrase, phraseId),
                  icon: Icon(
                    isPlayingTTS ? Icons.volume_up : Icons.volume_up_outlined,
                    size: 18,
                  ),
                  label: Text(isPlayingTTS ? 'Playing...' : 'Listen'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Practice Button (Record)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isRecording
                      ? () => _stopRecording(phraseId)
                      : () => _startRecording(phraseId),
                  icon: Icon(isRecording ? Icons.stop : Icons.mic, size: 18),
                  label: Text(isRecording ? 'Stop' : 'Practice'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isRecording ? Colors.red : Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),

          // Action Buttons Row 2 (shown only if has recording)
          if (hasRecording) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                // Playback Button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _playUserRecording(phraseId),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Playback'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Get Feedback Button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: hasFeedback
                        ? null
                        : () => _getAIFeedback(phraseId, phrase),
                    icon: const Icon(Icons.psychology, size: 18),
                    label: Text(hasFeedback ? 'Done' : 'Get Feedback'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasFeedback
                          ? Colors.grey
                          : Colors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],

          // AI Feedback Display
          if (hasFeedback) _buildFeedbackDisplay(phraseId),
        ],
      ),
    );
  }

  Widget _buildFeedbackDisplay(String phraseId) {
    final feedback = _speechFeedback[phraseId];
    if (feedback == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.indigo.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.analytics, color: Colors.indigo, size: 20),
              SizedBox(width: 8),
              Text(
                'Speech Analysis',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress bars for different metrics
          _buildMetricBar(
            'Accuracy',
            (feedback['accuracy'] ?? 0.0).toDouble(),
            Colors.green,
          ),
          const SizedBox(height: 8),
          _buildMetricBar(
            'Fluency',
            (feedback['fluency'] ?? 0.0).toDouble(),
            Colors.blue,
          ),
          const SizedBox(height: 8),
          _buildMetricBar(
            'Completeness',
            (feedback['completeness'] ?? 0.0).toDouble(),
            Colors.orange,
          ),
          const SizedBox(height: 8),
          _buildMetricBar(
            'Prosody',
            (feedback['prosody'] ?? 0.0).toDouble(),
            Colors.purple,
          ),

          if (feedback['feedback'] != null) ...[
            const SizedBox(height: 12),
            Text(
              feedback['feedback'],
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricBar(String label, double value, Color color) {
    final percentage = (value * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            Text(
              '$percentage%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: value,
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 6,
        ),
      ],
    );
  }

  // Audio Methods
  Future<void> _playTTSAudio(String text, String phraseId) async {
    try {
      setState(() => _isPlayingPhrase[phraseId] = true);

      // Call your backend TTS service
      final audioBytes = await _progressService.synthesizeSpeech(text);

      if (audioBytes != null) {
        // Save to temporary file and play
        final tempDir = await getTemporaryDirectory();
        final audioFile = File(
          '${tempDir.path}/tts_${DateTime.now().millisecondsSinceEpoch}.wav',
        );
        await audioFile.writeAsBytes(audioBytes);

        await _audioPlayer.setFilePath(audioFile.path);
        await _audioPlayer.play();

        // Listen for completion
        _audioPlayer.playerStateStream.listen((state) {
          if (state.processingState == ProcessingState.completed) {
            if (mounted) {
              setState(() => _isPlayingPhrase[phraseId] = false);
            }
          }
        });
      } else {
        setState(() => _isPlayingPhrase[phraseId] = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('TTS service unavailable')),
        );
      }
    } catch (e) {
      _logger.e('Error playing TTS audio: $e');
      setState(() => _isPlayingPhrase[phraseId] = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Error playing audio')));
    }
  }

  Future<void> _startRecording(String phraseId) async {
    try {
      // Request microphone permission
      final permission = await Permission.microphone.request();
      if (permission != PermissionStatus.granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission required')),
        );
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final recordingPath =
          '${tempDir.path}/recording_${phraseId}_${DateTime.now().millisecondsSinceEpoch}.wav';

      // FIXED: Updated recording method
      await _audioRecorder.start(
        RecordConfig(
          encoder: AudioEncoder.wav,
          bitRate: 16000,
          sampleRate: 16000,
        ),
        path: recordingPath,
      );

      setState(() {
        _isRecordingPhrase[phraseId] = true;
      });

      _logger.i('Started recording for phrase: $phraseId');
    } catch (e) {
      _logger.e('Error starting recording: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Error starting recording')));
    }
  }

  Future<void> _stopRecording(String phraseId) async {
    try {
      final recordingPath = await _audioRecorder.stop();

      setState(() {
        _isRecordingPhrase[phraseId] = false;
        if (recordingPath != null) {
          _phraseRecordings[phraseId] = recordingPath;
        }
      });

      _logger.i(
        'Stopped recording for phrase: $phraseId, path: $recordingPath',
      );

      if (recordingPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Recording saved! You can now play it back or get feedback.',
            ),
          ),
        );
      }
    } catch (e) {
      _logger.e('Error stopping recording: $e');
      setState(() => _isRecordingPhrase[phraseId] = false);
    }
  }

  Future<void> _playUserRecording(String phraseId) async {
    final recordingPath = _phraseRecordings[phraseId];
    if (recordingPath == null) return;

    try {
      await _audioPlayer.setFilePath(recordingPath);
      await _audioPlayer.play();
    } catch (e) {
      _logger.e('Error playing user recording: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Error playing recording')));
    }
  }

  Future<void> _getAIFeedback(String phraseId, String originalText) async {
    final recordingPath = _phraseRecordings[phraseId];
    if (recordingPath == null) return;

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Analyzing your pronunciation...'),
              SizedBox(height: 8),
              Text(
                'This may take a few seconds...',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      );

      // Upload file to get URL
      final audioUrl = await _uploadAudioFile(recordingPath);
      _logger.i('Audio uploaded. URL: $audioUrl');

      if (audioUrl != null) {
        // Get Azure speech analysis
        final azureResult = await _progressService.evaluateAzureSpeech(
          audioUrl,
          originalText,
        );

        _logger.i('Azure result: $azureResult');

        if (azureResult != null && azureResult['success'] == true) {
          _logger.i('Azure data: ${azureResult['data']}');

          // Get OpenAI explanation
          final openaiResult = await _progressService.getOpenAICoachExplanation(
            azureResult,
            originalText,
          );

          _logger.i('OpenAI result: $openaiResult');

          // ✅ FIXED: Extract scores directly from azureResult (root level)
          double accuracy = 0.0;
          double fluency = 0.0;
          double completeness = 0.0;
          double prosody = 0.0;

          // ✅ The scores are at the ROOT level of azureResult, not in a nested 'data' object
          if (azureResult['accuracyScore'] != null) {
            accuracy =
                (azureResult['accuracyScore'] as num).toDouble() /
                100; // Convert to 0-1 range
          }

          if (azureResult['fluencyScore'] != null) {
            fluency =
                (azureResult['fluencyScore'] as num).toDouble() /
                5; // Convert 0-5 to 0-1 range
          }

          if (azureResult['completenessScore'] != null) {
            completeness =
                (azureResult['completenessScore'] as num).toDouble() /
                100; // Convert to 0-1 range
          }

          if (azureResult['prosodyScore'] != null) {
            prosody =
                (azureResult['prosodyScore'] as num).toDouble() /
                100; // Convert to 0-1 range
          }

          _logger.i(
            'Parsed scores - Accuracy: $accuracy, Fluency: $fluency, Completeness: $completeness, Prosody: $prosody',
          );

          // ✅ REMOVED: All the fallback hardcoded logic

          // Combine results
          final combinedFeedback = {
            'accuracy': accuracy,
            'fluency': fluency,
            'completeness': completeness,
            'prosody': prosody,
            'feedback':
                openaiResult?['explanation'] ??
                'Analysis completed successfully.',
          };

          setState(() {
            _speechFeedback[phraseId] = combinedFeedback;
          });

          _logger.i('AI feedback received successfully for phrase: $phraseId');
        } else {
          throw Exception(
            'Azure speech analysis failed: ${azureResult?['error'] ?? 'Unknown error'}',
          );
        }
      } else {
        throw Exception('Failed to upload audio file');
      }

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _logger.e('Error getting AI feedback: $e');
      if (mounted) Navigator.of(context).pop();

      // Show error message to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to analyze pronunciation: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<String?> _uploadAudioFile(String filePath) async {
    try {
      final uId = FirebaseAuth.instance.currentUser?.uid;
      if (uId == null) {
        _logger.e('User not authenticated for audio upload.');
        return null;
      }

      File audioFile = File(filePath);
      if (!await audioFile.exists()) {
        _logger.e("Audio file does not exist at path: $filePath");
        return null;
      }

      // Upload to Firebase Storage
      String fileName = filePath.split('/').last;
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      String storagePath = 'speechAnalysis/$uId/${timestamp}_$fileName';

      final storageRef = FirebaseStorage.instance.ref().child(storagePath);
      UploadTask uploadTask = storageRef.putFile(audioFile);

      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      _logger.i("Audio uploaded successfully! Download URL: $downloadUrl");
      return downloadUrl;
    } catch (e) {
      _logger.e("Error uploading audio file: $e");
      return null;
    }
  }

  Widget _buildCallCenterExamplesSection() {
    return _buildSectionCard(
      icon: Icons.play_circle,
      title: 'Call Center Examples',
      color: Colors.blueGrey,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCallCenterExample(
            customer: '"I\'m calling about the problem with my serv—"',
            agent: '"I\'m sorry, could you repeat that last part?"',
          ),
          _buildCallCenterExample(
            customer: '"My email is jen_matsuba87@gmail.com."',
            agent: '"Could you spell that for me to make sure I got it right?"',
          ),
          _buildCallCenterExample(
            customer: '"I placed the order on the 15th."',
            agent:
                '"Just to confirm — you placed the order on March 15th, correct?"',
          ),
        ],
      ),
    );
  }

  Widget _buildCallCenterExample({
    required String customer,
    required String agent,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Customer: $customer',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
          Text(
            'Agent: $agent',
            style: const TextStyle(fontSize: 15, color: Colors.indigo),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoSection() {
    if (_videoController.initialVideoId.isEmpty) return const SizedBox.shrink();
    return _buildSectionCard(
      icon: Icons.videocam,
      title:
          _lessonData?['video']?['heading'] ??
          'Watch: Asking for Clarification',
      color: const Color(0xFF9C27B0),
      content: Column(
        children: [
          YoutubePlayer(
            controller: _videoController,
            showVideoProgressIndicator: true,
          ),
          if (_lessonData?['video']?['description'] != null) ...[
            const SizedBox(height: 12),
            Text(
              _lessonData!['video']['description'],
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLessonSummarySection() {
    final summary = _lessonData?['summary'];
    if (summary == null) return const SizedBox.shrink();
    return _buildSectionCard(
      icon: Icons.check_circle,
      title: summary['heading'] ?? 'Lesson Summary',
      color: Colors.green,
      content: Text(
        summary['paragraph'] ?? '',
        style: const TextStyle(fontSize: 16, color: Colors.black87),
      ),
    );
  }
}
