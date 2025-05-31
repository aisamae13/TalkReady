import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../lessons/common_widgets.dart';

class Lesson5_1 extends StatefulWidget {
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

  const Lesson5_1({
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
  State<Lesson5_1> createState() => _Lesson5_1State();
}

class _Lesson5_1State extends State<Lesson5_1> {
  late int _currentAttempt;
  int _secondsElapsed = 0;
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> slides = [
    {
      'title': 'Review: Key Concepts',
      'content': 'Let’s review the most important grammar and conversation points you have learned so far.',
    },
    {
      'title': 'Grammar Check',
      'content': 'Remember to use correct verb tense and subject-verb agreement.',
    },
    {
      'title': 'Conversation Skills',
      'content': 'Politeness, clarity, and active listening are essential for effective communication.',
    },
  ];

  final List<Map<String, dynamic>> questions = [
    {
      'id': 1,
      'question': 'Which sentence is correct?',
      'type': 'mcq',
      'options': [
        'She go to work every day.',
        'She goes to work every day.',
        'She going to work every day.',
        'She gone to work every day.',
      ],
      'correctAnswer': 'She goes to work every day.',
      'explanation': 'The correct form is "goes" for third person singular.',
    },
    {
      'id': 2,
      'question': 'How do you politely ask for clarification?',
      'type': 'mcq',
      'options': [
        'Repeat.',
        'What?',
        'Could you please repeat that?',
        'Say again.',
      ],
      'correctAnswer': 'Could you please repeat that?',
      'explanation': 'This is the most polite and clear way to ask.',
    },
    {
      'id': 3,
      'question': 'Which is an example of active listening?',
      'type': 'mcq',
      'options': [
        'Interrupting the speaker.',
        'Looking away.',
        'Nodding and making eye contact.',
        'Checking your phone.',
      ],
      'correctAnswer': 'Nodding and making eye contact.',
      'explanation': 'Active listening includes non-verbal cues like nodding and eye contact.',
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
          'Review: Go through key concepts',
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
              child: const Text('Proceed to Activity', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
        if (widget.showActivity) ...[
          const SizedBox(height: 16),
          const Text(
            'Review Quiz',
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