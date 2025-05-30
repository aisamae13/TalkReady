import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:logger/logger.dart';
import 'dart:async';
import '../lessons/common_widgets.dart';


class Lesson3_1 extends StatefulWidget {
  final CarouselSliderController carouselController;
  final YoutubePlayerController youtubeController;
  final bool showActivity;
  final VoidCallback onShowActivity;
  final int currentSlide;
  final Function(int) onSlideChanged;

  // New parameters for state management from module page
  final List<List<String>> selectedAnswers; // Expects List<List<String>> even for single answer
  final List<bool?> isCorrectStates;
  final List<String?> errorMessages;
  final Function(int questionIndex, bool isCorrect, int selectedOptionIndex) onAnswerChanged;
  final Function(List<Map<String, dynamic>> questionsData, int timeSpent, int attemptNumber, List<List<String>> directAnswers) onSubmitAnswers;
  final int initialAttemptNumber;


  const Lesson3_1({
    super.key,
    required this.carouselController,
    required this.youtubeController,
    required this.showActivity,
    required this.onShowActivity,
    required this.selectedAnswers,
    required this.isCorrectStates,
    required this.errorMessages,
    required this.onAnswerChanged,
    required this.onSubmitAnswers,
    required this.initialAttemptNumber,
    required this.currentSlide,
    required this.onSlideChanged,
  });

  @override
  State<Lesson3_1> createState() => _Lesson3_1State();
}

class _Lesson3_1State extends State<Lesson3_1> {
  final Logger _logger = Logger();
  bool _videoFinished = false;
  int _selectedAnswerIndex = -1; // For the Radio button
  bool _isSubmitting = false; // Added for loading state
  
  Timer? _timer;
  int _secondsElapsed = 0;
  late int _currentAttempt;

  // Structured question data
  final List<Map<String, dynamic>> questions = [
    {
      'id': 1,
      'question': 'What did the customer ask for in the audio?', // Audio prompt
      'type': 'mcq', // Multiple Choice Question
      'options': [
        'A refund',
        'Technical support',
        'Order status',
        'Product information',
      ],
      'correctAnswer': '2', // Index of the correct option (Order status)
      'explanation': 'The customer in the audio example asked about the status of their order.',
    }
  ];

  @override
  void initState() {
    super.initState();
    _currentAttempt = widget.initialAttemptNumber;
    widget.youtubeController.addListener(_videoListener);
    if (widget.selectedAnswers.isNotEmpty && widget.selectedAnswers[0].isNotEmpty) {
      _selectedAnswerIndex = int.tryParse(widget.selectedAnswers[0][0]) ?? -1;
    }
    if (widget.showActivity) {
      _startTimer();
    }
     _logger.i('Lesson 3.1 initState: initialAttemptNumber=${widget.initialAttemptNumber}, showActivity=${widget.showActivity}');
  }
  
