import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../notification_service.dart';
import '../../services/unified_progress_service.dart';

class ReviewSpeakingSubmissionPage extends StatefulWidget {
  final String submissionId;

  const ReviewSpeakingSubmissionPage({
    Key? key,
    required this.submissionId,
    String? assessmentId,
  }) : super(key: key);

  @override
  _ReviewSpeakingSubmissionPageState createState() =>
      _ReviewSpeakingSubmissionPageState();
}

class _ReviewSpeakingSubmissionPageState
    extends State<ReviewSpeakingSubmissionPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Logger _logger = Logger();
  final UnifiedProgressService _progressService = UnifiedProgressService();

  bool _loading = true;
  String _error = '';
  Map<String, dynamic>? _submission;
  Map<String, dynamic>? _assessment;

  // AI Evaluation State
  Map<String, dynamic>? _aiFeedback;
  bool _isLoadingAiFeedback = false;

  // Feedback State
  final TextEditingController _trainerFeedbackController =
      TextEditingController();
  double? _currentScore;
  bool _isSaving = false;

  // Audio Player State
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupAudioPlayerListeners();
  }

  Color _getScoreColor(double score) {
    if (score >= 90) return Colors.green;
    if (score >= 75) return Colors.blue;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  String _getPerformanceLabel(double score) {
    if (score >= 95) return 'Excellent';
    if (score >= 85) return 'Very Good';
    if (score >= 75) return 'Good';
    if (score >= 65) return 'Fair';
    if (score >= 50) return 'Needs Work';
    return 'Poor';
  }

  void _setupAudioPlayerListeners() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });
    _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) {
        setState(() {
          _duration = newDuration;
        });
      }
    });
    _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) {
        setState(() {
          _position = newPosition;
        });
      }
    });
  }

  Future<void> _loadData() async {
    if (_auth.currentUser == null) {
      setState(() {
        _error = 'You must be logged in.';
        _loading = false;
      });
      return;
    }

    try {
      final submissionDoc = await _firestore
          .collection('studentSubmissions')
          .doc(widget.submissionId)
          .get();

      if (!submissionDoc.exists) {
        throw Exception('Submission not found.');
      }

      final submissionData = submissionDoc.data() as Map<String, dynamic>;

      final assessmentDoc = await _firestore
          .collection('trainerAssessments')
          .doc(submissionData['assessmentId'])
          .get();

      if (!assessmentDoc.exists) {
        throw Exception('Associated assessment not found.');
      }
      final assessmentData = assessmentDoc.data() as Map<String, dynamic>;

      if (assessmentData['trainerId'] != _auth.currentUser!.uid) {
        throw Exception('You are not authorized to view this submission.');
      }

      if (mounted) {
        setState(() {
          _submission = submissionData;
          _assessment = assessmentData;
          _aiFeedback = submissionData['aiFeedback'];
          _trainerFeedbackController.text =
              submissionData['trainerFeedback'] ?? '';
          _currentScore = (submissionData['score'] as num?)?.toDouble();
          _loading = false;
        });
      }
    } catch (e) {
      _logger.e('Error loading submission data: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load data: ${e.toString()}';
          _loading = false;
        });
      }
    }
  }

  Future<void> _getAiEvaluation() async {
    if (_submission?['audioUrl'] == null || _assessment?['questions'] == null) {
      _showErrorSnackBar('Missing audio URL or assessment questions');
      return;
    }

    final questions = _assessment!['questions'] as List;
    if (questions.isEmpty) {
      _showErrorSnackBar('No questions found in assessment');
      return;
    }

    final firstQuestion = questions.first;
    final promptText =
        firstQuestion['promptText'] ?? firstQuestion['text'] ?? '';

    if (promptText.isEmpty) {
      _showErrorSnackBar('No prompt text found for evaluation');
      return;
    }

    setState(() {
      _isLoadingAiFeedback = true;
      _error = '';
    });

    try {
      _logger.i('Starting AI evaluation for submission ${widget.submissionId}');

      final baseUrl = await _progressService.getApiBaseUrl();
      final response = await http.post(
        Uri.parse('$baseUrl/evaluate-speaking-contextual'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'TalkReady-Mobile/1.0',
        },
        body: json.encode({
          'audioUrl': _submission!['audioUrl'],
          'promptText': promptText,
          'evaluationContext':
              firstQuestion['title'] ?? 'Customer service scenario',
        }),
      );

      _logger.i('AI evaluation response status: ${response.statusCode}');

      if (!mounted) return;

      if (response.statusCode == 200) {
        final feedbackResult = json.decode(response.body);

        // Save to Firestore immediately so students can see it
        await _firestore
            .collection('studentSubmissions')
            .doc(widget.submissionId)
            .update({
              'aiFeedback': feedbackResult,
              'aiFeedbackGeneratedAt': FieldValue.serverTimestamp(),
              'hasAiFeedback':
                  true, // Flag to easily check if AI feedback exists
            });

        setState(() {
          _aiFeedback = feedbackResult;
          _isLoadingAiFeedback = false;
        });

        _logger.i('AI evaluation completed and saved to database');

        _showSuccessSnackBar('AI evaluation completed and saved!');
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? 'AI evaluation failed');
      }
    } catch (e) {
      _logger.e('AI evaluation error: $e');
      if (mounted) {
        setState(() {
          _error = 'AI Evaluation Error: ${e.toString()}';
          _isLoadingAiFeedback = false;
        });
        _showErrorSnackBar('AI evaluation failed: ${e.toString()}');
      }
    }
  }

  Future<void> _publishFeedback() async {
    if (_assessment == null) return;

    // NEW: Validate that score has been set
    if (_currentScore == null) {
      _showErrorSnackBar("Please set a score before publishing feedback.");
      return;
    }

    final score = _currentScore!;

    // Validate score is within 0-100 range
    if (score > 100 || score < 0) {
      _showErrorSnackBar("Score must be between 0 and 100.");
      return;
    }

    setState(() => _isSaving = true);

    try {
      final feedbackData = {
        'aiFeedback': _aiFeedback,
        'trainerFeedback': _trainerFeedbackController.text,
        'score': score,
        'totalPossiblePoints': 100, // Fixed to 100 for percentage-based scoring
        'isReviewed': true,
        'reviewedAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('studentSubmissions')
          .doc(widget.submissionId)
          .update(feedbackData);

      // Get trainer's name from Firestore
      String trainerName = 'Your trainer';
      try {
        final trainerDoc = await _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .get();

        if (trainerDoc.exists) {
          final trainerData = trainerDoc.data()!;
          trainerName =
              '${trainerData['firstName'] ?? ''} ${trainerData['lastName'] ?? ''}'
                  .trim();
          if (trainerName.isEmpty) {
            trainerName = trainerData['displayName'] ?? 'Your trainer';
          }
        }
      } catch (e) {
        _logger.e('Could not fetch trainer name: $e');
      }

      // Get class name for notification
      String? className;
      try {
        if (_assessment!['classId'] != null) {
          final classDoc = await _firestore
              .collection('trainerClass')
              .doc(_assessment!['classId'])
              .get();
          className = classDoc.data()?['className'] as String?;
        }
      } catch (e) {
        _logger.e('Could not fetch class name: $e');
      }

      // Notify the student about the feedback
      try {
        final studentId = _submission!['studentId'];
        await NotificationService.notifyUser(
          userId: studentId,
          message:
              '$trainerName reviewed your speaking assessment: ${_assessment!['title']}',
          className: className,
          link: '/student/class/${_assessment!['classId']}',
        );
      } catch (e) {
        _logger.e('Failed to send notification to student: $e');
        // Don't throw - notification failure shouldn't stop feedback publishing
      }

      if (mounted) {
        _showSuccessSnackBar('Feedback published and student notified!');
        Navigator.pop(context);
      }
    } catch (e) {
      _logger.e("Failed to publish feedback: $e");
      _showErrorSnackBar('Failed to publish feedback: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  Future<void> _togglePlayAudio(String url) async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play(UrlSource(url));
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _trainerFeedbackController.dispose();

    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  Widget _buildQuickScoreButton(String label, double score) {
    final isSelected =
        _currentScore != null && (_currentScore! - score).abs() < 1;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: OutlinedButton(
          onPressed: () {
            setState(() {
              _currentScore = score;
            });
          },
          style: OutlinedButton.styleFrom(
            backgroundColor: isSelected
                ? _getScoreColor(score).withOpacity(0.1)
                : Colors.white,
            side: BorderSide(
              color: isSelected ? _getScoreColor(score) : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
            padding: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? _getScoreColor(score) : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${score.round()}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? _getScoreColor(score) : Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAiFeedbackDisplay() {
    if (_aiFeedback == null) return const SizedBox.shrink();

    final audioQuality = _aiFeedback!['audioQuality'] as Map<String, dynamic>?;
    final contextualAnalysis =
        _aiFeedback!['contextualAnalysis'] as Map<String, dynamic>?;
    final overallScore = _aiFeedback!['overallScore'] as num? ?? 0;
    final transcript =
        _aiFeedback!['transcript'] as String? ?? 'No transcript available';

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.indigo.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI Contextual Evaluation',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4338CA),
            ),
          ),
          const SizedBox(height: 16),

          // Transcript
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'What the student said:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '"$transcript"',
                  style: const TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Overall Score
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.indigo.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border(
                left: BorderSide(color: Colors.indigo.shade500, width: 4),
              ),
            ),
            child: Center(
              child: Column(
                children: [
                  Text(
                    '${overallScore.round()}%',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4338CA),
                    ),
                  ),
                  const Text(
                    'Overall Score',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF4338CA),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Speech Quality Analysis
          if (audioQuality != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Speech Quality Analysis:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E40AF),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildScoreCard(
                        'Clarity',
                        audioQuality['speechClarity'] ?? 0,
                      ),
                      _buildScoreCard(
                        'Fluency',
                        audioQuality['speechFluency'] ?? 0,
                      ),
                      _buildScoreCard(
                        'Expression',
                        audioQuality['prosody'] ?? 0,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Response Quality Analysis
          if (contextualAnalysis?['scores'] != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Response Quality Analysis:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF059669),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...(contextualAnalysis!['scores'] as Map<String, dynamic>)
                      .entries
                      .map(
                        (entry) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  _formatCriterionName(entry.key),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Text(
                                '${(entry.value as num).round()}%',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF059669),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Assessment
          if (contextualAnalysis?['overallAssessment'] != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.yellow.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Assessment:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFD97706),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    contextualAnalysis!['overallAssessment'],
                    style: const TextStyle(color: Colors.black87),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Strengths and Improvements
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Strengths
              if (contextualAnalysis?['strengths'] != null)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '✅ Strengths:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF059669),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...(contextualAnalysis!['strengths'] as List)
                            .map(
                              (strength) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '• ',
                                      style: TextStyle(
                                        color: Color(0xFF059669),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        strength,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ],
                    ),
                  ),
                ),

              const SizedBox(width: 8),

              // Improvement Areas
              if (contextualAnalysis?['improvementAreas'] != null)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '🎯 Areas for Improvement:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFEA580C),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...(contextualAnalysis!['improvementAreas'] as List)
                            .map(
                              (area) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '• ',
                                      style: TextStyle(
                                        color: Color(0xFFEA580C),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        area,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ],
                    ),
                  ),
                ),
            ],
          ),

          // Suggestion
          if (contextualAnalysis?['suggestion'] != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '💡 Suggestion:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF7C3AED),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    contextualAnalysis!['suggestion'],
                    style: const TextStyle(color: Colors.black87),
                  ),
                ],
              ),
            ),
          ],
          // Alternative Responses
          if (contextualAnalysis?['appropriateAlternatives'] != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '💬 Alternative Responses:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E40AF),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...(contextualAnalysis!['appropriateAlternatives'] as List)
                      .map(
                        (alternative) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border(
                              left: BorderSide(
                                color: Colors.blue.shade300,
                                width: 4,
                              ),
                            ),
                          ),
                          child: Text(
                            '"$alternative"',
                            style: const TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.black87,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScoreCard(String label, num score) {
    final normalizedScore = (score).round().clamp(0, 100);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Text(
            '$normalizedScore%',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E40AF),
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  String _formatCriterionName(String key) {
    // Convert camelCase to Title Case
    return key
        .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FDFA),
      appBar: AppBar(
        title: const Text(
          'Speaking Assessment Review',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F766E),
        elevation: 0,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, Color(0xFFF0FDFA)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF14B8A6).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF0F766E)),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildPublishButton(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF0FDFA), Color(0xFFCCFDF7)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF14B8A6).withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF14B8A6)),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Loading submission...',
                style: TextStyle(
                  color: Color(0xFF0F766E),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_error.isNotEmpty && _aiFeedback == null) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFEF2F2), Color(0xFFFEE2E2)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
                const SizedBox(height: 16),
                Text(
                  _error,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_submission == null || _assessment == null) {
      return const Center(child: Text("Submission data could not be loaded."));
    }

    final studentName = _submission!['studentName'] ?? 'Unknown Student';
    final speakingPrompt = (_assessment!['questions'] as List?)?.first;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF0FDFA), Color(0xFFCCFDF7)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF14B8A6).withOpacity(0.1),
                    const Color(0xFF0D9488).withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF14B8A6).withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14B8A6).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.person_outline,
                      color: Color(0xFF0F766E),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Reviewing submission from:',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          studentName,
                          style: const TextStyle(
                            fontSize: 18,
                            color: Color(0xFF0F766E),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 700) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildSubmissionCard(speakingPrompt)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildFeedbackCard()),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      _buildSubmissionCard(speakingPrompt),
                      const SizedBox(height: 16),
                      _buildFeedbackCard(),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmissionCard(Map<String, dynamic>? prompt) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF14B8A6).withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF14B8A6), Color(0xFF0D9488)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.assignment,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "Student's Submission",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // FIRST: Speaking Prompt Title and Description (the actual scenario/question)
                  Row(
                    children: [
                      Icon(
                        Icons.quiz_outlined,
                        color: const Color(0xFF0F766E),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        prompt?['title'] ?? 'Speaking Prompt',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (prompt?['promptText'] != null ||
                      prompt?['text'] != null) ...[
                    Text(
                      prompt!['promptText'] ?? prompt['text'] ?? '',
                      style: const TextStyle(
                        color: Color(0xFF374151),
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // SECOND: Reference Text (what student should say)
                  if (prompt?['referenceText'] != null &&
                      prompt!['referenceText'].toString().isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.purple.withOpacity(0.1),
                            Colors.purple.withOpacity(0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.purple.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                color: Colors.purple.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                "What the student should say:",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.purple,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            prompt['referenceText'],
                            style: const TextStyle(
                              color: Color(0xFF374151),
                              fontSize: 15,
                              height: 1.5,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Student's Recording
                  Row(
                    children: [
                      Icon(Icons.mic, color: const Color(0xFF0F766E), size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        "Student's Recording:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildAudioPlayer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioPlayer() {
    final audioUrl = _submission?['audioUrl'];
    if (audioUrl == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange.shade600,
              size: 24,
            ),
            const SizedBox(width: 12),
            const Text(
              'No audio recording found.',
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF14B8A6).withOpacity(0.05),
            const Color(0xFF0D9488).withOpacity(0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF14B8A6).withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF14B8A6), Color(0xFF0D9488)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF14B8A6).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 28,
                  ),
                  onPressed: () => _togglePlayAudio(audioUrl),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(_position),
                          style: const TextStyle(
                            color: Color(0xFF0F766E),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          _formatDuration(_duration),
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: const Color(0xFF14B8A6),
                        inactiveTrackColor: const Color(
                          0xFF14B8A6,
                        ).withOpacity(0.2),
                        thumbColor: const Color(0xFF0D9488),
                        overlayColor: const Color(0xFF14B8A6).withOpacity(0.2),
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 8,
                        ),
                      ),
                      child: Slider(
                        value: _position.inSeconds.toDouble(),
                        max: _duration.inSeconds.toDouble(),
                        onChanged: (value) async {
                          await _audioPlayer.seek(
                            Duration(seconds: value.toInt()),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF14B8A6).withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF14B8A6), Color(0xFF0D9488)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.feedback_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "Feedback Hub",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // AI Evaluation Button
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.deepPurple.withOpacity(0.1),
                          Colors.deepPurple.withOpacity(0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.deepPurple.withOpacity(0.2),
                        width: 1.5,
                      ),
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _isLoadingAiFeedback || _aiFeedback != null
                          ? null
                          : _getAiEvaluation,
                      icon: _isLoadingAiFeedback
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : _aiFeedback != null
                          ? const Icon(Icons.check, size: 20)
                          : const FaIcon(FontAwesomeIcons.robot, size: 20),
                      label: Text(
                        _isLoadingAiFeedback
                            ? 'Getting AI Evaluation...'
                            : _aiFeedback != null
                            ? 'AI Evaluation Complete'
                            : 'Get AI Evaluation',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _aiFeedback != null
                            ? Colors.green
                            : Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),

                  // Loading message
                  if (_isLoadingAiFeedback) ...[
                    const SizedBox(height: 12),
                    const Center(
                      child: Text(
                        'AI is analyzing the audio...',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],

                  // AI Feedback Display
                  _buildAiFeedbackDisplay(),

                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF14B8A6).withOpacity(0.05),
                          const Color(0xFF0D9488).withOpacity(0.02),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF14B8A6).withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.edit_note,
                              color: const Color(0xFF0F766E),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Your Manual Feedback',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFF0F766E),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _trainerFeedbackController,
                          maxLines: 5,
                          decoration: InputDecoration(
                            hintText: 'Provide constructive feedback here...',
                            hintStyle: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 15,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: const Color(0xFF14B8A6).withOpacity(0.3),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: const Color(0xFF14B8A6).withOpacity(0.3),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF14B8A6),
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.star_outline,
                                  color: const Color(0xFF0F766E),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Overall Score',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Color(0xFF0F766E),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Score Display
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: _currentScore == null
                                      ? Colors.grey.shade200
                                      : _getScoreColor(
                                          _currentScore!,
                                        ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: _currentScore == null
                                        ? Colors.grey.shade400
                                        : _getScoreColor(_currentScore!),
                                    width: 2,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      _currentScore == null
                                          ? '--'
                                          : '${_currentScore!.round()}',
                                      style: TextStyle(
                                        fontSize: 48,
                                        fontWeight: FontWeight.bold,
                                        color: _currentScore == null
                                            ? Colors.grey.shade600
                                            : _getScoreColor(_currentScore!),
                                      ),
                                    ),
                                    Text(
                                      'out of 100',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    if (_currentScore != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        _getPerformanceLabel(_currentScore!),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: _getScoreColor(_currentScore!),
                                        ),
                                      ),
                                    ] else ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Move slider to set score',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic,
                                          color: Colors.orange.shade700,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Slider
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: _currentScore == null
                                    ? const Color(0xFF14B8A6)
                                    : _getScoreColor(_currentScore!),
                                inactiveTrackColor: Colors.grey[300],
                                thumbColor: _currentScore == null
                                    ? const Color(0xFF14B8A6)
                                    : _getScoreColor(_currentScore!),
                                overlayColor:
                                    (_currentScore == null
                                            ? const Color(0xFF14B8A6)
                                            : _getScoreColor(_currentScore!))
                                        .withOpacity(0.2),
                                trackHeight: 8,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 12,
                                ),
                              ),
                              child: Slider(
                                value: _currentScore ?? 50.0,
                                min: 0,
                                max: 100,
                                divisions: 100,
                                label: _currentScore == null
                                    ? 'Set score'
                                    : '${_currentScore!.round()}',
                                onChanged: (value) {
                                  setState(() {
                                    _currentScore = value;
                                  });
                                },
                              ),
                            ),

                            // Quick Score Buttons
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildQuickScoreButton('Poor', 50),
                                _buildQuickScoreButton('Fair', 65),
                                _buildQuickScoreButton('Good', 75),
                                _buildQuickScoreButton('Great', 85),
                                _buildQuickScoreButton('Excellent', 95),
                              ],
                            ),
                          ],
                        ),
                      ],
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

  Widget _buildPublishButton() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF10B981), Color(0xFF059669)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: _isSaving ? null : _publishFeedback,
          icon: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const FaIcon(FontAwesomeIcons.paperPlane, size: 18),
          label: Text(
            _isSaving ? 'Publishing...' : 'Publish Feedback',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
            shadowColor: Colors.transparent,
          ),
        ),
      ),
    );
  }
}
