import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:logger/logger.dart';
import '../lessons/common_widgets.dart';
import 'dart:async';
import '../firebase_service.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'dart:convert';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// Add these imports for the assessment components
import '../StudentAssessment/TypingPreAssessment.dart';
import '../StudentAssessment/PreAssessment.dart';
import '../widgets/parsed_feedback_card.dart';

// Data structure for AI feedback for a single scenario
class ScenarioFeedback {
  final String text;
  final double? score;

  ScenarioFeedback({required this.text, this.score});

  factory ScenarioFeedback.fromJson(Map<String, dynamic> json) {
    return ScenarioFeedback(
      text: json['text'] as String? ?? 'No feedback text.',
      score: (json['score'] as num?)?.toDouble(),
    );
  }
}

// Interactive Phrase Widget (similar to React InteractivePhrase)
class InteractivePhrase extends StatefulWidget {
  final String situation;
  final String phrase;

  const InteractivePhrase({
    Key? key,
    required this.situation,
    required this.phrase,
  }) : super(key: key);

  @override
  _InteractivePhraseState createState() => _InteractivePhraseState();
}

class _InteractivePhraseState extends State<InteractivePhrase>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        _controller.forward();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _controller.reverse();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
        _controller.reverse();
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isPressed ? Colors.blue[100] : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isPressed ? Colors.blue[300]! : Colors.grey[300]!,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      widget.situation,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Text(
                        widget.phrase,
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          fontSize: 13,
                          color: Colors.blue[800],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// Enhanced feedback card
class FeedbackCardL4_1 extends StatelessWidget {
  final ScenarioFeedback scenarioFeedback;
  final double maxScore;

  const FeedbackCardL4_1({
    Key? key,
    required this.scenarioFeedback,
    required this.maxScore,
  }) : super(key: key);

  List<Map<String, dynamic>> _parseFeedbackSections(String rawText) {
    final sections = <Map<String, dynamic>>[];
    
    final categories = [
      {
        'title': 'Effectiveness of Clarification',
        'icon': FontAwesomeIcons.bullseye,
        'color': Colors.blue[600]!
      },
      {
        'title': 'Politeness and Professionalism',
        'icon': FontAwesomeIcons.handshake,
        'color': Colors.green[600]!
      },
      {
        'title': 'Clarity and Conciseness',
        'icon': FontAwesomeIcons.search,
        'color': Colors.orange[600]!
      },
      {
        'title': 'Grammar and Phrasing',
        'icon': FontAwesomeIcons.spellCheck,
        'color': Colors.purple[600]!
      },
      {
        'title': 'Suggestion for Improvement',
        'icon': FontAwesomeIcons.star,
        'color': Colors.amber[600]!
      },
    ];

    // Parse the text for each category
    for (var category in categories) {
      final titlePattern = '**${category['title']}:**';
      if (rawText.contains(titlePattern)) {
        final startIndex = rawText.indexOf(titlePattern) + titlePattern.length;
        int endIndex = rawText.length;
        
        // Find the next category if it exists
        for (var nextCat in categories) {
          if (nextCat == category) continue;
          final nextPattern = '**${nextCat['title']}:**';
          final nextIndex = rawText.indexOf(nextPattern, startIndex);
          if (nextIndex != -1 && nextIndex < endIndex) {
            endIndex = nextIndex;
          }
        }
        
        final sectionText = rawText.substring(startIndex, endIndex).trim();
        if (sectionText.isNotEmpty) {
          sections.add({
            'icon': category['icon'],
            'title': category['title'],
            'color': category['color'],
            'text': sectionText,
          });
        }
      }
    }

    // If no sections found, add the raw text
    if (sections.isEmpty && rawText.trim().isNotEmpty) {
      sections.add({
        'icon': FontAwesomeIcons.infoCircle,
        'title': 'General Feedback',
        'color': Colors.grey.shade700,
        'text': rawText.trim(),
      });
    }
    return sections;
  }

  @override
  Widget build(BuildContext context) {
    final score = scenarioFeedback.score ?? 0.0;
    final percentage = maxScore > 0 ? (score / maxScore) * 100 : 0.0;
    Color scoreColor = Colors.red.shade700;
    if (percentage >= 80) {
      scoreColor = Colors.green.shade700;
    } else if (percentage >= 50) scoreColor = Colors.orange.shade700;

    final sections = _parseFeedbackSections(scenarioFeedback.text);

    return Container(
      margin: const EdgeInsets.only(top: 8.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8.0),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 3, offset: const Offset(0, 1))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text("AI Score: ${score.toStringAsFixed(1)} / ${maxScore.toStringAsFixed(1)}",
              style: TextStyle(fontWeight: FontWeight.bold, color: scoreColor, fontSize: 15)),
        ]),
        const SizedBox(height: 6),
        LinearProgressIndicator(value: percentage / 100, backgroundColor: Colors.grey[300], color: scoreColor, minHeight: 6),
        const SizedBox(height: 12),
        if (sections.isEmpty)
          Text("No feedback available.", style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic)),
        ...sections.map((section) {
          return Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: section['color'] == Colors.grey.shade700 ? Colors.grey.shade50 : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border(
                left: BorderSide(color: section['color'] as Color, width: 4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    FaIcon(section['icon'] as IconData, color: section['color'] as Color, size: 16),
                    const SizedBox(width: 8),
                    Text(section['title'] as String,
                        style: TextStyle(fontWeight: FontWeight.bold, color: section['color'] as Color, fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(section['text'] as String, style: const TextStyle(fontSize: 13, height: 1.4)),
              ],
            ),
          );
        }).toList(),
      ]),
    );
  }
}

