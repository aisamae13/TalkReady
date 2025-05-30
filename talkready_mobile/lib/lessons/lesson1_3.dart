import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart'
    show YoutubePlayer, YoutubePlayerController, PlayerState, ProgressBarColors;
import 'package:logger/logger.dart';
import '../lessons/common_widgets.dart';
import 'dart:async'; // Import for Timer

class buildLesson1_3 extends StatefulWidget {
  final BuildContext context;
  final int currentSlide;
  final CarouselSliderController carouselController;
  final YoutubePlayerController youtubeController;
  final bool showActivity;
  final VoidCallback onShowActivity;
  final List<bool?> isCorrectStates;
  final List<String?> errorMessages;
  final Function(int) onSlideChanged;
  final Function(
          List<Map<String, dynamic>> questionsData,
          List<String> userAnswers, // This is what lesson1_3 will provide on submit
          int timeSpent,
          int attemptNumber)
      onSubmitAnswers; // This callback signature is correct for how lesson1_3 uses it
  final int initialAttemptNumber;

  const buildLesson1_3({
    super.key,
    required this.context,
    required this.currentSlide,
    required this.carouselController,
    required this.youtubeController,
    required this.showActivity,
    required this.onShowActivity,
    required this.isCorrectStates,
    required this.errorMessages,
    required this.onSlideChanged,
    required this.onSubmitAnswers,
    required this.initialAttemptNumber,
  });

  @override
  _Lesson1_3State createState() => _Lesson1_3State();
}

class _Lesson1_3State extends State<buildLesson1_3> {
  final Logger _logger = Logger();
  late List<TextEditingController> _controllers;
  bool _videoFinished = false;
  bool _isSubmitting = false; // Added

  Timer? _timer;
  int _secondsElapsed = 0;
  late int _currentAttempt;

  final List<Map<String, dynamic>> slides = [
    {
      'title': 'Objective: Mastering Present Simple Tense',
      'content':
          'By the end of this lesson, you will be able to use the present simple tense correctly in sentences and apply subject-verb agreement in call center scenarios.',
    },
    {
      'title': 'Introduction to Present Simple Tense',
      'content':
          'The present simple tense describes regular actions, habits, and general truths. It is commonly used in call centers for daily communication.\n'
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
      'content':
          '• Singular Subjects (He, She, It): Add -s to the base verb in affirmative sentences.\n'
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
      'content':
          'You learned how to form and use the present simple tense and apply subject-verb agreement. This skill is crucial for clear and accurate communication in call centers. Practice using it in real scenarios to enhance professionalism.',
    },
  ];

  final List<Map<String, dynamic>> questions = [
    {
      'id': 1,
      'question': 'I ___ (help) the customer with their order.',
      'type': 'verb',
      'correctAnswer': 'help',
      'explanation':
          'Base verb for plural subject (I) in affirmative sentence.',
    },
    {
      'id': 2,
      'question': 'The agent ___ (answer) the phone calls promptly.',
      'type': 'verb',
      'correctAnswer': 'answers',
      'explanation': 'Base verb + -s for singular subject (The agent).',
    },
    {
      'id': 3,
      'question': 'You ___ (resolve) customer issues efficiently.',
      'type': 'verb',
      'correctAnswer': 'resolve',
      'explanation':
          'Base verb for plural subject (You) in affirmative sentence.',
    },
    {
      'id': 4,
      'question': 'She ___ (assist) customers every day.',
      'type': 'verb',
      'correctAnswer': 'assists',
      'explanation': 'Base verb + -s for singular subject (She).',
    },
    {
      'id': 5,
      'question': 'They ___ (provide) excellent customer service.',
      'type': 'verb',
      'correctAnswer': 'provide',
      'explanation':
          'Base verb for plural subject (They) in affirmative sentence.',
    },
    {
      'id': 6,
      'question': 'The customer ___ (explain) the issue.',
      'type': 'verb',
      'correctAnswer': 'explains',
      'explanation': 'Base verb + -s for singular subject (The customer).',
    },
    {
      'id': 7,
      'question': 'We ___ (check) the details of the order.',
      'type': 'verb',
      'correctAnswer': 'check',
      'explanation':
          'Base verb for plural subject (We) in affirmative sentence.',
    },
    {
      'id': 8,
      'question': 'He ___ (not, answer) the customer’s question.',
      'type': 'verb',
      'correctAnswer': 'does not answer',
      'explanation': 'Negative form for singular subject (He).',
    },
    {
      'id': 9,
      'question': 'I ___ (not, work) on weekends.',
      'type': 'verb',
      'correctAnswer': 'do not work',
      'explanation': 'Negative form for plural subject (I).',
    },
    {
      'id': 10,
      'question': 'Does she ___ (assist) you with your problem?',
      'type': 'verb',
      'correctAnswer': 'assist',
      'explanation':
          'Base verb in interrogative form for singular subject (She).',
    },
  ];

