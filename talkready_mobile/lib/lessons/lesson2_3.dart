import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:logger/logger.dart';
import 'common_widgets.dart';

class buildLesson2_3 extends StatefulWidget {
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

  const buildLesson2_3({
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
  _Lesson2_3State createState() => _Lesson2_3State();
}

class _Lesson2_3State extends State<buildLesson2_3> {
  final Logger _logger = Logger();
  final List<TextEditingController> _controllers = List.generate(10, (_) => TextEditingController());

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
      'question': 'The price is ___ dollars.',
      'type': 'number',
      'correctAnswer': 'twenty',
      'explanation': 'Twenty is the cardinal number for 20.',
    },
    {
      'question': 'This is my ___ call.',
      'type': 'number',
      'correctAnswer': 'first',
      'explanation': 'First is the ordinal number for 1st.',
    },
    {
      'question': 'My birthday is on ___ first.',
      'type': 'date',
      'correctAnswer': 'January',
      'explanation': 'January is a month used in dates.',
    },
    {
      'question': 'The order was placed on the ___ of March.',
      'type': 'date',
      'correctAnswer': 'second',
      'explanation': 'Second is the ordinal number for 2nd.',
    },
    {
      'question': 'The price is ___ dollars.',
      'type': 'number',
      'correctAnswer': 'thirty-five',
      'explanation': 'Thirty-five is the cardinal number for 35.',
    },
    {
      'question': 'Your appointment is on ___ tenth.',
      'type': 'date',
      'correctAnswer': 'April',
      'explanation': 'April is a month used in dates.',
    },
    {
      'question': 'This is the ___ call today.',
      'type': 'number',
      'correctAnswer': 'third',
      'explanation': 'Third is the ordinal number for 3rd.',
    },
    {
      'question': 'The event is on ___ twenty-fifth.',
      'type': 'date',
      'correctAnswer': 'December',
      'explanation': 'December is a month used in dates.',
    },
    {
      'question': 'The total is ___ dollars.',
      'type': 'number',
      'correctAnswer': 'fifty',
      'explanation': 'Fifty is the cardinal number for 50.',
    },
    {
      'question': 'The deadline is the ___ of June.',
      'type': 'date',
      'correctAnswer': 'fifteenth',
      'explanation': 'Fifteenth is the ordinal number for 15th.',
    },
  ];

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget buildFillInTheBlankQuestion({
    required String question,
    required String correctAnswer,
    required String explanation,
    required int questionIndex,
    required List<String> selectedAnswers,
    required bool? isCorrect,
    required String? errorMessage,
    required TextEditingController controller,
    required Function(List<String>) onSelectionChanged,
    required Function(bool) onAnswerChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  question,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
              if (isCorrect != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Icon(
                    isCorrect ? Icons.check_circle : Icons.cancel,
                    color: isCorrect ? Colors.green : Colors.red,
                    size: 24,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              hintText: 'Enter the correct word',
              errorText: errorMessage,
            ),
            onChanged: (value) {
              _logger.d('TextField input for question $questionIndex: $value');
              onSelectionChanged([value.trim()]);
              bool isCorrectAnswer = value.trim().toLowerCase() == correctAnswer.toLowerCase();
              onAnswerChanged(isCorrectAnswer);
              _logger.d('Answer changed for question $questionIndex in Lesson 2.3: isCorrect=$isCorrectAnswer');
            },
          ),
          if (isCorrect != null && !isCorrect)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                explanation,
                style: const TextStyle(color: Colors.red, fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              _logger.d('Slide changed to $index in Lesson 2.3');
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
                  _logger.i('Rendering YouTube player for Lesson 2.3, videoId=${widget.youtubeController.initialVideoId}');
                  return YoutubePlayer(
                    controller: widget.youtubeController,
                    showVideoProgressIndicator: true,
                    progressIndicatorColor: const Color(0xFF00568D),
                    onReady: () {
                      _logger.i('YouTube player is ready for Lesson 2.3');
                    },
                  );
                } catch (e) {
                  _logger.e('Error rendering YouTube player in Lesson 2.3: $e');
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
            'Interactive Activity: Complete the Sentences',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Objective: Fill in the blanks with the correct number or date word.',
            style: TextStyle(fontSize: 16, color: Colors.black87),
          ),
          const SizedBox(height: 16),
          ...questions.asMap().entries.map((entry) {
            return buildFillInTheBlankQuestion(
              question: entry.value['question'],
              correctAnswer: entry.value['correctAnswer'],
              explanation: entry.value['explanation'],
              questionIndex: entry.key,
              selectedAnswers: widget.selectedAnswers[entry.key],
              isCorrect: widget.isCorrectStates[entry.key],
              errorMessage: widget.errorMessages[entry.key],
              controller: _controllers[entry.key],
              onSelectionChanged: (List<String> newSelections) {
                setState(() {
                  _logger.d('Updating selectedAnswers[${entry.key}]: $newSelections');
                  widget.selectedAnswers[entry.key] = List<String>.from(newSelections);
                });
              },
              onAnswerChanged: (isCorrect) {
                widget.onAnswerChanged(entry.key, isCorrect);
                _logger.d('Answer changed for question ${entry.key} in Lesson 2.3: isCorrect=$isCorrect');
              },
            );
          }),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                _logger.i('Submit Answers button pressed for Lesson 2.3');
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