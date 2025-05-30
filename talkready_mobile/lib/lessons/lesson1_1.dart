import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:logger/logger.dart';
import '../lessons/common_widgets.dart';
import 'dart:async'; // Import for Timer

class buildLesson1_1 extends StatefulWidget {
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

  const buildLesson1_1({
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
  _Lesson1_1State createState() => _Lesson1_1State();
}

class _Lesson1_1State extends State<buildLesson1_1> {
  final Logger _logger = Logger();
  bool _videoFinished = false;
  bool _isSubmitting = false; // Added

  Timer? _timer;
  int _secondsElapsed = 0;
  late int _currentAttempt;

  final List<Map<String, dynamic>> slides = [
    {
      'title': 'Objective: Understanding Pronouns and Nouns',
      'content': 'In this lesson, you will learn to identify pronouns and nouns in customer service scenarios. Mastering these parts of speech ensures clear communication.',
    },
    {
      'title': 'Introduction to Pronouns and Nouns',
      'content': 'Pronouns replace nouns to avoid repetition, and nouns name people, places, or things. In a call center, using them correctly builds clarity and professionalism.',
    },
    {
      'title': 'Key Concepts: Pronouns and Nouns',
      'content': '• Pronouns: Words that replace nouns.\n'
          '  - Personal: I, you, he, she, it, we, they.\n'
          '    Example: "She assists the customer." (She is a pronoun)\n'
          '  - Possessive: Mine, yours, his, hers, ours, theirs.\n'
          '    Example: "The order is yours." (Yours is a pronoun)\n'
          '• Nouns: Words that name people, places, or things.\n'
          '  - Common: agent, customer, order.\n'
          '    Example: "The agent helps." (Agent is a noun)\n'
          '  - Proper: John, Amazon, New York.\n'
          '    Example: "John called Amazon." (John, Amazon are nouns)',
    },
    {
      'title': 'Using Pronouns and Nouns Effectively',
      'content': '• Use pronouns to avoid repeating nouns: Instead of "The customer called, and the customer needs help," say "The customer called, and they need help."\n'
          '• Use specific nouns for clarity: "The agent processes the order" is clearer than "Someone processes something."\n'
          '• Importance: Correct usage builds trust and reduces confusion.',
    },
  ];

    final List<Map<String, dynamic>> questions = [
    {
      'id': 1,
      'question': 'Identify the pronouns. Thank you for calling XYZ Corp. How can I assist you today?',
      'type': 'pronoun',
      'words': ['Thank', 'you', 'for', 'calling', 'XYZ', 'Corp.', 'How', 'can', 'I', 'assist', 'you', 'today?'],
      'correctAnswer': 'I, you',
      'explanation': 'I, you: Pronouns (I refers to the agent, you refers to the customer).',
    },
    {
      'id': 2,
      'question': 'Identify the pronouns. We are processing your order now.',
      'type': 'pronoun',
      'words': ['We', 'are', 'processing', 'your', 'order', 'now.'],
      'correctAnswer': 'we, your',
      'explanation': 'We: Pronoun (refers to the team), Your: Possessive pronoun (refers to the customer’s order).',
    },
    {
      'id': 3,
      'question': 'Identify the pronouns. The system shows it is ready.',
      'type': 'pronoun',
      'words': ['The', 'system', 'shows', 'it', 'is', 'ready.'],
      'correctAnswer': 'it',
      'explanation': 'It: Pronoun (refers to the system or order).',
    },
    {
      'id': 4,
      'question': 'Identify the pronouns. Can I offer you any additional assistance?',
      'type': 'pronoun',
      'words': ['Can', 'I', 'offer', 'you', 'any', 'additional', 'assistance?'],
      'correctAnswer': 'I, you',
      'explanation': 'I, you: Pronouns (I refers to the agent, you refers to the customer).',
    },
    {
      'id': 5,
      'question': 'Identify the nouns. The agent will help the customer.',
      'type': 'noun',
      'words': ['The', 'agent', 'will', 'help', 'the', 'customer.'],
      'correctAnswer': 'agent, customer',
      'explanation': 'Agent, customer: Nouns (agent is the person helping, customer is the person being helped).',
    },
    {
      'id': 6,
      'question': 'Identify the nouns. Your order is ready for shipment.',
      'type': 'noun',
      'words': ['Your', 'order', 'is', 'ready', 'for', 'shipment.'],
      'correctAnswer': 'order, shipment',
      'explanation': 'Order, shipment: Nouns (order is the thing being shipped, shipment is the process).',
    },
    {
      'id': 7,
      'question': 'Identify the nouns. John called Amazon yesterday.',
      'type': 'noun',
      'words': ['John', 'called', 'Amazon', 'yesterday.'],
      'correctAnswer': 'John, Amazon',
      'explanation': 'John, Amazon: Proper nouns (John is a person, Amazon is a company).',
    },
    {
      'id': 8,
      'question': 'Identify the nouns. The refund was processed by the team.',
      'type': 'noun',
      'words': ['The', 'refund', 'was', 'processed', 'by', 'the', 'team.'],
      'correctAnswer': 'refund, team',
      'explanation': 'Refund, team: Nouns (refund is the thing processed, team is the group processing it).',
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
  void didUpdateWidget(covariant buildLesson1_1 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.youtubeController != oldWidget.youtubeController) {
      oldWidget.youtubeController.removeListener(_videoListener);
      widget.youtubeController.addListener(_videoListener);
    }
    if (widget.showActivity && !oldWidget.showActivity) {
      _resetTimer();
      _startTimer();
      // If activity is shown, ensure attempt number is current
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
      _logger.i('Video finished in Lesson 1.1');
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
    _logger.i('Stopwatch started for Lesson 1.1. Attempt: $_currentAttempt. Time: $_secondsElapsed');
  }

  void _stopTimer() {
    _timer?.cancel();
    _logger.i('Stopwatch stopped for Lesson 1.1. Attempt: $_currentAttempt. Time elapsed: $_secondsElapsed seconds.');
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
          'Lesson 1.1: Pronouns and Nouns',
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
              _logger.d('Slide changed to $index in Lesson 1.1');
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
                  onReady: () {
                    _logger.d('Player is ready for videoId: ${widget.youtubeController.initialVideoId} in Lesson 1.1.');
                  },
                  onEnded: (_) {
                     _logger.i('Video ended callback received in Lesson 1.1.');
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
            'Interactive Activity: Pronoun and Noun Identification',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Objective: Click the pronouns or nouns in each customer service scenario.',
            style: TextStyle(fontSize: 16, color: Colors.black87),
          ),
          const SizedBox(height: 16),
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