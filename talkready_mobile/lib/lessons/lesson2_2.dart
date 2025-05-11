import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:logger/logger.dart';
import 'common_widgets.dart';

class buildLesson2_2 extends StatefulWidget {
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

  const buildLesson2_2({
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
  _Lesson2_2State createState() => _Lesson2_2State();
}

class _Lesson2_2State extends State<buildLesson2_2> {
  final Logger _logger = Logger();
  final List<TextEditingController> _controllers = List.generate(8, (_) => TextEditingController());

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
      'question': '___ you tell me your name?',
      'type': 'question',
      'correctAnswer': 'Can',
      'explanation': 'Can is a polite modal verb for asking questions.',
    },
    {
      'question': 'Could you please ___ your address?',
      'type': 'question',
      'correctAnswer': 'confirm',
      'explanation': 'Confirm is used to verify information.',
    },
    {
      'question': '___ is your account number?',
      'type': 'question',
      'correctAnswer': 'What',
      'explanation': 'What is used for Wh- questions about specific information.',
    },
    {
      'question': 'May I ___ your order number?',
      'type': 'question',
      'correctAnswer': 'have',
      'explanation': 'Have is used in polite requests for information.',
    },
    {
      'question': 'Can you ___ that, please?',
      'type': 'question',
      'correctAnswer': 'repeat',
      'explanation': 'Repeat is used when asking for clarification.',
    },
    {
      'question': '___ you provide the details?',
      'type': 'question',
      'correctAnswer': 'Can',
      'explanation': 'Can is used for polite requests.',
    },
    {
      'question': 'What is the ___ with your account?',
      'type': 'question',
      'correctAnswer': 'issue',
      'explanation': 'Issue refers to the problem being discussed.',
    },
    {
      'question': 'Could you please ___ me the price?',
      'type': 'question',
      'correctAnswer': 'tell',
      'explanation': 'Tell is used to request information.',
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
              _logger.d('Answer changed for question $questionIndex in Lesson 2.2: isCorrect=$isCorrectAnswer');
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
          'Lesson 2.2: Asking for Information',
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
              _logger.d('Slide changed to $index in Lesson 2.2');
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
                  _logger.i('Rendering YouTube player for Lesson 2.2, videoId=${widget.youtubeController.initialVideoId}');
                  return YoutubePlayer(
                    controller: widget.youtubeController,
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
            'Objective: Fill in the blanks with the correct word for asking information.',
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