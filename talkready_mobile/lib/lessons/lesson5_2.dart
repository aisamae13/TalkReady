import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../lessons/common_widgets.dart';

class Lesson5_2 extends StatefulWidget {
  final int currentSlide;
  final CarouselSliderController carouselController;
  final bool showActivity;
  final VoidCallback onShowActivity;
  final List<List<String>> selectedAnswers;
  final List<bool?> isCorrectStates;
  final List<String?> errorMessages;
  final Function(int, bool) onAnswerChanged;
  final Function(int) onSlideChanged;
  final Function(List<Map<String, dynamic>> questionsData, int timeSpent, int attemptNumber) onSubmitAnswers;
  final Function(int questionIndex, List<String> selectedWords) onWordsSelected;
  final int initialAttemptNumber;

  const Lesson5_2({
    super.key,
    required this.currentSlide,
    required this.carouselController,
    required this.showActivity,
    required this.onShowActivity,
    required this.selectedAnswers,
    required this.isCorrectStates,
    required this.errorMessages,
    required this.onAnswerChanged,
    required this.onSlideChanged,
    required this.onSubmitAnswers,
    required this.onWordsSelected,
    required this.initialAttemptNumber,
  });

  @override
  State<Lesson5_2> createState() => _Lesson5_2State();
}

class _Lesson5_2State extends State<Lesson5_2> {
  late int _currentAttempt;
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> slides = [
    {
      'title': 'Final Assessment',
      'content': 'This is your final test. Answer the questions to the best of your ability!',
    },
    {
      'title': 'Tips',
      'content': 'Read each question carefully and choose the best answer.',
    },
  ];

  final List<Map<String, dynamic>> questions = [
    {
      'id': 1,
      'question': 'Which of the following is a complete sentence?',
      'type': 'mcq',
      'options': [
        'Running fast.',
        'She is running fast.',
        'Because she was late.',
        'After the meeting.',
      ],
      'correctAnswer': 'She is running fast.',
      'explanation': 'A complete sentence has a subject and a verb.',
    },
    {
      'id': 2,
      'question': 'What should you say to a customer if you do not know the answer?',
      'type': 'mcq',
      'options': [
        'I don’t know.',
        'Let me find that information for you.',
        'That’s not my job.',
        'Ask someone else.',
      ],
      'correctAnswer': 'Let me find that information for you.',
      'explanation': 'This is polite and shows willingness to help.',
    },
    {
      'id': 3,
      'question': 'Which is a polite closing for a customer call?',
      'type': 'mcq',
      'options': [
        'Bye.',
        'Talk to you later.',
        'Thank you for calling. Have a great day!',
        'See ya.',
      ],
      'correctAnswer': 'Thank you for calling. Have a great day!',
      'explanation': 'This is the most professional and polite closing.',
    },
    {
      'id': 4,
      'question': 'When is it appropriate to interrupt a customer?',
      'type': 'mcq',
      'options': [
        'Whenever you want.',
        'Only if it’s necessary to clarify important information.',
        'If you’re bored.',
        'To finish the call faster.',
      ],
      'correctAnswer': 'Only if it’s necessary to clarify important information.',
      'explanation': 'Interrupt only to clarify or for important reasons.',
    },
    {
      'id': 5,
      'question': 'Which is the best response to a customer’s complaint?',
      'type': 'mcq',
      'options': [
        'That’s not my problem.',
        'I understand your concern and I will help you.',
        'Calm down.',
        'You’re wrong.',
      ],
      'correctAnswer': 'I understand your concern and I will help you.',
      'explanation': 'Empathy and willingness to help is key.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _currentAttempt = widget.initialAttemptNumber;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Final Test: A combination of grammar, vocabulary, and practical speaking exercises',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF00568D)),
        ),
        const SizedBox(height: 16),
        CarouselSlider(
          carouselController: widget.carouselController,
          items: slides.map((slide) {
            return buildSlide(
              title: slide['title'],
              content: slide['content'],
              slideIndex: slides.indexOf(slide),
            );
          }).toList(),
          options: CarouselOptions(
            height: 220.0,
            enlargeCenterPage: true,
            enableInfiniteScroll: false,
            initialPage: widget.currentSlide,
            onPageChanged: (index, reason) {
              widget.onSlideChanged(index);
            },
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: slides.asMap().entries.map((entry) {
            return GestureDetector(
              onTap: () => widget.carouselController.animateToPage(entry.key),
              child: Container(
                width: 8.0,
                height: 8.0,
                margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 2.0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.currentSlide == entry.key
                      ? const Color(0xFF00568D)
                      : Colors.grey,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        if (widget.currentSlide == slides.length - 1 && !widget.showActivity) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.onShowActivity,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00568D),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Proceed to Assessment', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
        if (widget.showActivity) ...[
          const SizedBox(height: 16),
          const Text(
            'Assessment Quiz',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
          ),
          const SizedBox(height: 8),
          ...questions.asMap().entries.map((entry) {
            int questionIndex = entry.key;
            Map<String, dynamic> questionData = entry.value;
            return buildMCQQuestion(
              question: 'Q${questionData['id']}: ${questionData['question']}',
              options: (questionData['options'] as List<String>),
              correctAnswer: questionData['correctAnswer'] as String,
              explanation: questionData['explanation'] as String,
              questionIndex: questionIndex,
              selectedAnswers: widget.selectedAnswers[questionIndex],
              isCorrect: widget.isCorrectStates[questionIndex],
              errorMessage: widget.errorMessages[questionIndex],
              onSelectionChanged: (List<String> newSelected) {
                widget.onWordsSelected(questionIndex, newSelected);
              },
              onAnswerChanged: (bool isCorrect) {
                widget.onAnswerChanged(questionIndex, isCorrect);
              },
            );
          }),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: !_isSubmitting ? () async {
                setState(() { _isSubmitting = true; });
                await widget.onSubmitAnswers(questions, 0, _currentAttempt);
                if (mounted) {
                  setState(() {
                    _isSubmitting = false;
                    _currentAttempt++;
                  });
                }
              } : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00568D),
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16, color: Colors.white),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Submit Answers', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ],
    );
  }
}