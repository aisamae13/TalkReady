import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:logger/logger.dart';
import 'common_widgets.dart';

Widget buildLesson2_3({
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
      'title': 'Objective: Mastering Numbers and Dates',
      'content': 'By the end of this lesson, you will be able to use numbers and dates accurately in call center conversations.',
    },
    {
      'title': 'Numbers',
      'content': 'Numbers are used for quantities, prices, and more:\n'
          '• Cardinal: one, two, three, etc.\n'
          '• Ordinal: first, second, third, etc.\n'
          'Examples:\n'
          '• The price is twenty dollars.\n'
          '• This is my first call.',
    },
    {
      'title': 'Dates',
      'content': 'Dates are expressed in specific formats:\n'
          '• Month Day, Year (e.g., January 1st, 2025)\n'
          '• Day/Month/Year (e.g., 01/01/2025)\n'
          'Use ordinal numbers for days:\n'
          '• The first of January\n'
          '• The second of March',
    },
    {
      'title': 'Call Center Examples',
      'content': 'Examples in call center settings:\n'
          '• The order was placed on January first, two thousand twenty-five.\n'
          '• The price is thirty-five dollars.\n'
          '• Your appointment is on the second of April.',
    },
    {
      'title': 'Conclusion',
      'content': 'You learned how to use numbers and dates correctly in conversations. Practice these to provide clear and accurate information.',
    },
  ];

  final List<Map<String, dynamic>> questions = [
    {
      'question': 'Select the number. The price is twenty dollars.',
      'type': 'word_selection',
      'correctAnswer': 'twenty',
      'explanation': 'Twenty is the cardinal number for 20.',
    },
    {
      'question': 'Select the number. This is my first call.',
      'type': 'word_selection',
      'correctAnswer': 'first',
      'explanation': 'First is the ordinal number for 1st.',
    },
    {
      'question': 'Select the date word. My birthday is on January first.',
      'type': 'word_selection',
      'correctAnswer': 'January',
      'explanation': 'January is a month used in dates.',
    },
    {
      'question': 'Select the date word. The order was placed on the second of March.',
      'type': 'word_selection',
      'correctAnswer': 'second',
      'explanation': 'Second is the ordinal number for 2nd.',
    },
    {
      'question': 'Select the number. The price is thirty-five dollars.',
      'type': 'word_selection',
      'correctAnswer': 'thirty-five',
      'explanation': 'Thirty-five is the cardinal number for 35.',
    },
    {
      'question': 'Select the date word. Your appointment is on April tenth.',
      'type': 'word_selection',
      'correctAnswer': 'April',
      'explanation': 'April is a month used in dates.',
    },
    {
      'question': 'Select the number. This is the third call today.',
      'type': 'word_selection',
      'correctAnswer': 'third',
      'explanation': 'Third is the ordinal number for 3rd.',
    },
    {
      'question': 'Select the date word. The event is on December twenty-fifth.',
      'type': 'word_selection',
      'correctAnswer': 'December',
      'explanation': 'December is a month used in dates.',
    },
    {
      'question': 'Select the number. The total is fifty dollars.',
      'type': 'word_selection',
      'correctAnswer': 'fifty',
      'explanation': 'Fifty is the cardinal number for 50.',
    },
    {
      'question': 'Select the date word. The deadline is the fifteenth of June.',
      'type': 'word_selection',
      'correctAnswer': 'fifteenth',
      'explanation': 'Fifteenth is the ordinal number for 15th.',
    },
  ];

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Lesson 2.3: Numbers and Dates',
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
            logger.d('Slide changed to $index in Lesson 2.3');
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
                logger.i('Rendering YouTube player for Lesson 2.3, videoId=${youtubeController.initialVideoId}');
                return YoutubePlayer(
                  controller: youtubeController,
                  showVideoProgressIndicator: true,
                  progressIndicatorColor: const Color(0xFF00568D),
                  onReady: () {
                    logger.i('YouTube player is ready for Lesson 2.3');
                  },
                );
              } catch (e) {
                logger.e('Error rendering YouTube player in Lesson 2.3: $e');
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
          'Interactive Activity: Identify Numbers and Dates',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.orange,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Objective: Click the correct number or date word in each sentence.',
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
              logger.d('Updating selectedAnswers[${entry.key}]: $newSelections');
            },
            onAnswerChanged: (isCorrect) {
              onAnswerChanged(entry.key, isCorrect);
              logger.d('Answer changed for question ${entry.key} in Lesson 2.3: isCorrect=$isCorrect');
            },
          );
        }),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              logger.i('Submit Answers button pressed for Lesson 2.3');
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