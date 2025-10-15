import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart'; // ✅ ADD THIS IMPORT
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';

class PronunciationPracticePage extends StatefulWidget {
  const PronunciationPracticePage({Key? key}) : super(key: key);

  @override
  State<PronunciationPracticePage> createState() =>
      _PronunciationPracticePageState();
}

class _PronunciationPracticePageState extends State<PronunciationPracticePage> {
  final Logger _logger = Logger();
  final _user = FirebaseAuth.instance.currentUser;
  final _audioRecorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();

  bool _isLoading = true;
  List<Map<String, dynamic>> _phrases = [];
  int _currentPhraseIndex = 0;
  bool _isRecording = false;
  bool _hasRecorded = false;
  Map<String, dynamic>? _currentFeedback;
  String? _recordedFilePath;

  // Practice session data
  int _sessionScore = 0;
  int _phrasesCompleted = 0;
  DateTime? _sessionStartTime;
  List<Map<String, dynamic>> _sessionResults = [];

  // Backend configuration
  static const String _backendUrl = 'https://talkready-backend.onrender.com';

  @override
  void initState() {
    super.initState();
    _sessionStartTime = DateTime.now();
    _loadPhrases();
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
        'Please grant microphone permission to use pronunciation practice.',
      );
    }
  }

  Future<void> _loadPhrases() async {
    setState(() => _isLoading = true);

    try {
      // ✅ STEP 1: Call backend to generate practice phrases
      final response = await http.post(
        Uri.parse('$_backendUrl/generate-pronunciation-phrase'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'difficulty': 'beginner', // You can make this dynamic later
          'category': 'general',
          'count': 5,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['phrases'] != null) {
          setState(() {
            _phrases = List<Map<String, dynamic>>.from(data['phrases']);
            _isLoading = false;
          });
          _logger.i('Loaded ${_phrases.length} phrases from backend');
        } else {
          throw Exception('Invalid response format');
        }
      } else {
        throw Exception('Backend returned ${response.statusCode}');
      }
    } catch (e) {
      _logger.e('Error loading phrases from backend: $e');
      // ✅ Fallback to local phrases if backend fails
      _loadFallbackPhrases();
    }
  }

  void _loadFallbackPhrases() {
    setState(() {
      _phrases = [
        {
          'id': 'phrase_1',
          'text': 'Thank you for calling customer service.',
          'category': 'Greetings',
          'difficulty': 'Easy',
          'tips': 'Speak clearly and emphasize "thank you"',
        },
        {
          'id': 'phrase_2',
          'text': 'How may I assist you today?',
          'category': 'Greetings',
          'difficulty': 'Easy',
          'tips': 'Keep a friendly, helpful tone',
        },
        {
          'id': 'phrase_3',
          'text': 'I understand your concern and I\'m here to help.',
          'category': 'Empathy',
          'difficulty': 'Medium',
          'tips': 'Show empathy through your voice tone',
        },
      ];
      _isLoading = false;
    });
    _logger.i('Using fallback phrases');
  }

  Future<void> _startRecording() async {
    try {
      // Check permission first
      if (!await _audioRecorder.hasPermission()) {
        _showErrorDialog(
          'Microphone permission is required. Please enable it in your device settings.',
        );
        return;
      }

      // ✅ Use WAV format for better compatibility with Azure
      final directory = await getApplicationDocumentsDirectory();
      final filePath =
          '${directory.path}/pronunciation_${DateTime.now().millisecondsSinceEpoch}.wav';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav, // ✅ CHANGED from aacLc to wav
          sampleRate: 16000, // ✅ Azure prefers 16kHz
          numChannels: 1, // ✅ Mono audio
        ),
        path: filePath,
      );

      setState(() {
        _isRecording = true;
        _currentFeedback = null;
        _recordedFilePath = filePath;
      });

      _logger.i('Started recording to: $filePath');
    } catch (e) {
      _logger.e('Error starting recording: $e');
      _showErrorDialog(
        'Failed to start recording: ${e.toString()}\n\nPlease check microphone permissions.',
      );
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

      _logger.i('Stopped recording. File saved at: $path');
    } catch (e) {
      _logger.e('Error stopping recording: $e');
      _showErrorDialog('Failed to stop recording.');
    }
  }

  Future<void> _submitRecording() async {
    if (!_hasRecorded || _recordedFilePath == null) {
      _showErrorDialog('Please record your pronunciation first.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentPhrase = _phrases[_currentPhraseIndex];

      // ✅ STEP 1: Upload audio to Firebase Storage
      _logger.i('Uploading audio to Firebase Storage...');
      final audioFile = File(_recordedFilePath!);
      final fileName =
          'pronunciation/${_user!.uid}/${DateTime.now().millisecondsSinceEpoch}.m4a';

      final storageRef = FirebaseStorage.instance.ref().child(fileName);
      final uploadTask = await storageRef.putFile(audioFile);

      // Get download URL
      final audioUrl = await uploadTask.ref.getDownloadURL();

      _logger.i('Audio uploaded successfully: $audioUrl');

      // ✅ STEP 2: Send for Azure pronunciation evaluation
      final evaluationResponse = await http
          .post(
            Uri.parse('$_backendUrl/evaluate-speech-with-azure'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'audioUrl': audioUrl,
              'originalText': currentPhrase['text'],
              'assessmentType': 'script_reading',
              'language': 'en-US',
            }),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Request timed out after 30 seconds');
            },
          );

      if (evaluationResponse.statusCode != 200) {
        throw Exception(
          'Evaluation failed: ${evaluationResponse.statusCode}\n${evaluationResponse.body}',
        );
      }

      final feedback = json.decode(evaluationResponse.body);

      if (feedback['success'] != true) {
        throw Exception(feedback['error'] ?? 'Unknown error from backend');
      }

      _logger.i('Received Azure feedback: ${feedback['accuracyScore']}%');

      // ✅ STEP 3: Process and display feedback
      setState(() {
        _currentFeedback = {
          'pronunciationScore': feedback['accuracyScore']?.round() ?? 0,
          'fluencyScore': ((feedback['fluencyScore'] ?? 0) / 5 * 100).round(),
          'clarityScore': feedback['completenessScore']?.round() ?? 0,
          'overallScore': _calculateOverallScore(feedback),
          'strengths': _extractStrengths(feedback),
          'improvements': _extractImprovements(feedback),
          'transcript': feedback['textRecognized'] ?? currentPhrase['text'],
        };

        final overallScore = _currentFeedback!['overallScore'] as int;
        _sessionScore += overallScore;
        _phrasesCompleted++;

        // Store result for session history
        _sessionResults.add({
          'phrase': currentPhrase['text'],
          'score': overallScore,
          'feedback': _currentFeedback,
          'audioUrl': audioUrl, // ✅ Store for playback later
          'timestamp': DateTime.now().toIso8601String(),
        });

        _isLoading = false;
      });

      // ✅ OPTIONAL: Delete local file after successful upload
      try {
        await audioFile.delete();
        _logger.i('Deleted local audio file');
      } catch (e) {
        _logger.w('Could not delete local file: $e');
      }
    } catch (e) {
      _logger.e('Error submitting recording: $e');
      setState(() => _isLoading = false);
      _showErrorDialog(
        'Failed to analyze your recording. Please try again.\n\nError: ${e.toString()}',
      );
    }
  }

  int _calculateOverallScore(Map<String, dynamic> feedback) {
    final accuracy = feedback['accuracyScore'] ?? 0;
    final fluency = (feedback['fluencyScore'] ?? 0) / 5 * 100;
    final completeness = feedback['completenessScore'] ?? 0;
    return ((accuracy + fluency + completeness) / 3).round();
  }

  List<String> _extractStrengths(Map<String, dynamic> feedback) {
    final strengths = <String>[];
    final accuracy = feedback['accuracyScore'] ?? 0;
    final fluency = feedback['fluencyScore'] ?? 0;

    if (accuracy > 85) strengths.add('Clear pronunciation');
    if (fluency > 4) strengths.add('Good speaking pace');
    if ((feedback['completenessScore'] ?? 0) > 85)
      strengths.add('Complete delivery');

    return strengths.isEmpty ? ['Keep practicing!'] : strengths;
  }

  List<String> _extractImprovements(Map<String, dynamic> feedback) {
    final improvements = <String>[];
    final accuracy = feedback['accuracyScore'] ?? 0;
    final fluency = feedback['fluencyScore'] ?? 0;

    if (accuracy < 70) improvements.add('Focus on clearer articulation');
    if (fluency < 3.5) improvements.add('Work on speaking more smoothly');

    // Check for specific problem words
    final words = feedback['words'] as List<dynamic>?;
    if (words != null) {
      for (var word in words) {
        if ((word['accuracyScore'] ?? 100) < 70) {
          improvements.add('Practice the word "${word['word']}"');
          if (improvements.length >= 3) break;
        }
      }
    }

    return improvements.isEmpty
        ? ['Great job! Keep up the excellent work!']
        : improvements.take(3).toList();
  }

  void _nextPhrase() {
    if (_currentPhraseIndex < _phrases.length - 1) {
      setState(() {
        _currentPhraseIndex++;
        _hasRecorded = false;
        _currentFeedback = null;
        _recordedFilePath = null;
      });
    } else {
      _completeSession();
    }
  }

  Future<void> _completeSession() async {
    final avgScore = _phrasesCompleted > 0
        ? (_sessionScore / _phrasesCompleted).round()
        : 0;

    // ✅ STEP 6: Save session to backend
    try {
      final duration = DateTime.now().difference(_sessionStartTime!).inSeconds;

      await http.post(
        Uri.parse('$_backendUrl/save-pronunciation-session'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': _user?.uid,
          'sessionData': {
            'startedAt': _sessionStartTime!.toIso8601String(),
            'difficulty': 'beginner',
            'phrasesAttempted': _phrases.length,
            'phrasesCompleted': _phrasesCompleted,
            'averageAccuracy': avgScore.toDouble(),
            'averageFluency': avgScore.toDouble(),
            'results': _sessionResults,
            'duration': duration,
          },
        }),
      );

      _logger.i('Session saved to backend');
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
              'Phrases Completed',
              '$_phrasesCompleted/${_phrases.length}',
            ),
            _buildStatRow('Average Score', '$avgScore%'),
            _buildStatRow('Session Time', _getSessionDuration()),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Return to Practice Center
            },
            child: const Text('Done'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _resetSession();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
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
      _currentPhraseIndex = 0;
      _hasRecorded = false;
      _currentFeedback = null;
      _recordedFilePath = null;
      _sessionScore = 0;
      _phrasesCompleted = 0;
      _sessionResults.clear();
      _sessionStartTime = DateTime.now();
    });
    _loadPhrases();
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
    if (_isLoading && _phrases.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Pronunciation Practice'),
          backgroundColor: Colors.blue,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading practice phrases...'),
            ],
          ),
        ),
      );
    }

    final currentPhrase = _phrases[_currentPhraseIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text('🎤 Pronunciation Practice'),
        backgroundColor: Colors.blue,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '${_currentPhraseIndex + 1}/${_phrases.length}',
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
              value: (_currentPhraseIndex + 1) / _phrases.length,
              backgroundColor: Colors.grey[300],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
              minHeight: 8,
            ),
            const SizedBox(height: 24),

            // Phrase card
            _buildPhraseCard(currentPhrase),
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

  Widget _buildPhraseCard(Map<String, dynamic> phrase) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.white],
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
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    phrase['category'] ?? 'General',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getDifficultyColor(phrase['difficulty'] ?? 'Easy'),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    phrase['difficulty'] ?? 'Easy',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Say this phrase:',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              phrase['text'],
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                height: 1.4,
              ),
            ),
            if (phrase['tips'] != null) ...[
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
                    Icon(
                      Icons.lightbulb,
                      color: Colors.amber.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        phrase['tips'],
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
          ],
        ),
      ),
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return Colors.green;
      case 'medium':
      case 'intermediate':
        return Colors.orange;
      case 'hard':
      case 'advanced':
        return Colors.red;
      default:
        return Colors.grey;
    }
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
                            backgroundColor: Colors.blue,
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
                  const Icon(Icons.mic, size: 48, color: Colors.blue),
                  const SizedBox(height: 16),
                  const Text(
                    'Tap to record your pronunciation',
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
                      backgroundColor: Colors.blue,
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
              '✅ AI Feedback',
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
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Score breakdown
            _buildScoreRow('Pronunciation', feedback['pronunciationScore']),
            _buildScoreRow('Fluency', feedback['fluencyScore']),
            _buildScoreRow('Clarity', feedback['clarityScore']),
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
                onPressed: _nextPhrase,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  _currentPhraseIndex < _phrases.length - 1
                      ? 'Next Phrase →'
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
    if (score >= 90) return 'Excellent!';
    if (score >= 75) return 'Good job!';
    if (score >= 60) return 'Keep practicing!';
    return 'Need more work';
  }
}
