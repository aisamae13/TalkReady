import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:logger/logger.dart';
import '../lessons/common_widgets.dart';

class buildLesson1_1 extends StatefulWidget {
  final BuildContext context;
  final int currentSlide;
  final CarouselSliderController carouselController;
  final YoutubePlayerController youtubeController;
  final bool showActivity;
  final VoidCallback onShowActivity;
  final List<List<String>> selectedAnswers;
  final List<bool?> isCorrectStates;
  final List<String?> errorMessages;
  final Function(int, bool) onAnswerChanged;
  final Function(int) onSlideChanged;
  final Function(List<Map<String, dynamic>>) onSubmitAnswers;

  const buildLesson1_1({
    super.key,
    required this.context,
    required this.currentSlide,
    required this.carouselController,
    required this.youtubeController,
    required this.showActivity,
    required this.onShowActivity,
    required this.selectedAnswers,
    required this.isCorrectStates,
    required this.errorMessages,
    required this.onAnswerChanged,
    required this.onSlideChanged,
    required this.onSubmitAnswers,
  });

  @override
  _Lesson1_1State createState() => _Lesson1_1State();
}

class _Lesson1_1State extends State<buildLesson1_1> {
  final Logger _logger = Logger();

  final List<Map<String, dynamic>> slides = [
    {
      'title': 'Objective: Understanding Pronouns and Nouns',
      'content': 'In this lesson, you will learn to identify pronouns and nouns in customer service scenarios. Mastering these parts of speech ensures clear communication.',
    },
    {
      'title': 'Introduction to Pronouns and Nouns',
      'content': 'Pronouns replace nouns to avoid repetition, and nouns name people, places, or things. In a call center, using them correctly builds clarity and professionalism.',
    },
    {
      'title': 'Key Concepts: Pronouns and Nouns',
      'content': '• Pronouns: Words that replace nouns.\n'
          '  - Personal: I, you, he, she, it, we, they.\n'
          '    Example: "She assists the customer." (She is a pronoun)\n'
          '  - Possessive: Mine, yours, his, hers, ours, theirs.\n'
          '    Example: "The order is yours." (Yours is a pronoun)\n'
          '• Nouns: Words that name people, places, or things.\n'
          '  - Common: agent, customer, order.\n'
          '    Example: "The agent helps." (Agent is a noun)\n'
          '  - Proper: John, Amazon, New York.\n'
          '    Example: "John called Amazon." (John, Amazon are nouns)',
    },
    {
      'title': 'Using Pronouns and Nouns Effectively',
      'content': '• Use pronouns to avoid repeating nouns: Instead of "The customer called, and the customer needs help," say "The customer called, and they need help."\n'
          '• Use specific nouns for clarity: "The agent processes the order" is clearer than "Someone processes something."\n'
          '• Importance: Correct usage builds trust and reduces confusion.',
    },
  ];