  @override
  void initState() {
    super.initState();
    _currentAttempt = widget.initialAttemptNumber;
    _controllers = List.generate(questions.length, (i) {
      final controller = TextEditingController();
      // OPTIONAL: Pre-fill if initialUserAnswers is provided
      // if (widget.initialUserAnswers != null && i < widget.initialUserAnswers!.length) {
      //   controller.text = widget.initialUserAnswers![i];
      // }
      return controller;
    });
    widget.youtubeController.addListener(_videoListener);

    if (widget.showActivity) {
      _startTimer();
    }
  }

  @override
  void didUpdateWidget(covariant buildLesson1_3 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.youtubeController != widget.youtubeController) {
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
      // OPTIONAL: If supporting "Try Again" with pre-filled previous answers from parent
      // if (widget.initialUserAnswers != null) {
      //   for (int i = 0; i < _controllers.length; i++) {
      //     if (i < widget.initialUserAnswers!.length) {
      //       _controllers[i].text = widget.initialUserAnswers![i];
      //     } else {
      //       _controllers[i].clear();
      //     }
      //   }
      // } else { // Clear for a fresh attempt if no initial answers provided
      //    _controllers.forEach((controller) => controller.clear());
      // }
    }
  }

  @override
  void dispose() {
    widget.youtubeController.removeListener(_videoListener);
    _logger.i(
        'Disposing ${_controllers.length} TextEditingControllers for Lesson 1.3');
    for (var controller in _controllers) {
      controller.dispose();
    }
    _stopTimer();
    super.dispose();
  }

  void _videoListener() {
    if (widget.youtubeController.value.playerState == PlayerState.ended &&
        !_videoFinished) {
      if (mounted) {
        setState(() {
          _videoFinished = true;
        });
      }
      _logger.i('Video finished in Lesson 1.3');
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
    _logger.i(
        'Stopwatch started for Lesson 1.3. Attempt: $_currentAttempt. Time: $_secondsElapsed');
  }

  void _stopTimer() {
    _timer?.cancel();
    _logger.i(
        'Stopwatch stopped for Lesson 1.3. Attempt: $_currentAttempt. Time elapsed: $_secondsElapsed seconds.');
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

  Widget buildFillInTheBlankQuestion({
    required String questionText, // This will now include the Qx: prefix
    required int questionIndex,
    required TextEditingController controller,
    bool? isCorrect,
    String? errorMessage,
  }) {
    final parts = questionText.split('___');
    final String beforeText = parts.isNotEmpty ? parts[0] : '';
    final String afterText = parts.length > 1 ? parts[1] : '';

    // Extract hint from the original question format if present, before Qx: prefix
    String hintText = 'Type here';
    final originalQuestionPart = questionText
        .substring(questionText.indexOf(':') + 1)
        .trim(); // Get text after "Qx: "
    if (originalQuestionPart.contains('(') &&
        originalQuestionPart.contains(')')) {
      hintText = originalQuestionPart.substring(
          originalQuestionPart.indexOf('(') + 1,
          originalQuestionPart.indexOf(')'));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 16, color: Colors.black87),
              children: [
                TextSpan(
                    text:
                        beforeText), // beforeText will contain the Qx: prefix and the part before ___
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: hintText,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isCorrect == null
                            ? Colors.grey
                            : (isCorrect == true ? Colors.green : Colors.red),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isCorrect == null
                            ? Theme.of(context).primaryColor
                            : (isCorrect == true ? Colors.green : Colors.red),
                        width: 2,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isCorrect == null
                            ? Colors.grey
                            : (isCorrect == true ? Colors.green : Colors.red),
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  // Removed onChanged here as parent will get values on submit
                ),
              ),
              if (afterText.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(afterText,
                    style:
                        const TextStyle(fontSize: 16, color: Colors.black87)),
              ]
            ],
          ),
          if (errorMessage != null && errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                errorMessage,
                style: TextStyle(
                    color: isCorrect == false ? Colors.red : Colors.green,
                    fontSize: 12),
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
                width: 8.0,
                height: 8.0,
                margin:
                    const EdgeInsets.symmetric(vertical: 10.0, horizontal: 2.0),
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
                  onReady: () => _logger.d('Player is ready in Lesson 1.3.'),
                  onEnded: (_) {
                    _logger.i('Video ended callback received in Lesson 1.3.');
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
                child: const Text('Proceed to Activity',
                    style: TextStyle(color: Colors.white)),
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
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black54),
                ),
              ],
            ),
          ),
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
            'Objective: Fill in the blanks with the correct form of the verb in present simple tense.',
            style: TextStyle(fontSize: 16, color: Colors.black87),
          ),
          const SizedBox(height: 16),
          ...questions.asMap().entries.map((entry) {
            int questionIndex = entry.key;
            Map<String, dynamic> questionData = entry.value;
            return buildFillInTheBlankQuestion(
              questionText:
                  'Q${questionData['id']}: ${questionData['question']}',
              questionIndex: questionIndex,
              controller: _controllers[questionIndex], // This is correct
              isCorrect: widget.isCorrectStates.length > questionIndex
                  ? widget.isCorrectStates[questionIndex]
                  : null, // Pass feedback state
              errorMessage: widget.errorMessages.length > questionIndex
                  ? widget.errorMessages[questionIndex]
                  : null, // Pass feedback state
            );
          }),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: !_isSubmitting
                  ? () async {
                      setState(() {
                        _isSubmitting = true;
                      });
                      _stopTimer();
                      List<String> userAnswers = _controllers
                          .map((controller) => controller.text.trim())
                          .toList();

                      try {
                        await widget.onSubmitAnswers(questions, userAnswers,
                            _secondsElapsed, _currentAttempt);
                        // If successful, the _isSubmitting will be reset below in the finally block,
                        // and you can still proceed with UI changes for success if needed here,
                        // or rely on the parent (module1.dart) to show success messages.
                        // For example, the current attempt increment can stay here if successful.
                        if (mounted) {
                          setState(() {
                            _currentAttempt++;
                          });
                        }
                      } catch (e) {
                        _logger.e(
                            "Error during onSubmitAnswers for Lesson 1.3: $e");
                        // The parent (module1.dart) should ideally show its own error SnackBar.
                        // If not, you can show a generic one here too.
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(
                                    'An error occurred while submitting: $e. Please try again.')),
                          );
                        }
                      } finally {
                        // This block will always execute, whether there was an error or not.
                        if (mounted) {
                          setState(() {
                            _isSubmitting =
                                false; // Ensure loading indicator always stops
                          });
                        }
                      }
                    }
                  : null,
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
                  : const Text('Submit Answers',
                      style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ],
    );
  }
}