import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:logger/logger.dart';
import 'common_widgets.dart';

Widget buildLesson2_1({
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
  final Logger logger = Logger();

  final List<Map<String, dynamic>> slides = [
    {
      'title': 'Objective: Mastering Greetings and Introductions',
      'content': 'By the end of this lesson, you will be able to use common greetings and introduce yourself confidently in call center scenarios.',
    },
    {
      'title': 'Common Greetings',
      'content': 'Greetings set the tone for customer interactions:\n'
          '• Hello / Good morning / Good afternoon\n'
          '• How are you?\n'
          '• Welcome to [Company Name]!\n'
          'Responses:\n'
          '• I’m good, thank you!\n'
          '• Nice to meet you!',
    },
    {
      'title': 'Introductions',
      'content': 'Introduce yourself clearly:\n'
          '• My name is [Your Name].\n'
          '• I’m [Your Name], your customer service representative.\n'
          '• This is [Your Name] from [Company Name].\n'
          'Use polite and professional language.',
    },
    {
      'title': 'Call Center Examples',
      'content': 'Examples in call center settings:\n'
          '• Good morning, this is John from ABC Corp. How can I assist you?\n'
          '• Hello, my name is Sarah. Thank you for calling!\n'
          '• Welcome to XYZ Support, this is Mike speaking.',
    },
    {
      'title': 'Conclusion',
      'content': 'You learned how to use greetings and introductions to create a positive first impression. Practice these phrases to sound professional and approachable.',
    },
  ];

  final List<Map<String, dynamic>> questions = [
    {
      'question': 'Select the greeting. Good morning, this is John from ABC Corp.',
      'type': 'word_selection',
      'correctAnswer': 'Good morning',
      'explanation': 'Good morning is a polite greeting for morning calls.',
    },
    {
      'question': 'Select the introduction word. My name is Sarah.',
      'type': 'word_selection',
      'correctAnswer': 'Sarah',
      'explanation': 'Sarah is the name used to introduce oneself.',
    },
    {
      'question': 'Select the greeting. Welcome to XYZ Support!',
      'type': 'word_selection',
      'correctAnswer': 'Welcome',
      'explanation': 'Welcome is used to greet customers warmly.',
    },
    {
      'question': 'Select the greeting word. How are you?',
      'type': 'word_selection',
      'correctAnswer': 'How',
      'explanation': 'How is the key word in the greeting "How are you?".',
    },
    {
      'question': 'Select the response word. I’m good, thank you!',
      'type': 'word_selection',
      'correctAnswer': 'good',
      'explanation': 'Good is a common response to "How are you?".',
    },
    {
      'question': 'Select the introduction word. This is Mike from XYZ Corp.',
      'type': 'word_selection',
      'correctAnswer': 'Mike',
      'explanation': 'Mike is the name used to introduce oneself.',
    },
    {
      'question': 'Select the response word. Nice to meet you!',
      'type': 'word_selection',
      'correctAnswer': 'meet',
      'explanation': 'Meet is used in the phrase "Nice to meet you!".',
    },
    {
      'question': 'Select the greeting word. Good morning, how can I assist you?',
      'type': 'word_selection',
      'correctAnswer': 'Good morning',
      'explanation': 'Good morning is a professional greeting.',
    },
  ];

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Lesson 2.1: Greetings and Introductions',
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
            logger.d('Slide changed to $index in Lesson 2.1');
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
                logger.i('Rendering YouTube player for Lesson 2.1, videoId=${youtubeController.initialVideoId}');
                return YoutubePlayer(
                  controller: youtubeController,
                  showVideoProgressIndicator: true,
                  progressIndicatorColor: const Color(0xFF00568D),
                  onReady: () {
                    logger.i('YouTube player is ready for Lesson 2.1');
                  },
                );
              } catch (e) {
                logger.e('Error rendering YouTube player in Lesson 2.1: $e');
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
          'Interactive Activity: Identify Greetings and Introductions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.orange,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Objective: Click the correct greeting or introduction word in each sentence.',
          style: TextStyle(fontSize: 16, color: Colors.black87),
        ),
        const SizedBox(height: 16),
        ...questions.asMap().entries.map((entry) {
          return buildInteractiveQuestion(
            question: entry.value['question'],
            type: 'word_selection',
            correctAnswer: entry.value['correctAnswer'],
            explanation: entry.value['explanation'],
            questionIndex: entry.key,
            selectedAnswers: selectedAnswers[entry.key],
            isCorrect: isCorrectStates[entry.key],
            errorMessage: errorMessages[entry.key],
            onSelectionChanged: (List<String> newSelections) {
              selectedAnswers[entry.key] = List<String>.from(newSelections);
              logger.d('Updating selectedAnswers[${entry.key}]: $newSelections');
            },
            onAnswerChanged: (isCorrect) {
              onAnswerChanged(entry.key, isCorrect);
              logger.d('Answer changed for question ${entry.key} in Lesson 2.1: isCorrect=$isCorrect');
            },
          );
        }),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              logger.i('Submit Answers button pressed for Lesson 2.1');
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