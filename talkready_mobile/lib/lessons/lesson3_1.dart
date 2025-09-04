//OK NAMAN

import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:logger/logger.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../lessons/common_widgets.dart';
import '../StudentAssessment/AiFeedbackData.dart';
import '../widgets/parsed_feedback_card.dart';
import '../firebase_service.dart';

class BuildLesson3_1 extends StatefulWidget {
  final BuildContext parentContext;
  final int currentSlide;
  final CarouselSliderController carouselController;
  final YoutubePlayerController youtubeController;
  final Key? youtubePlayerKey;
  final bool showActivitySectionInitially;
  final VoidCallback onShowActivitySection;
  final Function(Map<String, String> userTextAnswers, int timeSpent, int attemptNumberForSubmission) onSubmitAnswers;
  final Function(int) onSlideChanged;
  final int initialAttemptNumber;
  final bool displayFeedback;
  final Map<String, dynamic>? aiFeedbackData;
  final int? overallAIScoreForDisplay;
  final int? maxPossibleAIScoreForDisplay;

  const BuildLesson3_1({
    super.key,
    required this.parentContext,
    required this.currentSlide,
    required this.carouselController,
    required this.youtubeController,
    this.youtubePlayerKey,
    required this.showActivitySectionInitially,
    required this.onShowActivitySection,
    required this.onSubmitAnswers,
    required this.onSlideChanged,
    required this.initialAttemptNumber,
    required this.displayFeedback,
    this.aiFeedbackData,
    this.overallAIScoreForDisplay,
    this.maxPossibleAIScoreForDisplay,
  });

  @override
  _Lesson3_1State createState() => _Lesson3_1State();
}

class _Lesson3_1State extends State<BuildLesson3_1> with TickerProviderStateMixin {
  final Logger _logger = Logger();
  final FirebaseService _firebaseService = FirebaseService();
  late FlutterTts flutterTts;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // TTS and Voice state
  List<dynamic> _voices = [];
  Map<String, String>? _selectedVoice;

  // Content and UI state
  bool _videoFinished = false;
  bool _isSubmitting = false;
  Timer? _timer;
  int _secondsElapsed = 0;
  late int _currentAttemptForDisplay;
  bool _isLoadingLessonContent = true;
  Map<String, dynamic>? _lessonData;
  late Map<String, TextEditingController> _textControllers;

  // Pre-assessment state
  bool _isPreAssessmentComplete = false;
  String _preAssessmentAnswer = '';
  String? _preAssessmentResult; // 'correct' or 'incorrect'
  bool _showPreAssessmentFeedback = false;
  bool _isAudioLoading = false;

  // Activity state
  bool _hasStudied = false;
  bool _isActivityVisible = false;
  bool _showResults = false;
  bool _isTimedOut = false;
  int _countdownTimer = 1200;
  bool _timerActive = false;
  int? _overallScore;
  int _maxPossibleAIScore = 0;
  Map<String, dynamic> _feedback = {};
  Map<String, String> _answers = {};
  String? _loadingAudioId;
  bool _isTranscriptVisible = false;

  // Activity log state
  bool _showActivityLog = false;
  List<Map<String, dynamic>> _activityLog = [];
  bool _activityLogLoading = false;

  static const String staticLessonId = "Lesson-3-1";
  static const int initialTime = 1200;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    // Initialize TTS
    flutterTts = FlutterTts();
    _initializeAndConfigureTts();

    _currentAttemptForDisplay = widget.initialAttemptNumber + 1;
    _textControllers = {};
    _fetchLessonContentAndInitialize();
    widget.youtubeController.addListener(_videoListener);

    if (widget.showActivitySectionInitially && !widget.displayFeedback) {
      _startTimer();
    }

    // Start animation
    _fadeController.forward();

