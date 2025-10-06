// lib/widgets/azure_fluency_display.dart
import 'package:flutter/material.dart';

class AzureFluencyDisplay extends StatelessWidget {
  final Map<String, dynamic> feedback;
  final String? originalText;

  const AzureFluencyDisplay({
    super.key,
    required this.feedback,
    this.originalText,
  });

  @override
  Widget build(BuildContext context) {
    final fluencyScore = (feedback['fluencyScore'] as num?)?.toDouble() ?? 0.0;
    final accuracyScore = (feedback['accuracyScore'] as num?)?.toDouble() ?? 0.0;
    final completenessScore = (feedback['completenessScore'] as num?)?.toDouble() ?? 0.0;
    final recognizedText = feedback['recognizedText'] as String? ?? 'Not recognized';
    final words = feedback['words'] as List? ?? [];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Row(
            children: [
              Icon(Icons.speed, color: Colors.purple.shade700, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Fluency Reading Analysis',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // What you said
          _buildInfoRow(
            '🗣️ You read:',
            '"$recognizedText"',
            Colors.black87,
          ),
          const SizedBox(height: 8),

          // Target passage
          if (originalText != null && originalText!.isNotEmpty)
            _buildInfoRow(
              '🎯 Target passage:',
              '"$originalText"',
              Colors.black87,
            ),
          if (originalText != null && originalText!.isNotEmpty)
            const SizedBox(height: 12),

          // Scores section
          const Text(
            '📊 Scores:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),

          _buildScoreBar('Fluency', fluencyScore, Colors.purple),
          const SizedBox(height: 6),
          _buildScoreBar('Accuracy', accuracyScore, Colors.green),
          const SizedBox(height: 6),
          _buildScoreBar('Completeness', completenessScore, Colors.orange),
          const SizedBox(height: 12),

          // Reading issues
          if (words.isNotEmpty) ...[
            _buildReadingIssues(words),
            const SizedBox(height: 12),
          ],

          // Overall feedback message
          _buildOverallFeedback(fluencyScore, accuracyScore, completenessScore),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color color) {
    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: 13, color: color, height: 1.4),
        children: [
          TextSpan(
            text: '$label ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }

  Widget _buildScoreBar(String label, double score, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            Text(
              '${score.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: _getScoreColor(score),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: score / 100,
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation<Color>(_getScoreColor(score)),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildReadingIssues(List<dynamic> words) {
    final issues = <Widget>[];

    for (var word in words) {
      final wordText = word['Word'] as String? ?? '';
      final errorType = word['ErrorType'] as String?;

      if (errorType == null || errorType == 'None') continue;

      String feedback;
      IconData icon;
      Color iconColor;

      if (errorType == 'Mispronunciation') {
        feedback = 'Pronunciation needs work';
        icon = Icons.warning_amber_rounded;
        iconColor = Colors.orange;
      } else if (errorType == 'Omission') {
        feedback = 'Word skipped';
        icon = Icons.error_outline_rounded;
        iconColor = Colors.red;
      } else if (errorType == 'Insertion') {
        feedback = 'Extra word added';
        icon = Icons.add_circle_outline_rounded;
        iconColor = Colors.blue;
      } else {
        continue;
      }

      issues.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.3),
                    children: [
                      TextSpan(
                        text: '"$wordText": ',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      TextSpan(text: feedback),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (issues.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '📝 Reading notes:',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        ...issues,
      ],
    );
  }

  Widget _buildOverallFeedback(double fluency, double accuracy, double completeness) {
  String message;
  IconData icon;
  Color color;

  // Use the 3 actual scores from Azure
  final averageScore = (fluency + accuracy + completeness) / 3;

  if (averageScore < 60) {
    message = "Keep practicing! Focus on reading smoothly and naturally.";
    icon = Icons.trending_up_rounded;
    color = Colors.orange.shade700;
  } else if (averageScore < 75) {
    message = "Good progress! Your reading is improving. Keep it up!";
    icon = Icons.thumb_up_outlined;
    color = Colors.blue.shade700;
  } else if (averageScore < 85) {
    message = "Great fluency! You're reading with good flow and rhythm.";
    icon = Icons.star_outline;
    color = Colors.purple.shade700;
  } else {
    message = "Excellent reading! Natural flow and great pronunciation!";
    icon = Icons.celebration_outlined;
    color = Colors.green.shade700;
  }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }
}