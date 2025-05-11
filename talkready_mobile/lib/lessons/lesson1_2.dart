import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:logger/logger.dart';
import '../lessons/common_widgets.dart';

class buildLesson1_2 extends StatefulWidget {
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

  const buildLesson1_2({
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
  _Lesson1_2State createState() => _Lesson1_2State();
}

class _Lesson1_2State extends State<buildLesson1_2> {
  final Logger _logger = Logger();

  final List<Map<String, dynamic>> slides = [
    {
      'title': 'Objective: Understanding Simple Sentences',
      'content': 'In this lesson, you will learn how to construct and identify simple sentences in customer service scenarios. Mastering simple sentences ensures clear and concise communication in a call center environment.',
    },
    {
      'title': 'Introduction to Simple Sentences in a Call Center Context',
      'content': 'Simple sentences are the foundation of clear communication. In a call center, using simple sentences helps agents convey information effectively, reducing misunderstandings with customers.',
    },
    {
      'title': 'Key Concepts: Simple Sentences',
      'content': '• A simple sentence has one independent clause with a subject and a verb.\n'
          '  - Subject: Who or what the sentence is about.\n'
          '    Example: "The agent assists the customer." (Agent is the subject)\n'
          '  - Verb: The action or state of being.\n'
          '    Example: "The agent assists the customer." (Assists is the verb)\n'
          '  - Importance: Simple sentences ensure clarity, e.g., "I will check your order."',
    },
    {
      'title': 'Using Simple Sentences Effectively',
      'content': '• Keep sentences short and direct for clarity.\n'
          '  - Example: "Your refund is processed." (Clear and concise)\n'
          '  - Avoid complexity: Instead of "Your refund, which was requested last week, is now being processed by our team," use "Your refund is processed."\n'
          '  - Importance: Simple sentences build trust and understanding with customers.',
    },
  ];

  final List<Map<String, dynamic>> questions = [
    {
      'question': 'Identify the subject. I will help you today.',
      'type': 'subject',
      'correctAnswer': 'I',
      'explanation': 'I: The subject (the agent who is performing the action).',
    },
    {
      'question': 'Identify the subject. The customer called yesterday.',
      'type': 'subject',
      'correctAnswer': 'The customer',
      'explanation': 'The customer: The subject (who performed the action of calling).',
    },
    {
      'question': 'Identify the subject. Your order ships tomorrow.',
      'type': 'subject',
      'correctAnswer': 'Your order',
      'explanation': 'Your order: The subject (what is performing the action of shipping).',
    },
    {
      'question': 'Identify the subject. We process your request now.',
      'type': 'subject',
      'correctAnswer': 'We',
      'explanation': 'We: The subject (the team or company processing the request).',
    },
    {
      'question': 'Identify the verb. The agent assists you.',
      'type': 'verb',
      'correctAnswer': 'assists',
      'explanation': 'Assists: The verb (the action the agent is performing).',
    },
    {
      'question': 'Identify the verb. Your refund arrives soon.',
      'type': 'verb',
      'correctAnswer': 'arrives',
      'explanation': 'Arrives: The verb (the action describing the refund).',
    },
    {
      'question': 'Identify the verb. I check the system.',
      'type': 'verb',
      'correctAnswer': 'check',
      'explanation': 'Check: The verb (the action the agent is performing).',
    },
    {
      'question': 'Identify the verb. The team resolves the issue.',
      'type': 'verb',
      'correctAnswer': 'resolves',
      'explanation': 'Resolves: The verb (the action the team is performing).',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Lesson 1.2: Simple Sentences',
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
              _logger.d('Slide changed to $index in Lesson 1.2');
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
                  _logger.i('Rendering YouTube player for Lesson 1.2, videoId=${widget.youtubeController.initialVideoId}');
                  return YoutubePlayer(
                    controller: widget.youtubeController,
                    showVideoProgressIndicator: true,
                    progressIndicatorColor: const Color(0xFF00568D),
                    onReady: () {
                      _logger.i('YouTube player is ready for Lesson 1.2');
                    },
                  );
                } catch (e) {
                  _logger.e('Error rendering YouTube player in Lesson 1.2: $e');
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
            'Interactive Activity: Simple Sentence Identification',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Objective: Click the subject or verb in each simple sentence used in a customer service scenario.',
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
                _logger.d('Answer changed for question ${entry.key} in Lesson 1.2: isCorrect=$isCorrect');
              },
            );
          }),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                _logger.i('Submit Answers button pressed for Lesson 1.2');
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
          if (widget.currentSlide == slides.length - 1) ...[
            const SizedBox(height: 16),
            const Text(
              'Reference Video',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00568D),
              ),
            ),
          ],
        ],
      ],
    );
  }
}