// Main lesson class
class buildLesson4_1 extends StatefulWidget {
  final int currentSlide;
  final CarouselSliderController carouselController;
  final YoutubePlayerController? youtubeController;
  final Key? youtubePlayerKey;
  final int initialAttemptNumber;
  final Function(int) onSlideChanged;
  final bool showActivityInitially;
  final VoidCallback onShowActivitySection;

  final Future<Map<String, dynamic>?> Function({
    required Map<String, String> scenarioAnswers,
    required String lessonId,
  }) onEvaluateScenarios;

  final Future<void> Function({
    required String lessonIdFirestoreKey,
    required int attemptNumber,
    required int timeSpent,
    required Map<String, String> scenarioResponses,
    required Map<String, dynamic> aiFeedbackForScenarios,
    required double overallAIScore,
    Map<String, String>? reflectionResponses,
    required bool isUpdate,
  }) onSaveAttempt;

  const buildLesson4_1({
    Key? key,
    required this.currentSlide,
    required this.carouselController,
    this.youtubeController,
    this.youtubePlayerKey,
    required this.initialAttemptNumber,
    required this.onSlideChanged,
    required this.showActivityInitially,
    required this.onShowActivitySection,
    required this.onEvaluateScenarios,
    required this.onSaveAttempt, required Future<void> Function({required Map<String, dynamic> aiFeedbackForScenarios, required int attemptNumber, required String lessonIdFirestoreKey, required double originalOverallAIScore, required Map<String, String> reflectionResponses, required Map<String, String> submittedScenarioResponses}) onSaveReflection,
  }) : super(key: key);

  @override
  _Lesson4_1State createState() => _Lesson4_1State();
}

