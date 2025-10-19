// progress_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'package:talkready_mobile/custom_animated_bottom_bar.dart';
import 'package:talkready_mobile/pdf_generator_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;

import '../firebase_service.dart';
import 'homepage.dart';
import 'courses_page.dart';
import 'journal/journal_page.dart';
import 'profile.dart';
import 'package:talkready_mobile/MyEnrolledClasses.dart';
import 'package:share_plus/share_plus.dart';

// Assessment Review Page
class AssessmentReviewPage extends StatefulWidget {
  final String submissionId;
  final String? assessmentId;

  const AssessmentReviewPage({
    super.key,
    required this.submissionId,
    this.assessmentId,
  });

  @override
  State<AssessmentReviewPage> createState() => _AssessmentReviewPageState();
}

class _AssessmentReviewPageState extends State<AssessmentReviewPage> {
  final Logger _logger = Logger();
  final FirebaseService _firebaseService = FirebaseService();

  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _submissionDetails;
  Map<String, dynamic>? _assessmentDetails;


  Color _getScoreColor(double score) {
  if (score >= 90) return Colors.green;
  if (score >= 75) return Colors.blue;
  if (score >= 60) return Colors.orange;
  return Colors.red;
}

  @override
  void initState() {
    super.initState();
    _loadReviewData();
  }

  Future<void> _loadReviewData() async {
    try {
      setState(() => _isLoading = true);

      final submission = await _firebaseService.getStudentSubmissionDetails(
        widget.submissionId,
      );
      if (submission == null) {
        throw Exception('Submission not found');
      }

      final assessmentId = widget.assessmentId ?? submission['assessmentId'];
      final assessment = await _firebaseService.getAssessmentDetails(
        assessmentId,
      );

      // Enhanced class name resolution
      String? className = submission['className'];

      if (className == null || className == 'N/A' || className.isEmpty) {
        // Try to get class name from assessment
        if (assessment?['classId'] != null) {
          final classData = await _firebaseService.getClassDetails(
            assessment!['classId'],
          );
          className = classData?['className'] ?? classData?['name'];
        }
      }

      // Update submission data with resolved class name
      if (className != null && className.isNotEmpty) {
        submission['className'] = className;
      }

      setState(() {
        _submissionDetails = submission;
        _assessmentDetails = assessment;
        _isLoading = false;
      });
    } catch (e) {
      _logger.e('Error loading review data: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Review Assessment'),
          backgroundColor: const Color(0xFF0077B3),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Review Assessment'),
          backgroundColor: const Color(0xFF0077B3),
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $_error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadReviewData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_assessmentDetails?['title'] ?? 'Review Assessment'),
        backgroundColor: const Color(0xFF0077B3),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAssessmentHeader(),
            const SizedBox(height: 20),
            _buildScoreCard(),
            const SizedBox(height: 20),
            _buildQuestionsReview(),
          ],
        ),
      ),
    );
  }

  Widget _buildAssessmentHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _assessmentDetails?['title'] ?? 'Assessment',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_assessmentDetails?['description'] != null)
              Text(_assessmentDetails!['description']),
            const SizedBox(height: 12),
            _buildInfoRow(
              'Submitted:',
              _formatDateTime(_submissionDetails?['submittedAt']),
            ),
            _buildInfoRow('Class:', _submissionDetails?['className'] ?? 'N/A'),
            _buildInfoRow(
              'Type:',
              _submissionDetails?['assessmentType'] ?? 'Standard Quiz',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    // Clean up the value
    String displayValue = value;
    if (value == 'N/A' || value.isEmpty) {
      if (label == 'Class:') {
        displayValue = 'Class information unavailable';
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(child: Text(displayValue)),
        ],
      ),
    );
  }

  Widget _buildScoreCard() {
    final score = _submissionDetails?['score'] ?? 0;
    final totalPoints = _submissionDetails?['totalPossiblePoints'] ?? 100;
    final percentage = totalPoints > 0 ? (score / totalPoints * 100) : 0;

    Color scoreColor;
    String scoreLabel;

    if (percentage >= 90) {
      scoreColor = Colors.green;
      scoreLabel = 'Excellent';
    } else if (percentage >= 75) {
      scoreColor = Colors.blue;
      scoreLabel = 'Good';
    } else if (percentage >= 60) {
      scoreColor = Colors.orange;
      scoreLabel = 'Fair';
    } else {
      scoreColor = Colors.red;
      scoreLabel = 'Needs Improvement';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Your Score',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$score',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: scoreColor,
                  ),
                ),
                Text(
                  ' / $totalPoints',
                  style: const TextStyle(fontSize: 24, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${percentage.toStringAsFixed(1)}% - $scoreLabel',
              style: TextStyle(fontSize: 16, color: scoreColor),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
              minHeight: 8,
            ),
          ],
        ),
      ),
    );
  }
