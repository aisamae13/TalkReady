import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // For icons
import 'package:talkready_mobile/lessons/common_widgets.dart';

class ParsedFeedbackCard extends StatelessWidget {
  final Map<String, dynamic> feedbackData;
  final String?
      scenarioLabel; // Optional: if you want to repeat the prompt label inside the card

  const ParsedFeedbackCard({
    super.key,
    required this.feedbackData,
    this.scenarioLabel,
  });

  // Parses the feedback text into structured sections
  Map<String, String> _parseFeedbackText(String? rawText) {
    if (rawText == null || rawText.isEmpty) {
      return {"General Feedback:": "No detailed feedback text available."};
    }

    final Map<String, String> sections = {};
    final List<String> definedCategories = [
      "Format & Unit Accuracy:",
      "Clarity for Customer Understanding:",
      "Suggestion for Improvement:",
      "📚 Vocabulary Used:",
      "💡 Tip:",
      // Add any other consistent headers the AI might use
    ];

    List<String> lines =
        rawText.split('\n').where((line) => line.trim().isNotEmpty).toList();
    String currentCategory = "General Feedback:"; // Default category
    List<String> currentCategoryLines = [];

    for (String line in lines) {
      String? matchedCategory;
      for (String cat in definedCategories) {
        if (line.startsWith(cat)) {
          matchedCategory = cat;
          break;
        }
      }

      if (matchedCategory != null) {
        // If there was content for the previous category, save it
        if (currentCategoryLines.isNotEmpty) {
          sections[currentCategory] = currentCategoryLines.join('\n').trim();
        }
        // Start a new category
        currentCategory = matchedCategory;
        currentCategoryLines = [line.substring(matchedCategory.length).trim()];
      } else {
        // Continue adding to the current category's lines
        currentCategoryLines.add(line.trim());
      }
    }

    // Add the last processed category
    if (currentCategoryLines.isNotEmpty) {
      sections[currentCategory] = currentCategoryLines.join('\n').trim();
    }

    if (sections.isEmpty && rawText.isNotEmpty) {
      sections["General Feedback:"] = rawText;
    }

    return sections;
  }

  IconData _getIconForCategory(String categoryTitle) {
    if (categoryTitle.contains("Format") || categoryTitle.contains("Accuracy"))
      return FontAwesomeIcons.checkToSlot;
    if (categoryTitle.contains("Clarity")) return FontAwesomeIcons.eye;
    if (categoryTitle.contains("Suggestion")) return FontAwesomeIcons.lightbulb;
    if (categoryTitle.contains("Vocabulary")) return FontAwesomeIcons.book;
    if (categoryTitle.contains("Tip"))
      return FontAwesomeIcons.solidLightbulb; // Or a different lightbulb
    return FontAwesomeIcons.infoCircle; // Default
  }

  Color _getColorForScore(int? score) {
    if (score == null) return Colors.grey;
    if (score >= 4) return Colors.green.shade700;
    if (score == 3) return Colors.orange.shade700;
    return Colors.red.shade700;
  }

  @override
  Widget build(BuildContext context) {
    final score = feedbackData['score'] as int?;
    final rawFeedbackText = feedbackData['text'] as String?;
    final parsedSections = _parseFeedbackText(rawFeedbackText);

    String scoreTextLabel = 'N/A';
    if (score != null) {
      if (score >= 4)
        scoreTextLabel = 'Excellent';
      else if (score == 3)
        scoreTextLabel = 'Good';
      else if (score == 2)
        scoreTextLabel = 'Fair';
      else
        scoreTextLabel = 'Needs Improvement';
    }

    return Card(
      margin: const EdgeInsets.only(top: 12.0, bottom: 8.0),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (scenarioLabel != null && scenarioLabel!.isNotEmpty)
                  Expanded(
                    child: Text(
                      '$scenarioLabel - AI Feedback',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColorDark,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                else
                  Text(
                    'AI Feedback',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColorDark,
                        ),
                  ),
                if (score != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getColorForScore(score).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Score: $score/5 ($scoreTextLabel)',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: _getColorForScore(score),
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
              ],
            ),
            const Divider(height: 20),
            if (parsedSections.isEmpty)
              const Text("No detailed feedback available.",
                  style: TextStyle(fontStyle: FontStyle.italic))
            else
              ...parsedSections.entries.map((entry) {
                String categoryTitle = entry.key;
                String categoryText = entry.value;
                IconData categoryIcon = _getIconForCategory(categoryTitle);

                // Clean up category title if icons are part of it
                if (categoryTitle.startsWith("📚 "))
                  categoryTitle = categoryTitle.substring(2);
                if (categoryTitle.startsWith("💡 "))
                  categoryTitle = categoryTitle.substring(2);

                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FaIcon(categoryIcon,
                              size: 16,
                              color: Theme.of(context).colorScheme.secondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              categoryTitle,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color:
                                        Theme.of(context).colorScheme.secondary,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(
                            left: 24), // Indent text under icon
                        child: HtmlFormattedText(
                            htmlString: categoryText.replaceAll('\n', '<br/>')),
                      ),
                    ],
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }
}
