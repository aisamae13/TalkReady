// lib/lessons/lesson_activity_log_page.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/ai_feedback_display_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Add this import if not already present

class LessonActivityLogPage extends StatelessWidget {
  final String lessonId;
  final Map<String, dynamic> lessonData;
  final List<Map<String, dynamic>> activityLog;

  const LessonActivityLogPage({
    super.key,
    required this.lessonId,
    required this.lessonData,
    required this.activityLog,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Activity Log: $lessonId'),
        backgroundColor: const Color(0xFF00568D),
      ),
      body: activityLog.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No attempts recorded yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Complete the lesson activity to see your progress here.',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: activityLog.length,
              itemBuilder: (context, index) {
                return _buildLogEntry(activityLog[index], index);
              },
            ),
    );
  }

  Widget _buildLogEntry(Map<String, dynamic> log, int index) {
    final attemptNum = log['attemptNumber'] ?? (index + 1);
    final score = log['score'] ?? 0;
    final attemptTimestamp = log['attemptTimestamp'];

    // FIX 1: Safely handle timeSpent which could be an int or a double.
    final timeSpent = (log['timeSpent'] as num?)?.round() ?? 0;

    // ✅ FIX: Improved timestamp formatting
    String formattedDate = 'Unknown date';
    if (attemptTimestamp != null) {
      DateTime dateTime;
      try {
        if (attemptTimestamp is DateTime) {
          dateTime = attemptTimestamp;
        } else if (attemptTimestamp is Timestamp) {
          // ✅ FIX: Handle Firestore Timestamp properly
          dateTime = attemptTimestamp.toDate();
        } else if (attemptTimestamp is int) {
          // ✅ FIX: Handle Unix timestamp
          dateTime = DateTime.fromMillisecondsSinceEpoch(attemptTimestamp);
        } else if (attemptTimestamp is String) {
          // ✅ FIX: Handle ISO string
          dateTime = DateTime.parse(attemptTimestamp);
        } else {
          dateTime = DateTime.now(); // Fallback
        }

        // ✅ FIX: Better date formatting to match the web version
        formattedDate = _formatAttemptDate(dateTime);
      } catch (e) {
        // If parsing fails, use current time as fallback
        dateTime = DateTime.now();
        formattedDate = _formatAttemptDate(dateTime);
      }
    }

    // Format time spent
    String formattedTime = '${timeSpent ~/ 60}m ${timeSpent % 60}s';

    // ✅ FIX: Handle different score formats for display - ensure double conversion
    String scoreDisplay;
    double scoreForColor;

    if (lessonId == 'Lesson-4-1') {
      // Lesson 4.1 uses out of 10 scale, so convert to percentage
      final scoreAsNum = (score as num).toDouble();
      final percentageScore = scoreAsNum * 10;
      scoreDisplay = 'Overall Score: ${percentageScore.round()}%';
      scoreForColor = percentageScore;
    } else {
      // Other lessons use percentage
      final scoreAsNum = (score as num).toDouble();
      scoreDisplay = 'Overall Score: ${scoreAsNum.round()}%';
      scoreForColor = scoreAsNum;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        childrenPadding: const EdgeInsets.only(bottom: 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF00568D).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Attempt $attemptNum',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF00568D),
                ),
              ),
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  scoreDisplay,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: _getScoreColor(scoreForColor),
                  ),
                ),
                Text(
                  'Time: $formattedTime',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            formattedDate,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Color(0xFF00568D),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'View Details for Attempt',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00568D),
                      ),
                    ),
                    Text(
                      ' $attemptNum',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00568D),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ..._buildDetailedFeedback(log),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatAttemptDate(DateTime dateTime) {
    // Format to match web version: "20 September 2025 at 16:13"
    final day = dateTime.day;
    final month = _getMonthName(dateTime.month);
    final year = dateTime.year;
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$day $month $year at $hour:$minute';
  }

  String _getMonthName(int month) {
    const months = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month];
  }

  List<Widget> _buildDetailedFeedback(Map<String, dynamic> log) {
    final detailedResponses =
        log['detailedResponses'] as Map<String, dynamic>? ?? {};

    if (lessonId == 'Lesson-3-2') {
      return _buildSpeakingPromptDetails(detailedResponses);
    }

    if (lessonId == 'Lesson-4-1') {
      return _buildLesson4_1Details(detailedResponses);
    }
    // ADD THIS CONDITION
    if (lessonId == 'Lesson-4-2') {
      return _buildLesson4_2Details(detailedResponses);
    }

    // ADD THIS NEW CONDITION
    if (lessonId == 'Lesson-5-1') {
      return _buildLesson5_1Details(detailedResponses);
    }

    // ✅ ADD THIS NEW CONDITION FOR LESSON 5.2
    if (lessonId == 'Lesson-5-2') {
      return _buildLesson5_2Details(detailedResponses);
    }

    // **FIX:** Improved handling for Module 2 lessons
    return _buildStandardResponseWidgets(detailedResponses);
  }

  List<Widget> _buildSpeakingPromptDetails(
    Map<String, dynamic> detailedResponses,
  ) {
    final promptDetails =
        detailedResponses['promptDetails'] as List<dynamic>? ?? [];
    final overallScore =
        (detailedResponses['overallScore'] as num?)?.round() ?? 0;
    final timeSpent = (detailedResponses['timeSpent'] as num?)?.round() ?? 0;

    if (promptDetails.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.grey),
              SizedBox(width: 8),
              Text('No detailed responses found for this attempt.'),
            ],
          ),
        ),
      ];
    }

    return [
      // Overall Summary Header
      _buildOverallSummaryHeader(overallScore, promptDetails.length, timeSpent),
      const SizedBox(height: 20),

      // Performance Breakdown
      _buildPerformanceBreakdownSection(promptDetails),
      const SizedBox(height: 20),

      // Individual Prompt Details
      ...promptDetails.asMap().entries.map<Widget>((entry) {
        final index = entry.key;
        final prompt = entry.value as Map<String, dynamic>;
        return Column(
          children: [
            _buildEnhancedPromptDetail(prompt, index + 1),
            const SizedBox(height: 16),
          ],
        );
      }).toList(),
    ];
  }

  Widget _buildOverallSummaryHeader(
    int overallScore,
    int totalPrompts,
    int timeSpent,
  ) {
    final minutes = timeSpent ~/ 60;
    final seconds = timeSpent % 60;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF00568D).withOpacity(0.1),
            Colors.blue.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00568D).withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF00568D).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.assessment,
                  color: Color(0xFF00568D),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Session Summary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00568D),
                      ),
                    ),
                    Text(
                      'Comprehensive breakdown of your performance',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Stats Row
          Row(
            children: [
              Expanded(
                child: _buildSummaryStatCard(
                  'Overall Score',
                  '$overallScore%',
                  Icons.stars,
                  _getScoreColor(overallScore.toDouble()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryStatCard(
                  'Prompts',
                  '$totalPrompts',
                  Icons.quiz,
                  const Color(0xFF00568D),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryStatCard(
                  'Time Spent',
                  '${minutes}m ${seconds}s',
                  Icons.access_time,
                  Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceBreakdownSection(List<dynamic> promptDetails) {
    // Calculate average scores with safe casting AND proper conversion
    double avgAccuracy = 0;
    double avgFluency = 0;
    double avgCompleteness = 0;
    double avgProsody = 0;
    int count = 0;

    for (final prompt in promptDetails) {
      final azure = prompt['azureAiFeedback'] as Map<String, dynamic>?;
      if (azure != null) {
        if (azure['accuracyScore'] != null) {
          avgAccuracy += (azure['accuracyScore'] as num).toDouble();
          count++;
        }
        if (azure['fluencyScore'] != null) {
          double fluencyScore = (azure['fluencyScore'] as num).toDouble();
          // ✅ Convert fluency if it's > 5 (percentage format)
          if (fluencyScore > 5) {
            fluencyScore = (fluencyScore / 100) * 5;
          }
          avgFluency += fluencyScore;
        }
        if (azure['completenessScore'] != null) {
          avgCompleteness += (azure['completenessScore'] as num).toDouble();
        }
        if (azure['prosodyScore'] != null) {
          double prosodyScore = (azure['prosodyScore'] as num).toDouble();
          // ✅ Convert prosody if it's > 5 (percentage format)
          if (prosodyScore > 5) {
            prosodyScore = (prosodyScore / 100) * 5;
          }
          avgProsody += prosodyScore;
        }
      }
    }

    if (count > 0) {
      avgAccuracy /= count;
      avgFluency /= count;
      avgCompleteness /= count;
      avgProsody /= count;
    }

    // Rest of the method remains the same...
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.trending_up, color: Color(0xFF00568D), size: 24),
              SizedBox(width: 12),
              Text(
                'Performance Breakdown',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00568D),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildPerformanceMetricCard(
                      'Accuracy',
                      avgAccuracy,
                      Icons.check_circle,
                      Colors.green,
                      isPercentage: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildPerformanceMetricCard(
                      'Fluency',
                      avgFluency,
                      Icons.timeline,
                      Colors.blue,
                      isPercentage: false,
                      maxValue: 5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildPerformanceMetricCard(
                      'Completeness',
                      avgCompleteness,
                      Icons.assignment_turned_in,
                      Colors.purple,
                      isPercentage: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildPerformanceMetricCard(
                      'Prosody',
                      avgProsody,
                      Icons.music_note,
                      Colors.orange,
                      isPercentage: false,
                      maxValue: 5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetricCard(
    String label,
    double value,
    IconData icon,
    Color color, {
    bool isPercentage = true,
    double maxValue = 100,
  }) {
    final normalizedValue = isPercentage ? value / 100 : value / maxValue;
    final displayValue = isPercentage
        ? '${value.toStringAsFixed(1)}%'
        : '${value.toStringAsFixed(1)}/$maxValue';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            displayValue,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: normalizedValue.clamp(0.0, 1.0),
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 4,
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedPromptDetail(
    Map<String, dynamic> prompt,
    int promptNumber,
  ) {
    final promptText = prompt['text'] as String? ?? 'Prompt text not available';
    final promptContext = prompt['context'] as String?;
    final score = prompt['score'] as num?;
    final transcription =
        prompt['transcription'] as String? ?? 'No transcription available';
    final azureFeedback = prompt['azureAiFeedback'] as Map<String, dynamic>?;
    final openAiFeedback = prompt['openAiDetailedFeedback'];
    final audioUrl = prompt['audioUrl'] as String?;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.all(20),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF00568D),
                const Color(0xFF00568D).withOpacity(0.8),
              ],
            ),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$promptNumber',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Prompt $promptNumber',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF00568D),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _truncateText(promptText, 60),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (score != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _getScoreColor(score.toDouble()),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${score.round()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.expand_more),
          ],
        ),
        children: [
          // FIX: Reduced horizontal padding from 20 to 16 to fix minor overflows.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),

                // Audio Player Section
                if (audioUrl != null) _buildAudioPlayerSection(audioUrl),

                // Context Section
                if (promptContext != null) _buildContextSection(promptContext),

                // Full Prompt Text
                _buildFullPromptSection(promptText),

                // Transcription Section
                _buildTranscriptionSection(transcription),

                // Azure Metrics with Enhanced Display
                if (azureFeedback != null)
                  _buildEnhancedAzureMetrics(azureFeedback),

                // Word Analysis
                if (azureFeedback?['words'] != null)
                  _buildEnhancedWordAnalysis(azureFeedback!['words']),

                // Coach's Detailed Feedback
                if (openAiFeedback != null)
                  _buildEnhancedCoachFeedback(openAiFeedback),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioPlayerSection(String audioUrl) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.indigo.shade50],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.headphones, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Recording',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.blue,
                  ),
                ),
                Text(
                  'Tap to listen to your pronunciation',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _playAudio(audioUrl),
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('Play'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContextSection(String context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline,
                size: 18,
                color: Color(0xFF00568D),
              ),
              const SizedBox(width: 8),
              const Text(
                'Context',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF00568D),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context,
            style: const TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullPromptSection(String promptText) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.chat_bubble_outline,
                size: 18,
                color: Colors.blue,
              ),
              const SizedBox(width: 8),
              const Text(
                'Agent\'s Line',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '"$promptText"',
            style: const TextStyle(
              fontSize: 16,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w500,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptionSection(String transcription) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.record_voice_over,
                size: 18,
                color: Colors.green,
              ),
              const SizedBox(width: 8),
              const Text(
                'What You Said',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '"$transcription"',
            style: const TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedAzureMetrics(Map<String, dynamic> azureFeedback) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.analytics,
                  size: 18,
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(width: 8),
              // FIX: Wrapped the title Text with Expanded to prevent right overflow.
              const Expanded(
                child: Text(
                  'Azure AI Pronunciation Analysis',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.indigo,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Enhanced metrics display
          _buildDetailedMetric(
            'Accuracy',
            azureFeedback['accuracyScore'],
            Icons.check_circle,
            Colors.green,
            'How clearly each word was pronounced',
            isPercentage: true,
          ),
          const SizedBox(height: 12),
          _buildDetailedMetric(
            'Fluency',
            azureFeedback['fluencyScore'],
            Icons.timeline,
            Colors.blue,
            'Natural rhythm and flow of speech',
            isPercentage: false,
            maxValue: 5,
          ),
          const SizedBox(height: 12),
          _buildDetailedMetric(
            'Completeness',
            azureFeedback['completenessScore'],
            Icons.assignment_turned_in,
            Colors.purple,
            'How much of the text was spoken',
            isPercentage: true,
          ),
          const SizedBox(height: 12),
          _buildDetailedMetric(
            'Prosody',
            azureFeedback['prosodyScore'],
            Icons.music_note,
            Colors.orange,
            'Stress, intonation, and timing patterns',
            isPercentage: false,
            maxValue: 5,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedMetric(
    String label,
    dynamic scoreValue,
    IconData icon,
    Color color,
    String description, {
    bool isPercentage = true,
    double maxValue = 100,
  }) {
    if (scoreValue == null) return const SizedBox.shrink();

    double score = (scoreValue as num).toDouble();

    // ✅ Convert /5 metrics if they're in percentage format
    if (!isPercentage && maxValue == 5 && score > 5) {
      score = (score / 100) * 5; // Convert percentage to /5 scale
    }

    final normalizedValue = isPercentage ? score / 100 : score / maxValue;
    final displayValue = isPercentage
        ? '${score.toStringAsFixed(1)}%'
        : '${score.toStringAsFixed(1)}/$maxValue';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: color,
                  ),
                ),
              ),
              Text(
                displayValue,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: normalizedValue.clamp(0.0, 1.0),
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedWordAnalysis(List<dynamic> words) {
    if (words.isEmpty) return const SizedBox.shrink();

    // Categorize words by performance
    final excellentWords = <Map<String, dynamic>>[];
    final goodWords = <Map<String, dynamic>>[];
    final needsWorkWords = <Map<String, dynamic>>[];

    for (final wordData in words) {
      final accuracy = (wordData['accuracyScore'] as num?)?.toDouble() ?? 0.0;
      final wordMap = wordData as Map<String, dynamic>;

      if (accuracy >= 95) {
        excellentWords.add(wordMap);
      } else if (accuracy >= 75) {
        goodWords.add(wordMap);
      } else {
        needsWorkWords.add(wordMap);
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.purple.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.spellcheck,
                  size: 18,
                  color: Colors.purple,
                ),
              ),
              const SizedBox(width: 8),
              // FIX: Wrapped the title Text with Expanded to prevent right overflow.
              const Expanded(
                child: Text(
                  'Word-by-Word Analysis',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.purple,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Summary stats
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildWordCategoryChip(
                  'Excellent',
                  excellentWords.length,
                  Colors.green,
                ),
                _buildWordCategoryChip('Good', goodWords.length, Colors.orange),
                _buildWordCategoryChip(
                  'Needs Work',
                  needsWorkWords.length,
                  Colors.red,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Word categories
          if (excellentWords.isNotEmpty)
            _buildWordCategory(
              'Excellent (95%+)',
              excellentWords,
              Colors.green,
            ),
          if (goodWords.isNotEmpty)
            _buildWordCategory('Good (75-94%)', goodWords, Colors.orange),
          if (needsWorkWords.isNotEmpty)
            _buildWordCategory('Needs Work (<75%)', needsWorkWords, Colors.red),
        ],
      ),
    );
  }

  Widget _buildWordCategoryChip(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildWordCategory(
    String title,
    List<Map<String, dynamic>> words,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: color,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: words.map<Widget>((wordData) {
            final word = wordData['word'] as String? ?? '';
            final accuracy =
                (wordData['accuracyScore'] as num?)?.toDouble() ?? 0.0;

            return Tooltip(
              message: 'Accuracy: ${accuracy.round()}%',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Text(
                  word,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildEnhancedCoachFeedback(dynamic openAiFeedback) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade50, Colors.blue.shade50],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.indigo.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.indigo,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.school, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 8),
              // FIX: Wrapped the title Text with Expanded to prevent right overflow.
              const Expanded(
                child: Text(
                  'AI Coach\'s Detailed Analysis',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.indigo,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (openAiFeedback is Map<String, dynamic>) ...[
            if (openAiFeedback['feedback'] is List)
              _buildStructuredCoachFeedback(openAiFeedback)
            else
              AiFeedbackDisplayCard(feedbackData: openAiFeedback),
          ] else
            const Text(
              'Detailed feedback is being processed or is unavailable.',
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
            ),
        ],
      ),
    );
  }

  // Helper method to truncate text safely
  String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) {
      return text;
    }
    return '${text.substring(0, maxLength)}...';
  }

  Widget _buildSinglePromptDetail(
    Map<String, dynamic> prompt,
    int promptNumber,
  ) {
    final promptText =
        prompt['promptText'] as String? ??
        prompt['text'] as String? ??
        'Prompt text not available';
    final promptContext = prompt['context'] as String?;
    final score = prompt['score'] as num?;
    final transcription =
        prompt['transcription'] as String? ?? 'No transcription available';
    final azureFeedback = prompt['azureAiFeedback'] as Map<String, dynamic>?;
    final openAiFeedback = prompt['openAiDetailedFeedback'];
    final audioUrl = prompt['audioUrl'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF00568D).withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00568D),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Prompt $promptNumber',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (audioUrl != null)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.play_circle_fill,
                            color: Colors.white,
                          ),
                          onPressed: () => _playAudio(audioUrl),
                          tooltip: 'Listen to your recording',
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Context section
                if (promptContext != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[400]!),
                    ),
                    child: Text(
                      promptContext,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // Prompt text
                Text(
                  '"$promptText"',
                  style: const TextStyle(
                    fontStyle: FontStyle.italic,
                    fontSize: 16,
                    color: Color(0xFF00568D),
                    fontWeight: FontWeight.w500,
                  ),
                ),

                // Score
                if (score != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text(
                        'Score: ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getScoreColor(
                            score.toDouble(),
                          ).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _getScoreColor(score.toDouble()),
                          ),
                        ),
                        child: Text(
                          '${score.round()}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _getScoreColor(score.toDouble()),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Content section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Transcription
                _buildInfoSection(
                  'Your Transcription',
                  Icons.record_voice_over,
                  Text(
                    transcription,
                    style: const TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),

                // Azure Metrics
                if (azureFeedback != null) ...[
                  const SizedBox(height: 16),
                  _buildAzureMetrics(azureFeedback),
                ],

                // Word pronunciation
                if (azureFeedback?['words'] != null) ...[
                  const SizedBox(height: 16),
                  _buildWordPronunciation(azureFeedback!['words']),
                ],

                // Coach's Playbook
                if (openAiFeedback != null) ...[
                  const SizedBox(height: 16),
                  _buildInfoSection(
                    "Coach's Playbook",
                    Icons.school,
                    _buildCoachFeedback(openAiFeedback),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, IconData icon, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF00568D)),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF00568D),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: content,
        ),
      ],
    );
  }

  Widget _buildAzureMetrics(Map<String, dynamic> azureFeedback) {
    final metrics = [
      {
        'name': 'Accuracy',
        'score': azureFeedback['accuracyScore'],
        'icon': Icons.check_circle,
        'color': Colors.green,
      },
      {
        'name': 'Fluency',
        'score': azureFeedback['fluencyScore'],
        'icon': Icons.speed,
        'color': Colors.blue,
      },
      {
        'name': 'Completeness',
        'score': azureFeedback['completenessScore'],
        'icon': Icons.assignment_turned_in,
        'color': Colors.purple,
      },
      {
        'name': 'Prosody',
        'score': azureFeedback['prosodyScore'],
        'icon': Icons.music_note,
        'color': Colors.orange,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.analytics, size: 18, color: Color(0xFF00568D)),
            const SizedBox(width: 8),
            const Text(
              'Azure AI Metrics',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF00568D),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // **FIX:** Changed to a more flexible layout to prevent overflow
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: metrics.map((metric) {
            final score = metric['score'] as num?;
            if (score == null) return const SizedBox.shrink();

            return _buildMetricCard(
              metric['name'] as String,
              score.toDouble(),
              metric['icon'] as IconData,
              metric['color'] as Color,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    String label,
    double score,
    IconData icon,
    Color color,
  ) {
    // **FIX:** Made the metric card more compact to prevent overflow
    return Container(
      width: 140, // Fixed width to prevent overflow
      padding: const EdgeInsets.all(8), // Reduced padding
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // **FIX:** Prevent excessive height
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color), // Smaller icon
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11, // Smaller font
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                  overflow:
                      TextOverflow.ellipsis, // **FIX:** Handle text overflow
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${score.round()}%',
            style: TextStyle(
              fontSize: 11, // Smaller font
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: score / 100,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 3, // Thinner progress bar
          ),
        ],
      ),
    );
  }

  Widget _buildWordPronunciation(List<dynamic> words) {
    if (words.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.record_voice_over,
              size: 18,
              color: Color(0xFF00568D),
            ),
            const SizedBox(width: 8),
            const Text(
              'Word Pronunciation Highlights',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF00568D),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: words.map<Widget>((wordData) {
              final word = wordData['word'] as String? ?? '';
              final accuracy =
                  (wordData['accuracyScore'] as num?)?.toDouble() ?? 0.0;
              final errorType = wordData['errorType'] as String? ?? 'None';

              return Tooltip(
                message: errorType != 'None'
                    ? 'Error: $errorType (${accuracy.round()}%)'
                    : 'Accuracy: ${accuracy.round()}%',
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getWordScoreColor(accuracy).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getWordScoreColor(accuracy).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    word,
                    style: TextStyle(
                      color: _getWordScoreColor(accuracy),
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildCoachFeedback(dynamic openAiFeedback) {
    if (openAiFeedback is Map<String, dynamic>) {
      // Check if it's the new structured format with 'feedback' array
      if (openAiFeedback['feedback'] is List) {
        return _buildStructuredCoachFeedback(openAiFeedback);
      }
      // Legacy format
      return AiFeedbackDisplayCard(feedbackData: openAiFeedback);
    }

    return const Text(
      'Feedback is being processed or is unavailable.',
      style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
    );
  }

  Widget _buildStructuredCoachFeedback(Map<String, dynamic> feedbackData) {
    final feedbackList = feedbackData['feedback'] as List<dynamic>? ?? [];
    final overall = feedbackData['overall'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...feedbackList.map<Widget>((metric) {
          final metricData = metric as Map<String, dynamic>;
          final metricName = metricData['metric'] as String? ?? 'Unknown';
          final score = metricData['score'] as num?;
          final whyThisScore = metricData['whyThisScore'] as String? ?? '';
          final tip = metricData['tip'] as String? ?? '';

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _getMetricIcon(metricName),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        metricName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF1565C0),
                        ),
                      ),
                    ),
                    if (score != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getScoreColor(
                            score.toDouble(),
                          ).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _getScoreColor(score.toDouble()),
                          ),
                        ),
                        child: Text(
                          '${score.round()}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _getScoreColor(score.toDouble()),
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                if (whyThisScore.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    whyThisScore,
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                ],
                if (tip.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.yellow[50],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.yellow[400]!),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.lightbulb,
                          size: 16,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Tip: ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.orange,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            tip,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),

        if (overall != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0).withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF1565C0).withOpacity(0.2),
              ),
            ),
            child: Text(
              overall,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Color(0xFF1565C0),
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }

  Widget _getMetricIcon(String metricName) {
    switch (metricName.toLowerCase()) {
      case 'accuracy':
        return const Icon(Icons.check_circle, size: 16, color: Colors.green);
      case 'fluency':
        return const Icon(Icons.speed, size: 16, color: Colors.blue);
      case 'completeness':
        return const Icon(
          Icons.assignment_turned_in,
          size: 16,
          color: Colors.purple,
        );
      case 'prosody':
        return const Icon(Icons.music_note, size: 16, color: Colors.orange);
      default:
        return const Icon(Icons.info, size: 16, color: Colors.grey);
    }
  }

  List<Widget> _buildStandardResponseWidgets(
    Map<String, dynamic> detailedResponses,
  ) {
    // **FIX:** Improved Module 2 lesson handling
    Map<String, dynamic> responses = {};
    Map<String, dynamic> feedback = {};

    if (lessonId.startsWith('Lesson-2')) {
      // **FIX:** Try multiple possible keys for Module 2 lessons
      final lessonKey = lessonId.replaceAll(
        '-',
        '_',
      ); // "Lesson_2_1", "Lesson_2_2", etc.

      // Try different possible key formats
      responses =
          detailedResponses['scenarioAnswers_$lessonKey']
              as Map<String, dynamic>? ??
          detailedResponses['scenarioAnswers_L2_1'] as Map<String, dynamic>? ??
          detailedResponses['scenarioAnswers_L2_2'] as Map<String, dynamic>? ??
          detailedResponses['scenarioAnswers_L2_3'] as Map<String, dynamic>? ??
          {};

      feedback =
          detailedResponses['scenarioFeedback_$lessonKey']
              as Map<String, dynamic>? ??
          detailedResponses['scenarioFeedback_L2_1'] as Map<String, dynamic>? ??
          detailedResponses['scenarioFeedback_L2_2'] as Map<String, dynamic>? ??
          detailedResponses['scenarioFeedback_L2_3'] as Map<String, dynamic>? ??
          {};
    } else if (lessonId == 'Lesson-3-1') {
      responses = detailedResponses['answers'] as Map<String, dynamic>? ?? {};
      feedback =
          detailedResponses['feedbackForAnswers'] as Map<String, dynamic>? ??
          {};
    }
    // --- THIS IS THE NEW LOGIC TO ADD ---
    else if (lessonId == 'Lesson-4-1') {
      // Instructions to parse the data structure from a Lesson 4.1 attempt
      // These keys match the ones saved by the web app
      responses =
          detailedResponses['scenarioResponses'] as Map<String, dynamic>? ?? {};
      feedback =
          detailedResponses['aiFeedbackForScenarios']
              as Map<String, dynamic>? ??
          {};
    }
    // --- END OF NEW LOGIC ---

    if (responses.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.grey),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'No detailed responses found for this attempt. This might be an older attempt before detailed logging was implemented.',
                ),
              ),
            ],
          ),
        ),
      ];
    }

    // **FIX:** Create feedback entries for each response
    return responses.entries.map((entry) {
      final key = entry.key;
      final userAnswer = entry.value;
      final feedbackData = feedback[key];

      // Get prompt information from lesson data if available
      String promptTitle = key;
      if (lessonId.startsWith('Lesson-2')) {
        final prompts = List<Map<String, dynamic>>.from(
          lessonData['activity']?['prompts'] ?? [],
        );
        final promptData = prompts.firstWhere(
          (p) => p['name'] == key,
          orElse: () => <String, dynamic>{},
        );
        promptTitle = promptData['label'] ?? promptData['promptText'] ?? key;
      }

      return _createStandardFeedbackEntry(
        promptTitle,
        userAnswer,
        feedbackData,
      );
    }).toList();
  }

  // In lesson_activity_log_page.dart, add this method inside _LessonActivityLogPageState class

  List<Widget> _buildLesson4_1Details(Map<String, dynamic> detailedResponses) {
    final scenarioResponses =
        detailedResponses['scenarioResponses'] as Map<String, dynamic>? ?? {};
    final aiFeedback =
        detailedResponses['aiFeedbackForScenarios'] as Map<String, dynamic>? ??
        {};

    if (scenarioResponses.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.grey),
              SizedBox(width: 8),
              Text('No scenario responses found for this attempt.'),
            ],
          ),
        ),
      ];
    }

    return scenarioResponses.entries.map((entry) {
      final scenarioId = entry.key;
      final userResponse = entry.value as String;
      final scenarioFeedback = aiFeedback[scenarioId];

      // Get scenario number from ID
      final scenarioNumber = scenarioId.replaceAll('scenario', '');

      return Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Scenario header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF9C27B0),
                    const Color(0xFF9C27B0).withOpacity(0.8),
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
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        scenarioNumber,
                        style: const TextStyle(
                          color: Color(0xFF9C27B0),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Scenario $scenarioNumber',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content area
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User response section
                  const Text(
                    'Your Response:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF9C27B0),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      '"$userResponse"',
                      style: const TextStyle(
                        fontSize: 15,
                        fontStyle: FontStyle.italic,
                        color: Colors.black87,
                      ),
                    ),
                  ),

                  // AI Feedback section
                  if (scenarioFeedback != null) ...[
                    const SizedBox(height: 20),
                    AiFeedbackDisplayCard(
                      feedbackData: Map<String, dynamic>.from(scenarioFeedback),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  List<Widget> _buildLesson5_2Details(Map<String, dynamic> detailedResponses) {
    final promptDetails =
        detailedResponses['promptDetails'] as List<dynamic>? ?? [];
    final overallScore =
        (detailedResponses['overallScore'] as num?)?.round() ?? 0;
    final timeSpent = (detailedResponses['timeSpent'] as num?)?.round() ?? 0;

    // ✅ NEW: Problem Resolution specific breakdown
    final problemResolutionBreakdown =
        detailedResponses['problemResolutionReadiness']
            as Map<String, dynamic>?;

    if (promptDetails.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.grey),
              SizedBox(width: 8),
              Text(
                'No problem resolution simulation data found for this attempt.',
              ),
            ],
          ),
        ),
      ];
    }

    // Filter only Agent turns (the ones the user performed)
    final agentTurns = promptDetails
        .where(
          (turn) =>
              turn['character'] == 'Agent - Your Turn' ||
              turn['character'] == 'You',
        )
        .toList();

    return [
      // Problem Resolution Readiness Header
      _buildProblemResolutionReadinessHeader(
        overallScore,
        agentTurns.length,
        timeSpent,
        problemResolutionBreakdown,
      ),
      const SizedBox(height: 20),

      // Turn-by-Turn Analysis
      const Text(
        'Turn-by-Turn Performance Analysis',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF00568D),
        ),
      ),
      const SizedBox(height: 12),

      // Individual Turn Details
      ...promptDetails.asMap().entries.map<Widget>((entry) {
        final index = entry.key;
        final turn = entry.value as Map<String, dynamic>;
        return Column(
          children: [
            _buildProblemResolutionTurnDetail(turn, index + 1),
            const SizedBox(height: 16),
          ],
        );
      }).toList(),

      // Overall Problem Resolution Analysis
      if (problemResolutionBreakdown != null)
        _buildProblemResolutionAnalysis(problemResolutionBreakdown),
    ];
  }

  Widget _buildProblemResolutionReadinessHeader(
    int overallScore,
    int totalAgentTurns,
    int timeSpent,
    Map<String, dynamic>? breakdown,
  ) {
    final minutes = timeSpent ~/ 60;
    final seconds = timeSpent % 60;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.red.shade50, Colors.orange.shade50],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.support_agent,
                  color: Colors.red,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Problem Resolution Simulation Results',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    Text(
                      'Advanced customer service problem-solving analysis',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Problem Resolution Stats Row
          Row(
            children: [
              Expanded(
                child: _buildSummaryStatCard(
                  'Resolution Score',
                  '$overallScore%',
                  Icons.psychology,
                  _getScoreColor(overallScore.toDouble()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryStatCard(
                  'Agent Responses',
                  '$totalAgentTurns',
                  Icons.record_voice_over,
                  Colors.indigo,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryStatCard(
                  'Session Time',
                  '${minutes}m ${seconds}s',
                  Icons.timer,
                  Colors.orange,
                ),
              ),
            ],
          ),

          // Problem Resolution Breakdown if available
          if (breakdown != null) ...[
            const SizedBox(height: 16),
            _buildProblemResolutionBreakdown(breakdown),
          ],
        ],
      ),
    );
  }

  Widget _buildProblemResolutionTurnDetail(
    Map<String, dynamic> turn,
    int turnNumber,
  ) {
    final turnText = turn['text'] as String? ?? 'Turn text not available';
    final character = turn['character'] as String? ?? 'Unknown';
    final transcription =
        turn['transcription'] as String? ?? 'No transcription available';
    final score = turn['score'] as num?;
    final azureFeedback = turn['azureAiFeedback'] as Map<String, dynamic>?;
    final aiCoachFeedback =
        turn['openAiDetailedFeedback'] as Map<String, dynamic>?;
    final audioUrl = turn['audioUrl'] as String?;

    // Determine if this is a user turn or customer turn
    final isUserTurn = character == 'Agent - Your Turn' || character == 'You';
    final displayCharacter = isUserTurn ? 'You' : 'Customer';
    final containerColor = isUserTurn ? Colors.red : Colors.blue;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.all(20),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [containerColor, containerColor.shade700],
            ),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$turnNumber',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$displayCharacter - Turn $turnNumber',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: containerColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _truncateText(turnText, 60),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isUserTurn && score != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _getScoreColor(score.toDouble()),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${score.round()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.expand_more),
          ],
        ),
        children: [
          if (isUserTurn)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),

                  // Audio Player Section
                  if (audioUrl != null) _buildAudioPlayerSection(audioUrl),

                  // Transcription Section
                  _buildTranscriptionSection(transcription),

                  // ✅ UPDATED: Azure Speech Analysis
                  if (azureFeedback != null)
                    _buildAzureSpeechAnalysisLesson52(azureFeedback),

                  // ✅ NEW: Enhanced Prosody Metrics
                  if (azureFeedback != null)
                    _buildEnhancedProsodyMetricsLesson52(azureFeedback),

                  // ✅ NEW: Word Pronunciation Analysis
                  if (azureFeedback?['words'] != null)
                    _buildWordPronunciationAnalysisLesson52(
                      azureFeedback!['words'],
                    ),

                  // ✅ UPDATED: Problem Resolution Service Metrics (less compressed)
                  if (azureFeedback != null)
                    _buildProblemResolutionServiceMetricsImproved(
                      azureFeedback,
                      aiCoachFeedback,
                    ),

                  // ✅ UPDATED: Advanced Quality Analysis
                  if (azureFeedback != null || aiCoachFeedback != null)
                    _buildAdvancedQualityAnalysisLesson52(
                      azureFeedback,
                      aiCoachFeedback,
                    ),

                  // ✅ REMOVED: AI Coach Analysis (as requested)
                  // The old _buildAICoachAnalysis call is now gone
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const Text(
                    'Customer Turn:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '"$turnText"',
                    style: const TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAdvancedQualityAnalysisLesson52(
    Map<String, dynamic>? azureFeedback,
    Map<String, dynamic>? aiCoachFeedback,
  ) {
    if (azureFeedback == null && aiCoachFeedback == null) {
      return const SizedBox.shrink();
    }

    // Calculate speech quality score for problem resolution
    final speechQualityScore = _calculateAdvancedSpeechQuality(azureFeedback);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.lightBlue.shade50, // ✅ This exists
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.lightBlue.shade200), // ✅ This exists
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.bar_chart, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Speech Quality Analysis',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Overall Score Display
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                const Text(
                  'Speech Quality Score',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${speechQualityScore.round()}%',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: _getScoreColor(speechQualityScore),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Based on pronunciation, fluency, and delivery',
                  style: TextStyle(fontSize: 12, color: Colors.blue),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: (speechQualityScore / 100).clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _getScoreColor(speechQualityScore),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _generateAdvancedSpeechAssessment(speechQualityScore),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.blue,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Key Speech Metrics
          if (azureFeedback != null) ...[
            const Text(
              'Key Speech Metrics',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildQualityMetricLesson52(
                    'Pronunciation Clarity',
                    azureFeedback['accuracyScore'],
                    'How clearly each word was pronounced',
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQualityMetricLesson52(
                    'Speech Flow',
                    azureFeedback['fluencyScore'],
                    'Smoothness and naturalness of delivery',
                    Colors.blue,
                    isOutOfFive: true,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ✅ NEW METHOD 1: Speech Quality Analysis for Lesson 5.2
  Widget _buildAzureSpeechAnalysisLesson52(Map<String, dynamic> azure) {
    final accuracy = (azure['accuracyScore'] as num?)?.toDouble() ?? 0;
    final fluency = (azure['fluencyScore'] as num?)?.toDouble() ?? 0;
    final completeness = (azure['completenessScore'] as num?)?.toDouble() ?? 0;
    final prosody = (azure['prosodyScore'] as num?)?.toDouble() ?? 0;

    final normalizedFluency = fluency > 5 ? fluency : (fluency * 20);
    final normalizedProsody = prosody > 5 ? prosody : (prosody * 20);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bar_chart, color: Colors.blue, size: 20),
              SizedBox(width: 8),
              Text(
                'Speech Quality Analysis',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildSpeechMetricCardLesson52(
                      'Accuracy',
                      accuracy,
                      Icons.gps_fixed,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSpeechMetricCardLesson52(
                      'Fluency',
                      normalizedFluency,
                      Icons.speed,
                      Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildSpeechMetricCardLesson52(
                      'Completeness',
                      completeness,
                      Icons.assignment_turned_in,
                      Colors.purple,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSpeechMetricCardLesson52(
                      'Prosody',
                      normalizedProsody,
                      Icons.multitrack_audio,
                      Colors.orange,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ✅ NEW METHOD 2: Speech Metric Card
  Widget _buildSpeechMetricCardLesson52(
    String label,
    double value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${value.round()}%',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ NEW METHOD 3: Enhanced Prosody Metrics
  Widget _buildEnhancedProsodyMetricsLesson52(
    Map<String, dynamic> azureFeedback,
  ) {
    final prosodyScore =
        (azureFeedback['prosodyScore'] as num?)?.toDouble() ?? 0.0;
    final fluencyScore =
        (azureFeedback['fluencyScore'] as num?)?.toDouble() ?? 0.0;
    final accuracyScore =
        (azureFeedback['accuracyScore'] as num?)?.toDouble() ?? 0.0;

    final speechRate = _calculateSpeechRate(fluencyScore);
    final pausePatterns = _calculatePausePatterns(prosodyScore);
    final professionalTone = _calculateProfessionalToneFromAzure(
      accuracyScore,
      prosodyScore,
      fluencyScore,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.music_note, color: Colors.purple, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Enhanced Prosody Metrics',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildProsodyMetricCardLesson52(
                      'Speech Rate',
                      speechRate.wpm,
                      speechRate.status,
                      'Optimal: 140-160 WPM',
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildProsodyMetricCardLesson52(
                      'Pause Patterns',
                      '${pausePatterns.round()}%',
                      'Naturalness',
                      'Strategic pausing clarity',
                      Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildProsodyMetricCardLesson52(
                      'Professional Tone',
                      '${professionalTone.round()}%',
                      'Problem Resolution Ready',
                      '',
                      Colors.orange,
                    ),
                  ),
                  Expanded(child: Container()), // Empty space for balance
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.purple.shade300),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.analytics, color: Colors.purple, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Prosody Analysis:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.purple,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _generateProsodyAnalysisLesson52(
                          prosodyScore,
                          fluencyScore,
                        ),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ NEW METHOD 4: Prosody Metric Card
  Widget _buildProsodyMetricCardLesson52(
    String title,
    String value,
    String status,
    String description,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            status,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              description,
              style: const TextStyle(fontSize: 8, color: Colors.grey),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  // ✅ NEW METHOD 5: Word Pronunciation Analysis
  Widget _buildWordPronunciationAnalysisLesson52(List<dynamic> words) {
    if (words.isEmpty) return const SizedBox.shrink();

    final clearToCustomer = <String>[];
    final practiceNeeded = <String>[];
    final mayConfuseCustomer = <String>[];

    for (final wordData in words) {
      final word = wordData['word'] as String? ?? '';
      final accuracy = (wordData['accuracyScore'] as num?)?.toDouble() ?? 0.0;

      if (accuracy >= 95) {
        clearToCustomer.add(word);
      } else if (accuracy >= 75) {
        practiceNeeded.add(word);
      } else {
        mayConfuseCustomer.add(word);
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.text_fields, color: Colors.teal, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Word Pronunciation Analysis',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
              ),
              Text(
                '${words.length} words analyzed',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildWordCategorySummary(
                  clearToCustomer.length.toString(),
                  'Clear to Customer',
                  Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildWordCategorySummary(
                  practiceNeeded.length.toString(),
                  'Practice Needed',
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildWordCategorySummary(
                  mayConfuseCustomer.length.toString(),
                  'May Confuse Customer',
                  Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text(
              'Word-by-Word Pronunciation Analysis',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              'Click to expand detailed breakdown',
              style: TextStyle(fontSize: 12, color: Colors.blue),
            ),
            children: [_buildDetailedWordGridLesson52(words)],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb, color: Colors.blue, size: 16),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Problem Resolution Tip:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.blue,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Words marked with issues may be difficult for customers to understand when explaining problem solutions. Practice these for clearer communication.',
                        style: TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ NEW METHOD 6: Word Category Summary
  Widget _buildWordCategorySummary(String count, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            count,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: color,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ✅ NEW METHOD 7: Detailed Word Grid
  Widget _buildDetailedWordGridLesson52(List<dynamic> words) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.0,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: words.length,
      itemBuilder: (context, index) {
        final wordData = words[index] as Map<String, dynamic>;
        final word = wordData['word'] as String? ?? '';
        final accuracy = (wordData['accuracyScore'] as num?)?.toDouble() ?? 0.0;

        Color cardColor;
        String category;
        if (accuracy >= 95) {
          cardColor = Colors.green;
          category = 'EXCELLENT';
        } else if (accuracy >= 75) {
          cardColor = Colors.orange;
          category = 'GOOD';
        } else {
          cardColor = Colors.red;
          category = 'NEEDS WORK';
        }

        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: cardColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: cardColor.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  word,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: cardColor,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${accuracy.round()}%',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: cardColor,
                ),
              ),
              Flexible(
                child: Text(
                  category,
                  style: TextStyle(
                    fontSize: 7,
                    fontWeight: FontWeight.w500,
                    color: cardColor,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ✅ NEW METHOD 8: Service Metric Card Improved
  Widget _buildServiceMetricCardImproved(
    String name,
    double score,
    String description,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            name,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Text(
            '${score.round()}%',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (score / 100).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ✅ NEW METHOD 9: Quality Metric for Lesson 5.2
  Widget _buildQualityMetricLesson52(
    String title,
    dynamic score,
    String description,
    Color color, {
    bool isOutOfFive = false,
  }) {
    if (score == null) return const SizedBox.shrink();

    double scoreValue = (score as num).toDouble();
    String displayValue;
    double barValue;

    if (isOutOfFive && scoreValue <= 5) {
      barValue = (scoreValue / 5) * 100;
      displayValue = '${barValue.round()}%';
    } else {
      barValue = scoreValue;
      displayValue = '${scoreValue.round()}%';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              Text(
                displayValue,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (barValue / 100).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ NEW METHOD 10: Helper calculation methods
  ({String wpm, String status}) _calculateSpeechRate(double fluencyScore) {
    final normalizedFluency = fluencyScore > 5
        ? fluencyScore / 20
        : fluencyScore;
    final baseWPM = 145;
    final adjustment = (normalizedFluency - 3) * 8;
    final estimatedWPM = (baseWPM + adjustment).clamp(120, 180).round();

    String status;
    if (estimatedWPM >= 140 && estimatedWPM <= 160) {
      status = 'Excellent pace';
    } else if (estimatedWPM >= 130 && estimatedWPM <= 170) {
      status = 'Good pace';
    } else {
      status = 'Could improve';
    }

    return (wpm: '$estimatedWPM WPM', status: status);
  }

  double _calculatePausePatterns(double prosodyScore) {
    final normalizedProsody = prosodyScore > 5
        ? prosodyScore / 20
        : prosodyScore;
    return ((normalizedProsody / 5) * 100).clamp(0, 100);
  }

  double _calculateProfessionalToneFromAzure(
    double accuracy,
    double prosody,
    double fluency,
  ) {
    final normalizedProsody = prosody > 5 ? prosody : (prosody / 5) * 100;
    final normalizedFluency = fluency > 5 ? fluency : (fluency / 5) * 100;

    return ((accuracy * 0.4) +
            (normalizedProsody * 0.3) +
            (normalizedFluency * 0.3))
        .clamp(0.0, 100.0);
  }

  String _generateProsodyAnalysisLesson52(
    double prosodyScore,
    double fluencyScore,
  ) {
    final normalizedFluency = fluencyScore > 5
        ? fluencyScore / 20
        : fluencyScore;
    final normalizedProsody = prosodyScore > 5
        ? prosodyScore / 20
        : prosodyScore;

    final insights = <String>[];

    if (normalizedFluency >= 4) {
      insights.add("Your speech flows smoothly for clear problem explanations");
    } else if (normalizedFluency >= 3) {
      insights.add("Good problem-solving communication rhythm");
    } else {
      insights.add("Focus on smoother delivery for customer clarity");
    }

    if (normalizedProsody >= 4) {
      insights.add("Natural tone builds customer confidence in solutions");
    } else if (normalizedProsody >= 3) {
      insights.add("Appropriate tone for problem resolution calls");
    } else {
      insights.add(
        "Work on more reassuring speech patterns for problem resolution",
      );
    }

    return insights.join(". ") + ".";
  }

  Widget _buildProblemResolutionServiceMetricsImproved(
    Map<String, dynamic> azureFeedback,
    Map<String, dynamic>? aiCoachFeedback,
  ) {
    // Calculate metrics
    final clarity = (azureFeedback['accuracyScore'] as num?)?.toDouble() ?? 0.0;
    final accuracyVerification =
        (azureFeedback['completenessScore'] as num?)?.toDouble() ?? 0.0;
    final directness = _calculateDirectness(azureFeedback);
    final professionalism = _calculateProfessionalism(azureFeedback);
    final completeness =
        (azureFeedback['completenessScore'] as num?)?.toDouble() ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.handshake, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Call Center Service Metrics (AI-Analyzed)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ✅ IMPROVED: Row-by-row layout instead of compressed 3x2
          Column(
            children: [
              // Row 1: Clarity and Accuracy Verification
              Row(
                children: [
                  Expanded(
                    child: _buildServiceMetricCardImproved(
                      'Clarity',
                      clarity,
                      'How clear and unambiguous your problem explanation was',
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildServiceMetricCardImproved(
                      'Accuracy Verification',
                      accuracyVerification,
                      'How well you verified customer information',
                      Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Row 2: Directness and Professionalism
              Row(
                children: [
                  Expanded(
                    child: _buildServiceMetricCardImproved(
                      'Directness',
                      directness,
                      'How direct and specific your solution was',
                      Colors.purple,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildServiceMetricCardImproved(
                      'Professionalism',
                      professionalism,
                      'Professional tone appropriate for problem resolution',
                      Colors.indigo,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Row 3: Completeness (centered, single item)
              Row(
                children: [
                  Expanded(
                    child: _buildServiceMetricCardImproved(
                      'Completeness',
                      completeness,
                      'Whether you addressed all aspects of the customer problem',
                      Colors.teal,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Container()), // Empty space for balance
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProblemResolutionBreakdown(Map<String, dynamic> breakdown) {
    final accuracy = (breakdown['accuracy'] as num?)?.toDouble() ?? 0;
    final fluency = (breakdown['fluency'] as num?)?.toDouble() ?? 0;
    final overall = (breakdown['overall'] as num?)?.toDouble() ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Problem Resolution Skills Breakdown',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF00568D),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSkillMetric(
                  'Problem Analysis',
                  accuracy,
                  Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSkillMetric(
                  'Solution Communication',
                  fluency,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSkillMetric(
                  'Overall Resolution',
                  overall,
                  Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProblemResolutionAnalysis(Map<String, dynamic> breakdown) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.psychology, color: Colors.red, size: 20),
              SizedBox(width: 8),
              Text(
                'Overall Problem Resolution Performance',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Your problem-solving approach demonstrates advanced customer service skills. Continue practicing complex scenarios to build expertise in de-escalation and solution implementation.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.red,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProblemResolutionServiceMetrics(
    Map<String, dynamic> azureFeedback,
    Map<String, dynamic>? aiCoachFeedback,
  ) {
    // Calculate advanced service metrics based on problem resolution context
    final clarity = (azureFeedback['accuracyScore'] as num?)?.toDouble() ?? 0.0;

    // For problem resolution, we focus on different metrics
    final accuracyVerification =
        (azureFeedback['completenessScore'] as num?)?.toDouble() ?? 0.0;
    final directness = _calculateDirectness(azureFeedback);
    final professionalism = _calculateProfessionalism(azureFeedback);
    final completeness =
        (azureFeedback['completenessScore'] as num?)?.toDouble() ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.handshake, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Call Center Service Metrics (AI-Analyzed)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Service Metrics in a 3-column grid (matching web image)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade300),
            ),
            child: Column(
              children: [
                // First row: Clarity, Accuracy Verification, Directness
                Row(
                  children: [
                    Expanded(
                      child: _buildAdvancedServiceMetric(
                        'Clarity',
                        clarity,
                        'How clear and unambiguous your confirmation was',
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildAdvancedServiceMetric(
                        'Accuracy Verification',
                        accuracyVerification,
                        'How well you verified customer information before providing confirmation',
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildAdvancedServiceMetric(
                        'Directness',
                        directness,
                        'How direct and specific your confirmation statement was',
                        Colors.purple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Second row: Professionalism, Completeness
                Row(
                  children: [
                    Expanded(
                      child: _buildAdvancedServiceMetric(
                        'Professionalism',
                        professionalism,
                        'Professional tone and delivery appropriate for confirmation scenarios',
                        Colors.indigo,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildAdvancedServiceMetric(
                        'Completeness',
                        completeness,
                        'Whether you addressed all aspects of the confirmation request',
                        Colors.teal,
                      ),
                    ),
                    // Empty space for third column to maintain alignment
                    Expanded(child: Container()),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedServiceMetric(
    String name,
    double score,
    String description,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            '${score.round()}%',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (score / 100).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedQualityAnalysis(
    Map<String, dynamic>? azureFeedback,
    Map<String, dynamic>? aiCoachFeedback,
  ) {
    if (azureFeedback == null && aiCoachFeedback == null) {
      return const SizedBox.shrink();
    }

    // Calculate speech quality score for problem resolution
    final speechQualityScore = _calculateAdvancedSpeechQuality(azureFeedback);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.bar_chart, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Speech Quality Analysis',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Overall Score Display
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                const Text(
                  'Speech Quality Score',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${speechQualityScore.round()}%',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: _getScoreColor(speechQualityScore),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Based on pronunciation, fluency, and delivery',
                  style: TextStyle(fontSize: 12, color: Colors.blue),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: (speechQualityScore / 100).clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _getScoreColor(speechQualityScore),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _generateAdvancedSpeechAssessment(speechQualityScore),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.blue,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Key Speech Metrics
          if (azureFeedback != null) ...[
            const Text(
              'Key Speech Metrics',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildQualityMetric(
                    'Pronunciation Clarity',
                    azureFeedback['accuracyScore'],
                    'How clearly each word was pronounced',
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQualityMetric(
                    'Speech Flow',
                    azureFeedback['fluencyScore'],
                    'Smoothness and naturalness of delivery',
                    Colors.blue,
                    isOutOfFive: true,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQualityMetric(
    String title,
    dynamic score,
    String description,
    Color color, {
    bool isOutOfFive = false,
  }) {
    if (score == null) return const SizedBox.shrink();

    double scoreValue = (score as num).toDouble();
    String displayValue;
    double barValue;

    if (isOutOfFive && scoreValue <= 5) {
      // Convert 0-5 scale to percentage for display
      barValue = (scoreValue / 5) * 100;
      displayValue = '${barValue.round()}%';
    } else {
      barValue = scoreValue;
      displayValue = '${scoreValue.round()}%';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              Text(
                displayValue,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (barValue / 100).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper calculation methods
  double _calculateDirectness(Map<String, dynamic> azureFeedback) {
    // Calculate directness based on completeness and accuracy
    final accuracy =
        (azureFeedback['accuracyScore'] as num?)?.toDouble() ?? 0.0;
    final completeness =
        (azureFeedback['completenessScore'] as num?)?.toDouble() ?? 0.0;

    // Directness is a combination of accuracy and completeness
    return ((accuracy * 0.6) + (completeness * 0.4)).clamp(0.0, 100.0);
  }

  double _calculateProfessionalism(Map<String, dynamic> azureFeedback) {
    // Calculate professionalism based on prosody and fluency
    final prosody = (azureFeedback['prosodyScore'] as num?)?.toDouble() ?? 0.0;
    final fluency = (azureFeedback['fluencyScore'] as num?)?.toDouble() ?? 0.0;

    // Normalize prosody and fluency if they're on 0-5 scale
    double normalizedProsody = prosody > 5 ? prosody : (prosody / 5) * 100;
    double normalizedFluency = fluency > 5 ? fluency : (fluency / 5) * 100;

    return ((normalizedProsody * 0.7) + (normalizedFluency * 0.3)).clamp(
      0.0,
      100.0,
    );
  }

  double _calculateAdvancedSpeechQuality(Map<String, dynamic>? azureFeedback) {
    if (azureFeedback == null) return 75.0;

    final accuracy =
        (azureFeedback['accuracyScore'] as num?)?.toDouble() ?? 0.0;
    final fluency = (azureFeedback['fluencyScore'] as num?)?.toDouble() ?? 0.0;
    final completeness =
        (azureFeedback['completenessScore'] as num?)?.toDouble() ?? 0.0;
    final prosody = (azureFeedback['prosodyScore'] as num?)?.toDouble() ?? 0.0;

    // Normalize fluency and prosody if needed
    double normalizedFluency = fluency > 5 ? fluency : (fluency / 5) * 100;
    double normalizedProsody = prosody > 5 ? prosody : (prosody / 5) * 100;

    // Weighted calculation for problem resolution context
    return ((accuracy * 0.4) +
            (normalizedFluency * 0.3) +
            (completeness * 0.2) +
            (normalizedProsody * 0.1))
        .clamp(0.0, 100.0);
  }

  String _generateAdvancedSpeechAssessment(double score) {
    if (score >= 90) {
      return "Excellent speech quality! Your pronunciation and delivery are very clear and professional for problem resolution.";
    } else if (score >= 80) {
      return "Very good speech quality. Minor improvements in pronunciation or flow could enhance customer understanding.";
    } else if (score >= 70) {
      return "Good speech quality for problem resolution. Focus on clarity when explaining solutions.";
    } else if (score >= 60) {
      return "Developing speech skills. Continue practicing clear communication for complex scenarios.";
    } else {
      return "Keep practicing speech delivery. Focus on clear pronunciation when handling customer problems.";
    }
  }

  List<Widget> _buildLesson5_1Details(Map<String, dynamic> detailedResponses) {
    final promptDetails =
        detailedResponses['promptDetails'] as List<dynamic>? ?? [];
    final overallScore =
        (detailedResponses['overallScore'] as num?)?.round() ?? 0;
    final timeSpent = (detailedResponses['timeSpent'] as num?)?.round() ?? 0;
    final callCenterBreakdown =
        detailedResponses['callCenterReadinessBreakdown']
            as Map<String, dynamic>?;

    if (promptDetails.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.grey),
              SizedBox(width: 8),
              Text('No call simulation data found for this attempt.'),
            ],
          ),
        ),
      ];
    }

    // Filter only Agent turns (the ones the user performed)
    final agentTurns = promptDetails
        .where((turn) => turn['character'] == 'Agent - Your Turn')
        .toList();

    return [
      // Call Center Readiness Header
      _buildCallCenterReadinessHeader(
        overallScore,
        agentTurns.length,
        timeSpent,
        callCenterBreakdown,
      ),
      const SizedBox(height: 20),

      // Turn-by-Turn Analysis
      const Text(
        'Turn-by-Turn Performance Analysis',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF00568D),
        ),
      ),
      const SizedBox(height: 12),

      // Individual Turn Details
      ...agentTurns.asMap().entries.map<Widget>((entry) {
        final index = entry.key;
        final turn = entry.value as Map<String, dynamic>;
        return Column(
          children: [
            _buildCallSimulationTurnDetail(turn, index + 1),
            const SizedBox(height: 16),
          ],
        );
      }).toList(),

      // Overall Call Flow Analysis
      if (callCenterBreakdown != null)
        _buildCallFlowAnalysis(callCenterBreakdown),
    ];
  }

  Widget _buildCallCenterReadinessHeader(
    int overallScore,
    int totalAgentTurns,
    int timeSpent,
    Map<String, dynamic>? breakdown,
  ) {
    final minutes = timeSpent ~/ 60;
    final seconds = timeSpent % 60;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.green.shade50, Colors.blue.shade50],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.call, color: Colors.green, size: 28),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Call Center Simulation Results',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    Text(
                      'Customer service call performance analysis',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Call Center Stats Row
          Row(
            children: [
              Expanded(
                child: _buildSummaryStatCard(
                  'Call Readiness',
                  '$overallScore%',
                  Icons.verified_user,
                  _getScoreColor(overallScore.toDouble()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryStatCard(
                  'Agent Turns',
                  '$totalAgentTurns',
                  Icons.record_voice_over,
                  Colors.indigo,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryStatCard(
                  'Call Duration',
                  '${minutes}m ${seconds}s',
                  Icons.timer,
                  Colors.orange,
                ),
              ),
            ],
          ),

          // Call Center Breakdown if available
          if (breakdown != null) ...[
            const SizedBox(height: 16),
            _buildCallCenterBreakdown(breakdown),
          ],
        ],
      ),
    );
  }

  Widget _buildCallCenterBreakdown(Map<String, dynamic> breakdown) {
    final accuracy = (breakdown['accuracy'] as num?)?.toDouble() ?? 0;
    final fluency = (breakdown['fluency'] as num?)?.toDouble() ?? 0;
    final overall = (breakdown['overall'] as num?)?.toDouble() ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Call Center Skills Breakdown',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF00568D),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSkillMetric(
                  'Customer Understanding',
                  accuracy,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSkillMetric(
                  'Professional Flow',
                  fluency,
                  Colors.blue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSkillMetric(String label, double value, Color color) {
    return Column(
      children: [
        Text(
          '${value.round()}%',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: (value / 100).clamp(0.0, 1.0),
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 4,
        ),
      ],
    );
  }

  Widget _buildCallSimulationTurnDetail(
    Map<String, dynamic> turn,
    int turnNumber,
  ) {
    final turnText = turn['text'] as String? ?? 'Turn text not available';
    final transcription =
        turn['transcription'] as String? ?? 'No transcription available';
    final score = turn['score'] as num?;
    final azureFeedback = turn['azureAiFeedback'] as Map<String, dynamic>?;
    final aiCoachFeedback =
        turn['openAiDetailedFeedback'] as Map<String, dynamic>?;
    final audioUrl = turn['audioUrl'] as String?;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.all(20),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green, Colors.green.shade700],
            ),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$turnNumber',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Response $turnNumber',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _truncateText(turnText, 60),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (score != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _getScoreColor(score.toDouble()),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${score.round()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.expand_more),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),

                // Audio Player Section
                if (audioUrl != null) _buildAudioPlayerSection(audioUrl),

                // Transcription Section
                _buildTranscriptionSection(transcription),

                // Azure Speech Analysis
                if (azureFeedback != null)
                  _buildAzureSpeechAnalysis(azureFeedback),

                // ✅ ADD THIS MISSING SECTION HERE
                if (azureFeedback != null)
                  _buildCallCenterServiceMetricsCard(azureFeedback),

                // AI Coach Analysis
                if (aiCoachFeedback != null)
                  _buildAICoachAnalysis(aiCoachFeedback),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAzureSpeechAnalysis(Map<String, dynamic> azure) {
    final accuracy = (azure['accuracyScore'] as num?)?.toDouble() ?? 0;
    final fluency = (azure['fluencyScore'] as num?)?.toDouble() ?? 0;
    final completeness = (azure['completenessScore'] as num?)?.toDouble() ?? 0;
    final prosody = (azure['prosodyScore'] as num?)?.toDouble() ?? 0;

    // Normalize fluency and prosody if they're on 0-5 scale
    final normalizedFluency = fluency > 5 ? fluency : (fluency * 20);
    final normalizedProsody = prosody > 5 ? prosody : (prosody * 20);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.analytics, color: Colors.blue, size: 20),
              SizedBox(width: 8),
              Text(
                'Speech Quality Analysis',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Replace GridView with Column and Rows for better mobile layout
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildCompactSpeechMetricCard(
                      'Accuracy',
                      accuracy,
                      Icons.gps_fixed,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildCompactSpeechMetricCard(
                      'Fluency',
                      normalizedFluency,
                      Icons.speed,
                      Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildCompactSpeechMetricCard(
                      'Completeness',
                      completeness,
                      Icons.assignment_turned_in,
                      Colors.purple,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildCompactSpeechMetricCard(
                      'Prosody',
                      normalizedProsody,
                      Icons.multitrack_audio,
                      Colors.orange,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactSpeechMetricCard(
    String label,
    double value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${value.round()}%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeechMetricCard(
    String label,
    double value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // ✅ Prevent expansion
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 2),
          Flexible(
            // ✅ Make text flexible
            child: Text(
              label,
              style: const TextStyle(fontSize: 9, color: Colors.grey),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${value.round()}%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAICoachAnalysis(Map<String, dynamic> aiCoach) {
    final overallScore = (aiCoach['overallScore'] as num?)?.toDouble() ?? 0;
    final summary =
        aiCoach['summary'] as String? ?? 'No AI analysis summary available.';
    final criteria =
        (aiCoach['criteria'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
        [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with flexible layout
          Column(
            // Changed from Row to Column to prevent overflow
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.psychology, color: Colors.teal, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'AI Call Center Coach Analysis',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getScoreColor(overallScore),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${overallScore.round()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            summary,
            style: TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: Colors.teal.shade700,
            ),
          ),
          if (criteria.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Detailed Analysis:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 8),
            ...criteria.map((criterion) {
              final name = criterion['name'] as String? ?? 'Criterion';
              final score = (criterion['score'] as num?)?.toDouble() ?? 0;
              final feedback =
                  criterion['feedback'] as String? ?? 'No feedback available.';

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Fixed Row with proper flex handling
                    Row(
                      children: [
                        Expanded(
                          // ✅ FIX: Wrap criterion name with Expanded
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            overflow:
                                TextOverflow.ellipsis, // ✅ Handle overflow
                            maxLines: 2, // Allow wrapping to 2 lines if needed
                          ),
                        ),
                        const SizedBox(width: 8), // ✅ Add spacing
                        // Score badge - fixed width to prevent expansion
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getScoreColor(score),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${score.round()}%',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      feedback,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildCallFlowAnalysis(Map<String, dynamic> breakdown) {
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
          const Row(
            children: [
              Icon(Icons.route, color: Colors.indigo, size: 20),
              SizedBox(width: 8),
              Text(
                'Overall Call Flow Performance',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Your call handling demonstrates professional customer service skills. Continue practicing to maintain consistency across all interactions.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.indigo,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  // Add this method to _buildDetailedFeedback in lesson_activity_log_page.dart
  List<Widget> _buildLesson4_2Details(Map<String, dynamic> detailedResponses) {
    final solutionResponses =
        detailedResponses['solutionResponses_L4_2'] as Map<String, dynamic>? ??
        {};
    final aiFeedback =
        detailedResponses['solutionFeedback_L4_2'] as Map<String, dynamic>? ??
        {};

    if (solutionResponses.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.grey),
              SizedBox(width: 8),
              Text('No solution responses found for this attempt.'),
            ],
          ),
        ),
      ];
    }

    return solutionResponses.entries.map((entry) {
      final solutionName = entry.key;
      final userResponse = entry.value as String;
      final solutionFeedback = aiFeedback[solutionName];

      return Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Solution header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF8a2be2),
                    const Color(0xFF8a2be2).withOpacity(0.8),
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
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.lightbulb,
                        color: Color(0xFF8a2be2),
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      solutionName.replaceAll('solution', 'Solution '),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content area
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User response section
                  const Text(
                    'Your Solution:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF8a2be2),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      '"$userResponse"',
                      style: const TextStyle(
                        fontSize: 15,
                        fontStyle: FontStyle.italic,
                        color: Colors.black87,
                      ),
                    ),
                  ),

                  // AI Feedback section
                  if (solutionFeedback != null) ...[
                    const SizedBox(height: 20),
                    AiFeedbackDisplayCard(
                      feedbackData: Map<String, dynamic>.from(solutionFeedback),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildConfirmationReadinessSection(Map<String, dynamic> breakdown) {
    final accuracy = (breakdown['accuracy'] as num?)?.toDouble() ?? 0.0;
    final fluency = (breakdown['fluency'] as num?)?.toDouble() ?? 0.0;
    final overall = (breakdown['overall'] as num?)?.toDouble() ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.check_circle,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Confirmation Readiness Breakdown',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Three key metrics for confirmation readiness
          Row(
            children: [
              Expanded(
                child: _buildConfirmationMetricCard(
                  'Accuracy',
                  accuracy,
                  'Pronunciation accuracy for clear confirmations',
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildConfirmationMetricCard(
                  'Fluency',
                  fluency,
                  'Natural flow for professional confirmations',
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildConfirmationMetricCard(
                  'Overall Readiness',
                  overall,
                  'Combined confirmation capability',
                  Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationMetricCard(
    String label,
    double score,
    String description,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            '${score.round()}%',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (score / 100).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildCallCenterServiceMetrics(Map<String, double> metrics) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.headset_mic,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Call Center Service Analysis',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.green,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Service metrics in a simple vertical layout
          _buildServiceMetricItem(
            'Customer Understanding',
            metrics['customerUnderstanding'] ?? 0.0,
            'Based on pronunciation accuracy',
            Colors.green,
          ),
          const SizedBox(height: 12),
          _buildServiceMetricItem(
            'Professional Flow',
            metrics['professionalFlow'] ?? 0.0,
            'Combines fluency and prosody for natural conversation',
            Colors.blue,
          ),
          const SizedBox(height: 12),
          _buildServiceMetricItem(
            'Task Completion',
            metrics['taskCompletion'] ?? 0.0,
            'How completely you addressed the customer request',
            Colors.purple,
          ),
        ],
      ),
    );
  }

  Widget _buildServiceMetricItem(
    String title,
    double score,
    String description,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                title.contains('Understanding')
                    ? Icons.visibility
                    : title.contains('Flow')
                    ? Icons.timeline
                    : Icons.assignment_turned_in,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              Text(
                '${score.round()}%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (score / 100).clamp(0.0, 1.0),
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 4,
          ),
        ],
      ),
    );
  }

  double _calculateProfessionalFlow(Map<String, dynamic> azureFeedback) {
    // ✅ FIX: Ensure safe casting to double
    final fluency = (azureFeedback['fluencyScore'] as num?)?.toDouble() ?? 0.0;
    final prosody = (azureFeedback['prosodyScore'] as num?)?.toDouble() ?? 0.0;

    // Normalize if needed
    double normalizedFluency = fluency > 5 ? fluency : (fluency / 5) * 100;
    double normalizedProsody = prosody > 5 ? prosody : (prosody / 5) * 100;

    return (normalizedFluency + normalizedProsody) / 2;
  }

  IconData _getServiceMetricIcon(String metric) {
    switch (metric.toLowerCase()) {
      case 'clarity':
        return Icons.visibility;
      case 'accuracy':
        return Icons.check_circle;
      case 'directness':
        return Icons.straighten;
      case 'professionalism':
        return Icons.business;
      case 'completeness':
        return Icons.assignment_turned_in;
      default:
        return Icons.analytics;
    }
  }

  Widget _buildWebStyleEnhancedProsodySection(
    Map<String, dynamic>? prosodyData,
  ) {
    if (prosodyData == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.music_note, color: Colors.purple, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Enhanced Prosody Metrics',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Column(
            children: [
              _buildWebStyleProsodyMetric(
                'Speech Rate',
                '158 WPM',
                'Excellent pace',
                'Optimal: 140-160 WPM',
                Colors.green,
              ),
              const SizedBox(height: 8),
              _buildWebStyleProsodyMetric(
                'Pause Patterns',
                '81%',
                'Naturalness',
                'Strategic pausing for clarity',
                Colors.blue,
              ),
              const SizedBox(height: 8),
              _buildWebStyleProsodyMetric(
                'Professional Tone',
                '89%',
                'Confirmation Ready',
                '',
                Colors.orange,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Prosody Analysis (like web)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.purple.shade300),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.analytics, color: Colors.purple, size: 16),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Prosody Analysis:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.purple,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Your speech flows smoothly for clear confirmations. Natural tone builds customer trust.',
                        style: TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebStyleWordPronunciationSection(List<dynamic> words) {
    if (words.isEmpty) return const SizedBox.shrink();

    // Categorize words (like web)
    final clearToCustomer = <String>[];
    final practiceNeeded = <String>[];
    final mayConfuseCustomer = <String>[];

    for (final wordData in words) {
      final word = wordData['word'] as String? ?? '';
      final accuracy = (wordData['accuracyScore'] as num?)?.toDouble() ?? 0.0;

      if (accuracy >= 95) {
        clearToCustomer.add(word);
      } else if (accuracy >= 75) {
        practiceNeeded.add(word);
      } else {
        mayConfuseCustomer.add(word);
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.text_fields, color: Colors.teal, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Word Pronunciation Analysis',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
              ),
              Text(
                '${words.length} words analyzed',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Word category summary (like web)
          Row(
            children: [
              Expanded(
                child: _buildWebStyleWordCategory(
                  clearToCustomer.length.toString(),
                  'Clear to Customer',
                  Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildWebStyleWordCategory(
                  practiceNeeded.length.toString(),
                  'Practice Needed',
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildWebStyleWordCategory(
                  mayConfuseCustomer.length.toString(),
                  'May Confuse Customer',
                  Colors.red,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Word-by-Word expandable section (like web)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text(
              'Word-by-Word Pronunciation Analysis',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              'Click to expand detailed breakdown',
              style: TextStyle(fontSize: 12, color: Colors.blue),
            ),
            children: [_buildDetailedWordGrid(words)],
          ),

          const SizedBox(height: 12),

          // Confirmation tip (like web)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb, color: Colors.blue, size: 16),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Confirmation Tip:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.blue,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Words marked with issues may be difficult for customers to understand when confirming important details. Practice these for clearer confirmations.',
                        style: TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebStyleMetricCard(
    String label,
    dynamic score,
    IconData icon,
    Color color, {
    bool isPercentage = true,
    double maxValue = 100,
  }) {
    if (score == null) return const SizedBox.shrink();

    double scoreValue = (score as num).toDouble();
    if (!isPercentage && maxValue == 5 && scoreValue > 5) {
      scoreValue = (scoreValue / 100) * 5;
    }

    final displayValue = isPercentage
        ? '${scoreValue.round()}%'
        : '${scoreValue.toStringAsFixed(1)}/$maxValue';

    return Container(
      padding: const EdgeInsets.all(6), // ✅ Reduced from 12 to 6
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6), // ✅ Reduced from 8 to 6
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min, // ✅ Added to prevent expansion
        children: [
          // ✅ Simplified header - icon OR text, not both
          Icon(icon, size: 12, color: color), // ✅ Reduced from 16 to 12
          const SizedBox(height: 2), // ✅ Reduced from 4 to 2
          Text(
            label,
            style: TextStyle(
              fontSize: 9, // ✅ Reduced from 12 to 9
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 1, // ✅ Added to prevent wrapping
          ),
          const SizedBox(height: 2), // ✅ Reduced from 8 to 2
          Text(
            displayValue,
            style: TextStyle(
              fontSize: 14, // ✅ Reduced from 18 to 14
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2), // ✅ Reduced from 8 to 2
          Container(
            height: 2, // ✅ Reduced from 4 to 2
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(1),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (scoreValue / (isPercentage ? 100 : maxValue)).clamp(
                0.0,
                1.0,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebStyleProsodyMetric(
    String title,
    String value,
    String status,
    String description,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(8), // ✅ Reduced from 12 to 8
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6), // ✅ Reduced from 8 to 6
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // ✅ Added to prevent expansion
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 9, // ✅ Reduced from 10 to 9
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
            maxLines: 1, // ✅ Added to prevent wrapping
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2), // ✅ Reduced from 4 to 2
          Text(
            value,
            style: TextStyle(
              fontSize: 14, // ✅ Reduced from 16 to 14
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2), // ✅ Reduced from 4 to 2
          Text(
            status,
            style: TextStyle(
              fontSize: 8, // ✅ Reduced from 9 to 8
              color: color,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1, // ✅ Added to prevent wrapping
            overflow: TextOverflow.ellipsis,
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 1), // ✅ Reduced from 2 to 1
            Text(
              description,
              style: const TextStyle(
                fontSize: 7,
                color: Colors.grey,
              ), // ✅ Reduced from 8 to 7
              textAlign: TextAlign.center,
              maxLines: 1, // ✅ Reduced from 2 to 1
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWebStyleWordCategory(String count, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            count,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: color,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildWebStyleKeyMetric(
    String title,
    String value,
    String description,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: 0.9,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsibleAnalysisSection({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
    bool initiallyExpanded = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: color,
          ),
        ),
        subtitle: Text(
          'Tap to expand analysis',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        children: [child],
      ),
    );
  }

  Widget _buildAIQualityAnalysisSection(Map<String, dynamic> aiCoachAnalysis) {
    final overallScore =
        (aiCoachAnalysis['overallScore'] as num?)?.toDouble() ?? 0.0;
    final strengths = (aiCoachAnalysis['strengths'] as List<dynamic>?) ?? [];
    final improvementAreas =
        (aiCoachAnalysis['improvementAreas'] as List<dynamic>?) ?? [];
    final specificFeedback =
        aiCoachAnalysis['specificFeedback'] as String? ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Overall Score Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple.shade50, Colors.purple.shade100],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.purple.shade200),
          ),
          child: Column(
            children: [
              Text(
                '${overallScore.round()}%',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: _getScoreColor(overallScore),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Overall Performance Score',
                style: TextStyle(fontSize: 14, color: Colors.purple),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Specific Feedback
        if (specificFeedback.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.purple.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Detailed Feedback:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  specificFeedback,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Strengths
        if (strengths.isNotEmpty) ...[
          _buildFeedbackSection(
            'Strengths',
            strengths,
            Colors.green,
            Icons.star,
          ),
          const SizedBox(height: 16),
        ],

        // Improvement Areas
        if (improvementAreas.isNotEmpty) ...[
          _buildFeedbackSection(
            'Areas for Improvement',
            improvementAreas,
            Colors.orange,
            Icons.trending_up,
          ),
        ],
      ],
    );
  }

  Widget _buildProsodyMetricRow(
    String title,
    String value,
    String status,
    String description,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(fontSize: 9, color: Colors.grey),
                textAlign: TextAlign.right,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWordCategorySection(
    String title,
    List<dynamic> words,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                color == Colors.green
                    ? Icons.check_circle
                    : color == Colors.orange
                    ? Icons.warning
                    : Icons.error,
                color: color,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: words
                .map(
                  (word) => Chip(
                    label: Text(
                      word.toString(),
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: color.withOpacity(0.1),
                    side: BorderSide(color: color.withOpacity(0.3)),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCriterionCard(Map<String, dynamic> criterion) {
    final name = criterion['name'] as String? ?? '';
    final score = (criterion['score'] as num?)?.toDouble() ?? 0.0;
    final feedback = criterion['feedback'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '${score.round()}%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _getScoreColor(score),
                ),
              ),
            ],
          ),
          if (feedback.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              feedback,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (score / 100).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: _getScoreColor(score),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackSection(
    String title,
    List<dynamic> items,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Text(
                '$title:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold),
                  ),
                  Expanded(
                    child: Text(
                      item.toString(),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProsodyMetricCard(
    String title,
    String value,
    String subtitle,
    String description,
    Color color,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10), // 🔧 Reduced from 12 to 10
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          // Left side - Title and subtitle
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Right side - Value and description
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14, // 🔧 Reduced from 16 to 14
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  textAlign: TextAlign.right,
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 8, color: Colors.grey),
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordCategoryCard(String title, int count, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: color,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedWordGrid(List<dynamic> words) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, // 🔧 Reduced from 4 to 3 columns for better fit
        childAspectRatio: 1.0, // 🔧 Adjusted for better proportions
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: words.length,
      itemBuilder: (context, index) {
        final wordData = words[index] as Map<String, dynamic>;
        final word = wordData['word'] as String? ?? '';
        final accuracy = (wordData['accuracyScore'] as num?)?.toDouble() ?? 0.0;

        Color cardColor;
        String category;
        if (accuracy >= 95) {
          cardColor = Colors.green;
          category = 'EXCELLENT';
        } else if (accuracy >= 82) {
          cardColor = Colors.orange;
          category = 'GOOD';
        } else {
          cardColor = Colors.red;
          category = 'NEEDS WORK';
        }

        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: cardColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: cardColor.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                // 🔧 Wrap with Flexible to prevent overflow
                child: Text(
                  word,
                  style: TextStyle(
                    fontSize: 11, // 🔧 Reduced from 12 to 11
                    fontWeight: FontWeight.bold,
                    color: cardColor,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${accuracy.round()}%',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: cardColor,
                ),
              ),
              Flexible(
                // 🔧 Wrap with Flexible
                child: Text(
                  category,
                  style: TextStyle(
                    fontSize: 7, // 🔧 Reduced from 8 to 7
                    fontWeight: FontWeight.w500,
                    color: cardColor,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Helper Methods
  Widget _buildKeyMetricCard(
    String title,
    String value,
    String description,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: 0.9,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSpeechQualityMetricCard(
    String label,
    dynamic score,
    IconData icon,
    Color color, {
    double maxValue = 100,
    bool isPercentage = true,
  }) {
    if (score == null) return const SizedBox.shrink();

    double scoreValue = (score as num).toDouble();
    if (!isPercentage && maxValue == 5 && scoreValue > 5) {
      scoreValue = (scoreValue / 100) * 5;
    }

    final displayValue = isPercentage
        ? '${scoreValue.round()}%'
        : '${scoreValue.toStringAsFixed(1)}/$maxValue';
    final normalizedValue = isPercentage
        ? scoreValue / 100
        : scoreValue / maxValue;

    return Container(
      padding: const EdgeInsets.all(8), // 🔧 Reduced from 12 to 8
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8), // 🔧 Reduced from 12 to 8
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color), // 🔧 Reduced from 16 to 14
              const SizedBox(width: 4),
              Expanded(
                // 🔧 Wrap with Expanded to prevent overflow
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11, // 🔧 Reduced from 12 to 11
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4), // 🔧 Reduced from 8 to 4
          Text(
            displayValue,
            style: TextStyle(
              fontSize: 16, // 🔧 Reduced from 18 to 16
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4), // 🔧 Reduced from 8 to 4
          Container(
            height: 3, // 🔧 Reduced from 4 to 3
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: normalizedValue.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedCoachAnalysis(Map<String, dynamic> aiCoachFeedback) {
    // Enhanced version of the coach analysis for advanced lesson
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade50, Colors.indigo.shade50],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.purple,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.psychology,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Advanced AI Coach Analysis',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.purple,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Use the existing coach feedback display logic
          if (aiCoachFeedback['feedback'] is List)
            _buildStructuredCoachFeedback(aiCoachFeedback)
          else
            AiFeedbackDisplayCard(feedbackData: aiCoachFeedback),
        ],
      ),
    );
  }

  Widget _buildTurnAnalysisCard(Map<String, dynamic> turn, int index) {
    final text = turn['text'] as String? ?? '';
    final transcription =
        turn['transcription'] as String? ?? 'No transcription recorded.';
    final score = turn['score'] as num?;
    final azureFeedback = turn['azureAiFeedback'] as Map<String, dynamic>?;
    final openAiFeedback =
        turn['openAiDetailedFeedback'] as Map<String, dynamic>?;
    final audioUrl = turn['audioUrl'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.all(16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00BCD4), Color(0xFF0097A7)],
            ),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '${(index ~/ 2) + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Response (${(index ~/ 2) + 1})',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF00BCD4),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _truncateText(text, 60),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (score != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getScoreColor((score as num).toDouble()),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${score.round()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.expand_more),
          ],
        ),
        children: [
          // Audio Player Section (if available)
          if (audioUrl != null) _buildAudioPlayerSection(audioUrl),

          // Transcription Section
          _buildTranscriptionSection(transcription),

          // ✅ NEW: Collapsible Analysis Sections
          const Text(
            'Detailed Analysis Available',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF00BCD4),
            ),
          ),
          const SizedBox(height: 12),

          // Speech Quality Analysis (Collapsible)
          if (azureFeedback != null)
            _buildCollapsibleAnalysisSection(
              title: 'Speech Analysis',
              icon: Icons.graphic_eq,
              color: Colors.blue,
              child: _buildBasicSpeechQualityAnalysis(azureFeedback),
            ),

          // Call Center Service Analysis (Collapsible) - NEW SECTION
          if (azureFeedback != null)
            _buildCollapsibleAnalysisSection(
              title: 'Call Center Service Analysis',
              icon: Icons.headset_mic,
              color: Colors.green,
              child: _buildCallCenterServiceMetricsCard(azureFeedback),
              initiallyExpanded: false,
            ),

          // AI Call Center Coach Analysis (Collapsible)
          if (openAiFeedback != null)
            _buildCollapsibleAnalysisSection(
              title: 'AI Coach Analysis',
              icon: Icons.psychology,
              color: Colors.indigo,
              child: _buildCallCenterCoachAnalysis(openAiFeedback),
            ),
        ],
      ),
    );
  }

  Widget _buildCallCenterServiceMetricsCard(
    Map<String, dynamic> azureFeedback,
  ) {
    // Calculate service metrics from Azure feedback
    final customerUnderstanding =
        (azureFeedback['accuracyScore'] as num?)?.toDouble() ?? 0.0;
    final professionalFlow = _calculateProfessionalFlow(azureFeedback);
    final taskCompletion =
        (azureFeedback['completenessScore'] as num?)?.toDouble() ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.headset_mic,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Call Center Service Analysis',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.green,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Service Metrics Row (like in the web image)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade300),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildServiceMetricColumn(
                    '${customerUnderstanding.round()}%',
                    'Customer Understanding',
                    Colors.green,
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.grey.shade300),
                Expanded(
                  child: _buildServiceMetricColumn(
                    '${professionalFlow.round()}%',
                    'Professional Flow',
                    Colors.blue,
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.grey.shade300),
                Expanded(
                  child: _buildServiceMetricColumn(
                    '${taskCompletion.round()}%',
                    'Task Completion',
                    Colors.purple,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Description text
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.green.shade700,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'These metrics evaluate your readiness for call center service based on speech clarity, professional communication flow, and task completion capabilities.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade700,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceMetricColumn(
    String percentage,
    String label,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          percentage,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildCallCenterCoachAnalysis(Map<String, dynamic> aiCoachFeedback) {
    final overallScore =
        (aiCoachFeedback['overallScore'] as num?)?.toDouble() ?? 0.0;
    final criteria =
        (aiCoachFeedback['criteria'] as List<dynamic>?)
            ?.map((c) => c as Map<String, dynamic>)
            .toList() ??
        [];

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
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.indigo,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.psychology,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'AI Call Center Coach Analysis',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.indigo,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Overall Score
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getScoreColor(overallScore).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _getScoreColor(overallScore).withOpacity(0.3),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    '${overallScore.round()}%',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: _getScoreColor(overallScore),
                    ),
                  ),
                  const Text(
                    'AI Call Center Readiness',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Detailed Criteria
          const Text(
            'Detailed AI Analysis:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.indigo,
            ),
          ),
          const SizedBox(height: 12),

          ...criteria.map((criterion) {
            final name = criterion['name'] as String? ?? 'Criterion';
            final score = (criterion['score'] as num?)?.toDouble() ?? 0.0;
            final feedback =
                criterion['feedback'] as String? ?? 'No feedback available.';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${score.round()}%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _getScoreColor(score),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    feedback,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildCallCenterServiceAnalysis(Map<String, dynamic> azureFeedback) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.headset_mic,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Call Center Service Analysis',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.green,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Service metrics in a simple vertical layout
          _buildServiceMetricItem(
            'Customer Understanding',
            (azureFeedback['accuracyScore'] as num?)?.toDouble() ?? 0.0,
            'Based on pronunciation accuracy',
            Colors.green,
          ),
          const SizedBox(height: 12),
          _buildServiceMetricItem(
            'Professional Flow',
            _calculateProfessionalFlow(azureFeedback),
            'Combines fluency and prosody for natural conversation',
            Colors.blue,
          ),
          const SizedBox(height: 12),
          _buildServiceMetricItem(
            'Task Completion',
            (azureFeedback['completenessScore'] as num?)?.toDouble() ?? 0.0,
            'How completely you addressed the customer request',
            Colors.purple,
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleMetricCard(
    String label,
    dynamic score,
    IconData icon,
    Color color, {
    double maxValue = 100,
    bool isPercentage = true,
  }) {
    if (score == null) return const SizedBox.shrink();

    double scoreValue = (score as num).toDouble();
    if (!isPercentage && maxValue == 5 && scoreValue > 5) {
      scoreValue = (scoreValue / 100) * 5;
    }

    final displayValue = isPercentage
        ? '${scoreValue.round()}%'
        : '${scoreValue.toStringAsFixed(1)}/$maxValue';

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            displayValue,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicSpeechQualityAnalysis(Map<String, dynamic> azureFeedback) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.graphic_eq,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Speech Quality Analysis',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.blue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Simple 2x2 grid of basic metrics
          // Replace the GridView.count with this simpler layout
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildSimpleMetricCard(
                      'Accuracy',
                      azureFeedback['accuracyScore'],
                      Icons.check_circle,
                      Colors.green,
                      isPercentage: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSimpleMetricCard(
                      'Fluency',
                      azureFeedback['fluencyScore'],
                      Icons.timeline,
                      Colors.blue,
                      isPercentage: false,
                      maxValue: 5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildSimpleMetricCard(
                      'Completeness',
                      azureFeedback['completenessScore'],
                      Icons.assignment_turned_in,
                      Colors.purple,
                      isPercentage: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSimpleMetricCard(
                      'Prosody',
                      azureFeedback['prosodyScore'],
                      Icons.music_note,
                      Colors.orange,
                      isPercentage: false,
                      maxValue: 5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCallCenterAnalysis(Map<String, dynamic> aiCoachFeedback) {
    final overallScore =
        (aiCoachFeedback['overallScore'] as num?)?.toDouble() ?? 0.0;
    final criteria =
        (aiCoachFeedback['criteria'] as List<dynamic>?)
            ?.map((c) => c as Map<String, dynamic>)
            .toList() ??
        [];

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
          // Header - FIX: Wrap with Expanded to prevent overflow
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.indigo,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.psychology,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                // ✅ FIX: Wrap with Expanded
                child: Text(
                  'AI Call Center Coach Analysis',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.indigo,
                  ),
                  overflow: TextOverflow.ellipsis, // ✅ FIX: Handle overflow
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Overall Score
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getScoreColor(overallScore).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _getScoreColor(overallScore).withOpacity(0.3),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    '${overallScore.round()}%',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: _getScoreColor(overallScore),
                    ),
                  ),
                  const Text(
                    'AI Call Center Readiness',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Detailed Criteria
          const Text(
            'Detailed AI Analysis:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.indigo,
            ),
          ),
          const SizedBox(height: 12),

          ...criteria.map((criterion) {
            final name = criterion['name'] as String? ?? 'Criterion';
            final score = (criterion['score'] as num?)?.toDouble() ?? 0.0;
            final feedback =
                criterion['feedback'] as String? ?? 'No feedback available.';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ✅ FIX: This Row also needs proper flex handling
                  Row(
                    children: [
                      Expanded(
                        // ✅ FIX: Wrap with Expanded
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          overflow:
                              TextOverflow.ellipsis, // ✅ FIX: Handle overflow
                        ),
                      ),
                      const SizedBox(width: 8), // ✅ FIX: Add spacing
                      Text(
                        '${score.round()}%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _getScoreColor(score),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    feedback,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  String _formatTimeSpent(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes}m ${remainingSeconds}s';
  }

  Widget _createStandardFeedbackEntry(
    String title,
    dynamic userAnswer,
    dynamic feedbackData,
  ) {
    if (userAnswer == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Your Answer: $userAnswer',
              style: const TextStyle(fontSize: 14),
            ),
          ),
          if (feedbackData != null) ...[
            const SizedBox(height: 12),
            AiFeedbackDisplayCard(
              feedbackData: feedbackData as Map<String, dynamic>,
            ),
          ],
        ],
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 90) return Colors.green;
    if (score >= 75) return Colors.lime;
    if (score >= 60) return Colors.yellow[700]!;
    if (score >= 40) return Colors.orange;
    return Colors.red;
  }

  Color _getWordScoreColor(double score) {
    if (score < 60) return Colors.red;
    if (score < 80) return Colors.orange;
    if (score >= 95) return Colors.green;
    return Colors.grey[700]!;
  }

  Future<void> _playAudio(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      debugPrint('Error playing audio: $e');
    }
  }
}