List<Widget> _buildSpeakingPrompts() {
  final questions = _assessmentDetails?['questions'] as List?;
  if (questions == null) return [];

  return questions.map<Widget>((question) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (question['title'] != null)
            Text(
              question['title'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          if (question['promptText'] != null || question['text'] != null)
            Text(question['promptText'] ?? question['text'] ?? ''),
        ],
      ),
    );
  }).toList();
}

  Widget _buildAIFeedbackSection() {
  final aiFeedback = _submissionDetails?['aiFeedback'] as Map<String, dynamic>?;

  if (aiFeedback == null) {
    return const SizedBox.shrink(); // Don't show anything if no AI feedback
  }

  final audioQuality = aiFeedback['audioQuality'] as Map<String, dynamic>?;
  final contextualAnalysis = aiFeedback['contextualAnalysis'] as Map<String, dynamic>?;
  final overallScore = aiFeedback['overallScore'] as num? ?? 0;
  final transcript = aiFeedback['transcript'] as String? ?? 'No transcript available';

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.purple.shade50, Colors.indigo.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.purple.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.psychology, color: Colors.purple.shade700),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'AI Performance Analysis',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6B21A8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Overall Score
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Overall AI Score',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${overallScore.round()}%',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _getScoreColor(overallScore.toDouble()),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

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
                    'What you said:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '"$transcript"',
                    style: const TextStyle(
                      fontStyle: FontStyle.italic,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            // Speech Quality Metrics
            if (audioQuality != null) ...[
              const SizedBox(height: 12),
              const Text(
                'Speech Quality:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMiniScoreCard(
                    'Clarity',
                    audioQuality['speechClarity'] ?? 0,
                  ),
                  _buildMiniScoreCard(
                    'Fluency',
                    audioQuality['speechFluency'] ?? 0,
                  ),
                  _buildMiniScoreCard(
                    'Expression',
                    audioQuality['prosody'] ?? 0,
                  ),
                ],
              ),
            ],

            // Strengths
            if (contextualAnalysis?['strengths'] != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green.shade700, size: 16),
                        const SizedBox(width: 4),
                        const Text(
                          'Strengths:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...(contextualAnalysis!['strengths'] as List).map(
                      (strength) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(fontSize: 12)),
                            Expanded(
                              child: Text(
                                strength,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Improvement Areas
            if (contextualAnalysis?['improvementAreas'] != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline, color: Colors.orange.shade700, size: 16),
                        const SizedBox(width: 4),
                        const Text(
                          'Areas for Improvement:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...(contextualAnalysis!['improvementAreas'] as List).map(
                      (area) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(fontSize: 12)),
                            Expanded(
                              child: Text(
                                area,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Suggestion
            if (contextualAnalysis?['suggestion'] != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.tips_and_updates, color: Colors.blue.shade700, size: 16),
                        const SizedBox(width: 4),
                        const Text(
                          'Suggestion:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      contextualAnalysis!['suggestion'],
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

Widget _buildMiniScoreCard(String label, num score) {
  final normalizedScore = (score).round().clamp(0, 100);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      children: [
        Text(
          '$normalizedScore%',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: _getScoreColor(normalizedScore.toDouble()),
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    ),
  );
}

  Widget _buildQuestionsReview() {
    if (_submissionDetails?['assessmentType'] == 'speaking_assessment') {
      return _buildSpeakingAssessmentReview();
    } else {
      return _buildStandardAssessmentReview();
    }
  }

Widget _buildSpeakingAssessmentReview() {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Speaking Assessment Details',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Show prompt/questions
          if (_assessmentDetails?['questions'] != null) ...[
            const Text(
              'Prompt:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._buildSpeakingPrompts(),
          ],

          const SizedBox(height: 16),

          // Audio submission info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.mic, color: Colors.blue),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Audio response submitted',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                if (_submissionDetails?['audioUrl'] != null)
                  IconButton(
                    icon: const Icon(Icons.play_arrow),
                    onPressed: () =>
                        _playAudio(_submissionDetails!['audioUrl']),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // AI Feedback Section - NEW
          _buildAIFeedbackSection(),

          const SizedBox(height: 16),

          // Trainer Feedback section
          _buildFeedbackSection(),
        ],
      ),
    ),
  );
}
  Widget _buildFeedbackSection() {
  final isReviewed = _submissionDetails?['isReviewed'] ?? false;

  if (!isReviewed) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: const Row(
        children: [
          Icon(Icons.access_time, color: Colors.orange),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Awaiting trainer review',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  final trainerFeedback = _submissionDetails?['trainerFeedback'];
  final hasFeedback = trainerFeedback != null && trainerFeedback.toString().trim().isNotEmpty;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Trainer Feedback',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: hasFeedback ? Colors.green.shade50 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hasFeedback ? Colors.green.shade200 : Colors.grey.shade300,
          ),
        ),
        child: hasFeedback
            ? Text(trainerFeedback)
            : const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'The trainer did not provide written feedback for this submission.',
                      style: TextStyle(
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    ],
  );
}
Widget _buildStandardAssessmentReview() {
  final questions = _assessmentDetails?['questions'] as List? ?? [];
  final answers = _submissionDetails?['answers'] as List? ?? [];

  // Calculate statistics
  int correctCount = 0;
  int incorrectCount = 0;
  for (var answer in answers) {
    if (answer['isCorrect'] == true) {
      correctCount++;
    } else {
      incorrectCount++;
    }
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Summary Statistics Card
      Card(
        elevation: 0,
        color: Colors.blue.shade50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.blue.shade200, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.quiz, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Quiz Summary',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryItem(
                    'Total Questions',
                    '${questions.length}',
                    Icons.format_list_numbered,
                    Colors.blue,
                  ),
                  _buildSummaryItem(
                    'Correct',
                    '$correctCount',
                    Icons.check_circle,
                    Colors.green,
                  ),
                  _buildSummaryItem(
                    'Incorrect',
                    '$incorrectCount',
                    Icons.cancel,
                    Colors.red,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),

      const SizedBox(height: 20),

      const Text(
        'Detailed Question Review',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 16),

      ...questions.asMap().entries.map((entry) {
        final index = entry.key;
        final question = entry.value;
        final answer = answers.isNotEmpty && index < answers.length
            ? answers[index]
            : null;
        return _buildQuestionCard(question, answer, index + 1);
      }).toList(),
    ],
  );
}

Widget _buildSummaryItem(String label, String value, IconData icon, Color color) {
  return Column(
    children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      const SizedBox(height: 8),
      Text(
        value,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
      Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade600,
        ),
      ),
    ],
  );
}

