import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:logger/logger.dart';
import '../lessons/common_widgets.dart';
import 'dart:async';

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
  final Function(List<Map<String, dynamic>> questionsData, int timeSpent, int attemptNumber) onSubmitAnswers;
  final Function(int questionIndex, List<String> selectedWords) onWordsSelected;
  final int initialAttemptNumber;

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
    required this.onWordsSelected,
    required this.initialAttemptNumber,
  });

  @override
  _Lesson2_2State createState() => _Lesson2_2State();
}

class _Lesson2_2State extends State<buildLesson2_2> {
  final Logger _logger = Logger();
  bool _videoFinished = false;
  bool _isSubmitting = false; // Added
  Timer? _timer;
  int _secondsElapsed = 0;
  late int _currentAttempt;

  final List<Map<String, dynamic>> slides = [
    {
      'title': 'Objective: Asking for Information Politely',
      'content': 'Learn phrases and techniques for asking for information from customers in a polite and professional manner.',
    },
    {
      'title': 'Using Polite Question Forms',
      'content': '• Use "Could you," "Would you mind," or "May I" for requests.\n'
          '  Example: "Could you please provide your account number?"\n'
          '  Example: "Would you mind spelling your last name for me?"\n'
          '• Avoid abrupt questions like "What\'s your name?".',
    },
    {
      'title': 'Explaining Why Information is Needed',
      'content': '• Briefly explain why you need certain information to build trust.\n'
          '  Example: "May I have your date of birth to verify your account?"\n'
          '  Example: "To pull up your records, could I get your phone number?"',
    },
    {
      'title': 'Active Listening and Clarification',
      'content': '• Listen carefully to the customer\'s responses.\n'
          '• Ask clarifying questions if needed.\n'
          '  Example: "Could you please repeat that?" or "Did you say B as in Bravo?"',
    },
    {
      'title': 'Conclusion',
      'content': 'Asking for information politely and clearly is key to efficient customer service. Practice these techniques to enhance your communication skills.',
    },
  ];

  final List<Map<String, dynamic>> questions = [
    {
      'id': 1,
      'question': 'Select the question word. Can you tell me your name?',
      'type': 'word_selection',
      'words': ['Can', 'you', 'tell', 'me', 'your', 'name?'],
      'correctAnswer': 'Can',
      'explanation': 'Can is a polite modal verb for asking questions.',
    },
    {
      'id': 2,
      'question': 'Select the question word. Could you please confirm your address?',
      'type': 'word_selection',
      'words': ['Could', 'you', 'please', 'confirm', 'your', 'address?'],
      'correctAnswer': 'Could',
      'explanation': 'Could is a polite modal verb for requesting information.',
    },
    {
      'id': 3,
      'question': 'Select the question word. What is your account number?',
      'type': 'word_selection',
      'words': ['What', 'is', 'your', 'account', 'number?'],
      'correctAnswer': 'What',
      'explanation': 'What is used for Wh- questions about specific information.',
    },
    {
      'id': 4,
      'question': 'Select the question word. May I have your order number?',
      'type': 'word_selection',
      'words': ['May', 'I', 'have', 'your', 'order', 'number?'],
      'correctAnswer': 'May',
      'explanation': 'May is a polite modal verb for requests.',
    },
    {
      'id': 5,
      'question': 'Select the question word. Can you repeat that, please?',
      'type': 'word_selection',
      'words': ['Can', 'you', 'repeat', 'that,', 'please?'],
      'correctAnswer': 'Can',
      'explanation': 'Can is used for polite requests.',
    },
    {
      'id': 6,
      'question': 'Select the question word. Can you provide the details?',
      'type': 'word_selection',
      'words': ['Can', 'you', 'provide', 'the', 'details?'],
      'correctAnswer': 'Can',
      'explanation': 'Can is used for polite requests.',
    },
    {
      'id': 7,
      'question': 'Select the question word. What is the issue with your account?',
      'type': 'word_selection',
      'words': ['What', 'is', 'the', 'issue', 'with', 'your', 'account?'],
      'correctAnswer': 'What',
      'explanation': 'What is the Wh- question word for asking about specific information.',
    },
    {
      'id': 8,
      'question': 'Select the question word. Could you please tell me the price?',
      'type': 'word_selection',
      'words': ['Could', 'you', 'please', 'tell', 'me', 'the', 'price?'],
      'correctAnswer': 'Could',
      'explanation': 'Could is a polite modal verb for requesting information.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _currentAttempt = widget.initialAttemptNumber;
    widget.youtubeController.addListener(_videoListener);
    if (widget.showActivity) {
      _startTimer();
    }
  }

  @override
  void didUpdateWidget(covariant buildLesson2_2 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.youtubeController != oldWidget.youtubeController) {
      oldWidget.youtubeController.removeListener(_videoListener);
      widget.youtubeController.addListener(_videoListener);
    }
    if (widget.showActivity && !oldWidget.showActivity) {
      _resetTimer();
      _startTimer();
      _currentAttempt = widget.initialAttemptNumber;
    } else if (!widget.showActivity && oldWidget.showActivity) {
      _stopTimer();
    }
     if (widget.initialAttemptNumber != oldWidget.initialAttemptNumber) {
        _currentAttempt = widget.initialAttemptNumber;
    }
  }

