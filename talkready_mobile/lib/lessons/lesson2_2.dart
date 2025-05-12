import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:logger/logger.dart';
import 'common_widgets.dart';

Widget buildLesson2_2({
  required BuildContext context,
  required int currentSlide,
  required CarouselSliderController carouselController,
  required YoutubePlayerController youtubeController,
  required bool showActivity,
  required VoidCallback onShowActivity,
  required List<List<String>> selectedAnswers,
  required List<bool?> isCorrectStates,
  required List<String?> errorMessages,
  required Function(int, bool) onAnswerChanged,
  required Function(int) onSlideChanged,
  required Function(List<Map<String, dynamic>>) onSubmitAnswers,
}) {
  final Logger _logger = Logger();

  final List<Map<String, dynamic>> slides = [
    {
      'title': 'Objective: Asking for Information',
      'content': 'By the end of this lesson, you will be able to ask polite questions to gather information in call center scenarios.',
    },
    {
      'title': 'Polite Questions',
      'content': 'Use polite phrases to ask for information:\n'
          '• Can you tell me...?\n'
          '• Could you please...?\n'
          '• May I have...?\n'
          '• What is...?\n'
          'Examples:\n'
          '• Can you tell me your account number?\n'
          '• Could you please repeat that?',
    },
    {
      'title': 'Question Structure',
      'content': 'Structure for polite questions:\n'
          '• Modal verb (Can/Could/May) + Subject + Base verb\n'
          '  Example: Can you provide the details?\n'
          '• Wh- question word + Modal verb + Subject + Base verb\n'
          '  Example: What is your name?',
    },
    {
      'title': 'Call Center Examples',
      'content': 'Examples in call center settings:\n'
          '• May I have your order number, please?\n'
          '• Could you please confirm your address?\n'
          '• What is the issue with your account?\n'
          'Polite questions improve customer experience.',
    },
    {
      'title': 'Conclusion',
      'content': 'You learned how to ask for information politely using modal verbs and Wh- questions. Practice these to sound professional and courteous.',
    },
  ];

  final List<Map<String, dynamic>> questions = [
    {
      'question': 'Select the question word. Can you tell me your name?',
      'type': 'word_selection',
      'correctAnswer': 'Can',
      'explanation': 'Can is a polite modal verb for asking questions.',
    },
    {
      'question': 'Select the question word. Could you please confirm your address?',
      'type': 'word_selection',
      'correctAnswer': 'Could',
      'explanation': 'Could is a polite modal verb for requesting information.',
    },
    {
      'question': 'Select the question word. What is your account number?',
      'type': 'word_selection',
      'correctAnswer': 'What',
      'explanation': 'What is used for Wh- questions about specific information.',
    },
    {
      'question': 'Select the question word. May I have your order number?',
      'type': 'word_selection',
      'correctAnswer': 'May',
      'explanation': 'May is a polite modal verb for requests.',
    },
    {
      'question': 'Select the question word. Can you repeat that, please?',
      'type': 'word_selection',
      'correctAnswer': 'Can',
      'explanation': 'Can is used for polite requests.',
    },
    {
      'question': 'Select the question word. Can you provide the details?',
      'type': 'word_selection',
      'correctAnswer': 'Can',
      'explanation': 'Can is used for polite requests.',
    },
    {
      'question': 'Select the question word. What is the issue with your account?',
      'type': 'word_selection',
      'correctAnswer': 'What',
      'explanation': 'What is the Wh- question word for asking about specific information.',
    },
    {
      'question': 'Select the question word. Could you please tell me the price?',
      'type': 'word_selection',
      'correctAnswer': 'Could',
      'explanation': 'Could is a polite modal verb for requesting information.',
    },
  ];

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Lesson 2.2: Asking for Information',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Color(0xFF00568D),
        ),
      ),
      const SizedBox(height: 16),
      CarouselSlider(
        carouselController: carouselController,
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
            onSlideChanged(index);
            _logger.d('Slide changed to $index in Lesson 2.2');
          },
        ),
      ),
      const SizedBox(height: 16),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: slides.asMap().entries.map((entry) {
          return GestureDetector(
            onTap: () => carouselController.jumpToPage(entry.key),
            child: Container(
              width: 12.0,
              height: 12.0,
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: currentSlide == entry.key
                    ? const Color(0xFF00568D)
                    : Colors.grey.withOpacity(0.5),
              ),
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 16),
      if (currentSlide == slides.length - 1) ...[
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
                _logger.i('Rendering YouTube player for Lesson 2.2, videoId=${youtubeController.initialVideoId}');
                return YoutubePlayer(
                  controller: youtubeController,
                  showVideoProgressIndicator: true,
                  progressIndicatorColor: const Color(0xFF00568D),
                  onReady: () {
                    _logger.i('YouTube player is ready for Lesson 2.2');
                  },
                );
              } catch (e) {
                _logger.e('Error rendering YouTube player in Lesson 2.2: $e');
                return const Text('Error loading video');
              }
            },
          ),
        ),
        if (!showActivity) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onShowActivity,
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
      if (showActivity) ...[
        const SizedBox(height: 16),
        const Text(
          'Interactive Activity: Identify Question Words',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.orange,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Objective: Click the correct word for asking information in each sentence.',
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
            selectedAnswers: selectedAnswers[entry.key],
            isCorrect: isCorrectStates[entry.key],
            errorMessage: errorMessages[entry.key],
            onSelectionChanged: (List<String> newSelections) {
              selectedAnswers[entry.key] = List<String>.from(newSelections);
              _logger.d('Updating selectedAnswers[${entry.key}]: $newSelections');
            },
            onAnswerChanged: (isCorrect) {
              onAnswerChanged(entry.key, isCorrect);
              _logger.d('Answer changed for question ${entry.key} in Lesson 2.2: isCorrect=$isCorrect');
            },
          );
        }),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              _logger.i('Submit Answers button pressed for Lesson 2.2');
              onSubmitAnswers(questions);
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