  @override
  void didUpdateWidget(covariant Lesson3_1 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.youtubeController != oldWidget.youtubeController) {
      oldWidget.youtubeController.removeListener(_videoListener);
      widget.youtubeController.addListener(_videoListener);
    }
    if (widget.showActivity && !oldWidget.showActivity) {
      _resetTimer();
      _startTimer();
      _currentAttempt = widget.initialAttemptNumber; // Reset attempt if activity is newly shown
       _logger.i('Lesson 3.1 didUpdateWidget: showActivity became true, attempt reset to $_currentAttempt');
    } else if (!widget.showActivity && oldWidget.showActivity) {
      _stopTimer();
    }
     if (widget.initialAttemptNumber != oldWidget.initialAttemptNumber) {
        _currentAttempt = widget.initialAttemptNumber;
        _logger.i('Lesson 3.1 didUpdateWidget: initialAttemptNumber changed to $_currentAttempt');
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
      if (mounted) setState(() => _videoFinished = true);
      _logger.i('Lesson 3.1 Video finished.');
    }
  }

  void _startTimer() {
    _timer?.cancel(); // Cancel any existing timer
    _secondsElapsed = 0; // Reset time
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _secondsElapsed++;
        });
      } else {
        timer.cancel(); // Stop timer if widget is disposed
      }
    });
     _logger.i('Lesson 3.1 Timer started. Attempt: $_currentAttempt');
  }

  void _stopTimer() {
    _timer?.cancel();
    _logger.i('Lesson 3.1 Timer stopped. Time: $_secondsElapsed s, Attempt: $_currentAttempt');
  }

  void _resetTimer() {
    _stopTimer();
    if(mounted) {
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

  final List<Map<String, dynamic>> slides = [
    {
      'title': 'Objective: Listening Comprehension',
      'content': 'Listen carefully to the audio played in the video and answer the question based on what you hear.',
    },
    {
      'title': 'Tips for Listening',
      'content': 'Focus on key words, the context of the conversation, and try to understand the main idea or purpose of the speaker.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final questionData = questions[0]; // Since there's only one question

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Lesson 3.1: Listening Comprehension',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF00568D)),
        ),
        const SizedBox(height: 16),
        CarouselSlider(
          carouselController: widget.carouselController,
          items: slides.map((slide) {
            return buildSlide(
              title: slide['title'],
              content: slide['content'],
              slideIndex: slides.indexOf(slide), // Pass the actual index
            );
          }).toList(),
          options: CarouselOptions(
            height: 220.0, // Adjusted height
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

        if (widget.currentSlide == slides.length - 1) ...[
          const Text(
            'Watch the Video (Listen to the Audio)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00568D)),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: YoutubePlayer(
              controller: widget.youtubeController,
              showVideoProgressIndicator: true,
              onReady: () => _logger.d('Lesson 3.1 Player is ready.'),
              onEnded: (_) {
                 if (mounted) setState(() => _videoFinished = true);
                 _logger.i('Lesson 3.1 Video ended.');
              }
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
                  'Please listen to the audio in the video to the end to proceed.',
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
                Text(
                  'Attempt: $_currentAttempt',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black54),
                ),
              ],
            ),
          ),
          Text(
            questionData['question'] as String,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
          ),
          const SizedBox(height: 12),
          ...(questionData['options'] as List<String>).asMap().entries.map((entry) {
            int idx = entry.key;
            String optionText = entry.value;
            return ListTile(
              title: Text(optionText),
              leading: Radio<int>(
                value: idx,
                groupValue: _selectedAnswerIndex,
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedAnswerIndex = val;
                      bool isCorrect = _selectedAnswerIndex.toString() == (questionData['correctAnswer'] as String);
                      widget.onAnswerChanged(0, isCorrect, _selectedAnswerIndex); // questionIndex is 0
                    });
                  }
                },
              ),
            );
          }).toList(),
          const SizedBox(height: 12),
          if (widget.isCorrectStates.isNotEmpty && widget.isCorrectStates[0] != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                widget.isCorrectStates[0]!
                    ? 'Correct! ${questionData['explanation']}'
                    : 'Incorrect. ${questionData['explanation']}',
                style: TextStyle(
                  color: widget.isCorrectStates[0]! ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_selectedAnswerIndex != -1 && !_isSubmitting) ? () async {
  setState(() { _isSubmitting = true; });
  _stopTimer();
  List<List<String>> directAnswers = [[_selectedAnswerIndex.toString()]];
  await widget.onSubmitAnswers(questions, _secondsElapsed, _currentAttempt, directAnswers);
  _logger.i('Lesson 3.1 Submitted. Attempt: $_currentAttempt, Time: $_secondsElapsed, Answer: $_selectedAnswerIndex');
  if (mounted) {
    setState(() {
      _isSubmitting = false;
      _currentAttempt++; // <-- increment attempt after submit
    });
  }
} : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00568D),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[400],
              ),
              child: _isSubmitting // Modified
                  ? const SizedBox( // Added
                      height: 20, 
                      width: 20,  
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Submit Answer'), 
            ),
          ),
        ],
      ],
    );
  }
}