  final List<Map<String, dynamic>> questions = [
    {
      'question': 'Identify the pronouns. Thank you for calling XYZ Corp. How can I assist you today?',
      'type': 'pronoun',
      'correctAnswer': 'I, you',
      'explanation': 'I, you: Pronouns (I refers to the agent, you refers to the customer).',
    },
    {
      'question': 'Identify the pronouns. We are processing your order now.',
      'type': 'pronoun',
      'correctAnswer': 'we, your',
      'explanation': 'We: Pronoun (refers to the team), Your: Possessive pronoun (refers to the customer’s order).',
    },
    {
      'question': 'Identify the pronouns. The system shows it is ready.',
      'type': 'pronoun',
      'correctAnswer': 'it',
      'explanation': 'It: Pronoun (refers to the system or order).',
    },
    {
      'question': 'Identify the pronouns. Can I offer you any additional assistance?',
      'type': 'pronoun',
      'correctAnswer': 'I, you',
      'explanation': 'I, you: Pronouns (I refers to the agent, you refers to the customer).',
    },
    {
      'question': 'Identify the nouns. The agent will help the customer.',
      'type': 'noun',
      'correctAnswer': 'agent, customer',
      'explanation': 'Agent, customer: Nouns (agent is the person helping, customer is the person being helped).',
    },
    {
      'question': 'Identify the nouns. Your order is ready for shipment.',
      'type': 'noun',
      'correctAnswer': 'order, shipment',
      'explanation': 'Order, shipment: Nouns (order is the thing being shipped, shipment is the process).',
    },
    {
      'question': 'Identify the nouns. John called Amazon yesterday.',
      'type': 'noun',
      'correctAnswer': 'John, Amazon',
      'explanation': 'John, Amazon: Proper nouns (John is a person, Amazon is a company).',
    },
    {
      'question': 'Identify the nouns. The refund was processed by the team.',
      'type': 'noun',
      'correctAnswer': 'refund, team',
      'explanation': 'Refund, team: Nouns (refund is the thing processed, team is the group processing it).',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Lesson 1.1: Pronouns and Nouns',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF00568D),
          ),
        ),
        const SizedBox(height: 16),
        CarouselSlider(
          carouselController: widget.carouselController,
          items: slides.asMap().entries.map((entry) {
            return buildSlide(
              title: entry.value['title'],
              content: entry.value['content'],
              slideIndex: entry.key,
            );
          }).toList(),
          options: CarouselOptions(
            height: 300.0,
            enlargeCenterPage: true,
            enableInfiniteScroll: false,
            onPageChanged: (index, reason) {
              widget.onSlideChanged(index);
              _logger.d('Slide changed to $index in Lesson 1.1');
            },
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: slides.asMap().entries.map((entry) {
            return GestureDetector(
              onTap: () => widget.carouselController.jumpToPage(entry.key),
              child: Container(
                width: 12.0,
                height: 12.0,
                margin: const EdgeInsets.symmetric(horizontal: 4.0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.currentSlide == entry.key
                      ? const Color(0xFF00568D)
                      : Colors.grey.withOpacity(0.5),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        if (widget.currentSlide == slides.length - 1) ...[
          const Text(
            'Watch the Video',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF00568D),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: Builder(
              builder: (context) {
                try {
                  _logger.i('Rendering YouTube player for Lesson 1.1, videoId=${widget.youtubeController.initialVideoId}');
                  return YoutubePlayer(
                    controller: widget.youtubeController,
                    showVideoProgressIndicator: true,
                    progressIndicatorColor: const Color(0xFF00568D),
                    onReady: () {
                      _logger.i('YouTube player is ready for Lesson 1.1');
                    },
                  );
                } catch (e) {
                  _logger.e('Error rendering YouTube player in Lesson 1.1: $e');
                  return const Text('Error loading video');
                }
              },
            ),
          ),
          if (!widget.showActivity) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.onShowActivity,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00568D),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Proceed to Activity'),
              ),
            ),
          ],
        ],
        if (widget.showActivity) ...[
          const SizedBox(height: 16),
          const Text(
            'Interactive Activity: Pronoun and Noun Identification',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Objective: Click the pronouns or nouns in each customer service scenario.',
            style: TextStyle(fontSize: 16, color: Colors.black87),
          ),
          const SizedBox(height: 16),
          ...questions.asMap().entries.map((entry) {
            return buildInteractiveQuestion(
              question: entry.value['question'],
              type: entry.value['type'],
              correctAnswer: entry.value['correctAnswer'],
              explanation: entry.value['explanation'],
              questionIndex: entry.key,
              selectedAnswers: widget.selectedAnswers[entry.key],
              isCorrect: widget.isCorrectStates[entry.key],
              errorMessage: widget.errorMessages[entry.key],
              onSelectionChanged: (List<String> newSelections) {
                setState(() {
                  _logger.d('Updating selectedAnswers[${entry.key}]: $newSelections');
                  widget.selectedAnswers[entry.key] = List<String>.from(newSelections);
                });
              },
              onAnswerChanged: (isCorrect) {
                widget.onAnswerChanged(entry.key, isCorrect);
                _logger.d('Answer changed for question ${entry.key} in Lesson 1.1: isCorrect=$isCorrect');
              },
            );
          }),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                _logger.i('Submit Answers button pressed for Lesson 1.1');
                widget.onSubmitAnswers(questions);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Submit Answers'),
            ),
          ),
        ],
      ],
    );
  }
}