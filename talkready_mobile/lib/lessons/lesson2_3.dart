import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:logger/logger.dart';
import '../lessons/common_widgets.dart';
import 'dart:async';

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
  final Function(List<Map<String, dynamic>> questionsData, int timeSpent, int attemptNumber) onSubmitAnswers;
  final Function(int questionIndex, List<String> selectedWords) onWordsSelected;
  final int initialAttemptNumber;

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
    required this.onWordsSelected,
    required this.initialAttemptNumber,
  });

  @override
  _Lesson2_3State createState() => _Lesson2_3State();
}

class _Lesson2_3State extends State<buildLesson2_3> {
  final Logger _logger = Logger();
  bool _videoFinished = false;
  Timer? _timer;
  bool _isSubmitting = false; // Added
  int _secondsElapsed = 0;
  late int _currentAttempt;

  final List<Map<String, dynamic>> slides = [
    {
      'title': 'Objective: Understanding Numbers and Dates',
      'content': 'Learn to correctly say and understand numbers (cardinal, ordinal) and dates, crucial for scheduling and transactions in a call center.',
    },
    {
      'title': 'Cardinal and Ordinal Numbers',
      'content': '• Cardinal Numbers: Indicate quantity (one, two, three).\n'
          '  Example: "There are three items in your order."\n'
          '• Ordinal Numbers: Indicate position or rank (first, second, third).\n'
          '  Example: "This is your first call to us."',
    },
    {
      'title': 'Saying Dates',
      'content': '• Common formats: Month Day, Year (e.g., "July fourth, twenty twenty-three") or Day Month, Year (e.g., "the fourth of July, twenty twenty-three").\n'
          '• Be clear and consistent.\n'
          '  Example: "Your appointment is scheduled for August 15th, 2024."',
    },
    {
      'title': 'Understanding Time and Prices',
      'content': '• Time: Use AM/PM or 24-hour format clearly.\n'
          '  Example: "The store closes at 9 PM." or "The meeting is at 14:00."\n'
          '• Prices: State currency and amounts clearly.\n'
          '  Example: "The total is twenty-five dollars and fifty cents (25.50)."',
    },
    {
      'title': 'Conclusion',
      'content': 'Accurate use of numbers, dates, and times prevents errors and misunderstandings. Practice these to ensure clarity in customer interactions.',
    },
  ];

  final List<Map<String, dynamic>> questions = [
    {
      'id': 1,
      'question': 'Select the number. The price is twenty dollars.',
      'type': 'word_selection',
      'words': ['The', 'price', 'is', 'twenty', 'dollars.'],
      'correctAnswer': 'twenty',
      'explanation': 'Twenty is the cardinal number for 20.',
    },
    {
      'id': 2,
      'question': 'Select the number. This is my first call.',
      'type': 'word_selection',
      'words': ['This', 'is', 'my', 'first', 'call.'],
      'correctAnswer': 'first',
      'explanation': 'First is the ordinal number for 1st.',
    },
    {
      'id': 3,
      'question': 'Select the date word. My birthday is on January first.',
      'type': 'word_selection',
      'words': ['My', 'birthday', 'is', 'on', 'January', 'first.'],
      'correctAnswer': 'January',
      'explanation': 'January is a month used in dates.',
    },
    {
      'id': 4,
      'question': 'Select the date word. The order was placed on the second of March.',
      'type': 'word_selection',
      'words': ['The', 'order', 'was', 'placed', 'on', 'the', 'second', 'of', 'March.'],
      'correctAnswer': 'second',
      'explanation': 'Second is the ordinal number for 2nd.',
    },
    {
      'id': 5,
      'question': 'Select the number. The price is thirty-five dollars.',
      'type': 'word_selection',
      'words': ['The', 'price', 'is', 'thirty-five', 'dollars.'],
      'correctAnswer': 'thirty-five',
      'explanation': 'Thirty-five is the cardinal number for 35.',
    },
    {
      'id': 6,
      'question': 'Select the date word. Your appointment is on April tenth.',
      'type': 'word_selection',
      'words': ['Your', 'appointment', 'is', 'on', 'April', 'tenth.'],
      'correctAnswer': 'April',
      'explanation': 'April is a month used in dates.',
    },
    {
      'id': 7,
      'question': 'Select the number. This is the third call today.',
      'type': 'word_selection',
      'words': ['This', 'is', 'the', 'third', 'call', 'today.'],
      'correctAnswer': 'third',
      'explanation': 'Third is the ordinal number for 3rd.',
    },
    {
      'id': 8,
      'question': 'Select the date word. The event is on December twenty-fifth.',
      'type': 'word_selection',
      'words': ['The', 'event', 'is', 'on', 'December', 'twenty-fifth.'],
      'correctAnswer': 'December',
      'explanation': 'December is a month used in dates.',
    },
    {
      'id': 9,
      'question': 'Select the number. The total is fifty dollars.',
      'type': 'word_selection',
      'words': ['The', 'total', 'is', 'fifty', 'dollars.'],
      'correctAnswer': 'fifty',
      'explanation': 'Fifty is the cardinal number for 50.',
    },
    {
      'id': 10,
      'question': 'Select the date word. The deadline is the fifteenth of June.',
      'type': 'word_selection',
      'words': ['The', 'deadline', 'is', 'the', 'fifteenth', 'of', 'June.'],
      'correctAnswer': 'fifteenth',
      'explanation': 'Fifteenth is the ordinal number for 15th.',
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
  void didUpdateWidget(covariant buildLesson2_3 oldWidget) {
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
      _logger.i('Video finished in Lesson 2.3');
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
    _logger.i('Stopwatch started for Lesson 2.3. Attempt: $_currentAttempt. Time: $_secondsElapsed');
  }

  void _stopTimer() {
    _timer?.cancel();
    _logger.i('Stopwatch stopped for Lesson 2.3. Attempt: $_currentAttempt. Time elapsed: $_secondsElapsed seconds.');
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
              onReady: () => _logger.d('Player is ready in Lesson 2.3.'),
              onEnded: (_) {
                if (mounted) {
                  setState(() {
                    _videoFinished = true;
                  });
                }
                _logger.i('Video ended in Lesson 2.3');
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
            'Interactive Activity: Numbers and Dates',
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