class _Lesson4_1State extends State<buildLesson4_1> with TickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  final Logger _logger = Logger();
  
  // Animation controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // State variables
  bool _isStudied = false;
  bool _isActivityVisible = false;
  bool _showResults = false;
  bool _isLoadingAI = false;
  bool _isSaveComplete = false;
  Timer? _timer;
  int _secondsElapsed = 0;
  late int _currentAttemptNumberForUI;

  // Step-by-step navigation state
  int _currentScenarioIndex = 0;
  bool _isScriptVisible = false;
  bool _isAudioLoading = false;

  // UI state
  bool _showActivityLog = false;
  List<Map<String, dynamic>> _activityLog = [];
  bool _isActivityLogLoading = false;

  // Enhanced pre-assessment state
  bool _isPreAssessmentComplete = false;
  Map<String, dynamic>? _lessonData;
  bool _loadingLesson = true;
  
  // Response controllers and data
  final Map<String, TextEditingController> _textControllers = {};
  
  // AI feedback state
  Map<String, ScenarioFeedback> _aiFeedbackForScenarios = {};
  double? _overallAIScore;
  final double _maxPossibleAIScorePerScenario = 2.5;

  Map<String, String>? _submittedScenarioResponsesForDisplay;

  final AudioPlayer _audioPlayer = AudioPlayer();

  // Interactive phrases data
  final List<Map<String, String>> _interactivePhrases = [
    {
      'situation': 'Didn\'t catch what was said',
      'phrase': '"Sorry, can you say that again?"'
    },
    {
      'situation': 'Didn\'t understand fully',
      'phrase': '"I didn\'t quite get that. Could you repeat it?"'
    },
    {
      'situation': 'Need spelling confirmation',
      'phrase': '"Could you spell that for me, please?"'
    },
    {
      'situation': 'Need to confirm details',
      'phrase': '"Just to confirm, did you say [repeat info]?"'
    },
    {
      'situation': 'Need more information',
      'phrase': '"Could you explain that a little more?"'
    },
    {
      'situation': 'Need clarification on meaning',
      'phrase': '"Could you clarify what you meant by...?"'
    },
  ];

  final List<Map<String, dynamic>> _rolePlayScenarios = [
    {
      'id': 'scenario1',
      'text': '"Yes, my order was… [muffled] … and I need to change the delivery."',
      'instruction': 'The customer\'s speech is unclear due to audio issues. Ask for clarification politely.'
    },
    {
      'id': 'scenario2',
      'text': '"My email is zlaytsev_b12@yahoo.com."',
      'instruction': 'Confirm the spelling of this complex email address to ensure accuracy.'
    },
    {
      'id': 'scenario3',
      'text': '"The item number is 47823A."',
      'instruction': 'This alphanumeric code needs to be verified. Ask the customer to confirm.'
    },
    {
      'id': 'scenario4',
      'text': '"Yeah I called yesterday and they said it\'d be fixed in two days but it\'s not."',
      'instruction': 'The customer is frustrated. Ask for clarification while showing empathy.'
    },
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _currentAttemptNumberForUI = widget.initialAttemptNumber + 1;
    _isStudied = widget.showActivityInitially;
    _isActivityVisible = widget.showActivityInitially;

    // Initialize controllers
    _initializeControllers();
    
    // Load lesson data
    _loadLessonData();

    if (_isActivityVisible && !_showResults) {
      _startTimer();
    }
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    _fadeController.forward();
  }

  void _initializeControllers() {
    for (var scenario in _rolePlayScenarios) {
      _textControllers[scenario['id']!] = TextEditingController();
    }
  }

  Future<void> _loadLessonData() async {
    setState(() => _loadingLesson = true);
    
    try {
      // In a real app, fetch from Firestore here
      await Future.delayed(const Duration(milliseconds: 800));
      
      setState(() {
        _loadingLesson = false;
        _isPreAssessmentComplete = false;
      });
    } catch (e) {
      _logger.e('Error loading lesson data: $e');
      setState(() => _loadingLesson = false);
    }
  }

  // Handle pre-assessment completion
  void _handlePreAssessmentComplete() {
    setState(() {
      _isPreAssessmentComplete = true;
    });
  }

  @override
  void didUpdateWidget(covariant buildLesson4_1 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialAttemptNumber != oldWidget.initialAttemptNumber) {
      _currentAttemptNumberForUI = widget.initialAttemptNumber + 1;
      if (widget.showActivityInitially && !_showResults) {
        _prepareForNewAttempt();
      }
    }
    if (widget.showActivityInitially && !oldWidget.showActivityInitially) {
      _logger.i("L4.1: showActivitySectionInitially became true. Preparing new attempt.");
      _isStudied = true;
      _isActivityVisible = true;
      _prepareForNewAttempt();
    }
  }

  void _prepareForNewAttempt() {
    _textControllers.forEach((key, controller) => controller.clear());
    if (mounted) {
      setState(() {
        _aiFeedbackForScenarios = {};
        _overallAIScore = null;
        _showResults = false;
        _secondsElapsed = 0;
        _submittedScenarioResponsesForDisplay = null;
        _currentScenarioIndex = 0; // Reset to first scenario
        _isScriptVisible = false;
        _startTimer();
      });
    }
  }

  void _startTimer() {
    _stopTimer();
    _secondsElapsed = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _secondsElapsed++);
    });
  }

  void _stopTimer() {
    _timer?.cancel();
  }

  String _formatDuration(int totalSeconds) {
    final duration = Duration(seconds: totalSeconds);
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _loadActivityLog() async {
    if (_firebaseService.userId == null) return;

    setState(() => _isActivityLogLoading = true);
    try {
      final userProgress = await _firebaseService.getUserProgress(_firebaseService.userId!, 'Lesson-4-1');
      final formattedLog = userProgress.attempts.map((a) {
        final scenarioResponses = a.detailedResponses?['scenarioResponses'] ?? {};
        final aiFeedback = a.detailedResponses?['aiFeedbackForScenarios'] ?? {};
        return {
          'attemptNumber': a.attemptNumber,
          'score': a.score,
          'timeSpent': a.timeSpent,
          'attemptTimestamp': a.attemptTimestamp,
          'scenarioResponses': scenarioResponses,
          'aiFeedbackForScenarios': aiFeedback,
        };
      }).toList();

      setState(() {
        _activityLog = formattedLog;
        _isActivityLogLoading = false;
      });
    } catch (e) {
      _logger.e('Error loading activity log: $e');
      setState(() {
        _activityLog = [];
        _isActivityLogLoading = false;
      });
    }
  }

  Future<void> _handleCheckSingleScenario(String scenarioKey) async {
    if (_isLoadingAI) return;
    final answer = _textControllers[scenarioKey]?.text.trim() ?? '';
    if (answer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide an answer for this scenario.')),
      );
      return;
    }

    setState(() => _isLoadingAI = true);
    try {
      final res = await widget.onEvaluateScenarios(
        scenarioAnswers: {scenarioKey: answer},
        lessonId: '4.1',
      );
      if (res != null && res['aiFeedbackForScenarios'] is Map) {
        final Map feedbackMap = res['aiFeedbackForScenarios'];
        if (feedbackMap[scenarioKey] is Map) {
          final parsed = ScenarioFeedback.fromJson(
              Map<String, dynamic>.from(feedbackMap[scenarioKey]));
          setState(() => _aiFeedbackForScenarios[scenarioKey] = parsed);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No feedback returned for this scenario.')),
        );
      }
    } catch (e) {
      _logger.e('Error checking single scenario: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error getting feedback for this scenario.')),
      );
    } finally {
      if (mounted) setState(() => _isLoadingAI = false);
    }
  }

  Future<void> _playScenarioAudio() async {
  if (_isAudioLoading) return;
  
  final currentScenario = _rolePlayScenarios[_currentScenarioIndex];
  setState(() => _isAudioLoading = true);
  
  try {
    // Check for network connectivity first
    bool hasNetwork = false;
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      hasNetwork = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      hasNetwork = false;
    }
    
    if (!hasNetwork) {
      // Skip server attempt if no connectivity
      throw Exception('No internet connection detected');
    }
    
    // CONFIGURATION: I-setup ang actual server address at port
    final String serverAddress = "192.168.1.2"; // PALITAN NG ACTUAL IP NG SERVER
    final int serverPort = 5001;
    
    final uri = Uri.parse('http://$serverAddress:$serverPort/synthesize-speech');
    _logger.i('Connecting to TTS server at $uri');
    
    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'parts': [{'text': currentScenario['text']}]
      }),
    ).timeout(const Duration(seconds: 10)); // Shorter timeout - fail faster
  
    if (resp.statusCode != 200) {
      throw Exception('TTS failed: ${resp.statusCode}');
    }
    
    final bytes = resp.bodyBytes;
    await _audioPlayer.stop();
    await _audioPlayer.play(BytesSource(bytes));
    
  } catch (e) {
    _logger.e('Error playing audio: $e');
    // Always use fallback TTS when server is unreachable
    _tryFallbackTTS(currentScenario['text'] as String);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Using device text-to-speech instead of server'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  } finally {
    if (mounted) setState(() => _isAudioLoading = false);
  }
}

  // New fallback method that uses Flutter's built-in TTS
  void _tryFallbackTTS(String text) async {
    try {
      final FlutterTts flutterTts = FlutterTts();
      await flutterTts.setLanguage("en-US");
      await flutterTts.setPitch(1.0);
      await flutterTts.setSpeechRate(0.5);
      await flutterTts.speak(text);
    } catch (e) {
      _logger.e('Fallback TTS failed: $e');
    }
  }

  Future<void> _handleSubmitToAIAndFirestore() async {
    if (_firebaseService.userId == null || _isLoadingAI) return;
    
    setState(() {
      _isLoadingAI = true;
      _stopTimer();
    });
    
    try {
      // Prepare scenario responses
      final Map<String, String> scenarioResponses = {};
      for (var scenario in _rolePlayScenarios) {
        final controller = _textControllers[scenario['id']];
        if (controller != null) {
          scenarioResponses[scenario['id']] = controller.text.trim();
        }
      }
      
      // Calculate overall score
      double calculatedAIScore = 0;
      for (var feedback in _aiFeedbackForScenarios.values) {
        if (feedback.score != null) {
          calculatedAIScore += feedback.score!;
        }
      }
      
      final newAttemptNumber = _currentAttemptNumberForUI;
      final timeSpent = _secondsElapsed;
      
      // Create detailed response payload
      final detailedResponsesPayload = {
        'scenarioResponses': scenarioResponses,
        'aiFeedbackForScenarios': _aiFeedbackForScenarios,
      };
      
      // Save to Firestore
      await widget.onSaveAttempt(
        lessonIdFirestoreKey: 'Lesson-4-1',
        attemptNumber: newAttemptNumber,
        timeSpent: timeSpent,
        scenarioResponses: scenarioResponses,
        aiFeedbackForScenarios: _aiFeedbackForScenarios,
        overallAIScore: calculatedAIScore,
        isUpdate: false,
      );
      
      setState(() {
        _overallAIScore = calculatedAIScore;
        _showResults = true;
        _submittedScenarioResponsesForDisplay = Map.from(scenarioResponses);
        _isLoadingAI = false;
        _isSaveComplete = true;
      });
      
      // Show success message briefly before auto-navigating
      Timer(const Duration(seconds: 3), () {
        if (mounted) {
          Navigator.pop(context); // Return to module overview
        }
      });
    } catch (e) {
      _logger.e('Error submitting to AI and Firestore: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error submitting your responses. Please try again.')),
      );
      setState(() => _isLoadingAI = false);
    }
  }

  Future<Map<String, dynamic>?> _fetchUserProgress() async {
  try {
    final userId = _firebaseService.userId;
    if (userId == null) {
      _logger.w("L4.1: User not authenticated");
      return null;
    }
    
    final prog = await FirebaseFirestore.instance
        .collection('userProgress')
        .doc(userId)
        .get();
        
    if (prog.exists) {
      _logger.i('L4.1: User progress data fetched');
      return prog.data();
    }
  } catch (e) {
    _logger.e('L4.1: Error fetching user progress: $e');
  }
  return null;
}

  @override
  Widget build(BuildContext context) {
    if (_loadingLesson) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Remove debug info section and only keep the title
                Text(
                  'Lesson 4.1: Asking for Clarification',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: const Color(0xFF3066be),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Activity Log Button (only when activity not visible)
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
                
                // Pre-assessment or main content based on completion state
                if (!_isPreAssessmentComplete && !_isActivityVisible) ...[
                  _buildPreAssessmentView(),
                ] else if (!_isActivityVisible) ...[
                  _buildStudyContent(),
                ] else ...[
                  _buildActivityContent(),
                ],
              ],
            ),
          ),
          
          // Activity Log Overlay
          if (_showActivityLog)
            _buildActivityLogOverlay(),
          
          // Loading overlay during submission
          if (_isLoadingAI)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
            
          // Save complete overlay
          if (_isSaveComplete)
            _buildSaveCompleteOverlay(),
        ],
      ),
    );
  }

  Widget _buildPreAssessmentView() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3066be), Color(0xFF4080ce)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              children: [
                Text(
                  'Pre-Assessment: Customer Service Response',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'Let\'s assess your current knowledge before beginning',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          
          // Pre-assessment content - replace with your actual pre-assessment widget
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Scenario:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'A customer calls and says: "I\'m having trouble with my recent order, but I can\'t remember the exact details." The line quality is poor and you can barely hear them.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                const Text(
                  'How would you professionally ask for clarification in this situation?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Type your response here...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  maxLines: 4,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _handlePreAssessmentComplete,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3066be),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Submit Pre-Assessment',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudyContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Acknowledgment of pre-assessment completion
        if (_isPreAssessmentComplete)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.green[50],
              border: Border.all(color: Colors.green[200]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[600], size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Great job on the pre-assessment! Now let\'s build on that knowledge.',
                    style: TextStyle(
                      color: Colors.green[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        
        // Objective section
        _buildStudyCard(
          icon: Icons.flag,
          iconColor: Colors.blue,
          title: '🎯 Learning Objectives',
          child: const Text(
            'By the end of this lesson, you will be able to:\n\n• Use polite and professional phrases to ask customers to repeat or clarify information\n• Respond naturally when you don\'t understand a customer during a call\n• Practice these skills in simulated role-play conversations\n• Build confidence in handling unclear communication',
            style: TextStyle(fontSize: 16, height: 1.5),
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Why Clarification Matters section
        _buildStudyCard(
          icon: Icons.lightbulb,
          iconColor: Colors.orange,
          title: '💡 Why Clarification Matters',
          child: const Text(
            'In call center environments, clear communication is essential for success. Background noise, unclear speech, technical issues, or unfamiliar accents can create barriers to understanding.\n\n🔹 **Ensures accurate problem resolution**\n🔹 **Prevents costly mistakes and misunderstandings**\n🔹 **Builds customer trust through respectful communication**\n🔹 **Demonstrates professionalism and attention to detail**',
            style: TextStyle(fontSize: 16, height: 1.5),
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Key Phrases section
        _buildStudyCard(
          icon: Icons.chat_bubble,
          iconColor: Colors.green,
          title: '📝 Key Phrases for Clarification',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Master these essential clarification phrases for different situations:',
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 16),
              ..._interactivePhrases.map((phrase) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: InteractivePhrase(
                  situation: phrase['situation']!,
                  phrase: phrase['phrase']!,
                ),
              )),
            ],
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Call Center Examples section
        _buildStudyCard(
          icon: Icons.theater_comedy,
          iconColor: Colors.purple,
          title: '🎭 Call Center Examples',
          child: const Text(
            'See these phrases in action:\n\n**Example 1:**\n👤 Customer: "I\'m calling about the problem with my serv—"\n🎧 Agent: "I\'m sorry, could you repeat that last part?"\n\n**Example 2:**\n👤 Customer: "My email is jen_matsuba87@gmail.com."\n🎧 Agent: "Could you spell that for me to make sure I got it right?"\n\n**Example 3:**\n👤 Customer: "I placed the order on the 15th."\n🎧 Agent: "Just to confirm — you placed the order on March 15th, correct?"',
            style: TextStyle(fontSize: 16, height: 1.5),
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Lesson Summary section
        _buildStudyCard(
          icon: Icons.emoji_events,
          iconColor: Colors.amber,
          title: '🎉 Lesson Summary',
          child: const Text(
            '**Key Takeaways:**\n\n✅ Asking for clarification shows professionalism\n✅ Polite phrases build customer rapport\n✅ Confirmation prevents misunderstandings\n✅ Practice makes these responses natural\n\nWith consistent practice, these clarification techniques will become second nature, enhancing your confidence and communication effectiveness in any call center environment.',
            style: TextStyle(fontSize: 16, height: 1.5),
          ),
        ),
        
        const SizedBox(height: 32),
        
        // Practice button
        Center(
          child: ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _isStudied = true;
                _isActivityVisible = true;
              });
              widget.onShowActivitySection();
            },
            icon: const Icon(Icons.play_arrow, size: 24),
            label: const Text(
              'Start Practice Activities',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3066be),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStudyCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildActivityContent() {
    // Helper to get the current scenario
    final currentScenario = _rolePlayScenarios.length > _currentScenarioIndex ? 
                           _rolePlayScenarios[_currentScenarioIndex] : null;
    final scenarioId = currentScenario?['id'] as String?;
    final isFeedbackReceived = scenarioId != null && 
                              _aiFeedbackForScenarios.containsKey(scenarioId);
    final isLastScenario = _currentScenarioIndex == _rolePlayScenarios.length - 1;
    
    if (currentScenario == null) {
      return const Center(child: Text('No scenarios available'));
    }

    if (_showResults) {
      return _buildResultsView();
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header section - Remove debug info
          Text(
            'Activity: Clarification Role-Play',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: const Color(0xFF3066be),
              fontWeight: FontWeight.bold,
            ),
          ),
          
          // Only show attempt number, not as debug info
          Text(
            'Attempt Number: $_currentAttemptNumberForUI',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          
          if (_timer != null)
            Text(
              'Time Elapsed: ${_formatDuration(_secondsElapsed)}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          
          const SizedBox(height: 20),
          
          // Scenario prompt
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border(left: BorderSide(color: Colors.blue.shade400, width: 4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scenario ${_currentScenarioIndex + 1} of ${_rolePlayScenarios.length}: Listen to the customer\'s statement.',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      
                      // Either show script or button to reveal it
                      if (_isScriptVisible)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Text(
                            currentScenario['text'] as String,
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.blue.shade800,
                            ),
                          ),
                        )
                      else
                        TextButton(
                          onPressed: () => setState(() => _isScriptVisible = true),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 30),
                            alignment: Alignment.centerLeft,
                          ),
                          child: const Text('Show Script'),
                        ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Audio play button
                ElevatedButton(
                  onPressed: _isAudioLoading ? null : _playScenarioAudio,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo.shade500,
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(16),
                  ),
                  child: _isAudioLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const FaIcon(FontAwesomeIcons.volumeUp),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Instruction
          Text(
            currentScenario['instruction'] as String,
            style: TextStyle(
              fontSize: 15,
              fontStyle: FontStyle.italic,
              color: Colors.grey.shade700,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Response textarea
          TextField(
            controller: _textControllers[currentScenario['id']],
            decoration: InputDecoration(
              hintText: 'Type your clarification response here...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            maxLines: 4,
            enabled: !_isLoadingAI && !isFeedbackReceived,
          ),
          
          const SizedBox(height: 16),
          
          // Feedback display if available
          if (isFeedbackReceived)
            FeedbackCardL4_1(
              scenarioFeedback: _aiFeedbackForScenarios[scenarioId!]!,
              maxScore: _maxPossibleAIScorePerScenario,
            ),
          
          const SizedBox(height: 24),
          
          // Navigation buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Previous button
              ElevatedButton(
                onPressed: _currentScenarioIndex > 0
                    ? () => setState(() => _currentScenarioIndex--)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade200,
                  foregroundColor: Colors.black87,
                ),
                child: const Text('Previous'),
              ),
              
              // Check/Next/Finish button
              if (!isFeedbackReceived)
                ElevatedButton(
                  onPressed: _isLoadingAI
                      ? null
                      : () => _handleCheckSingleScenario(currentScenario['id'] as String),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                  ),
                  child: _isLoadingAI
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Check Answer'),
                )
              else if (isLastScenario)
                ElevatedButton(
                  onPressed: _handleSubmitToAIAndFirestore,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                  ),
                  child: const Text('Finish & Submit'),
                )
              else
                ElevatedButton(
                  onPressed: () => setState(() {
                    _currentScenarioIndex++;
                    _isScriptVisible = false;
                  }),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo.shade500,
                  ),
                  child: const Text('Next Scenario'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultsView() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200!),
      ),
      child: Column(
        children: [
          const FaIcon(FontAwesomeIcons.checkCircle, color: Colors.green, size: 40),
          const SizedBox(height: 16),
          const Text(
            'Results Submitted Successfully!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your score: ${_overallAIScore?.toStringAsFixed(1) ?? "N/A"} / 10',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'You will be redirected to the module overview shortly...',
            style: TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityLogOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Activity Log - Lesson 4.1',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3066be),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _showActivityLog = false),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: _isActivityLogLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _activityLog.isEmpty
                        ? const Center(
                            child: Text(
                              'No activities recorded yet.',
                              style: TextStyle(
                                color: Colors.grey,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _activityLog.length,
                            itemBuilder: (context, index) {
                              final log = _activityLog[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Attempt ${log['attemptNumber']}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Score: ${log['score']?.toStringAsFixed(1) ?? 'N/A'} / 10',
                                      ),
                                      Text(
                                        'Time Spent: ${log['timeSpent'] ?? 'N/A'} seconds',
                                      ),
                                      if (log['attemptTimestamp'] != null)
                                        Text(
                                          'Date: ${log['attemptTimestamp'].toDate().toString()}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSaveCompleteOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Saving progress...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _textControllers.forEach((_, controller) => controller.dispose());
    _fadeController.dispose();
    _stopTimer();
    _audioPlayer.dispose();
    super.dispose();
  }
}