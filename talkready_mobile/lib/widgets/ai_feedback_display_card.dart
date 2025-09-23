// lib/widgets/ai_feedback_display_card.dart
import 'package:flutter/material.dart';
import 'dart:convert';

class AiFeedbackDisplayCard extends StatelessWidget {
  final Map<String, dynamic> feedbackData;

  const AiFeedbackDisplayCard({super.key, required this.feedbackData});

  // Helper to parse the feedback string into structured parts for older format
  List<Map<String, String>> _parseMarkdownText(String rawText) {
    if (rawText.isEmpty) return [];

    final parts = rawText.split(RegExp(r'\*\*(.*?):\*\*'));
    if (parts.length <= 1) {
      return [
        {'title': 'Feedback', 'text': rawText},
      ];
    }

    final List<Map<String, String>> result = [];
    for (int i = 1; i < parts.length; i += 2) {
      final title = parts[i].trim();
      final text = (i + 1 < parts.length)
          ? parts[i + 1].trim().replaceAll('\\n', '\n')
          : '';
      if (title.isNotEmpty || text.isNotEmpty) {
        result.add({'title': title, 'text': text});
      }
    }
    return result;
  }

  // Helper to parse Lesson 3.1 specific feedback format
  List<Map<String, String>> _parseLesson3_1Feedback(String rawText) {
    final List<Map<String, String>> result = [];

    // Split by known section patterns for Lesson 3.1
    final patterns = ['Accuracy:', 'Clarity:', 'Suggestion:'];

    String remainingText = rawText;

    for (int i = 0; i < patterns.length; i++) {
      final currentPattern = patterns[i];
      final nextPattern = i < patterns.length - 1 ? patterns[i + 1] : null;

      final startIndex = remainingText.indexOf(currentPattern);
      if (startIndex == -1) continue;

      final contentStart = startIndex + currentPattern.length;
      int contentEnd;

      if (nextPattern != null) {
        final nextIndex = remainingText.indexOf(nextPattern, contentStart);
        contentEnd = nextIndex == -1 ? remainingText.length : nextIndex;
      } else {
        contentEnd = remainingText.length;
      }

      final content = remainingText
          .substring(contentStart, contentEnd)
          .trim()
          .replaceAll(RegExp(r'\*\*'), '') // Remove markdown asterisks
          .replaceAll(RegExp(r'\s+'), ' ') // Clean up whitespace
          .trim(); // Final trim after removing asterisks

      if (content.isNotEmpty) {
        result.add({
          'title': currentPattern.replaceAll(':', ''),
          'text': content,
        });
      }
    }

    return result;
  }

  // Helper to parse Lesson 4.1 specific feedback format
  List<Map<String, String>> _parseLesson4_1Feedback(String rawText) {
    final List<Map<String, String>> result = [];

    // Split by known section patterns for Lesson 4.1
    final patterns = [
      'Effectiveness of Clarification:',
      'Politeness and Professionalism:',
      'Clarity and Conciseness:',
      'Grammar and Phrasing:',
      'Suggestion for Improvement:',
    ];

    String remainingText = rawText;

    for (int i = 0; i < patterns.length; i++) {
      final currentPattern = patterns[i];
      final nextPattern = i < patterns.length - 1 ? patterns[i + 1] : null;

      final startIndex = remainingText.indexOf(currentPattern);
      if (startIndex == -1) continue;

      final contentStart = startIndex + currentPattern.length;
      int contentEnd;

      if (nextPattern != null) {
        final nextIndex = remainingText.indexOf(nextPattern, contentStart);
        contentEnd = nextIndex == -1 ? remainingText.length : nextIndex;
      } else {
        contentEnd = remainingText.length;
      }

      final content = remainingText
          .substring(contentStart, contentEnd)
          .trim()
          .replaceAll(RegExp(r'\*\*'), '') // Remove markdown asterisks
          .replaceAll(RegExp(r'\s+'), ' ') // Clean up whitespace
          .trim(); // Final trim after removing asterisks

      if (content.isNotEmpty) {
        result.add({
          'title': currentPattern.replaceAll(':', ''),
          'text': content,
        });
      }
    }

    return result;
  }

