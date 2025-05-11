import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:logger/logger.dart';
import '../lessons/common_widgets.dart';

class buildLesson1_3 extends StatefulWidget {
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

  const buildLesson1_3({
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
  _Lesson1_3State createState() => _Lesson1_3State();
}

class _Lesson1_3State extends State<buildLesson1_3> {
  final Logger _logger = Logger();
  final List<TextEditingController> _controllers = List.generate(10, (_) => TextEditingController());

  final List<Map<String, dynamic>> slides = [
    {
      'title': 'Objective: Mastering Present Simple Tense',
      'content': 'By the end of this lesson, you will be able to use the present simple tense correctly in sentences and apply subject-verb agreement in call center scenarios.',
    },
    {
      'title': 'Introduction to Present Simple Tense',
      'content': 'The present simple tense describes regular actions, habits, and general truths. It is commonly used in call centers for daily communication.\n'
          'Structure:\n'
          '• Affirmative: Subject + Base verb (add -s for he/she/it)\n'
          '  Example: I help customers. She helps customers.\n'
          '• Negative: Subject + do/does + not + Base verb\n'
          '  Example: I don’t help customers. He doesn’t answer calls.\n'
          '• Interrogative: Do/Does + Subject + Base verb?\n'
          '  Example: Do I help you? Does he answer calls?',
    },
    {
      'title': 'Subject-Verb Agreement in Present Simple',
      'content': '• Singular Subjects (He, She, It): Add -s to the base verb in affirmative sentences.\n'
          '  Example: She helps the customer.\n'
          '• Plural Subjects (I, You, We, They): Use the base verb without -s.\n'
          '  Example: I help the customer.\n'
          'Correct agreement ensures clear and professional communication.',
    },
    {
      'title': 'Call Center Examples',
      'content': 'Use present simple to describe routine tasks:\n'
          '• I help customers with their inquiries.\n'
          '• You assist customers in placing orders.\n'
          '• The agent resolves the issue promptly.\n'
          '• The customer explains the problem clearly.\n'
          'Mastering this tense improves clarity in customer interactions.',
    },
    {
      'title': 'Conclusion',
      'content': 'You learned how to form and use the present simple tense and apply subject-verb agreement. This skill is crucial for clear and accurate communication in call centers. Practice using it in real scenarios to enhance professionalism.',
    },
  ];

  final List<Map<String, dynamic>> questions = [
    {
      'question': 'I ___ (help) the customer with their order.',
      'type': 'verb',
      'correctAnswer': 'help',
      'explanation': 'Help: Base verb for plural subject (I) in affirmative sentence.',
    },
    {
      'question': 'The agent ___ (answer) the phone calls promptly.',
      'type': 'verb',
      'correctAnswer': 'answers',
      'explanation': 'Answers: Base verb + -s for singular subject (The agent).',
    },
    {
      'question': 'You ___ (resolve) customer issues efficiently.',
      'type': 'verb',
      'correctAnswer': 'resolve',
      'explanation': 'Resolve: Base verb for plural subject (You) in affirmative sentence.',
    },
    {
      'question': 'She ___ (assist) customers every day.',
      'type': 'verb',
      'correctAnswer': 'assists',
      'explanation': 'Assists: Base verb + -s for singular subject (She).',
    },
    {
      'question': 'They ___ (provide) excellent customer service.',
      'type': 'verb',
      'correctAnswer': 'provide',
      'explanation': 'Provide: Base verb for plural subject (They) in affirmative sentence.',
    },
    {
      'question': 'The customer ___ (explain) the issue.',
      'type': 'verb',
      'correctAnswer': 'explains',
      'explanation': 'Explains: Base verb + -s for singular subject (The customer).',
    },
    {
      'question': 'We ___ (check) the details of the order.',
      'type': 'verb',
      'correctAnswer': 'check',
      'explanation': 'Check: Base verb for plural subject (We) in affirmative sentence.',
    },
    {
      'question': 'He ___ (not, answer) the customer’s question.',
      'type': 'verb',
      'correctAnswer': 'does not answer',
      'explanation': 'Does not answer: Negative form for singular subject (He).',
    },
    {
      'question': 'I ___ (not, work) on weekends.',
      'type': 'verb',
      'correctAnswer': 'do not work',
      'explanation': 'Do not work: Negative form for plural subject (I).',
    },
    {
      'question': 'Does she ___ (assist) you with your problem?',
      'type': 'verb',
      'correctAnswer': 'assist',
      'explanation': 'Assist: Base verb in interrogative form for singular subject (She).',
    },
  ];

  bool get _allAnswersCorrect {
    // Check if all answers are correct (no null or false in isCorrectStates)
    return widget.isCorrectStates.every((state) => state == true);
  }

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
              hintText: 'Enter the correct verb form',
              errorText: errorMessage,
            ),
            onChanged: (value) {
              _logger.d('TextField input for question $questionIndex: $value');
              onSelectionChanged([value.trim()]);
              bool isCorrectAnswer = value.trim().toLowerCase() == correctAnswer.toLowerCase();
              onAnswerChanged(isCorrectAnswer);
              _logger.d('Answer changed for question $questionIndex in Lesson 1.3: isCorrect=$isCorrectAnswer');
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
          'Lesson 1.3: Verb and Tenses (Present Simple)',
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
              _logger.d('Slide changed to $index in Lesson 1.3');
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
                  _logger.i('Rendering YouTube player for Lesson 1.3, videoId=${widget.youtubeController.initialVideoId}');
                  return YoutubePlayer(
                    controller: widget.youtubeController,
                    showVideoProgressIndicator: true,
                    progressIndicatorColor: const Color(0xFF00568D),
                    onReady: () {
                      _logger.i('YouTube player is ready for Lesson 1.3');
                    },
                  );
                } catch (e) {
                  _logger.e('Error rendering YouTube player in Lesson 1.3: $e');
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
            'Objective: Fill in the blanks with the correct form of the verb in the present simple tense.',
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
                _logger.d('Answer changed for question ${entry.key} in Lesson 1.3: isCorrect=$isCorrect');
              },
            );
          }),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _allAnswersCorrect
                  ? () {
                      _logger.i('Submit Answers button pressed for Lesson 1.3 - All answers correct');
                      widget.onSubmitAnswers(questions);
                    }
                  : () {
                      _logger.w('Submit Answers attempted but not all answers are correct');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please correct all answers before submitting.'),
                          backgroundColor: Colors.red,
                          duration: Duration(seconds: 3),
                        ),
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: _allAnswersCorrect ? Colors.orange : Colors.grey,
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