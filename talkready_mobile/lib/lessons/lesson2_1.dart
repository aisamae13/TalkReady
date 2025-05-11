import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:logger/logger.dart';
import 'common_widgets.dart';

class buildLesson2_1 extends StatefulWidget {
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

  const buildLesson2_1({
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
  _Lesson2_1State createState() => _Lesson2_1State();
}

class _Lesson2_1State extends State<buildLesson2_1> {
  final Logger _logger = Logger();
  final List<TextEditingController> _controllers = List.generate(8, (_) => TextEditingController());

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
      'question': '___, this is John from ABC Corp.',
      'type': 'greeting',
      'correctAnswer': 'Good morning',
      'explanation': 'Good morning is a polite greeting for morning calls.',
    },
    {
      'question': 'My ___ is Sarah.',
      'type': 'introduction',
      'correctAnswer': 'name',
      'explanation': 'Name is used to introduce yourself.',
    },
    {
      'question': '___ to XYZ Support!',
      'type': 'greeting',
      'correctAnswer': 'Welcome',
      'explanation': 'Welcome is used to greet customers warmly.',
    },
    {
      'question': 'How ___ you?',
      'type': 'greeting',
      'correctAnswer': 'are',
      'explanation': 'Are is used in the question "How are you?".',
    },
    {
      'question': 'I’m ___, thank you!',
      'type': 'response',
      'correctAnswer': 'good',
      'explanation': 'Good is a common response to "How are you?".',
    },
    {
      'question': 'This is Mike ___ XYZ Corp.',
      'type': 'introduction',
      'correctAnswer': 'from',
      'explanation': 'From indicates your company affiliation.',
    },
    {
      'question': 'Nice to ___ you!',
      'type': 'response',
      'correctAnswer': 'meet',
      'explanation': 'Meet is used in the phrase "Nice to meet you!".',
    },
    {
      'question': '___ morning, how can I assist you?',
      'type': 'greeting',
      'correctAnswer': 'Good',
      'explanation': 'Good morning is a professional greeting.',
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
              _logger.d('Answer changed for question $questionIndex in Lesson 2.1: isCorrect=$isCorrectAnswer');
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
          'Lesson 2.1: Greetings and Introductions',
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
              _logger.d('Slide changed to $index in Lesson 2.1');
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
                  _logger.i('Rendering YouTube player for Lesson 2.1, videoId=${widget.youtubeController.initialVideoId}');
                  return YoutubePlayer(
                    controller: widget.youtubeController,
                    showVideoProgressIndicator: true,
                    progressIndicatorColor: const Color(0xFF00568D),
                    onReady: () {
                      _logger.i('YouTube player is ready for Lesson 2.1');
                    },
                  );
                } catch (e) {
                  _logger.e('Error rendering YouTube player in Lesson 2.1: $e');
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
            'Objective: Fill in the blanks with the correct word for greetings and introductions.',
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
                _logger.d('Answer changed for question ${entry.key} in Lesson 2.1: isCorrect=$isCorrect');
              },
            );
          }),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                _logger.i('Submit Answers button pressed for Lesson 2.1');
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