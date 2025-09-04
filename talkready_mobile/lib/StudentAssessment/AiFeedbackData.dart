import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class AiFeedbackSection {
  final String title;
  final String text;

  AiFeedbackSection({required this.title, required this.text});

  factory AiFeedbackSection.fromMap(Map m) {
    return AiFeedbackSection(
      title: (m['title'] ?? '') as String,
      text: (m['text'] ?? '') as String,
    );
  }
}

class AiFeedbackDataModel {
  final double score;
  final List<AiFeedbackSection>? sections;
  final String? text;

  AiFeedbackDataModel({
    required this.score,
    this.sections,
    this.text,
  });

  factory AiFeedbackDataModel.fromMap(Map m) {
    final rawScore = m['score'];
    double parsedScore = 0;
    if (rawScore is num) parsedScore = rawScore.toDouble();
    else if (rawScore is String) parsedScore = double.tryParse(rawScore) ?? 0;

    List<AiFeedbackSection>? sections;
    if (m['sections'] is List) {
      sections = (m['sections'] as List)
          .whereType<Map>()
          .map((s) => AiFeedbackSection.fromMap(s))
          .toList();
    }

    return AiFeedbackDataModel(
      score: parsedScore,
      sections: sections,
      text: m['text'] as String?,
    );
  }
}

class AiFeedbackDisplayCard extends StatelessWidget {
  final AiFeedbackDataModel? feedbackData;
  final String? scenarioLabel;

  const AiFeedbackDisplayCard({
    Key? key,
    required this.feedbackData,
    this.scenarioLabel,
  }) : super(key: key);

  static const Map<String, Icon> _iconMap = {
    "Greeting": Icon(FontAwesomeIcons.handshake, color: Color(0xFF3B82F6)),
    "Self-introduction": Icon(FontAwesomeIcons.userCircle, color: Color(0xFF14B8A6)),
    "Tone & Politeness": Icon(FontAwesomeIcons.commentDots, color: Color(0xFF10B981)),
    "Grammar": Icon(FontAwesomeIcons.checkCircle, color: Color(0xFF7C3AED)),
    "Suggestion": Icon(FontAwesomeIcons.lightbulb, color: Color(0xFFF59E0B)),
    "Question Quality": Icon(FontAwesomeIcons.questionCircle, color: Color(0xFFFB923C)),
    "Accuracy": Icon(FontAwesomeIcons.checkCircle, color: Color(0xFF7C3AED)),
    "Clarity": Icon(FontAwesomeIcons.infoCircle, color: Color(0xFF06B6D4)),
  };

  Icon _getIconForTitle(String title) {
    return (_iconMap[title] ?? const Icon(FontAwesomeIcons.infoCircle, color: Color(0xFF6B7280)))
        as Icon;
  }

  @override
  Widget build(BuildContext context) {
    // Guard clause: check for essential data
    if (feedbackData == null || feedbackData!.score.isNaN) {
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Text(
            'Feedback is being processed or is unavailable.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
          ),
        ),
      );
    }

    final score = feedbackData!.score;
    Color badgeBg = Colors.red.shade100;
    Color badgeText = Colors.red.shade700;
    String scoreLabel = 'Needs Improvement';
    if (score >= 4) {
      badgeBg = Colors.green.shade100;
      badgeText = Colors.green.shade700;
      scoreLabel = 'Excellent';
    } else if (score >= 3) {
      badgeBg = Colors.yellow.shade100;
      badgeText = Colors.yellow.shade700;
      scoreLabel = 'Good';
    }

    final isStructured = (feedbackData!.sections != null && feedbackData!.sections!.isNotEmpty);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
        border: Border(top: BorderSide(color: Colors.indigo.shade500, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // header row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  scenarioLabel ?? 'AI Feedback',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.indigo.shade700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Score: ${score.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}/5 — $scoreLabel',
                  style: TextStyle(
                    color: badgeText,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // content
          if (isStructured)
            Column(
              children: feedbackData!.sections!.map((section) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: _getIconForTitle(section.title),
                          ),
                          Expanded(
                            child: Text(
                              section.title,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        section.text,
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
            )
          else
            // fallback old text format: simple parser for **bold** and newlines
            _buildParsedText(feedbackData!.text ?? ''),
        ],
      ),
    );
  }

  Widget _buildParsedText(String raw) {
    // Split on newlines and preserve them using Column; parse **bold** spans inside each line.
    final lines = raw.split(RegExp(r'\r?\n'));

    List<Widget> lineWidgets = lines.map((line) {
      final spans = <TextSpan>[];
      final regex = RegExp(r'\*\*(.*?)\*\*');
      int lastEnd = 0;
      for (final match in regex.allMatches(line)) {
        if (match.start > lastEnd) {
          spans.add(TextSpan(text: line.substring(lastEnd, match.start)));
        }
        spans.add(TextSpan(
          text: match.group(1),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ));
        lastEnd = match.end;
      }
      if (lastEnd < line.length) {
        spans.add(TextSpan(text: line.substring(lastEnd)));
      }
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: RichText(
          text: TextSpan(
            style: TextStyle(color: Colors.grey.shade800, fontSize: 13, height: 1.4),
            children: spans,
          ),
        ),
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lineWidgets,
    );
  }
}