Widget _buildQuestionCard(
  Map<String, dynamic> question,
  Map<String, dynamic>? answer,
  int questionNumber,
) {
  final isCorrect = answer?['isCorrect'] ?? false;
  final pointsEarned = answer?['pointsEarned'] ?? 0;
  final totalPoints = question['points'] ?? 0;

  return Card(
    margin: const EdgeInsets.only(bottom: 16),
    elevation: 2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(
        color: isCorrect ? Colors.green.shade200 : Colors.red.shade200,
        width: 1.5,
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question header with result indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isCorrect
                            ? Colors.green.shade100
                            : Colors.red.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isCorrect ? Icons.check : Icons.close,
                        color: isCorrect
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Question $questionNumber',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isCorrect
                      ? Colors.green.shade100
                      : Colors.red.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$pointsEarned / $totalPoints pts',
                  style: TextStyle(
                    color: isCorrect
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Question type indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              question['type'] == 'multiple-choice'
                  ? 'Multiple Choice'
                  : 'Fill in the Blank',
              style: TextStyle(
                fontSize: 11,
                color: Colors.blue.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Question text
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              question['text'] ?? 'Question text not available',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Answer section
          if (question['type'] == 'multiple-choice')
            _buildMultipleChoiceReview(question, answer)
          else if (question['type'] == 'fill-in-the-blank')
            _buildFillInBlankReview(question, answer),

          // Explanation if available
          if (question['explanation'] != null && question['explanation'].toString().isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline,
                    color: Colors.amber.shade700,
                    size: 20
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Explanation:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          question['explanation'],
                          style: TextStyle(
                            color: Colors.amber.shade900,
                            fontSize: 13,
                          ),
                        ),
                      ],
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

  Widget _buildMultipleChoiceReview(
    Map<String, dynamic> question,
    Map<String, dynamic>? answer,
  ) {
    final options = question['options'] as List? ?? [];
    final selectedOptionId = answer?['selectedOptionId'];
    final correctOptions = question['correctOptionIds'] as List? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Options:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...options.map<Widget>((option) {
          final optionId = option['optionId'];
          final isSelected = selectedOptionId == optionId;
          final isCorrect = correctOptions.contains(optionId);

          Color backgroundColor;
          Color textColor;
          IconData? icon;

          if (isSelected && isCorrect) {
            backgroundColor = Colors.green.shade100;
            textColor = Colors.green.shade700;
            icon = Icons.check_circle;
          } else if (isSelected && !isCorrect) {
            backgroundColor = Colors.red.shade100;
            textColor = Colors.red.shade700;
            icon = Icons.cancel;
          } else if (!isSelected && isCorrect) {
            backgroundColor = Colors.green.shade50;
            textColor = Colors.green.shade600;
            icon = Icons.check_circle_outline;
          } else {
            backgroundColor = Colors.grey.shade50;
            textColor = Colors.grey.shade700;
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected || isCorrect
                    ? (isCorrect ? Colors.green.shade300 : Colors.red.shade300)
                    : Colors.grey.shade300,
              ),
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: textColor, size: 20),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    option['text'] ?? '',
                    style: TextStyle(color: textColor),
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: textColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Your Answer',
                      style: TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildFillInBlankReview(
    Map<String, dynamic> question,
    Map<String, dynamic>? answer,
  ) {
    final studentAnswer = answer?['studentAnswer'] ?? '';
    final correctAnswers = question['correctAnswers'] as List? ?? [];
    final isCorrect = answer?['isCorrect'] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Answer:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isCorrect ? Colors.green.shade100 : Colors.red.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isCorrect ? Colors.green.shade300 : Colors.red.shade300,
            ),
          ),
          child: Text(
            studentAnswer.isEmpty ? 'No answer provided' : studentAnswer,
            style: TextStyle(
              color: isCorrect ? Colors.green.shade700 : Colors.red.shade700,
            ),
          ),
        ),

        if (!isCorrect && correctAnswers.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            'Correct Answer(s):',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Text(
              correctAnswers.join(', '),
              style: TextStyle(color: Colors.green.shade700),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _playAudio(String audioUrl) async {
    try {
      final uri = Uri.parse(audioUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not play audio: $e')));
    }
  }

  String _formatDateTime(dynamic timestamp) {
    if (timestamp == null) return 'N/A';

    try {
      DateTime date;
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is DateTime) {
        date = timestamp;
      } else {
        return 'N/A';
      }

      return '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'N/A';
    }
  }
}

// Main Progress Tracker Page
class ProgressTrackerPage extends StatefulWidget {
  const ProgressTrackerPage({super.key});

  @override
  State<ProgressTrackerPage> createState() => _ProgressTrackerPageState();
}

class _ProgressTrackerPageState extends State<ProgressTrackerPage>
    with TickerProviderStateMixin {
  final Logger _logger = Logger();
  final FirebaseService _firebaseService = FirebaseService();
  User? _currentUser;

  bool _isLoading = true;
  String? _error;
  Map<String, List<Map<String, dynamic>>> _allUserAttempts = {};
  List<Map<String, dynamic>> _assessmentSubmissions = [];
  bool _isLoadingAssessments = true;
  final PdfGeneratorService _pdfService = PdfGeneratorService();

  Map<String, dynamic> _overallStats = {
    'attemptedLessonsCount': 0,
    'totalAttempts': 0,
    'averageScore': "N/A",
  };

  Map<String, List<MapEntry<String, List<Map<String, dynamic>>>>>
  _groupLessonsByLevel() {
    final Map<String, List<MapEntry<String, List<Map<String, dynamic>>>>>
    levelGroups = {'Beginner': [], 'Intermediate': [], 'Advanced': []};

    _allUserAttempts.entries.forEach((entry) {
      final lessonId = entry.key;

      // Find which module this lesson belongs to
      String? lessonLevel;
      for (var moduleEntry in COURSE_STRUCTURE_MOBILE.entries) {
        final lessons = moduleEntry.value['lessons'] as List<dynamic>?;
        if (lessons != null) {
          for (var lesson in lessons) {
            if (lesson is Map && lesson['firestoreId'] == lessonId) {
              lessonLevel = moduleEntry.value['level'] as String?;
              break;
            }
          }
        }
        if (lessonLevel != null) break;
      }

      lessonLevel ??= 'Beginner'; // Default fallback
      levelGroups[lessonLevel]?.add(entry);
    });

    return levelGroups;
  }

  // AI Advisor state
  String? _aiAdvisorFeedback;
  bool _loadingAdvisor = false;
  String? _advisorError;

  final Map<String, bool> _expandedLesson = {};
  int _selectedIndex = 4;

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _currentUser = FirebaseAuth.instance.currentUser;
    if (_currentUser != null) {
      _fetchAllReportData();
    } else {
      setState(() {
        _isLoading = false;
        _isLoadingAssessments = false;
        _error = "Please log in to view your progress.";
      });
    }
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllReportData() async {
    if (_currentUser == null) return;
    setState(() {
      _isLoading = true;
      _isLoadingAssessments = true;
      _error = null;
    });

    try {
      final attemptsFuture = _firebaseService.getAllUserLessonAttempts();
      final assessmentSubmissionsFuture = _firebaseService
          .getStudentSubmissionsWithDetails(_currentUser!.uid);

      final results = await Future.wait([
        attemptsFuture,
        assessmentSubmissionsFuture,
      ]);

      final attempts = results[0] as Map<String, List<Map<String, dynamic>>>;
      final assessmentSubmissions = results[1] as List<Map<String, dynamic>>;

      if (mounted) {
        setState(() {
          _allUserAttempts = attempts;
          _assessmentSubmissions = assessmentSubmissions;
          _calculateOverallStats();
          _isLoading = false;
          _isLoadingAssessments = false;
        });

        _fadeController.forward();
        _generateAIAdvisorFeedback();
      }
    } catch (e) {
      _logger.e("Error fetching all report data: $e");
      if (mounted) {
        setState(() {
          _error = "Failed to load progress data.";
          _isLoading = false;
          _isLoadingAssessments = false;
        });
      }
    }
  }

  void _calculateOverallStats() {
    if (_allUserAttempts.isEmpty) {
      _overallStats = {
        'attemptedLessonsCount': 0,
        'totalAttempts': 0,
        'averageScore': "N/A",
      };
      return;
    }

    int totalAttempts = 0;
    double totalScoreSum = 0;
    int scoredAttemptsCount = 0;
    Set<String> attemptedLessonIds = {};

    _allUserAttempts.forEach((lessonId, attempts) {
      if (attempts.isNotEmpty) {
        attemptedLessonIds.add(lessonId);
        totalAttempts += attempts.length;
        for (var attempt in attempts) {
          final score = attempt['score'];
          if (score != null && score is num) {
            totalScoreSum += score;
            scoredAttemptsCount++;
          }
        }
      }
    });

    _overallStats = {
      'attemptedLessonsCount': attemptedLessonIds.length,
      'totalAttempts': totalAttempts,
      'averageScore': scoredAttemptsCount > 0
          ? (totalScoreSum / scoredAttemptsCount).toStringAsFixed(1)
          : "N/A",
    };
  }

  Future<void> _generateAIAdvisorFeedback() async {
    if (_overallStats['attemptedLessonsCount'] == 0) return;

    setState(() {
      _loadingAdvisor = true;
      _advisorError = null;
    });

    try {
      // Simulate AI advisor feedback generation
      await Future.delayed(const Duration(seconds: 2));

      final avgScore = _overallStats['averageScore'];
      final lessonsCount = _overallStats['attemptedLessonsCount'];
      final attemptsCount = _overallStats['totalAttempts'];

      String feedback = _generateMockFeedback(
        avgScore,
        lessonsCount,
        attemptsCount,
      );

      setState(() {
        _aiAdvisorFeedback = feedback;
        _loadingAdvisor = false;
      });
    } catch (e) {
      setState(() {
        _advisorError = 'Failed to generate AI advice';
        _loadingAdvisor = false;
      });
    }
  }

  String _generateMockFeedback(
    dynamic avgScore,
    int lessonsCount,
    int attemptsCount,
  ) {
    if (avgScore == "N/A")
      return "Complete some lessons to get personalized feedback!";

    final score = double.tryParse(avgScore.toString()) ?? 0;
    List<String> feedback = [];

    if (score >= 85) {
      feedback.add("🌟 Excellent performance! You're mastering the material.");
    } else if (score >= 70) {
      feedback.add("👍 Good progress! Keep practicing to reach excellence.");
    } else {
      feedback.add(
        "💪 Keep working hard! Focus on understanding core concepts.",
      );
    }

    if (lessonsCount < 3) {
      feedback.add("📚 Try exploring more lessons to broaden your knowledge.");
    }

    if (attemptsCount > lessonsCount * 2) {
      feedback.add(
        "🎯 Great dedication! Your practice frequency is impressive.",
      );
    }

    feedback.add("🚀 Continue your learning journey - you're doing great!");

    return feedback.join('\n\n');
  }

  Widget _buildAppBarWithLogo() {
    return Container(
      padding: const EdgeInsets.only(top: 40, left: 16, right: 16, bottom: 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0077B3), Color(0xFF005f8c)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Image.asset('images/TR Logo.png', height: 40, width: 40),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'My Progress Reports',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchAllReportData,
          ),
        ],
      ),
    );
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);

    Widget nextPage;
    switch (index) {
      case 0:
        nextPage = const HomePage();
        break;
      case 1:
        nextPage = const CoursesPage();
        break;
      case 2:
        nextPage = const MyEnrolledClasses();
        break;
      case 3:
        nextPage = const JournalPage();
        break;
      case 4:
        return; // Already on ProgressTrackerPage
      case 5:
        nextPage = const ProfilePage();
        break;
      default:
        return;
    }

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => nextPage,
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            child,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: Column(
          children: [
            _buildAppBarWithLogo(),
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF0077B3)),
                    SizedBox(height: 16),
                    Text('Loading your progress...'),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomNavBar(),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: Column(
          children: [
            _buildAppBarWithLogo(),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _fetchAllReportData,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomNavBar(),
      );
    }

    bool hasProgress =
        _allUserAttempts.isNotEmpty || _assessmentSubmissions.isNotEmpty;

    if (!hasProgress) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: Column(
          children: [
            _buildAppBarWithLogo(),
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.trending_up, size: 80, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No Progress Yet',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Start learning to see your progress here!',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomNavBar(),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          _buildAppBarWithLogo(),
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: RefreshIndicator(
                onRefresh: _fetchAllReportData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAIAdvisorCard(),
                      const SizedBox(height: 16),
                      _buildOverallStatsCards(),
                      const SizedBox(height: 16),
                      _buildTrainerAssessmentsSection(),
                      const SizedBox(height: 16),
                      _buildAILessonsSection(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildAIAdvisorCard() {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.blue.shade100, width: 1),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white,
              Colors.blue.shade50.withOpacity(0.3),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0077B3), Color(0xFF005f8c)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.psychology,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Your AI Learning Advisor',
                      style: TextStyle(
                        color: Color(0xFF1a1a1a),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (_loadingAdvisor) ...[
                Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.blue.shade600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Analyzing your progress...',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ] else if (_advisorError != null) ...[
                Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade400),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _advisorError!,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (_aiAdvisorFeedback != null) ...[
                Text(
                  _aiAdvisorFeedback!,
                  style: TextStyle(
                    color: Colors.grey.shade800,
                    fontSize: 15,
                    height: 1.6,
                    letterSpacing: 0.2,
                  ),
                ),
              ] else ...[
                Text(
                  'Complete some lessons to receive personalized advice!',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildOverallStatsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Lessons Tried',
            '${_overallStats['attemptedLessonsCount']}',
            Icons.book,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            'Total Attempts',
            '${_overallStats['totalAttempts']}',
            Icons.refresh,
            Colors.green,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            'Average Score',
            '${_overallStats['averageScore']}${_overallStats['averageScore'] == "N/A" ? "" : "%"}',
            Icons.analytics,
            Colors.purple,
          ),
        ),
      ],
    );
  }

 Widget _buildStatCard(
  String title,
  String value,
  IconData icon,
  Color color,
) {
  return Card(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: Colors.grey.shade200, width: 1),
    ),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildTrainerAssessmentsSection() {
  return Card(
    elevation: 0,
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: const Color.fromARGB(255, 82, 177, 255), width: 1),
    ),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trainer Assessments',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1a1a1a),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Your formal assessment submissions',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (_assessmentSubmissions.isNotEmpty)
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0077B3).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextButton.icon(
                    icon: const Icon(
                      Icons.download,
                      size: 18,
                      color: Color(0xFF0077B3),
                    ),
                    label: const Text(
                      'Export',
                      style: TextStyle(color: Color(0xFF0077B3)),
                    ),
                    onPressed: _showExportOptions,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          if (_isLoadingAssessments) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            ),
          ] else if (_assessmentSubmissions.isEmpty) ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.assignment_outlined,
                      size: 64,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No assessments submitted yet',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _assessmentSubmissions.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return _buildAssessmentSubmissionCard(
                  _assessmentSubmissions[index],
                );
              },
            ),
          ],
        ],
      ),
    ),
  );
}

