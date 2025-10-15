import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';

class FluencyPracticePage extends StatefulWidget {
  const FluencyPracticePage({Key? key}) : super(key: key);

  @override
  State<FluencyPracticePage> createState() => _FluencyPracticePageState();
}

class _FluencyPracticePageState extends State<FluencyPracticePage> {
  final Logger _logger = Logger();
  final _user = FirebaseAuth.instance.currentUser;
  final _audioRecorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();

  bool _isLoading = true;
  List<Map<String, dynamic>> _passages = [];
  int _currentPassageIndex = 0;
  bool _isRecording = false;
  bool _hasRecorded = false;
  Map<String, dynamic>? _currentFeedback;
  String? _recordedFilePath;

  // Practice session data
  int _sessionScore = 0;
  int _passagesCompleted = 0;
  DateTime? _sessionStartTime;
  List<Map<String, dynamic>> _sessionResults = [];

  // Backend configuration
  static const String _backendUrl = 'https://talkready-backend.onrender.com';

  @override
  void initState() {
    super.initState();
    _sessionStartTime = DateTime.now();
    _loadPassages();
    _checkMicrophonePermission();
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _checkMicrophonePermission() async {
    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      _logger.w('Microphone permission not granted');
      _showErrorDialog(
        'Please grant microphone permission to use fluency practice.',
      );
    }
  }

  Future<void> _loadPassages() async {
    setState(() => _isLoading = true);

    try {
      // ✅ Load fluency passages (can be from backend or local)
      // For now, using pre-defined passages
      _passages = [
        {
          'id': 'passage_1',
          'title': 'Customer Service Excellence',
          'text':
              'Welcome to our customer service department. We are here to assist you with any questions or concerns you may have. Our team is dedicated to providing excellent service and ensuring your satisfaction. Please feel free to reach out to us at any time.',
          'difficulty': 'Beginner',
          'wordCount': 49,
          'estimatedTime': '30 seconds',
          'tips':
              'Read at a steady pace, pause naturally at commas and periods',
        },
        {
          'id': 'passage_2',
          'title': 'Handling Customer Issues',
          'text':
              'I understand that you are experiencing difficulties with your recent order. Let me take a moment to review your account and see what we can do to resolve this situation. Your satisfaction is our top priority, and I want to make sure we find the best solution for you. Thank you for your patience while I look into this matter.',
          'difficulty': 'Intermediate',
          'wordCount': 63,
          'estimatedTime': '40 seconds',
          'tips':
              'Emphasize empathy words like "understand" and "satisfaction"',
        },
        {
          'id': 'passage_3',
          'title': 'Technical Support Script',
          'text':
              'Thank you for contacting technical support. I will be happy to help you troubleshoot this issue. First, could you please describe the problem you are experiencing in detail? Once I have a better understanding of the situation, I can guide you through the necessary steps to resolve it. Please let me know if you have any questions during this process.',
          'difficulty': 'Advanced',
          'wordCount': 65,
          'estimatedTime': '45 seconds',
          'tips':
              'Maintain a helpful, professional tone throughout. Speak clearly on technical terms.',
        },
      ];

      setState(() => _isLoading = false);
      _logger.i('Loaded ${_passages.length} fluency passages');
    } catch (e) {
      _logger.e('Error loading passages: $e');
      setState(() => _isLoading = false);
      _showErrorDialog('Failed to load practice passages.');
    }
  }