    // Check user authentication and progress
    _checkUserProgressAndPreAssessment();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    widget.youtubeController.removeListener(_videoListener);
    _textControllers.forEach((_, controller) => controller.dispose());
    _stopTimer();
    flutterTts.stop();
    _logger.i("L3.1: Disposed");
    super.dispose();
  }

  Future<void> _checkUserProgressAndPreAssessment() async {
    if (_firebaseService.userId == null) return;

    try {
      final userProgressDoc = await FirebaseFirestore.instance
          .collection('userProgress')
          .doc(_firebaseService.userId)
          .get();

      if (userProgressDoc.exists) {
        final data = userProgressDoc.data();
        final preAssessmentsCompleted = data?['preAssessmentsCompleted'] as Map<String, dynamic>? ?? {};
        
        if (preAssessmentsCompleted[staticLessonId] == true) {
          setState(() {
            _isPreAssessmentComplete = true;
            _hasStudied = true;
          });
        }

        final lessonAttempts = data?['lessonAttempts'] as Map<String, dynamic>? ?? {};
        final attempts = lessonAttempts[staticLessonId] as List<dynamic>? ?? [];
        setState(() {
          _currentAttemptForDisplay = attempts.length + 1;
        });
      }
    } catch (e) {
      _logger.e("Error checking user progress: $e");
    }
  }

  Future<void> _initializeAndConfigureTts() async {
    try {
      var voices = await flutterTts.getVoices;
      if (voices != null && voices is List && mounted) {
        setState(() {
          _voices = voices;
        });
        _setDesiredVoice("en-GB");
      }
    } catch (e) {
      _logger.e("Error getting TTS voices: $e");
    }
    try {
      await flutterTts.setSpeechRate(0.45);
      await flutterTts.setVolume(1.0);
      await flutterTts.setPitch(1.0);
    } catch (e) {
      _logger.e("Error setting basic TTS properties: $e");
    }
    await _configureTts();
  }

  Future<void> _configureTts() async {
    try {
      await flutterTts.stop();
      await flutterTts.setLanguage("en-US");
      await flutterTts.setSpeechRate(0.5);
      await flutterTts.setPitch(0.5);
      await flutterTts.setVolume(1.0);
      _logger.i("L3.1: Flutter TTS configured with rate and pitch adjustments.");
    } catch (e) {
      _logger.e("L3.1: Error configuring TTS settings: $e");
    }
  }

  Future<void> _setDesiredVoice(String targetLocalePrefix) async {
    Map<String, String>? foundVoice;
    for (var voiceDyn in _voices) {
      if (voiceDyn is Map) {
        final voiceMap = Map<String, String>.from(
            voiceDyn.map((k, v) => MapEntry(k.toString(), v.toString())));
        final String? locale = voiceMap['locale']?.toLowerCase();
        if (locale != null && locale.startsWith(targetLocalePrefix.toLowerCase())) {
          foundVoice = voiceMap;
          break;
        }
      }
    }
    if (foundVoice != null) {
      try {
        await flutterTts.setVoice(foundVoice);
        setState(() {
          _selectedVoice = foundVoice;
        });
      } catch (e) {
        _logger.e("L3.1: Error setting specific voice: $e");
      }
    }
  }

  Future<void> _fetchLessonContentAndInitialize() async {
    setState(() => _isLoadingLessonContent = true);

    // Enhanced hardcoded data matching the React structure
    final Map<String, dynamic> hardcodedData = {
      'moduleTitle': 'Module 3: Listening & Speaking Practice',
      'lessonTitle': 'Lesson 3.1: Listening Comprehension – Understanding Customer Calls',
      'objective': {
        'heading': 'Objective',
        'paragraph': 'To develop effective listening comprehension skills crucial for call center success, focusing on understanding customer needs and emotions accurately.',
      },
      'introduction': {
        'heading': 'Introduction to Listening Comprehension',
        'paragraph1': 'Effective listening is more than just hearing words; it\'s about understanding the full message being conveyed, including the emotions and intentions behind it. In a call center, this skill is paramount for providing excellent customer service.',
        'paragraph2': 'Active listening involves focusing on both verbal (words) and non-verbal cues (tone, pace), identifying keywords and main points, and understanding customer emotions.',
      },
      'slides': [
        {
          'title': 'Objective',
          'content': 'To develop effective listening comprehension skills crucial for call center success, focusing on understanding customer needs and emotions accurately.',
        },
        {
          'title': 'Introduction',
          'content': 'Effective listening is more than just hearing words; it\'s about understanding the full message being conveyed, including the emotions and intentions behind it.',
        },
        {
          'title': 'Watch: Mastering Active Listening',
          'content': 'The following video explains active listening techniques essential for call center professionals.',
        },
        {
          'title': 'Key Takeaways',
          'content': '• Active listening involves focusing on both verbal and non-verbal cues\n• Identifying keywords and main points helps in quickly grasping issues\n• Understanding customer emotions is crucial for empathetic service\n• Summarizing or paraphrasing confirms understanding',
        },
      ],
      'video': {'url': 'qY9iPdZfOic'}, // YouTube video ID
      'preAssessmentData': {
        'title': 'Pre-Assessment',
        'instruction': 'Listen to the following audio and type what you hear.',
        'question': 'What is the order number mentioned?',
        'textToSpeak': 'The order number is 784512.',
        'correctAnswer': '784512',
      },
      'activity': {
        'title': 'Listening Activity',
        'instructions': 'Listen to each call script carefully, then answer the questions based on what you heard.',
        'maxPossibleAIScore': 60,
        'timerDuration': 1200,
        'questionSets': [
          {
            'callId': 'call1',
            'questions': [
              {
                'id': 'call1_q1',
                'text': 'What was the customer\'s issue?',
              },
              {
                'id': 'call1_q2',
                'text': 'What information did the agent ask for?',
              },
              {
                'id': 'call1_q3',
                'text': 'What solution did the agent offer?',
              },
              {
                'id': 'call1_q4',
                'text': 'Was the customer satisfied with the response? (e.g., Yes/No, and why)',
              },
            ],
          },
          {
            'callId': 'call2',
            'questions': [
              {
                'id': 'call2_q1',
                'text': 'What was the customer\'s issue?',
              },
              {
                'id': 'call2_q2',
                'text': 'What information did the agent ask for?',
              },
              {
                'id': 'call2_q3',
                'text': 'What solution did the agent offer?',
              },
              {
                'id': 'call2_q4',
                'text': 'Was the customer satisfied with the response? (e.g., Yes/No, and why)',
              },
            ],
          },
          {
            'callId': 'call3',
            'questions': [
              {
                'id': 'call3_q1',
                'text': 'What was the customer\'s issue?',
              },
              {
                'id': 'call3_q2',
                'text': 'What information did the agent ask for?',
              },
              {
                'id': 'call3_q3',
                'text': 'What solution did the agent offer?',
              },
              {
                'id': 'call3_q4',
                'text': 'Was the customer satisfied with the response? (e.g., Yes/No, and why)',
              },
            ],
          },
        ],
        'transcripts': {
          'call1': [
            {'character': 'Customer', 'text': 'Hi, I received the wrong item in my order.'},
            {'character': 'Agent', 'text': 'I\'m really sorry about that. Can you please provide the order number?'},
            {'character': 'Customer', 'text': 'It\'s 784512.'},
            {'character': 'Agent', 'text': 'Thank you. I\'ll arrange a replacement right away.'},
            {'character': 'Customer', 'text': 'Thanks.'},
          ],
          'call2': [
            {'character': 'Customer', 'text': 'My internet has been disconnected for two days.'},
            {'character': 'Agent', 'text': 'I apologize for the inconvenience. Can I have your account ID?'},
            {'character': 'Customer', 'text': 'Sure, it\'s 56102.'},
            {'character': 'Agent', 'text': 'I\'ve reported the issue and a technician will visit tomorrow.'},
            {'character': 'Customer', 'text': 'Great, thanks.'},
          ],
          'call3': [
            {'character': 'Customer', 'text': 'I was charged twice for the same bill.'},
            {'character': 'Agent', 'text': 'I see. Can I verify your billing date and amount?'},
            {'character': 'Customer', 'text': 'April 3rd, \$39.99.'},
            {'character': 'Agent', 'text': 'I\'ll process the refund today.'},
            {'character': 'Customer', 'text': 'Thank you.'},
          ],
        },
      },
    };

    _lessonData = hardcodedData;
    _initializeTextControllers();
    _maxPossibleAIScore = _lessonData!['activity']?['maxPossibleAIScore'] ?? 60;
    
    if (mounted) setState(() => _isLoadingLessonContent = false);
  }

  void _initializeTextControllers() {
    _textControllers.clear();
    _answers.clear();
    
    if (_lessonData?['activity']?['questionSets'] != null) {
      final questionSets = _lessonData!['activity']['questionSets'] as List<dynamic>;
      for (final questionSet in questionSets) {
        final questions = questionSet['questions'] as List<dynamic>;
        for (final question in questions) {
          final questionId = question['id'] as String;
          _textControllers[questionId] = TextEditingController();
          _answers[questionId] = '';
        }
      }
    }
  }

  Future<void> _playScript(String callId) async {
    if (_loadingAudioId != null) return;

    final transcripts = _lessonData?['activity']?['transcripts'];
    final scriptToPlay = transcripts?[callId] as List<dynamic>?;
    
    if (scriptToPlay == null || scriptToPlay.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not find the script text.')),
      );
      return;
    }

    setState(() => _loadingAudioId = callId);

    try {
      // Convert script to readable text for TTS
      final scriptText = scriptToPlay.map((turn) => 
        '${turn['character']}: ${turn['text']}'
      ).join('. ');

      await flutterTts.stop();
      await flutterTts.speak(scriptText);
      
      // Reset loading state after a delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _loadingAudioId = null);
        }
      });
      
    } catch (e) {
      _logger.e("L3.1: Error during TTS speak: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not play the audio script. Please try again.')),
      );
      setState(() => _loadingAudioId = null);
    }
  }

  Future<void> _playPreAssessmentAudio() async {
    if (_isAudioLoading) return;

    final textToSpeak = _lessonData?['preAssessmentData']?['textToSpeak'];
    if (textToSpeak == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No text to speak.')),
      );
      return;
    }

    setState(() => _isAudioLoading = true);

    try {
      await flutterTts.stop();
      await flutterTts.speak(textToSpeak);
    } catch (e) {
      _logger.e("Error playing pre-assessment audio: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not play audio. Please try again.')),
      );
    } finally {
      setState(() => _isAudioLoading = false);
    }
  }

  void _handleCheckPreAssessment() {
    final correctAnswer = _lessonData?['preAssessmentData']?['correctAnswer'] ?? '';
    final isCorrect = _preAssessmentAnswer.trim().toLowerCase() == correctAnswer.toLowerCase();
    
    setState(() {
      _preAssessmentResult = isCorrect ? 'correct' : 'incorrect';
      _showPreAssessmentFeedback = true;
    });

    // Save to Firebase and proceed after delay
    Timer(const Duration(seconds: 3), () async {
      if (_firebaseService.userId != null) {
        try {
          await _markPreAssessmentAsComplete();
          setState(() {
            _isPreAssessmentComplete = true;
            _hasStudied = true;
          });
        } catch (e) {
          _logger.e("Failed to save pre-assessment status: $e");
        }
      } else {
        setState(() => _hasStudied = true);
      }
    });
  }

  Future<void> _markPreAssessmentAsComplete() async {
    if (_firebaseService.userId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('userProgress')
          .doc(_firebaseService.userId)
          .set({
        'preAssessmentsCompleted': {
          staticLessonId: true,
        },
      }, SetOptions(merge: true));
    } catch (e) {
      _logger.e("Error marking pre-assessment as complete: $e");
      rethrow;
    }
  }

  void _videoListener() {
    if (widget.youtubeController.value.playerState == PlayerState.ended && !_videoFinished) {
      if (mounted) setState(() => _videoFinished = true);
      _logger.i('L3.1 Video finished.');
    }
  }

  void _startTimer() {
    _stopTimer();
    _secondsElapsed = 0;
    _countdownTimer = _lessonData?['activity']?['timerDuration'] ?? initialTime;
    _timerActive = true;
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      setState(() {
        if (_countdownTimer > 0) {
          _countdownTimer--;
          _secondsElapsed++;
        } else {
          _isTimedOut = true;
          _timerActive = false;
          timer.cancel();
          _handleSubmitToAIAndFirestore(); // Auto-submit when time runs out
        }
      });
    });
    
    _logger.i('L3.1 Timer started. Attempt: $_currentAttemptForDisplay.');
  }

  void _stopTimer() {
    _timer?.cancel();
    _timerActive = false;
    _logger.i('L3.1 Timer stopped. Elapsed: $_secondsElapsed s.');
  }

  String _formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  void _handleAnswerChanged(String questionId, String value) {
    if (_showResults || _isTimedOut) return;
    
    setState(() {
      _answers[questionId] = value;
      _textControllers[questionId]?.text = value;
    });
  }

  void _handleStudyComplete() {
    setState(() => _hasStudied = true);
  }

  void _handleStartActivity() {
    setState(() {
      _isActivityVisible = true;
      _showResults = false;
      _overallScore = null;
      _isTimedOut = false;
      _isTranscriptVisible = false;
      _countdownTimer = _lessonData?['activity']?['timerDuration'] ?? initialTime;
      
      // Reset answers and controllers
      _answers.clear();
      _feedback.clear();
      _textControllers.forEach((key, controller) {
        controller.clear();
        _answers[key] = '';
      });
    });
    
    _startTimer();
    widget.onShowActivitySection();
  }

  Future<void> _handleSubmitToAIAndFirestore() async {
    if (_firebaseService.userId == null || _lessonData == null) return;
    if (_showResults && !_isTimedOut) return;

    // Check if all fields are filled (unless timed out)
    if (!_isTimedOut) {
      final questionSets = _lessonData!['activity']['questionSets'] as List<dynamic>;
      bool allFieldsFilled = true;
      
      for (final questionSet in questionSets) {
        final questions = questionSet['questions'] as List<dynamic>;
        for (final question in questions) {
          final questionId = question['id'] as String;
          if (_answers[questionId]?.trim().isEmpty ?? true) {
            allFieldsFilled = false;
            break;
          }
        }
        if (!allFieldsFilled) break;
      }

      if (!allFieldsFilled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please provide an answer for all questions before submitting.')),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);
    _stopTimer();

    try {
      // Call the parent's submission handler which connects to AI server and saves to Firebase
      await widget.onSubmitAnswers(
        Map<String, String>.from(_answers),
        _secondsElapsed,
        widget.initialAttemptNumber,
      );

      setState(() {
        _showResults = true;
        _currentAttemptForDisplay = widget.initialAttemptNumber + 1;
      });

      _logger.i('Lesson 3.1: Successfully submitted answers to parent module');
      
    } catch (e) {
      _logger.e("Error during lesson submission: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission error: $e. Please try again.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _loadActivityLog() async {
    if (_firebaseService.userId == null) return;
    
    setState(() {
      _showActivityLog = true;
      _activityLogLoading = true;
    });

    try {
      // Load activity log data - implement actual loading here
      await Future.delayed(const Duration(seconds: 1));
      setState(() {
        _activityLog = []; // Replace with actual data
        _activityLogLoading = false;
      });
    } catch (e) {
      _logger.e('Error loading activity log: $e');
      setState(() {
        _activityLog = [];
        _activityLogLoading = false;
      });
    }
  }

  int? _convertToInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.round();
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed?.round();
    }
    return null;
  }

  Widget _buildPreAssessmentSection() {
    final preAssessmentData = _lessonData?['preAssessmentData'];
    if (preAssessmentData == null) return const SizedBox.shrink();

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const FaIcon(FontAwesomeIcons.infoCircle, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    preAssessmentData['title'] ?? 'Pre-Assessment',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              preAssessmentData['instruction'] ?? '',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    preAssessmentData['question'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _isAudioLoading ? null : _playPreAssessmentAudio,
                        icon: _isAudioLoading 
                            ? const FaIcon(FontAwesomeIcons.spinner, size: 20)
                            : const FaIcon(FontAwesomeIcons.volumeUp, size: 20),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(12),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          onChanged: (value) => setState(() => _preAssessmentAnswer = value),
                          enabled: !_showPreAssessmentFeedback,
                          decoration: const InputDecoration(
                            hintText: 'Type your answer here...',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.all(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (!_showPreAssessmentFeedback) ...[
              Center(
                child: ElevatedButton(
                  onPressed: _preAssessmentAnswer.trim().isEmpty ? null : _handleCheckPreAssessment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                  child: const Text(
                    'Check Answer',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _preAssessmentResult == 'correct' ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    _preAssessmentResult == 'correct' 
                        ? 'Correct! Getting you ready for the lesson...'
                        : 'Not quite. The correct answer was "${preAssessmentData['correctAnswer']}". Let\'s review the material.',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStudyMaterialSection() {
    return Column(
      children: [
        // Objective Section
        Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const FaIcon(FontAwesomeIcons.book, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _lessonData?['objective']?['heading'] ?? 'Objective',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _lessonData?['objective']?['paragraph'] ?? '',
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
              ],
            ),
          ),
        ),

        // Introduction Section
        Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const FaIcon(FontAwesomeIcons.infoCircle, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _lessonData?['introduction']?['heading'] ?? 'Introduction',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _lessonData?['introduction']?['paragraph1'] ?? '',
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
                if (_lessonData?['introduction']?['paragraph2'] != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _lessonData!['introduction']['paragraph2'],
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Video Section
        Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                ),
                child: const Row(
                  children: [
                    FaIcon(FontAwesomeIcons.headphones, color: Colors.purple),
                    SizedBox(width: 8),
                    Text(
                      'Watch: Mastering Active Listening',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              AspectRatio(
                aspectRatio: 16 / 9,
                child: YoutubePlayer(
                  key: widget.youtubePlayerKey,
                  controller: widget.youtubeController,
                  showVideoProgressIndicator: true,
                  onEnded: (_) => _videoListener(),
                ),
              ),
            ],
          ),
        ),

        // Key Takeaways Section
        Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    FaIcon(FontAwesomeIcons.listUl, color: Colors.orange),
                    SizedBox(width: 8),
                    Text(
                      'Key Takeaways:',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: const Column(
                    children: [
                      _KeyTakeawayItem(text: 'Active listening involves focusing on both verbal (words) and non-verbal cues (tone, pace).'),
                      _KeyTakeawayItem(text: 'Identifying keywords and main points helps in quickly grasping the customer\'s primary issue.'),
                      _KeyTakeawayItem(text: 'Understanding and acknowledging customer emotions are crucial for empathetic and effective service.'),
                      _KeyTakeawayItem(text: 'Summarizing or paraphrasing what the customer said can confirm understanding and show engagement.'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActivitySection() {
    if (!_lessonData!.containsKey('activity')) return const SizedBox.shrink();

    final activity = _lessonData!['activity'];
    final questionSets = activity['questionSets'] as List<dynamic>? ?? [];

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const FaIcon(FontAwesomeIcons.headphones, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    activity['title'] ?? 'Listening Activity',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Attempt: $_currentAttemptForDisplay',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                if (_timerActive && !_isTimedOut)
                  Row(
                    children: [
                      const FaIcon(FontAwesomeIcons.clock, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Time: ${_formatTime(_countdownTimer)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: _countdownTimer < 60 ? Colors.red : null,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Instructions
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  const FaIcon(FontAwesomeIcons.infoCircle, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      activity['instructions'] ?? '',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Question Sets
            ...questionSets.asMap().entries.map((entry) {
              final questionSet = entry.value;
              final callId = questionSet['callId'] as String;
              final questions = questionSet['questions'] as List<dynamic>;

              return Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Call Transcript (${callId.replaceAll('call', 'Call ')})',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        ElevatedButton.icon(
                          onPressed: (_isSubmitting || _showResults || _isTimedOut || _loadingAudioId != null)
                              ? null
                              : () => _playScript(callId),
                          icon: _loadingAudioId == callId
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const FaIcon(FontAwesomeIcons.volumeUp, size: 16),
                          label: Text(_loadingAudioId == callId ? 'Loading...' : 'Play Script'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Transcript visibility toggle (only show after results)
                    if (_showResults && !_isTranscriptVisible) ...[
                      TextButton(
                        onPressed: () => setState(() => _isTranscriptVisible = true),
                        child: const Text(
                          'Show Transcript to Review',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],

                    // Transcript display
                    if (_isTranscriptVisible) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border(left: BorderSide(color: Colors.grey.shade400, width: 4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ..._buildTranscriptLines(callId),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Questions
                    ...questions.asMap().entries.map((qEntry) {
                      final question = qEntry.value;
                      final questionId = question['id'] as String;
                      final questionText = question['text'] as String;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              questionText,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _textControllers[questionId],
                              onChanged: (value) => _handleAnswerChanged(questionId, value),
                              enabled: !_isSubmitting && !_showResults && !_isTimedOut,
                              decoration: const InputDecoration(
                                hintText: 'Your answer here...',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.all(12),
                              ),
                              maxLines: 2,
                            ),
                            // Show feedback if available
                            if (_showResults && widget.aiFeedbackData != null && widget.aiFeedbackData!.containsKey(questionId))
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: ParsedFeedbackCard(
                                  feedbackData: widget.aiFeedbackData![questionId],
                                  scenarioLabel: questionText,
                                ),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              );
            }).toList(),

            // Timeout Warning
            if (_isTimedOut && !_showResults) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: const Row(
                  children: [
                    FaIcon(FontAwesomeIcons.exclamationTriangle, color: Colors.red),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Time's Up!",
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            "This attempt was not submitted and will not be saved.",
                            style: TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Action Buttons
            Row(
              children: [
                if (!_showResults && !_isTimedOut) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _handleSubmitToAIAndFirestore,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const FaIcon(FontAwesomeIcons.checkCircle, size: 16),
                      label: Text(_isSubmitting ? 'Submitting...' : 'Submit My Answers'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3066be),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
                if (_showResults || _isTimedOut) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _handleStartActivity,
                      icon: const FaIcon(FontAwesomeIcons.redo, size: 16),
                      label: const Text('Try Again'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ),

            // Score Display
            if (_showResults && !_isTimedOut && widget.overallAIScoreForDisplay != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.purple.shade600,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Text(
                        'Your Total AI Score: ${_convertToInt(widget.overallAIScoreForDisplay)} / ${_convertToInt(widget.maxPossibleAIScoreForDisplay) ?? _maxPossibleAIScore}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '(This score and time spent have been saved.)',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTranscriptLines(String callId) {
    final transcripts = _lessonData?['activity']?['transcripts'];
    final script = transcripts?[callId] as List<dynamic>? ?? [];
    
    return script.map((turn) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '${turn['character']}: ',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              TextSpan(
                text: turn['text'],
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildActivityLogModal() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Activity Log: $staticLessonId',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _showActivityLog = false),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _activityLogLoading
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Loading log...'),
                            ],
                          ),
                        )
                      : _activityLog.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  FaIcon(FontAwesomeIcons.book, size: 48, color: Colors.grey),
                                  SizedBox(height: 16),
                                  Text(
                                    'No activity recorded for this lesson yet.',
                                    style: TextStyle(fontSize: 16, color: Colors.grey),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _activityLog.length,
                              itemBuilder: (context, index) {
                                final log = _activityLog[index];
                                return Card(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  child: ListTile(
                                    title: Text('Attempt ${log['attemptNumber'] ?? index + 1}'),
                                    subtitle: Text('Score: ${log['score'] ?? 'N/A'}'),
                                  ),
                                );
                              },
                            ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: () => setState(() => _showActivityLog = false),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                  child: const Text('Close Log', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingLessonContent || _lessonData == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  _lessonData!['lessonTitle'] ?? 'Lesson 3.1',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: const Color(0xFF00568D),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Activity Log Button (only when activity not visible and user logged in)
                if (!_isActivityVisible && _firebaseService.userId != null) ...[
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: _loadActivityLog,
                      icon: const FaIcon(FontAwesomeIcons.book, size: 16),
                      label: const Text('View Your Activity Log'),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Content based on state
                if (!_isActivityVisible) ...[
                  // Pre-assessment or study material
                  if (!_isPreAssessmentComplete && !_hasStudied && _lessonData!.containsKey('preAssessmentData'))
                    _buildPreAssessmentSection()
                  else ...[
                    // Study material
                    _buildStudyMaterialSection(),
                    const SizedBox(height: 20),
                    
                    // Study complete / Start activity buttons
                    Center(
                      child: !_hasStudied
                          ? ElevatedButton(
                              onPressed: _handleStudyComplete,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3066be),
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                              ),
                              child: const Text(
                                'I\'ve Finished Studying – Proceed to Activity',
                                style: TextStyle(color: Colors.white, fontSize: 16),
                              ),
                            )
                          : ElevatedButton.icon(
                              onPressed: _firebaseService.userId != null ? _handleStartActivity : null,
                              icon: const FaIcon(FontAwesomeIcons.playCircle),
                              label: const Text('Start the Activity'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                textStyle: const TextStyle(fontSize: 16),
                              ),
                            ),
                    ),
                    if (_firebaseService.userId == null) ...[
                      const SizedBox(height: 8),
                      const Center(
                        child: Text(
                          'Please log in to start the activity.',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ],
                ],

                // Activity Section
                if (_isActivityVisible && _firebaseService.userId != null) ...[
                  const SizedBox(height: 20),
                  _buildActivitySection(),
                ],
              ],
            ),
          ),

          // Activity log modal overlay
          if (_showActivityLog) _buildActivityLogModal(),

          // Loading overlay
          if (_isSubmitting)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Evaluating your responses...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Please wait for your personalized feedback.',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Helper widget for key takeaway items
class _KeyTakeawayItem extends StatelessWidget {
  final String text;

  const _KeyTakeawayItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}