Widget _buildAssessmentSubmissionCard(Map<String, dynamic> submission) {
  final score = submission['score'] ?? 0;
  final totalPoints = submission['totalPossiblePoints'] ?? 100;
  final percentage = totalPoints > 0 ? (score / totalPoints * 100) : 0;

  Color scoreColor = _getScoreColor(percentage);

  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade200, width: 1),
    ),
    child: InkWell(
      onTap: () => _navigateToReview(submission),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    submission['assessmentTitle'] ?? 'Assessment',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1a1a1a),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: scoreColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$score / $totalPoints',
                    style: TextStyle(
                      color: scoreColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            if (submission['className'] != null &&
                submission['className'] != 'Class Name Not Found')
              Row(
                children: [
                  Icon(
                    Icons.class_,
                    size: 14,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    submission['className'],
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: scoreColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${percentage.toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: scoreColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 14,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatSubmissionDate(submission['submittedAt']),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => _navigateToReview(submission),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF0077B3),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      child: const Text(
                        'Review',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.share, size: 16),
                      label: const Text(
                        'Share',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF0077B3),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      onPressed: () => _shareAssessment(submission),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
  Widget _buildAILessonsSection() {
  if (_allUserAttempts.isEmpty) return const SizedBox.shrink();

  final levelGroups = _groupLessonsByLevel();

  return Column(
    children: [
      // Header card
      Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: const Color.fromARGB(255, 82, 177, 255), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0077B3), Color(0xFF005f8c)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.school,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detailed Performance by Level & Module',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1a1a1a),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Explore your progress through each learning module',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),

      const SizedBox(height: 16),

      // Level sections
      ...levelGroups.entries.map((levelEntry) {
        return _buildLevelSection(levelEntry.key, levelEntry.value);
      }).toList(),
    ],
  );
}

 Widget _buildLevelSection(
  String level,
  List<MapEntry<String, List<Map<String, dynamic>>>> lessons,
) {
  // Get modules for this level
  final modulesForLevel = COURSE_STRUCTURE_MOBILE.entries
      .where((entry) => entry.value['level'] == level)
      .toList();

  // Check if user has any progress in this level
  final hasAnyProgress = lessons.isNotEmpty;

  if (!hasAnyProgress) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _getLevelColor(level).withOpacity(0.1),
                    _getLevelColor(level).withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _getLevelColor(level).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _getLevelIcon(level),
                      color: _getLevelColor(level),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '$level Level',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _getLevelColor(level),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.grey.shade500,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'You haven\'t started this level yet. Begin your journey to unlock new challenges!',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                      height: 1.5,
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

  return Card(
    elevation: 0,
    color: Colors.white,
    margin: const EdgeInsets.only(bottom: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: Colors.grey.shade200, width: 1),
    ),
    child: Column(
      children: [
        // Level header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _getLevelColor(level).withOpacity(0.1),
                _getLevelColor(level).withOpacity(0.05),
              ],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _getLevelColor(level).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getLevelIcon(level),
                  color: _getLevelColor(level),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '$level Level',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _getLevelColor(level),
                ),
              ),
            ],
          ),
        ),

        // Modules in this level
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: modulesForLevel.map((moduleEntry) {
              return _buildModuleSection(moduleEntry.key, moduleEntry.value);
            }).toList(),
          ),
        ),
      ],
    ),
  );
}

 Widget _buildModuleSection(String moduleId, Map<String, dynamic> moduleData) {
  final moduleLessons = moduleData['lessons'] as List<dynamic>? ?? [];
  final moduleAssessment = moduleData['assessment'] as Map<String, dynamic>?;

  // Check if any lessons in this module have progress
  final hasProgress = moduleLessons.any((lesson) {
    final lessonId = lesson['firestoreId'] as String;
    return _allUserAttempts[lessonId]?.isNotEmpty ?? false;
  });

  // Check module assessment progress
  final hasAssessmentProgress =
      moduleAssessment != null &&
      (_assessmentSubmissions.any(
        (sub) => sub['assessmentId'] == moduleAssessment['id'],
      ));

  if (!hasProgress && !hasAssessmentProgress) {
    return const SizedBox.shrink(); // Don't show modules with no progress
  }

  return Container(
    margin: const EdgeInsets.only(bottom: 20),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: Colors.grey.shade200, width: 1),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Module header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0077B3).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.book,
                  color: const Color(0xFF0077B3),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  moduleData['title'] as String,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1a1a1a),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  // Navigate to courses page and scroll to this module
                  Navigator.pushReplacementNamed(context, '/courses');
                },
                icon: const Icon(Icons.launch, size: 14),
                label: const Text(
                  'View Module',
                  style: TextStyle(fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF0077B3),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Module lessons
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Lessons
              ...moduleLessons.map((lesson) {
                final lessonId = lesson['firestoreId'] as String;
                final attempts = _allUserAttempts[lessonId] ?? [];
                if (attempts.isEmpty) return const SizedBox.shrink();

                return _buildLessonProgressCard(lessonId, attempts);
              }).toList(),

              // Module Assessment
              if (moduleAssessment != null && hasAssessmentProgress)
                _buildModuleAssessmentCard(moduleAssessment),
            ],
          ),
        ),
      ],
    ),
  );
}
 Widget _buildModuleAssessmentCard(Map<String, dynamic> assessmentData) {
  final assessmentId = assessmentData['id'] as String;
  final assessmentTitle = assessmentData['title'] as String;

  // Find assessment submissions for this assessment
  final assessmentSubmissions = _assessmentSubmissions
      .where((sub) => sub['assessmentId'] == assessmentId)
      .toList();

  if (assessmentSubmissions.isEmpty) return const SizedBox.shrink();

  // Get the best submission
  final bestSubmission = assessmentSubmissions.reduce((a, b) {
    final scoreA = a['score'] ?? 0;
    final scoreB = b['score'] ?? 0;
    return scoreA > scoreB ? a : b;
  });

  final score = bestSubmission['score'] ?? 0;
  final totalPoints = bestSubmission['totalPossiblePoints'] ?? 100;
  final percentage = totalPoints > 0 ? (score / totalPoints * 100) : 0;

  return Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Colors.amber.shade50,
          Colors.orange.shade50.withOpacity(0.3),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.amber.shade200, width: 1),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.emoji_events,
                color: Colors.amber.shade700,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                assessmentTitle,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(
              Icons.repeat,
              size: 14,
              color: Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              '${assessmentSubmissions.length} attempt${assessmentSubmissions.length != 1 ? 's' : ''}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(width: 16),
            Icon(
              Icons.star,
              size: 14,
              color: Colors.amber.shade700,
            ),
            const SizedBox(width: 6),
            Text(
              'Best: $score / $totalPoints',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: Colors.amber.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.amber.shade600),
            minHeight: 6,
          ),
        ),
      ],
    ),
  );
}

  Color _getLevelColor(String level) {
    switch (level) {
      case 'Beginner':
        return Colors.blue;
      case 'Intermediate':
        return Colors.orange;
      case 'Advanced':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getLevelIcon(String level) {
    switch (level) {
      case 'Beginner':
        return Icons.star_outline;
      case 'Intermediate':
        return Icons.star_half;
      case 'Advanced':
        return Icons.star;
      default:
        return Icons.circle;
    }
  }

Widget _buildLessonProgressCard(
  String lessonId,
  List<Map<String, dynamic>> attempts,
) {
  final lessonTitle = _getLessonTitle(lessonId);

  // Calculate best percentage instead of raw score
  final bestPercentage = attempts
      .map((a) {
        final score = (a['score'] as num?)?.toDouble() ?? 0;
        final maxScore = _getMaxScoreForLesson(a);
        return maxScore > 0 ? (score / maxScore * 100) : 0.0;
      })
      .reduce(math.max);

  final isExpanded = _expandedLesson[lessonId] ?? false;

  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade200, width: 1),
    ),
    child: Column(
      children: [
        InkWell(
          onTap: () =>
              setState(() => _expandedLesson[lessonId] = !isExpanded),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        lessonTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF1a1a1a),
                        ),
                      ),
                    ),
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.grey.shade600,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.repeat,
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${attempts.length} attempt${attempts.length != 1 ? 's' : ''}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.emoji_events,
                      size: 14,
                      color: _getScoreColor(bestPercentage),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Best: ${bestPercentage.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Progress bar for best score
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: bestPercentage / 100,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getScoreColor(bestPercentage),
                    ),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getScoreColor(bestPercentage).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _getPerformanceLabel(bestPercentage),
                        style: TextStyle(
                          color: _getScoreColor(bestPercentage),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.share, size: 18),
                      color: const Color(0xFF0077B3),
                      onPressed: () => _shareLessonProgress(lessonId, attempts),
                      tooltip: 'Share progress',
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        if (isExpanded) ...[
          Divider(height: 1, color: Colors.grey.shade200),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: attempts
                  .map((attempt) => _buildAttemptSummary(attempt))
                  .toList(),
            ),
          ),
        ],
      ],
    ),
  );
}

  Widget _buildAttemptSummary(Map<String, dynamic> attempt) {
  final score = (attempt['score'] as num?)?.toDouble() ?? 0;
  final attemptNumber = attempt['attemptNumber'] ?? 0;
  final timestamp = attempt['attemptTimestamp'] as DateTime?;

  // Get the maximum possible score for this lesson
  final maxScore = _getMaxScoreForLesson(attempt);
  final percentage = maxScore > 0 ? (score / maxScore * 100) : 0.0;

  return Container(
    margin: const EdgeInsets.symmetric(vertical: 6),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.grey.shade200, width: 1),
    ),
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Attempt $attemptNumber',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1a1a1a),
              ),
            ),
            if (timestamp != null)
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 12,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatShortDate(timestamp),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: percentage / 100,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getScoreColor(percentage),
                  ),
                  minHeight: 8,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _getScoreColor(percentage).withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${percentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: _getScoreColor(percentage),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Score: ${score.toStringAsFixed(0)} / $maxScore',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _getScoreColor(percentage).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getPerformanceLabel(percentage),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _getScoreColor(percentage),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

  double _getMaxScoreForLesson(Map<String, dynamic> attempt) {
    // Try to get from the attempt data first
    if (attempt['maxScore'] != null) {
      return (attempt['maxScore'] as num).toDouble();
    }

    // Get lesson ID to look up in our lesson configs
    final lessonId = attempt['lessonId'] as String?;
    if (lessonId == null) return 100.0; // Default fallback

    // Define max scores for different lessons based on your lesson configs
    const lessonMaxScores = {
      'Lesson-1-1': 7.0, // From your module configs
      'Lesson-1-2': 5.0,
      'Lesson-1-3': 11.0,
      'Lesson-2-1': 10.0,
      'Lesson-2-2': 10.0,
      'Lesson-2-3': 10.0,
      'Lesson-3-1': 60.0,
      'Lesson-3-2': 50.0,
      'Lesson-4-1': 80.0,
      'Lesson-4-2': 70.0,
      'Lesson-5-1': 100.0,
      'Lesson-5-2': 100.0,
      'Lesson-6-1': 100.0,
    };

    return lessonMaxScores[lessonId] ?? 100.0; // Default to 100 if not found
  }

  String _getPerformanceLabel(double percentage) {
    if (percentage >= 95) return 'Excellent';
    if (percentage >= 85) return 'Very Good';
    if (percentage >= 75) return 'Good';
    if (percentage >= 65) return 'Fair';
    if (percentage >= 50) return 'Needs Work';
    return 'Poor';
  }

  Widget _buildBottomNavBar() {
    return AnimatedBottomNavBar(
      currentIndex: _selectedIndex,
      onTap: _onItemTapped,
      items: [
        CustomBottomNavItem(icon: Icons.home, label: 'Home'),
        CustomBottomNavItem(icon: Icons.book, label: 'Courses'),
        CustomBottomNavItem(icon: Icons.school, label: 'My Classes'),
        CustomBottomNavItem(icon: Icons.library_books, label: 'Journal'),
        CustomBottomNavItem(icon: Icons.trending_up, label: 'Progress'),
        CustomBottomNavItem(icon: Icons.person, label: 'Profile'),
      ],
      activeColor: Colors.white,
      inactiveColor: Colors.grey[600]!,
      notchColor: const Color(0xFF0077B3),
      backgroundColor: Colors.white,
      selectedIconSize: 28.0,
      iconSize: 25.0,
      barHeight: 55,
      selectedIconPadding: 10,
      animationDuration: const Duration(milliseconds: 300),
      customNotchWidthFactor: 1.8,
    );
  }

  // Helper methods
  Color _getScoreColor(double score) {
    if (score >= 90) return Colors.green;
    if (score >= 75) return Colors.blue;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  String _getLessonTitle(String lessonId) {
    // Implementation from your existing COURSE_STRUCTURE_MOBILE
    for (var moduleEntry in COURSE_STRUCTURE_MOBILE.entries) {
      var lessons = moduleEntry.value['lessons'] as List<dynamic>?;
      if (lessons != null) {
        for (var lesson in lessons) {
          if (lesson is Map && lesson['firestoreId'] == lessonId) {
            return lesson['title'] as String? ?? lessonId;
          }
        }
      }
    }
    return lessonId;
  }

  String _formatSubmissionDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';

    try {
      DateTime date;
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is DateTime) {
        date = timestamp;
      } else {
        return 'N/A';
      }

      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'N/A';
    }
  }

  String _formatShortDate(DateTime date) {
    return '${date.day}/${date.month}';
  }

  void _navigateToReview(Map<String, dynamic> submission) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AssessmentReviewPage(
          submissionId: submission['id'],
          assessmentId: submission['assessmentId'],
        ),
      ),
    );
  }