  Future<void> _startRecording() async {
    try {
      if (!await _audioRecorder.hasPermission()) {
        _showErrorDialog('Microphone permission is required.');
        return;
      }

      final directory = await getApplicationDocumentsDirectory();
      final filePath =
          '${directory.path}/fluency_${DateTime.now().millisecondsSinceEpoch}.wav';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: filePath,
      );

      setState(() {
        _isRecording = true;
        _currentFeedback = null;
        _recordedFilePath = filePath;
      });

      _logger.i('Started recording: $filePath');
    } catch (e) {
      _logger.e('Error starting recording: $e');
      _showErrorDialog('Failed to start recording: ${e.toString()}');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();

      setState(() {
        _isRecording = false;
        _hasRecorded = true;
        _recordedFilePath = path;
      });

      _logger.i('Stopped recording: $path');
    } catch (e) {
      _logger.e('Error stopping recording: $e');
      _showErrorDialog('Failed to stop recording.');
    }
  }

  Future<void> _submitRecording() async {
    if (!_hasRecorded || _recordedFilePath == null) {
      _showErrorDialog('Please record your reading first.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentPassage = _passages[_currentPassageIndex];

      // Upload to Firebase Storage
      _logger.i('Uploading audio to Firebase Storage...');
      final audioFile = File(_recordedFilePath!);
      final fileName =
          'fluency/${_user!.uid}/${DateTime.now().millisecondsSinceEpoch}.wav';

      final storageRef = FirebaseStorage.instance.ref().child(fileName);
      final uploadTask = await storageRef.putFile(audioFile);
      final audioUrl = await uploadTask.ref.getDownloadURL();

      _logger.i('Audio uploaded: $audioUrl');

      // Send for Azure evaluation
      final evaluationResponse = await http
          .post(
            Uri.parse('$_backendUrl/evaluate-speech-with-azure'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'audioUrl': audioUrl,
              'originalText': currentPassage['text'],
              'assessmentType': 'script_reading', // Fluency uses script reading
              'language': 'en-US',
            }),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw Exception('Request timed out'),
          );

      if (evaluationResponse.statusCode != 200) {
        throw Exception('Evaluation failed: ${evaluationResponse.statusCode}');
      }

      final feedback = json.decode(evaluationResponse.body);

      if (feedback['success'] != true) {
        throw Exception(feedback['error'] ?? 'Unknown error');
      }

      _logger.i('Received feedback: Fluency ${feedback['fluencyScore']}/5');

      // Calculate fluency-specific metrics
      setState(() {
        // ✅ NEW CODE (correct score calculation)
        _currentFeedback = {
          'fluencyScore': _normalizeScore(
            feedback['fluencyScore'],
            isRating: true,
          ),
          'accuracyScore': _normalizeScore(feedback['accuracyScore']),
          'completenessScore': _normalizeScore(feedback['completenessScore']),
          'prosodyScore': _normalizeScore(
            feedback['prosodyScore'],
            isRating: true,
          ),
          'overallScore': _calculateFluencyScore(feedback),
          'strengths': _extractFluencyStrengths(feedback),
          'improvements': _extractFluencyImprovements(feedback),
          'transcript': feedback['textRecognized'] ?? '',
          'wordsPerMinute': _estimateWPM(currentPassage['wordCount'], feedback),
        };

        final overallScore = _currentFeedback!['overallScore'] as int;
        _sessionScore += overallScore;
        _passagesCompleted++;

        _sessionResults.add({
          'passage': currentPassage['title'],
          'score': overallScore,
          'feedback': _currentFeedback,
          'audioUrl': audioUrl,
          'timestamp': DateTime.now().toIso8601String(),
        });

        _isLoading = false;
      });

      // Clean up local file
      try {
        await audioFile.delete();
      } catch (e) {
        _logger.w('Could not delete local file: $e');
      }
    } catch (e) {
      _logger.e('Error submitting recording: $e');
      setState(() => _isLoading = false);
      _showErrorDialog('Failed to analyze recording: ${e.toString()}');
    }
  }

  /// Normalize Azure scores to 0-100 scale
  /// - isRating: true for 0-5 scale scores (fluency, prosody)
  /// - isRating: false for 0-100 scale scores (accuracy, completeness)
  int _normalizeScore(dynamic score, {bool isRating = false}) {
    if (score == null) return 0;

    // Convert to double first
    final double numericScore = score is int
        ? score.toDouble()
        : (score as double);

    if (isRating) {
      // For 0-5 scale: convert to percentage
      // But Azure sometimes returns already-converted values (0-100)
      if (numericScore > 5) {
        // Already a percentage, just ensure it's within bounds
        return numericScore.round().clamp(0, 100);
      } else {
        // Convert 0-5 to 0-100
        return (numericScore / 5 * 100).round().clamp(0, 100);
      }
    } else {
      // For 0-100 scale: just ensure it's within bounds
      return numericScore.round().clamp(0, 100);
    }
  }

  int _calculateFluencyScore(Map<String, dynamic> feedback) {
    // ✅ FIXED: Properly normalize all scores before calculating
    final fluency = _normalizeScore(feedback['fluencyScore'], isRating: true);
    final prosody = _normalizeScore(feedback['prosodyScore'], isRating: true);
    final accuracy = _normalizeScore(feedback['accuracyScore']);
    final completeness = _normalizeScore(feedback['completenessScore']);

    // Fluency practice weighs fluency and prosody more heavily
    final overall =
        ((fluency * 0.35) +
                (prosody * 0.35) +
                (accuracy * 0.15) +
                (completeness * 0.15))
            .round();

    return overall.clamp(0, 100);
  }

  int _estimateWPM(int wordCount, Map<String, dynamic> feedback) {
    // Rough estimate: assume average speaking time based on fluency
    final fluency = feedback['fluencyScore'] ?? 3.5;
    final baseWPM = 150; // Average speaking rate
    return (baseWPM * (fluency / 5)).round();
  }

  List<String> _extractFluencyStrengths(Map<String, dynamic> feedback) {
    final strengths = <String>[];

    // ✅ FIXED: Use normalized scores
    final fluency = _normalizeScore(feedback['fluencyScore'], isRating: true);
    final prosody = _normalizeScore(feedback['prosodyScore'], isRating: true);
    final completeness = _normalizeScore(feedback['completenessScore']);

    if (fluency > 80) strengths.add('Excellent reading flow');
    if (prosody > 80) strengths.add('Natural intonation and expression');
    if (completeness > 85) strengths.add('Complete passage delivery');

    return strengths.isEmpty ? ['Good effort!'] : strengths;
  }

  List<String> _extractFluencyImprovements(Map<String, dynamic> feedback) {
    final improvements = <String>[];

    // ✅ FIXED: Use normalized scores
    final fluency = _normalizeScore(feedback['fluencyScore'], isRating: true);
    final prosody = _normalizeScore(feedback['prosodyScore'], isRating: true);
    final completeness = _normalizeScore(feedback['completenessScore']);

    if (fluency < 70)
      improvements.add('Practice reading aloud daily to build fluency');
    if (prosody < 70)
      improvements.add('Work on varying your tone and emphasis');
    if (completeness < 80)
      improvements.add('Focus on reading the complete passage');

    return improvements.isEmpty
        ? ['Excellent work! Keep practicing to maintain this level.']
        : improvements.take(3).toList();
  }

  void _nextPassage() {
    if (_currentPassageIndex < _passages.length - 1) {
      setState(() {
        _currentPassageIndex++;
        _hasRecorded = false;
        _currentFeedback = null;
        _recordedFilePath = null;
      });
    } else {
      _completeSession();
    }
  }

  Future<void> _completeSession() async {
    final avgScore = _passagesCompleted > 0
        ? (_sessionScore / _passagesCompleted).round()
        : 0;

    // Save session to backend
    try {
      final duration = DateTime.now().difference(_sessionStartTime!).inSeconds;

      await http.post(
        Uri.parse('$_backendUrl/save-fluency-session'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': _user?.uid,
          'sessionData': {
            'startedAt': _sessionStartTime!.toIso8601String(),
            'passagesAttempted': _passages.length,
            'passagesCompleted': _passagesCompleted,
            'averageScore': avgScore.toDouble(),
            'results': _sessionResults,
            'duration': duration,
          },
        }),
      );

      _logger.i('Fluency session saved');
    } catch (e) {
      _logger.e('Failed to save session: $e');
    }

    _showSessionComplete(avgScore);
  }

  void _showSessionComplete(int avgScore) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🎉 Session Complete!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Great job, ${_user?.displayName?.split(' ')[0] ?? 'there'}!',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildStatRow(
              'Passages Completed',
              '$_passagesCompleted/${_passages.length}',
            ),
            _buildStatRow('Average Score', '$avgScore%'),
            _buildStatRow('Session Time', _getSessionDuration()),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _resetSession();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Practice Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _getSessionDuration() {
    if (_sessionStartTime == null) return '0m';
    final duration = DateTime.now().difference(_sessionStartTime!);
    return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
  }

  void _resetSession() {
    setState(() {
      _currentPassageIndex = 0;
      _hasRecorded = false;
      _currentFeedback = null;
      _recordedFilePath = null;
      _sessionScore = 0;
      _passagesCompleted = 0;
      _sessionResults.clear();
      _sessionStartTime = DateTime.now();
    });
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _passages.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Fluency Practice'),
          backgroundColor: Colors.green,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading passages...'),
            ],
          ),
        ),
      );
    }

    final currentPassage = _passages[_currentPassageIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text('📖 Fluency Practice'),
        backgroundColor: Colors.green,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '${_currentPassageIndex + 1}/${_passages.length}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Progress indicator
            LinearProgressIndicator(
              value: (_currentPassageIndex + 1) / _passages.length,
              backgroundColor: Colors.grey[300],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
              minHeight: 8,
            ),
            const SizedBox(height: 24),

            // Passage card
            _buildPassageCard(currentPassage),
            const SizedBox(height: 24),

            // Recording controls
            _buildRecordingControls(),
            const SizedBox(height: 24),

            // Feedback display
            if (_currentFeedback != null) _buildFeedbackCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildPassageCard(Map<String, dynamic> passage) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade50, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    passage['difficulty'] ?? 'Medium',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${passage['wordCount']} words • ${passage['estimatedTime']}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              passage['title'],
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Read this passage aloud:',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                passage['text'],
                style: const TextStyle(fontSize: 16, height: 1.6),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb, color: Colors.amber.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      passage['tips'],
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingControls() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (_isRecording)
              Column(
                children: [
                  const Text(
                    'Recording...',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const CircularProgressIndicator(color: Colors.red),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _stopRecording,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop Recording'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                  ),
                ],
              )
            else if (_hasRecorded && _currentFeedback == null)
              Column(
                children: [
                  const Icon(Icons.check_circle, size: 48, color: Colors.green),
                  const SizedBox(height: 16),
                  const Text(
                    'Recording Complete!',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _hasRecorded = false;
                              _currentFeedback = null;
                              _recordedFilePath = null;
                            });
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Re-record'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _submitRecording,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send),
                          label: Text(
                            _isLoading ? 'Analyzing...' : 'Get Feedback',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            else
              Column(
                children: [
                  const Icon(Icons.mic, size: 48, color: Colors.green),
                  const SizedBox(height: 16),
                  const Text(
                    'Tap to record your reading',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _startRecording,
                    icon: const Icon(Icons.mic, size: 28),
                    label: const Text(
                      'Start Recording',
                      style: TextStyle(fontSize: 18),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackCard() {
    final feedback = _currentFeedback!;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade50, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '✅ Fluency Feedback',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 16),

            // Overall score
            Center(
              child: Column(
                children: [
                  Text(
                    '${feedback['overallScore']}%',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: _getScoreColor(feedback['overallScore']),
                    ),
                  ),
                  Text(
                    _getScoreLabel(feedback['overallScore']),
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '~${feedback['wordsPerMinute']} words per minute',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Score breakdown
            _buildScoreRow('Reading Fluency', feedback['fluencyScore']),
            _buildScoreRow('Expression', feedback['prosodyScore']),
            _buildScoreRow('Accuracy', feedback['accuracyScore']),
            _buildScoreRow('Completeness', feedback['completenessScore']),
            const SizedBox(height: 20),

            // Strengths
            if ((feedback['strengths'] as List).isNotEmpty) ...[
              const Text(
                '💪 Strengths:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...(feedback['strengths'] as List).map(
                (strength) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        size: 16,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(strength)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Improvements
            if ((feedback['improvements'] as List).isNotEmpty) ...[
              const Text(
                '🎯 Areas to improve:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...(feedback['improvements'] as List).map(
                (improvement) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.lightbulb,
                        size: 16,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(improvement)),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Next button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _nextPassage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  _currentPassageIndex < _passages.length - 1
                      ? 'Next Passage →'
                      : 'Complete Session',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreRow(String label, int score) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: score / 100,
                minHeight: 8,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  _getScoreColor(score),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('$score%', style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 90) return Colors.green;
    if (score >= 75) return Colors.blue;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  String _getScoreLabel(int score) {
    if (score >= 90) return 'Excellent fluency!';
    if (score >= 75) return 'Good reading flow!';
    if (score >= 60) return 'Keep practicing!';
    return 'Needs more work';
  }
}
