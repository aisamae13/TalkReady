import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:logger/logger.dart';
import '../lessons/common_widgets.dart';
import 'dart:async'; // Import for Timer

class buildLesson1_2 extends StatefulWidget {
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

  const buildLesson1_2({
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
  _Lesson1_2State createState() => _Lesson1_2State();
}

class _Lesson1_2State extends State<buildLesson1_2> {
  final Logger _logger = Logger();
  bool _videoFinished = false;
  bool _isSubmitting = false; // Added

  Timer? _timer;
  int _secondsElapsed = 0;
  late int _currentAttempt;

  final List<Map<String, dynamic>> slides = [
    {
      'title': 'Objective: Mastering Simple Sentences',
      'content': 'By the end of this lesson, you will be able to form simple sentences correctly and identify sentence types in call center scenarios.',
    },
    {
      'title': 'Introduction to Simple Sentences',
      'content': 'Simple sentences contain one independent clause (a subject and a verb). They are fundamental for clear communication in call centers.\n'
          'Structure: Subject + Verb + (Object/Complement)\n'
          'Example: "I help." (Subject: I, Verb: help)\n'
          'Example: "The customer needs assistance." (Subject: The customer, Verb: needs, Object: assistance)',
    },
    {
      'title': 'Types of Simple Sentences',
      'content': '• Declarative: Makes a statement. Ends with a period (.).\n'
          '  Example: "The agent resolved the issue."\n'
          '• Interrogative: Asks a question. Ends with a question mark (?).\n'
          '  Example: "Can I help you?"\n'
          '• Imperative: Gives a command or makes a request. Ends with a period (.) or exclamation mark (!).\n'
          '  Example: "Please hold the line."\n'
          '• Exclamatory: Expresses strong emotion. Ends with an exclamation mark (!).\n'
          '  Example: "Thank you so much!"',
    },
    {
      'title': 'Call Center Examples',
      'content': '• Declarative: "Your account is updated."\n'
          '• Interrogative: "Do you have your account number?"\n'
          '• Imperative: "Please provide your name."\n'
          '• Exclamatory: "That’s great news!"\n'
          'Using varied sentence types makes conversations engaging.',
    },
    {
      'title': 'Conclusion',
      'content': 'You learned to form simple sentences and identify their types. This skill is crucial for effective and professional communication in call centers. Practice using these sentence structures in your interactions.',
    },
  ];

    final List<Map<String, dynamic>> questions = [
    {
      'id': 1,
      'question': 'Identify the subject. I will help you today.',
      'type': 'subject',
      'words': ['I', 'will', 'help', 'you', 'today.'],
      'correctAnswer': 'I',
      'explanation': 'I: The subject (the agent who is performing the action).',
    },
    {
      'id': 2,
      'question': 'Identify the subject. The customer called yesterday.',
      'type': 'subject',
      'words': ['The', 'customer', 'called', 'yesterday.'],
      'correctAnswer': 'The customer',
      'explanation': 'The customer: The subject (who performed the action of calling).',
    },
    {
      'id': 3,
      'question': 'Identify the subject. Your order ships tomorrow.',
      'type': 'subject',
      'words': ['Your', 'order', 'ships', 'tomorrow.'],
      'correctAnswer': 'Your order',
      'explanation': 'Your order: The subject (what is performing the action of shipping).',
    },
    {
      'id': 4,
      'question': 'Identify the subject. We process your request now.',
      'type': 'subject',
      'words': ['We', 'process', 'your', 'request', 'now.'],
      'correctAnswer': 'We',
      'explanation': 'We: The subject (the team or company processing the request).',
    },
    {
      'id': 5,
      'question': 'Identify the verb. The agent assists you.',
      'type': 'verb',
      'words': ['The', 'agent', 'assists', 'you.'],
      'correctAnswer': 'assists',
      'explanation': 'Assists: The verb (the action the agent is performing).',
    },
    {
      'id': 6,
      'question': 'Identify the verb. Your refund arrives soon.',
      'type': 'verb',
      'words': ['Your', 'refund', 'arrives', 'soon.'],
      'correctAnswer': 'arrives',
      'explanation': 'Arrives: The verb (the action describing the refund).',
    },
    {
      'id': 7,
      'question': 'Identify the verb. I check the system.',
      'type': 'verb',
      'words': ['I', 'check', 'the', 'system.'],
      'correctAnswer': 'check',
      'explanation': 'Check: The verb (the action the agent is performing).',
    },
    {
      'id': 8,
      'question': 'Identify the verb. The team resolves the issue.',
      'type': 'verb',
      'words': ['The', 'team', 'resolves', 'the', 'issue.'],
      'correctAnswer': 'resolves',
      'explanation': 'Resolves: The verb (the action the team is performing).',
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
  void didUpdateWidget(covariant buildLesson1_2 oldWidget) {
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
      _logger.i('Video finished in Lesson 1.2');
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
    _logger.i('Stopwatch started for Lesson 1.2. Attempt: $_currentAttempt. Time: $_secondsElapsed');
  }

  void _stopTimer() {
    _timer?.cancel();
    _logger.i('Stopwatch stopped for Lesson 1.2. Attempt: $_currentAttempt. Time elapsed: $_secondsElapsed seconds.');
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
          'Lesson 1.2: Simple Sentences',
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
              _logger.d('Slide changed to $index in Lesson 1.2');
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
                return YoutubePlayer(
                  controller: widget.youtubeController,
                  showVideoProgressIndicator: true,
                  progressIndicatorColor: Colors.amber,
                  progressColors: const ProgressBarColors(
                    playedColor: Colors.amber,
                    handleColor: Colors.amberAccent,
                  ),
                  onReady: () => _logger.d('Player is ready in Lesson 1.2.'),
                   onEnded: (_) {
                    _logger.i('Video ended callback received in Lesson 1.2.');
                    if (!_videoFinished && mounted) {
                       setState(() {
                        _videoFinished = true;
                      });
                    }
                  },
                );
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
            'Interactive Activity: Identify Sentence Types',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Objective: Choose the correct sentence type for each example.',
            style: TextStyle(fontSize: 16, color: Colors.black87),
          ),
          const SizedBox(height: 16),
          ...questions.asMap().entries.map((entry) {
            int questionIndex = entry.key;
            Map<String, dynamic> questionData = entry.value;
            
            List<String> wordsList = (questionData['words'] as List<dynamic>?)?.cast<String>() ?? [];
            List<String> correctAnswerList = [(questionData['correctAnswer'] as String?) ?? ''];


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