void _shareLessonProgress(String lessonId, List<Map<String, dynamic>> attempts) {
  final lessonTitle = _getLessonTitle(lessonId);
  final bestPercentage = attempts
      .map((a) {
        final score = (a['score'] as num?)?.toDouble() ?? 0;
        final maxScore = _getMaxScoreForLesson(a);
        return maxScore > 0 ? (score / maxScore * 100) : 0.0;
      })
      .reduce(math.max);

  final totalAttempts = attempts.length;
  final latestAttempt = attempts.last;
  final latestScore = (latestAttempt['score'] as num?)?.toDouble() ?? 0;
  final latestMaxScore = _getMaxScoreForLesson(latestAttempt);
  final latestPercentage = latestMaxScore > 0 ? (latestScore / latestMaxScore * 100) : 0;

  final shareText = '''
TalkReady Lesson Progress

Lesson: $lessonTitle

Statistics:
- Total Attempts: $totalAttempts
- Best Score: ${bestPercentage.toStringAsFixed(1)}%
- Latest Score: ${latestPercentage.toStringAsFixed(1)}%
- Performance: ${_getPerformanceLabel(bestPercentage)}

${bestPercentage >= 90 ? "Excellent work!" : bestPercentage >= 75 ? "Great progress!" : "Keep practicing!"}

#TalkReady #Learning
  '''.trim();

  Share.share(
    shareText,
    subject: 'My Progress: $lessonTitle',
  );
}
 void _shareAssessment(Map<String, dynamic> submission) {
  final title = submission['assessmentTitle'] ?? 'Assessment';
  final score = submission['score'] ?? 0;
  final totalPoints = submission['totalPossiblePoints'] ?? 100;
  final percentage = totalPoints > 0 ? (score / totalPoints * 100) : 0;
  final className = submission['className'] ?? 'N/A';
  final date = _formatSubmissionDate(submission['submittedAt']);

  final shareText = '''
📊 TalkReady Assessment Result

📝 Assessment: $title
🏫 Class: $className
📅 Date: $date

✅ Score: $score / $totalPoints
📈 Percentage: ${percentage.toStringAsFixed(1)}%
🎯 Performance: ${_getPerformanceLabel(percentage)}

Keep up the great work! 🚀

#TalkReady #Learning #Progress
  '''.trim();

  Share.share(
    shareText,
    subject: 'My TalkReady Assessment Result: $title',
  );
}

  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Export Options',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('Download Full History PDF'),
              onTap: () {
                Navigator.pop(context);
                _handleDownloadFullHistoryPdf();
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share Progress Summary'),
              onTap: () {
                Navigator.pop(context);
                _shareProgressSummary();
              },
            ),
          ],
        ),
      ),
    );
  }

