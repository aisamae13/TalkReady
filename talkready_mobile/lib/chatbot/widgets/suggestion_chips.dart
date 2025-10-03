import 'package:flutter/material.dart';
import '../models/prompt.dart';

class SuggestionChip {
  final String label;
  final String prompt;
  final PromptCategory mode;
  final IconData icon;

  SuggestionChip({
    required this.label,
    required this.prompt,
    required this.mode,
    required this.icon,
  });
}

final List<SuggestionChip> practiceSuggestions = [
  SuggestionChip(
    label: "Practice Pronunciation",
    prompt: "I'd like to practice my pronunciation.",
    mode: PromptCategory.pronunciation,
    icon: Icons.record_voice_over,
  ),
  SuggestionChip(
    label: "Enhance Fluency",
    prompt: "Let's have a conversation to practice fluency.",
    mode: PromptCategory.fluency,
    icon: Icons.speed,
  ),
  SuggestionChip(
    label: "Check My Grammar",
    prompt: "Could you please check my grammar for a sentence I type?",
    mode: PromptCategory.grammar,
    icon: Icons.spellcheck,
  ),
  SuggestionChip(
    label: "Build Vocabulary",
    prompt: "Can you teach me a new vocabulary word relevant to customer service?",
    mode: PromptCategory.vocabulary,
    icon: Icons.book,
  ),
  SuggestionChip(
    label: "Customer Service Role-Play",
    prompt: "Let's do a simple customer service role-play.",
    mode: PromptCategory.rolePlay,
    icon: Icons.groups,
  ),
];

class SuggestionChipsDisplay extends StatelessWidget {
  final Function(SuggestionChip) onChipClick;

  const SuggestionChipsDisplay({
    super.key,
    required this.onChipClick,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: practiceSuggestions.map((suggestion) {
            return Padding(
              padding: EdgeInsets.only(right: 8),
              child: _buildSuggestionChip(context, suggestion),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSuggestionChip(BuildContext context, SuggestionChip suggestion) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChipClick(suggestion),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Color.fromARGB(255, 224, 242, 254),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Color.fromARGB(255, 3, 169, 244).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                suggestion.icon,
                size: 18,
                color: Color.fromARGB(255, 1, 87, 155),
              ),
              SizedBox(width: 8),
              Text(
                suggestion.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color.fromARGB(255, 1, 87, 155),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}