  @override
  void dispose() {
    widget.youtubeController.removeListener(_videoListener);
    _stopTimer();
    super.dispose();
  }

  void _videoListener() {
    if (widget.youtubeController.value.playerState == PlayerState.ended && !_videoFinished) {
      if (mounted) {
        setState(() {
          _videoFinished = true;
        });
      }
      _logger.i('Video finished in Lesson 2.2');
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _secondsElapsed++;
        });
      } else {
        timer.cancel();
      }
    });
    _logger.i('Stopwatch started for Lesson 2.2. Attempt: $_currentAttempt. Time: $_secondsElapsed');
  }

  void _stopTimer() {
    _timer?.cancel();
    _logger.i('Stopwatch stopped for Lesson 2.2. Attempt: $_currentAttempt. Time elapsed: $_secondsElapsed seconds.');
  }

  void _resetTimer() {
    _stopTimer();
    if (mounted) {
      setState(() {
        _secondsElapsed = 0;
      });
    }
  }

  String _formatDuration(int totalSeconds) {
    final duration = Duration(seconds: totalSeconds);
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
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
        if (widget.currentSlide == slides.length - 1) ...[
          const Text(
            'Watch the Video',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00568D)),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: YoutubePlayer(
              controller: widget.youtubeController,
              showVideoProgressIndicator: true,
              onReady: () => _logger.d('Player is ready in Lesson 2.2.'),
              onEnded: (_) {
                if (mounted) {
                  setState(() {
                    _videoFinished = true;
                  });
                }
                _logger.i('Video ended in Lesson 2.2');
              },
            ),
          ),
          if (!widget.showActivity) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _videoFinished ? widget.onShowActivity : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00568D),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16, color: Colors.white),
                  disabledBackgroundColor: Colors.grey[400],
                ),
                child: const Text('Proceed to Activity', style: TextStyle(color: Colors.white)),
              ),
            ),
            if (!_videoFinished)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text(
                  'Please watch the video to the end to proceed.',
                  style: TextStyle(color: Colors.red, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ],
        if (widget.showActivity) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Time: ${_formatDuration(_secondsElapsed)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black54),
                ),
              ],
            ),
          ),
          const Text(
            'Interactive Activity: Polite Questions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
          ),
          const SizedBox(height: 8),
          ...questions.asMap().entries.map((entry) {
            int questionIndex = entry.key;
            Map<String, dynamic> questionData = entry.value;

            List<String> wordsList = (questionData['words'] as List<dynamic>?)?.cast<String>() ??
                                     (questionData['question'] as String?)?.split(' ') ?? [];

            List<String> correctAnswerList;
            final correctAnswerValue = questionData['correctAnswer'];
            if (correctAnswerValue is String) {
              correctAnswerList = correctAnswerValue.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
            } else if (correctAnswerValue is List) {
              correctAnswerList = correctAnswerValue.cast<String>();
            } else {
              correctAnswerList = [];
            }

            return buildInteractiveQuestion(
              question: 'Q${questionData['id']}: ${questionData['question'] as String? ?? ''}',
              type: questionData['type'] as String? ?? '',
              words: wordsList,
              correctAnswer: correctAnswerList,
              explanation: questionData['explanation'] as String? ?? '',
              questionIndex: questionIndex,
              selectedAnswers: widget.selectedAnswers[questionIndex],
              isCorrect: widget.isCorrectStates[questionIndex],
              errorMessage: widget.errorMessages[questionIndex],
              onSelectionChanged: (List<String> newSelectedWords) {
                widget.onWordsSelected(questionIndex, newSelectedWords);
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
                _stopTimer();
                await widget.onSubmitAnswers(questions, _secondsElapsed, _currentAttempt);
                if (mounted) {
                  setState(() {
                    _isSubmitting = false;
                    _currentAttempt++; // <-- increment attempt after submit
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