  // Helper to parse Lesson 4.2 specific feedback format
  List<Map<String, String>> _parseLesson4_2Feedback(String rawText) {
    final List<Map<String, String>> result = [];

    // Split by known section patterns for Lesson 4.2 (matching web version)
    final patterns = [
      'Effectiveness and Appropriateness of Solution:',
      'Clarity and Completeness:',
      'Professionalism, Tone, and Empathy:',
      'Grammar and Phrasing:',
      'Overall Actionable Suggestion:',
    ];

    String remainingText = rawText;

    for (int i = 0; i < patterns.length; i++) {
      final currentPattern = patterns[i];
      final nextPattern = i < patterns.length - 1 ? patterns[i + 1] : null;

      final startIndex = remainingText.indexOf(currentPattern);
      if (startIndex == -1) continue;

      final contentStart = startIndex + currentPattern.length;
      int contentEnd;

      if (nextPattern != null) {
        final nextIndex = remainingText.indexOf(nextPattern, contentStart);
        contentEnd = nextIndex == -1 ? remainingText.length : nextIndex;
      } else {
        contentEnd = remainingText.length;
      }

      final content = remainingText
          .substring(contentStart, contentEnd)
          .trim()
          .replaceAll(RegExp(r'\*\*'), '') // Remove markdown asterisks
          .replaceAll(RegExp(r'\s+'), ' ') // Clean up whitespace
          .trim(); // Final trim after removing asterisks

      if (content.isNotEmpty) {
        result.add({
          'title': currentPattern.replaceAll(':', ''),
          'text': content,
        });
      }
    }

    return result;
  }

  IconData _getIconForTitle(String title) {
    switch (title.toLowerCase()) {
      case 'effectiveness of clarification':
      case 'effectiveness':
        return Icons.center_focus_strong;
      case 'politeness and professionalism':
      case 'politeness':
      case 'professionalism':
        return Icons.handshake;
      case 'clarity and conciseness':
      case 'clarity':
        return Icons.visibility;
      case 'grammar and phrasing':
      case 'grammar':
        return Icons.spellcheck;
      case 'suggestion for improvement':
      case 'suggestions for improvement':
      case 'suggestion': // ✅ Added for Lesson 3.1
        return Icons.lightbulb;
      case 'accuracy': // ✅ Added for Lesson 3.1
      case 'question quality':
      case 'greeting':
        return Icons.check_circle_outline;
      // ✅ ADD THESE FOR LESSON 4.2
      case 'effectiveness and appropriateness of solution':
        return Icons.check_circle;
      case 'clarity and completeness':
        return Icons.visibility;
      case 'professionalism, tone, and empathy':
        return Icons.favorite;
      case 'overall actionable suggestion':
        return Icons.star;
      default:
        return Icons.info_outline;
    }
  }

  Color _getColorForTitle(String title) {
    switch (title.toLowerCase()) {
      case 'effectiveness of clarification':
      case 'effectiveness':
        return const Color(0xFF1976D2); // Blue
      case 'politeness and professionalism':
      case 'politeness':
      case 'professionalism':
        return const Color(0xFF388E3C); // Green
      case 'clarity and conciseness':
      case 'clarity':
        return const Color(0xFFFF8F00); // Amber
      case 'grammar and phrasing':
      case 'grammar':
        return const Color(0xFF7B1FA2); // Purple
      case 'suggestion for improvement':
      case 'suggestions for improvement':
      case 'suggestion': // ✅ Added for Lesson 3.1
        return const Color(0xFFFF5722); // Orange
      case 'accuracy': // ✅ Added for Lesson 3.1
      case 'question quality':
      case 'greeting':
        return const Color(0xFF4CAF50); // Green
      // ✅ ADD THESE FOR LESSON 4.2 (matching web colors)
      case 'effectiveness and appropriateness of solution':
        return const Color(0xFF2196F3); // Blue
      case 'clarity and completeness':
        return const Color(0xFFF57C00); // Orange
      case 'professionalism, tone, and empathy':
        return const Color(0xFF4CAF50); // Green
      case 'overall actionable suggestion':
        return const Color(0xFFFF5722); // Red-Orange
      default:
        return const Color(0xFF424242); // Grey
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ FIX: Handle both int and double for score
    final scoreValue = feedbackData['score'];
    num? score;

    if (scoreValue is int) {
      score = scoreValue;
    } else if (scoreValue is double) {
      score = scoreValue;
    } else if (scoreValue is num) {
      score = scoreValue;
    }

    // Check for both 'sections' (new format) and 'text' (old format)
    final sections = feedbackData['sections'] as List<dynamic>?;
    final rawText = feedbackData['text'] as String?;

    if (score == null || (sections == null && rawText == null)) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('Feedback is being processed or is unavailable.'),
      );
    }

    // Determine which format to use and parse feedback
    List<Map<String, String>> feedbackParts;

