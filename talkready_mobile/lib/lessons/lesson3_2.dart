import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:logger/logger.dart';
import 'dart:async';
import '../lessons/common_widgets.dart';


class Lesson3_2 extends StatefulWidget {
  final CarouselSliderController carouselController;
  final YoutubePlayerController youtubeController;
  final bool showActivity;
  final VoidCallback onShowActivity;
  final int currentSlide;
  final Function(int) onSlideChanged;

  // New parameters
  final List<List<String>> selectedAnswers; // To store recorded text
  final List<bool?> isCorrectStates;
  final List<String?> errorMessages;
  final Function(int questionIndex, bool isCorrect, String recordedText) onAnswerChanged;
  final Function(List<Map<String, dynamic>> questionsData, int timeSpent, int attemptNumber, List<List<String>> directAnswers) onSubmitAnswers;
  final int initialAttemptNumber;

  const Lesson3_2({
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
  State<Lesson3_2> createState() => _Lesson3_2State();
}

class _Lesson3_2State extends State<Lesson3_2> {
  final Logger _logger = Logger();
  bool _videoFinished = false;
  String? _recordedText;
  bool _isRecording = false; 
  bool _isSubmitting = false; // Added
  
  Timer? _timer;
  int _secondsElapsed = 0;
  late int _currentAttempt;

  final List<Map<String, dynamic>> slides = [
    {
      'title': 'Objective: Speaking Practice',
      'content': 'Practice speaking by recording your answer to the prompt after watching the video. This helps build confidence and fluency.',
    },
    {
      'title': 'Tips for Speaking',
      'content': 'Speak clearly and at a natural pace. Try to use complete sentences and appropriate vocabulary learned in previous lessons.',
    },
  ];

  // Structured question data for the speaking prompt
  final List<Map<String, dynamic>> questions = [
    {
      'id': 1,
      'question': 'Please introduce yourself as if you are answering a customer call for the first time. Include your name and offer assistance.',
      'type': 'speaking',
      'correctAnswer': 'N/A', // No specific correct text, completion based
      'explanation': 'The goal is to practice a professional introduction.',
    }
  ];


  @override
  void initState() {
    super.initState();
    _currentAttempt = widget.initialAttemptNumber;
    widget.youtubeController.addListener(_videoListener);
    if (widget.selectedAnswers.isNotEmpty && widget.selectedAnswers[0].isNotEmpty) {
      _recordedText = widget.selectedAnswers[0][0];
    }
     if (widget.showActivity) {
      _startTimer();
    }
    _logger.i('Lesson 3.2 initState: initialAttemptNumber=${widget.initialAttemptNumber}, showActivity=${widget.showActivity}');
  }

  @override
  void didUpdateWidget(covariant Lesson3_2 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.youtubeController != oldWidget.youtubeController) {
      oldWidget.youtubeController.removeListener(_videoListener);
      widget.youtubeController.addListener(_videoListener);
    }
     if (widget.showActivity && !oldWidget.showActivity) {
      _resetTimer();
      _startTimer();
      _currentAttempt = widget.initialAttemptNumber;
      _logger.i('Lesson 3.2 didUpdateWidget: showActivity became true, attempt reset to $_currentAttempt');
    } else if (!widget.showActivity && oldWidget.showActivity) {
      _stopTimer();
    }
    if (widget.initialAttemptNumber != oldWidget.initialAttemptNumber) {
        _currentAttempt = widget.initialAttemptNumber;
        _logger.i('Lesson 3.2 didUpdateWidget: initialAttemptNumber changed to $_currentAttempt');
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
      _logger.i('Lesson 3.2 Video finished.');
    }
  }
  
  void _startTimer() {
    _timer?.cancel();
    _secondsElapsed = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _secondsElapsed++;
        });
      } else {
        timer.cancel();
      }
    });
    _logger.i('Lesson 3.2 Timer started. Attempt: $_currentAttempt');
  }

  void _stopTimer() {
    _timer?.cancel();
     _logger.i('Lesson 3.2 Timer stopped. Time: $_secondsElapsed s, Attempt: $_currentAttempt');
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

  // Placeholder for microphone recording logic
  Future<void> _recordVoice() async {
    setState(() => _isRecording = true);
    _logger.i("Lesson 3.2: Simulating voice recording start.");
    // Simulate recording
    await Future.delayed(const Duration(seconds: 3)); // Simulate recording time

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        TextEditingController controller = TextEditingController();
        return AlertDialog(
          title: const Text('Simulate Voice Recording'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: "Type your spoken response here"),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text.isNotEmpty ? controller.text : "Sample recorded response."),
              child: const Text('Finish Recording'),
            ),
          ],
        );
      }
    );
    
    setState(() => _isRecording = false);
    if (result != null && mounted) {
      setState(() {
        _recordedText = result;
        // Notify module page about the change
        widget.onAnswerChanged(0, true, _recordedText!); // questionIndex 0, isCorrect true for submission
      });
      _logger.i("Lesson 3.2: Simulated voice recording finished. Text: $_recordedText");
    } else {
      _logger.i("Lesson 3.2: Simulated voice recording cancelled or no input.");
    }
  }

  @override
 Widget build(BuildContext context) {
    final speakingPrompt = questions[0]['question'] as String;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Lesson 3.2: Speaking Practice',
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
            'Watch the Video Example',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00568D)),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: YoutubePlayer(
              controller: widget.youtubeController,
              showVideoProgressIndicator: true,
              onReady: () => _logger.d('Lesson 3.2 Player is ready.'),
              onEnded: (_) {
                 if (mounted) setState(() => _videoFinished = true);
                 _logger.i('Lesson 3.2 Video ended.');
              }
            ),
          ),
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
            speakingPrompt,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: Icon(_isRecording ? Icons.stop_circle_outlined : Icons.mic),
            label: Text(_isRecording ? 'Recording...' : 'Record Your Answer'),
            onPressed: _isRecording ? null : _recordVoice,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isRecording ? Colors.redAccent : Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
          if (_recordedText != null && !_isRecording) ...[
            const SizedBox(height: 12),
            const Text('Your recorded answer (simulated):', style: TextStyle(fontWeight: FontWeight.bold)),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200)
              ),
              child: Text(_recordedText!),
            ),
          ],
          const SizedBox(height: 16),
         SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_recordedText != null && !_isRecording && !_isSubmitting) ? () async {
  setState(() { _isSubmitting = true; });
  _stopTimer();
  List<List<String>> directAnswers = [[_recordedText!]];
  await widget.onSubmitAnswers(questions, _secondsElapsed, _currentAttempt, directAnswers);
  _logger.i('Lesson 3.2 Submitted. Attempt: $_currentAttempt, Time: $_secondsElapsed, Response: "$_recordedText"');
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
              child: _isSubmitting 
                  ? const SizedBox( 
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Submit Recording'), 
            ),
          ),
           if (widget.isCorrectStates.isNotEmpty && widget.isCorrectStates[0] == true) // Submitted
            const Padding(
              padding: EdgeInsets.only(top: 12.0),
              child: Text(
                'Thank you for submitting your answer!',
                style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ],
    );
  }
}