Future<void> _handleDownloadFullHistoryPdf() async {
  try {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Generating PDF...')),
    );

    // Fetch user's first and last name from Firestore
    String userName = 'Student';
    if (_currentUser != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser!.uid)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data();
          final firstName = userData?['firstName'] ?? '';
          final lastName = userData?['lastName'] ?? '';

          if (firstName.isNotEmpty || lastName.isNotEmpty) {
            userName = '$firstName $lastName'.trim();
          } else {
            // Fallback to email if names are not available
            userName = _currentUser!.email ?? 'Student';
          }
        }
      } catch (e) {
        _logger.w('Error fetching user name: $e');
        userName = _currentUser!.email ?? 'Student';
      }
    }

    await _pdfService.generateProgressReportPdf(
      overallStats: _overallStats,
      allUserAttempts: _allUserAttempts,
      assessmentSubmissions: _assessmentSubmissions,
      userName: userName,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF generated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

void _shareProgressSummary() {
  final attemptedLessons = _overallStats['attemptedLessonsCount'];
  final totalAttempts = _overallStats['totalAttempts'];
  final avgScore = _overallStats['averageScore'];

  // Calculate assessment stats - ONLY reviewed assessments
  final reviewedAssessments = _assessmentSubmissions
      .where((s) => s['isReviewed'] == true)
      .toList();

  final totalAssessments = _assessmentSubmissions.length;
  final pendingReview = totalAssessments - reviewedAssessments.length;

  // Calculate average assessment score from REVIEWED submissions only
  double avgAssessmentScore = 0;
  if (reviewedAssessments.isNotEmpty) {
    final totalScore = reviewedAssessments.fold<double>(
      0,
      (sum, s) {
        final score = (s['score'] as num?)?.toDouble() ?? 0;
        final total = (s['totalPossiblePoints'] as num?)?.toDouble() ?? 100;
        return sum + (total > 0 ? (score / total * 100) : 0);
      },
    );
    avgAssessmentScore = totalScore / reviewedAssessments.length;
  }

  final shareText = '''
📚 My TalkReady Learning Progress

🎓 AI Lessons:
   • Lessons Attempted: $attemptedLessons
   • Total Practice Attempts: $totalAttempts
   • Average Score: $avgScore${avgScore == "N/A" ? "" : "%"}

📝 Trainer Assessments:
   • Total Submissions: $totalAssessments
   • Reviewed: ${reviewedAssessments.length}${reviewedAssessments.isNotEmpty ? " (Average: ${avgAssessmentScore.toStringAsFixed(1)}%)" : ""}
   • Pending Review: $pendingReview

🚀 Keep learning and growing with TalkReady!

#TalkReady #LearningJourney #Progress
  '''.trim();

  Share.share(
    shareText,
    subject: 'My TalkReady Learning Progress',
  );
}
    }