    if (sections != null && sections.isNotEmpty) {
      // New structured format
      feedbackParts = sections.map((s) => Map<String, String>.from(s)).toList();
    } else if (rawText != null) {
      // Try to parse as JSON first, then fall back to markdown parsing
      try {
        final jsonData = jsonDecode(rawText);
        if (jsonData is Map && jsonData['sections'] is List) {
          feedbackParts = (jsonData['sections'] as List)
              .map((s) => Map<String, String>.from(s))
              .toList();
        } else {
          // ✅ ENHANCED: Try specific lesson parsing based on content
          // ✅ ENHANCED: Try specific lesson parsing based on content
          if (rawText.contains(
                'Effectiveness and Appropriateness of Solution:',
              ) ||
              rawText.contains('Professionalism, Tone, and Empathy:')) {
            feedbackParts = _parseLesson4_2Feedback(
              rawText,
            ); // ✅ Lesson 4.2 specific
          } else if (rawText.contains('Effectiveness of Clarification:') ||
              rawText.contains('Politeness and Professionalism:')) {
            feedbackParts = _parseLesson4_1Feedback(
              rawText,
            ); // ✅ Lesson 4.1 specific
          } else if (rawText.contains('Accuracy:') &&
              rawText.contains('Clarity:') &&
              rawText.contains('Suggestion:')) {
            feedbackParts = _parseLesson3_1Feedback(rawText);
          } else {
            feedbackParts = _parseMarkdownText(rawText);
          }
        }
      } catch (e) {
        if (rawText.contains(
              'Effectiveness and Appropriateness of Solution:',
            ) ||
            rawText.contains('Professionalism, Tone, and Empathy:')) {
          feedbackParts = _parseLesson4_2Feedback(
            rawText,
          ); // ✅ Lesson 4.2 specific
        } else if (rawText.contains('Effectiveness of Clarification:') ||
            rawText.contains('Politeness and Professionalism:')) {
          feedbackParts = _parseLesson4_1Feedback(
            rawText,
          ); // ✅ Lesson 4.1 specific
        } else if (rawText.contains('Accuracy:') &&
            rawText.contains('Clarity:') &&
            rawText.contains('Suggestion:')) {
          feedbackParts = _parseLesson3_1Feedback(rawText);
        } else {
          feedbackParts = _parseMarkdownText(rawText);
        }
      }
    } else {
      feedbackParts = [];
    }

    // Calculate score display
    Color scoreColor;
    String scoreLabel;
    String scoreDisplay;

    // Handle different score formats (5-point vs 2.5-point scale)
    // Handle different score formats (2.5-point vs 5-point scale)
    double normalizedScore;
    if (score! <= 2.5) {
      // ✅ 2.5-point scale (for Lessons 4.1 and 4.2)
      normalizedScore = score.toDouble();
      scoreDisplay = '${score.toStringAsFixed(1)}/2.5';

      if (normalizedScore >= 2.0) {
        scoreColor = Colors.green;
        scoreLabel = 'Excellent';
      } else if (normalizedScore >= 1.5) {
        scoreColor = Colors.orange;
        scoreLabel = 'Good';
      } else if (normalizedScore >= 1.0) {
        scoreColor = Colors.amber;
        scoreLabel = 'Fair';
      } else {
        scoreColor = Colors.red;
        scoreLabel = 'Needs Improvement';
      }
    } else if (score! <= 5) {
      // 5-point scale (for other lessons)
      normalizedScore = score.toDouble();
      scoreDisplay = '${score.toStringAsFixed(1)}/5';

      if (normalizedScore >= 4) {
        scoreColor = Colors.green;
        scoreLabel = 'Excellent';
      } else if (normalizedScore >= 3) {
        scoreColor = Colors.orange;
        scoreLabel = 'Good';
      } else if (normalizedScore >= 2) {
        scoreColor = Colors.amber;
        scoreLabel = 'Fair';
      } else {
        scoreColor = Colors.red;
        scoreLabel = 'Needs Improvement';
      }
    } else {
      // Percentage scale (for other formats)
      normalizedScore = score.toDouble() * 20;
      scoreDisplay = '${normalizedScore.round()}%';

      if (normalizedScore >= 80) {
        scoreColor = Colors.green;
        scoreLabel = 'Excellent';
      } else if (normalizedScore >= 60) {
        scoreColor = Colors.orange;
        scoreLabel = 'Good';
      } else if (normalizedScore >= 40) {
        scoreColor = Colors.amber;
        scoreLabel = 'Fair';
      } else {
        scoreColor = Colors.red;
        scoreLabel = 'Needs Improvement';
      }
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.indigo.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with AI Feedback title and score
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Column(
              children: [
                // First row: Icon + Title
                Row(
                  children: [
                    const Icon(
                      Icons.psychology,
                      color: Colors.indigo,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'AI Feedback',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Second row: Score badge (full width, centered)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: scoreColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$scoreDisplay - $scoreLabel',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Progress bar
          Container(
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: LinearProgressIndicator(
              value:
                  (score <= 2.5
                          ? normalizedScore / 2.5
                          : score <= 5
                          ? normalizedScore / 5
                          : normalizedScore / 100)
                      .clamp(0.0, 1.0),
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
            ),
          ),

          const SizedBox(height: 16),

          // Individual feedback sections
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: feedbackParts.map((part) {
                final title = part['title'] ?? 'Feedback';
                final text = part['text'] ?? '';
                final color = _getColorForTitle(title);
                final icon = _getIconForTitle(title);

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section header
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(icon, size: 14, color: Colors.white),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: color,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Section content
                      if (text.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            text,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black87,
                              height: 1.4,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