// Keep your existing COURSE_STRUCTURE_MOBILE and helper methods...
const Map<String, Map<String, dynamic>> COURSE_STRUCTURE_MOBILE = {
  "module1": {
    "title": "Module 1: Basic English Grammar",
    "level": "Beginner",
    "lessons": [
      {
        "firestoreId": "Lesson-1-1",
        "title": "Lesson 1.1: Nouns and Pronouns",
        "type": "MCQ",
      },
      {
        "firestoreId": "Lesson-1-2",
        "title": "Lesson 1.2: Simple Sentences",
        "type": "MCQ",
      },
      {
        "firestoreId": "Lesson-1-3",
        "title": "Lesson 1.3: Verb and Tenses (Present Simple)",
        "type": "MCQ",
      },
    ],
    "assessment": {
      "id": "module_1_final",
      "title": "Module 1 Final Assessment",
    },
  },
  "module2": {
    "title": "Module 2: Vocabulary & Everyday Conversations",
    "level": "Beginner",
    "lessons": [
      {
        "firestoreId": "Lesson-2-1",
        "title": "Lesson 2.1: Greetings and Self-Introductions",
        "type": "TEXT_SCENARIO",
      },
      {
        "firestoreId": "Lesson-2-2",
        "title": "Lesson 2.2: Asking for Information",
        "type": "TEXT_SCENARIO",
      },
      {
        "firestoreId": "Lesson-2-3",
        "title": "Lesson 2.3: Numbers and Dates",
        "type": "TEXT_FILL_IN",
      },
    ],
    "assessment": {
      "id": "module_2_final",
      "title": "Module 2 Final Assessment",
    },
  },
  "module3": {
    "title": "Module 3: Listening & Speaking Practice",
    "level": "Intermediate",
    "lessons": [
      {
        "firestoreId": "Lesson-3-1",
        "title": "Lesson 3.1: Listening Comprehension",
        "type": "LISTENING_COMP",
      },
      {
        "firestoreId": "Lesson-3-2",
        "title": "Lesson 3.2: Speaking Practice - Dialogues",
        "type": "SPEAKING_PRACTICE",
      },
    ],
    "assessment": {
      "id": "module_3_final",
      "title": "Module 3 Final Assessment: Role-Play Scenario",
    },
  },
  "module4": {
    "title": "Module 4: Practical Grammar & Customer Service Scenarios",
    "level": "Intermediate",
    "lessons": [
      {
        "firestoreId": "Lesson-4-1",
        "title": "Lesson 4.1: Asking for Clarification",
        "type": "CLARIFICATION_SCENARIO",
      },
      {
        "firestoreId": "Lesson-4-2",
        "title": "Lesson 4.2: Providing Solutions",
        "type": "PROVIDING_SOLUTIONS",
      },
    ],
    "assessment": {
      "id": "module_4_final",
      "title": "Module 4 Final Assessment",
    },
  },
  "module5": {
    "title": "Module 5: Basic Call Simulations",
    "level": "Intermediate",
    "lessons": [
      {
        "firestoreId": "Lesson-5-1",
        "title": "Lesson 5.1: Call Simulation - Scenario 1",
        "type": "BASIC_CALL_SIMULATION",
      },
      {
        "firestoreId": "Lesson-5-2",
        "title": "Lesson 5.2: Call Simulation - Scenario 2",
        "type": "BASIC_CALL_SIMULATION",
      },
    ],
    "assessment": {
      "id": "module_5_final",
      "title": "Module 5 Final Assessment",
    },
  },
  "module6": {
    "title": "Module 6: Advanced Call Simulation",
    "level": "Advanced",
    "lessons": [
      {
        "firestoreId": "Lesson-6-1",
        "title": "Lesson 6.1: Advanced Call Simulation",
        "type": "ADVANCED_CALL_SIMULATION",
      },
    ],
  },
};
