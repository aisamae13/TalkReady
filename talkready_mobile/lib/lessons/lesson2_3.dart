import 'dart:async';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:logger/logger.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../lessons/common_widgets.dart';
import '../widgets/parsed_feedback_card.dart';
import '../firebase_service.dart';
import '../StudentAssessment/AiFeedbackData.dart';

class BuildLesson2_3 extends StatefulWidget {
  final BuildContext parentContext;
  final int currentSlide;
  final CarouselSliderController carouselController;
  final YoutubePlayerController youtubeController;
  final Key? youtubePlayerKey;
  final bool showActivitySection;
  final VoidCallback onShowActivitySection;

  final Function(
    Map<String, String> userScenarioAnswers,
    int timeSpent,
    int attemptNumberForSubmission,
  ) onSubmitAnswers;

  final Function(int) onSlideChanged;
  final int initialAttemptNumber;

  final bool displayFeedback;
  final Map<String, dynamic>? aiFeedbackData;
  final int? overallAIScoreForDisplay;
  final int? maxPossibleAIScoreForDisplay;

  const BuildLesson2_3({
    super.key,
    required this.parentContext,
    required this.currentSlide,
    required this.carouselController,
    required this.youtubeController,
    required this.showActivitySection,
    required this.onShowActivitySection,
    required this.onSubmitAnswers,
    required this.onSlideChanged,
    required this.initialAttemptNumber,
    required this.displayFeedback,
    this.youtubePlayerKey,
    this.aiFeedbackData,
    this.overallAIScoreForDisplay,
    this.maxPossibleAIScoreForDisplay,
  });

  @override
  State<BuildLesson2_3> createState() => _Lesson2_3State();
}

class _Lesson2_3State extends State<BuildLesson2_3> with TickerProviderStateMixin {
  final Logger _logger = Logger();
  final FirebaseService _firebaseService = FirebaseService();

  // Animation controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Video and content states
  bool _videoFinished = false;
  Timer? _timer;
  late int _currentAttemptForDisplay;

  // Lesson content
  bool _isLoadingLessonContent = true;
  Map<String, dynamic>? _lessonData;
  List<dynamic> _activityPrompts = [];
  late Map<String, TextEditingController> _textControllers;

  // Activity states - SIMPLIFIED to match working lessons
  bool _isActivityVisible = false;
  bool _isTimedOut = false;
  int _timerSeconds = 900;
  bool _timerActive = false;
  final Map<String, String> _answers = {};
  bool _loading = false;
  int _secondsElapsed = 0; // Track time for submission

  // Pre-assessment and activity log
  bool _preAssessmentCompleted = false;
  bool _showActivityLog = false;
  List<Map<String, dynamic>> _activityLog = [];
  bool _activityLogLoading = false;

  // Key phrases mini-activity
  Map<String, String> _keyPhraseAnswers = {};
  bool _showKeyPhraseResults = false;

  // Icon mapping for visual consistency
  static const Map<String, IconData> _iconMap = {
    'FaDollarSign': FontAwesomeIcons.dollarSign,
    'FaCalendarAlt': FontAwesomeIcons.calendar,
    'FaClock': FontAwesomeIcons.clock,
    'FaUserCheck': FontAwesomeIcons.userCheck,
    'FaFileInvoiceDollar': FontAwesomeIcons.fileInvoiceDollar,
  };

  @override
  void initState() {
    super.initState();
    _currentAttemptForDisplay = widget.initialAttemptNumber + 1;
    _textControllers = {};
    
    // Initialize animations
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _fetchLessonContentAndInitialize();
    widget.youtubeController.addListener(_videoListener);
    
    if (widget.showActivitySection && !widget.displayFeedback) {
      _startTimer();
    }

    // Start fade animation
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    widget.youtubeController.removeListener(_videoListener);
    _textControllers.forEach((_, c) => c.dispose());
    _stopTimer();
    super.dispose();
  }

  Future<void> _fetchLessonContentAndInitialize() async {
    if (!mounted) return;
    setState(() => _isLoadingLessonContent = true);

    // Enhanced hardcoded data that matches the React component structure
    final Map<String, dynamic> hardcoded = {
      'moduleTitle': 'Module 2: Professional Communication',
      'lessonTitle': 'Lesson 2.3: Numbers and Dates',
      'objective': {
        'paragraph': 'To help learners use numbers and talk about time, dates, and prices accurately and confidently in real-world customer service interactions.',
      },
      'keyPhrases': {
        'heading': 'Key Phrases and Vocabulary',
        'introParagraph': 'In customer service, numbers are frequently used for various purposes. Let\'s explore the essential phrases and vocabulary you\'ll need.',
        'listItems': [
          '<strong>Cardinal numbers</strong> - one, two, three (used for counting)',
          '<strong>Ordinal numbers</strong> - first, second, third (used in dates)',
          '<strong>Price expressions</strong> - "twenty-nine dollars and fifty cents"',
          '<strong>Time expressions</strong> - "3:30 p.m.", "eight fifteen a.m."',
          '<strong>Date formats</strong> - "March 15th, 2025", "April 3rd"',
        ],
      },
      'videos': {
        'priceVideo': {
          'heading': 'Understanding Prices in Customer Service',
          'url': 'https://www.youtube.com/embed/VIDEO_ID_1',
        },
        'timeAndDateVideo': {
          'heading': 'Time and Date Communication',
          'url': 'https://www.youtube.com/embed/VIDEO_ID_2',
        },
      },
      'keyPhraseActivity': {
        'title': 'Quick Knowledge Check',
        'instruction': 'Test your understanding of numbers and dates terminology before starting the main activity.',
        'questions': [
          {
            'id': 'number_type',
            'promptText': 'Which type of numbers do we use in dates?',
            'options': ['Cardinal numbers', 'Ordinal numbers', 'Decimal numbers', 'Fraction numbers'],
            'correctAnswer': 'Ordinal numbers',
          },
          {
            'id': 'price_format',
            'promptText': 'What is the correct way to say \$25.50?',
            'options': ['Twenty-five fifty', 'Twenty-five dollars and fifty cents', 'Two five point five zero', 'Twenty-five point fifty'],
            'correctAnswer': 'Twenty-five dollars and fifty cents',
          },
          {
            'id': 'time_format',
            'promptText': 'How should you express 3:30 in the afternoon?',
            'options': ['Three thirty', 'Three thirty p.m.', 'Fifteen thirty', 'Half past three afternoon'],
            'correctAnswer': 'Three thirty p.m.',
          },
        ],
      },
      'slides': [
        {
          'title': 'Objective',
          'content': 'To help learners use numbers and talk about time, dates, and prices accurately and confidently in real-world customer service interactions.',
        },
        {
          'title': 'Part 1: Using Numbers in Customer Service',
          'content': 'In a call center setting, numbers are often used to:\n• Share prices – e.g., "It\'s \$25.50"\n• Confirm orders – e.g., "Your order number is 135728."\n• Provide dates/schedules – e.g., "It will arrive on March 15th."\n• Give time – e.g., "Your appointment is at 3:30 p.m."\n\nVocabulary:\n• Cardinal numbers – one, two, three\n• Ordinal numbers – first, second, third (used in dates)\n\nExamples:\n• "Your total is twenty-nine dollars."\n• "You are speaking with Agent Number 5."\n• "Please hold for two minutes."\n• "Your refund will be processed in 3 to 5 business days."',
        },
        {
          'title': 'Part 2: Talking About Prices',
          'content': '• "It\'s \$10." ("ten dollars")\n• "The shipping fee is \$7.99."\n• "That item costs \$249."',
        },
        {
          'title': 'Part 3 & 4: Time & Dates',
          'content': 'Asking & Telling the Time:\n• "What time is it?"\n• "It\'s 8:15 a.m."\nTalking About Dates:\n• Month + Day (ordinal) + Year (April 15th, 2025).',
        },
        {
          'title': 'Watch: Numbers, Dates, and Prices',
          'content': 'Watch the video before doing the activity.',
        }
      ],
      'video': {'url': 'VIDEO_ID_FOR_2_3_HERE'},
      'activity': {
        'title': 'Simulation Activity: Price, Time, and Date Communication',
        'objective': 'Practice using numbers, time, dates, and prices in call center scenarios.',
        'instructions': {
          'heading': 'Important Guidelines',
          'introParagraph': 'Provide clear answers using proper formats for all your responses.',
          'listItems': [
            'Use proper <strong>price formats</strong> (e.g., "twenty-nine dollars and fifty cents")',
            'Include <strong>a.m./p.m.</strong> for time expressions',
            'Use <strong>ordinal numbers</strong> for dates (e.g., "March 15th, 2025")',
            'Be consistent with your formatting throughout',
          ],
        },
        'prompts': [
          {
            'name': 'price',
            'label': 'Prompt 1 – Price Confirmation',
            'customerText': 'Customer: "How much is the total for my order?"',
            'agentPrompt': 'Agent: "Your total is …"',
            'placeholder': 'e.g., twenty-nine dollars and fifty cents',
            'icon': 'FaDollarSign',
            'type': 'text',
          },
          {
            'name': 'delivery',
            'label': 'Prompt 2 – Delivery Date',
            'customerText': 'Customer: "When can I expect my package?"',
            'agentPrompt': 'Agent: "It will arrive on …"',
            'placeholder': 'e.g., June 3rd, 2025',
            'icon': 'FaCalendarAlt',
            'type': 'text',
          },
          {
            'name': 'appointment',
            'label': 'Prompt 3 – Appointment Time',
            'customerText': 'Customer: "What time is my appointment?"',
            'agentPrompt': 'Agent: "It\'s scheduled for …"',
            'placeholder': 'e.g., 3:30 p.m.',
            'icon': 'FaClock',
            'type': 'text',
          },
          {
            'name': 'account',
            'label': 'Prompt 4 – Account Number',
            'customerText': 'Customer: "Can you check my account?"',
            'agentPrompt': 'Agent: "Yes, I see it\'s …"',
            'placeholder': 'e.g., 135728',
            'icon': 'FaUserCheck',
            'type': 'text',
          },
          {
            'name': 'billing',
            'label': 'Prompt 5 – Billing Issue',
            'customerText': 'Customer: "I was charged twice!"',
            'agentPrompt': 'Agent: "I see a charge of …"',
            'placeholder': r'e.g., $50.00 on May 12, 2025',
            'icon': 'FaFileInvoiceDollar',
            'type': 'text',
          },
        ],
        'maxPossibleAIScore': 25,
        'timerDuration': 900,
      },
    };

    _lessonData = hardcoded;
    _activityPrompts = _lessonData!['activity']?['prompts'] as List<dynamic>? ?? [];

    // Initialize text controllers and answers
    _textControllers.forEach((_, c) => c.dispose());
    _textControllers.clear();
    _keyPhraseAnswers.clear();

    for (final p in _activityPrompts) {
      if (p is Map && p['name'] is String) {
        _textControllers[p['name']] = TextEditingController();
        _answers[p['name']] = '';
      }
    }

    // Initialize key phrase answers
    final keyPhraseQuestions = _lessonData!['keyPhraseActivity']?['questions'] as List<dynamic>? ?? [];
    for (final q in keyPhraseQuestions) {
      if (q is Map && q['id'] is String) {
        _keyPhraseAnswers[q['id']] = '';
      }
    }

    if (mounted) {
      setState(() => _isLoadingLessonContent = false);
    }
  }

  void _videoListener() {
    if (widget.youtubeController.value.playerState == PlayerState.ended && !_videoFinished) {
      if (mounted) setState(() => _videoFinished = true);
    }
  }

  void _startTimer() {
    _stopTimer();
    _timerSeconds = _lessonData?['activity']?['timerDuration'] ?? 900;
    _secondsElapsed = 0;
    _isTimedOut = false;
    _timerActive = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_timerSeconds > 0) {
          _timerSeconds--;
          _secondsElapsed++;
        } else {
          _isTimedOut = true;
          _timerActive = false;
          _timer?.cancel();
        }
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timerActive = false;
  }

  String _formatTime(int seconds) =>
      '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';

  void _handleAnswerChanged(String name, String value) {
    setState(() {
      _answers[name] = value;
      _textControllers[name]?.text = value;
    });
  }

  void _handleKeyPhraseAnswerChanged(String questionId, String value) {
    setState(() {
      _keyPhraseAnswers[questionId] = value;
    });
  }

  // MAIN SUBMISSION METHOD - This is the key fix!
  Future<void> _handleSubmit() async {
    if (_answers.values.any((a) => a.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please answer all prompts before submitting.')),
      );
      return;
    }

    if (_loading) return;

    setState(() => _loading = true);

    try {
      // Stop timer and calculate time spent
      _stopTimer();
      final timeSpent = _secondsElapsed;

      // Call the parent's submission handler which connects to AI server and saves to Firebase
      await widget.onSubmitAnswers(
        Map<String, String>.from(_answers),
        timeSpent,
        widget.initialAttemptNumber,
      );

      _logger.i('Lesson 2.3: Successfully submitted answers to parent module');
      
    } catch (e) {
      _logger.e("Error during lesson submission: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission error: $e. Please try again.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _handleStartActivity() {
    setState(() {
      _isActivityVisible = true;
      // Reset all answers and controllers
      for (final p in _activityPrompts) {
        final name = p['name'];
        _answers[name] = '';
        _textControllers[name]?.clear();
      }
      _isTimedOut = false;
      _secondsElapsed = 0;
    });
    _startTimer();
    widget.onShowActivitySection();
  }

  void _handleCheckKeyPhrases() {
    setState(() {
      _showKeyPhraseResults = true;
    });
  }

  Future<void> _loadActivityLog() async {
    if (_firebaseService.userId == null) return;
    
    setState(() {
      _showActivityLog = true;
      _activityLogLoading = true;
    });

    try {
      // Implement actual activity log loading
      // This is a placeholder - replace with actual implementation
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

  Widget _buildKeyPhrasesSection() {
    final keyPhrases = _lessonData?['keyPhrases'];
    if (keyPhrases == null) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const FaIcon(FontAwesomeIcons.lightbulb, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    keyPhrases['heading'] ?? 'Key Phrases',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (keyPhrases['introParagraph'] != null)
              Text(
                keyPhrases['introParagraph'],
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
            const SizedBox(height: 12),
            if (keyPhrases['listItems'] != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  children: (keyPhrases['listItems'] as List<dynamic>)
                      .map((item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                                Expanded(
                                  child: HtmlFormattedText(htmlString: item.toString()),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoSection() {
    final videos = _lessonData?['videos'];
    if (videos == null) return const SizedBox.shrink();

    return Column(
      children: [
        if (videos['priceVideo'] != null) ...[
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
                  child: Text(
                    videos['priceVideo']['heading'] ?? 'Video',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  height: 200,
                  width: double.infinity,
                  color: Colors.grey.shade300,
                  child: const Center(
                    child: Text('Video Player Placeholder\n(Replace with actual video player)'),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (videos['timeAndDateVideo'] != null) ...[
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
                  child: Text(
                    videos['timeAndDateVideo']['heading'] ?? 'Video',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  height: 200,
                  width: double.infinity,
                  color: Colors.grey.shade300,
                  child: const Center(
                    child: Text('Video Player Placeholder\n(Replace with actual video player)'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildKeyPhraseActivity() {
    final keyPhraseActivity = _lessonData?['keyPhraseActivity'];
    if (keyPhraseActivity == null) return const SizedBox.shrink();

    final questions = keyPhraseActivity['questions'] as List<dynamic>? ?? [];

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const FaIcon(FontAwesomeIcons.checkCircle, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    keyPhraseActivity['title'] ?? 'Quick Check',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              keyPhraseActivity['instruction'] ?? '',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ...questions.asMap().entries.map((entry) {
              final index = entry.key;
              final question = entry.value;
              final questionId = question['id'];
              final options = question['options'] as List<dynamic>? ?? [];
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${index + 1}. ${question['promptText']}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    ...options.map((option) {
                      final isSelected = _keyPhraseAnswers[questionId] == option;
                      final isCorrect = option == question['correctAnswer'];
                      final showResults = _showKeyPhraseResults;
                      
                      Color? backgroundColor;
                      Color? textColor;
                      
                      if (showResults) {
                        if (isCorrect) {
                          backgroundColor = Colors.green.shade100;
                          textColor = Colors.green.shade800;
                        } else if (isSelected && !isCorrect) {
                          backgroundColor = Colors.red.shade100;
                          textColor = Colors.red.shade800;
                        }
                      }
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: InkWell(
                          onTap: showResults ? null : () => _handleKeyPhraseAnswerChanged(questionId, option),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: backgroundColor ?? (isSelected ? Colors.blue.shade50 : null),
                              border: Border.all(
                                color: isSelected ? Colors.blue : Colors.grey.shade300,
                                width: isSelected ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                  color: textColor ?? (isSelected ? Colors.blue : Colors.grey),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    option.toString(),
                                    style: TextStyle(color: textColor),
                                  ),
                                ),
                                if (showResults && isCorrect)
                                  const Icon(Icons.check_circle, color: Colors.green),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              );
            }).toList(),
            if (!_showKeyPhraseResults) ...[
              const SizedBox(height: 16),
              Center(
                child: ElevatedButton(
                  onPressed: _handleCheckKeyPhrases,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  child: const Text('Check My Answers', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActivityLogModal() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Activity Log',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _showActivityLog = false),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Container(
                constraints: const BoxConstraints(maxHeight: 400),
                padding: const EdgeInsets.all(16),
                child: _activityLogLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _activityLog.isEmpty
                        ? const Center(child: Text('No activity recorded yet.'))
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: _activityLog.length,
                            itemBuilder: (context, index) {
                              final log = _activityLog[index];
                              return Card(
                                child: ListTile(
                                  title: Text('Attempt ${log['attemptNumber'] ?? index + 1}'),
                                  subtitle: Text('Score: ${log['score'] ?? 'N/A'}'),
                                ),
                              );
                            },
                          ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: () => setState(() => _showActivityLog = false),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAiFeedbackWidget() {
    if (!widget.displayFeedback || widget.aiFeedbackData == null) {
      return const SizedBox.shrink();
    }

    final feedbackData = widget.aiFeedbackData!;
    if (feedbackData.isEmpty) return const SizedBox.shrink();

    final cards = <Widget>[];
    
    feedbackData.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        try {
          final aiFeedback = AiFeedbackDataModel.fromMap(value);
          cards.add(
            AiFeedbackDisplayCard(
              feedbackData: aiFeedback,
              scenarioLabel: 'Scenario: $key',
            ),
          );
        } catch (e) {
          _logger.e('Error parsing AI feedback for $key: $e');
          cards.add(
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error loading feedback for $key'),
              ),
            ),
          );
        }
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AI Performance Analysis',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        if (widget.overallAIScoreForDisplay != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Overall Score:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${widget.overallAIScoreForDisplay} / ${widget.maxPossibleAIScoreForDisplay ?? 25}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        ...cards,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingLessonContent || _lessonData == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final title = _lessonData!['lessonTitle'] as String? ?? 'Lesson 2.3';
    final slides = _lessonData!['slides'] as List<dynamic>? ?? [];
    final activityTitle = _lessonData!['activity']?['title'] as String? ?? 'Simulation Activity';
    final instructions = _lessonData!['activity']?['instructions'];

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
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: const Color(0xFF00568D),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),

                // Only show non-activity content when activity is not visible
                if (!_isActivityVisible) ...[
                  // Check if user is logged in before showing activity log button
                  if (_firebaseService.userId != null) ...[
                    Center(
                      child: OutlinedButton.icon(
                        onPressed: _loadActivityLog,
                        icon: const Icon(Icons.history),
                        label: const Text('View Activity Log'),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Objective Section
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              FaIcon(FontAwesomeIcons.bullseye, color: Colors.blue),
                              SizedBox(width: 8),
                              Text(
                                'Objective',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _lessonData!['objective']?['paragraph'] ?? '',
                            style: const TextStyle(fontSize: 14, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Key Phrases Section
                  _buildKeyPhrasesSection(),

                  // Video Section
                  _buildVideoSection(),

                  // Key Phrase Activity
                  _buildKeyPhraseActivity(),

                  // Slides (Carousel)
                  if (slides.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    CarouselSlider(
                      key: ValueKey('carousel_l2_3_${slides.hashCode}'),
                      carouselController: widget.carouselController,
                      items: slides.map((slide) {
                        return buildSlide(
                          title: slide['title'] as String? ?? 'Slide',
                          content: slide['content'] as String? ?? '',
                          slideIndex: slides.indexOf(slide),
                        );
                      }).toList(),
                      options: CarouselOptions(
                        height: 280,
                        viewportFraction: 0.9,
                        enlargeCenterPage: false,
                        enableInfiniteScroll: false,
                        initialPage: widget.currentSlide,
                        onPageChanged: (i, _) => widget.onSlideChanged(i),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: slides.asMap().entries.map((e) {
                        return GestureDetector(
                          onTap: () => widget.carouselController.animateToPage(e.key),
                          child: Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 10),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: widget.currentSlide == e.key
                                  ? const Color(0xFF00568D)
                                  : Colors.grey,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  // Video Section and Start Activity Button
                  if (widget.currentSlide >= (slides.isNotEmpty ? slides.length - 1 : 0)) ...[
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Watch the Video',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: const Color(0xFF00568D),
                          ),
                        ),
                        const SizedBox(height: 8),
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: YoutubePlayer(
                            key: widget.youtubePlayerKey,
                            controller: widget.youtubeController,
                            showVideoProgressIndicator: true,
                            onEnded: (_) => _videoListener(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _videoFinished ? _handleStartActivity : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text(
                              'Start the Activity',
                              style: TextStyle(color: Colors.white, fontSize: 16),
                            ),
                          ),
                        ),
                        if (!_videoFinished)
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text(
                              'Please finish the video to proceed.',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],

                // Activity Section
                if (_isActivityVisible && !widget.displayFeedback) ...[
                  const SizedBox(height: 20),
                  Card(
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activityTitle,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Attempt: $_currentAttemptForDisplay',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if (_timerActive && !_isTimedOut)
                                Text(
                                  'Time: ${_formatTime(_timerSeconds)}',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: _timerSeconds < 60 ? Colors.red : null,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Instructions
                          if (instructions != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.yellow.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.yellow.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const FaIcon(FontAwesomeIcons.infoCircle, color: Colors.orange),
                                      const SizedBox(width: 8),
                                      Text(
                                        instructions['heading'] ?? 'Instructions',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(instructions['introParagraph'] ?? ''),
                                  if (instructions['listItems'] != null) ...[
                                    const SizedBox(height: 8),
                                    ...((instructions['listItems'] as List<dynamic>).map((item) =>
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 2),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('• '),
                                            Expanded(child: HtmlFormattedText(htmlString: item.toString())),
                                          ],
                                        ),
                                      ),
                                    ).toList()),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Activity Prompts
                          ..._activityPrompts.asMap().entries.map((entry) {
                            final index = entry.key;
                            final prompt = entry.value as Map<String, dynamic>;
                            final name = prompt['name'] as String;
                            final icon = _iconMap[prompt['icon']] ?? FontAwesomeIcons.questionCircle;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      FaIcon(icon, size: 16, color: Colors.grey.shade600),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          prompt['label'] ?? 'Prompt ${index + 1}',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  if (prompt['customerText'] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 24, bottom: 4),
                                      child: Text(
                                        prompt['customerText'],
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                  if (prompt['agentPrompt'] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 24, bottom: 8),
                                      child: Text(
                                        prompt['agentPrompt'],
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                  TextField(
                                    controller: _textControllers[name],
                                    onChanged: (value) => _handleAnswerChanged(name, value),
                                    maxLines: 2,
                                    decoration: InputDecoration(
                                      hintText: prompt['placeholder'],
                                      border: const OutlineInputBorder(),
                                      contentPadding: const EdgeInsets.all(12),
                                    ),
                                    enabled: !_loading && !_isTimedOut,
                                  ),
                                ],
                              ),
                            );
                          }).toList(),

                          // Timeout Warning
                          if (_isTimedOut) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.shade300),
                              ),
                              child: const Column(
                                children: [
                                  Icon(Icons.warning, color: Colors.red, size: 32),
                                  SizedBox(height: 8),
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
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Submit Button
                          if (!_isTimedOut) ...[
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _loading ? null : _handleSubmit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00568D),
                                  disabledBackgroundColor: Colors.grey,
                                ),
                                child: _loading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : const Text(
                                        'Submit for AI Feedback',
                                        style: TextStyle(color: Colors.white, fontSize: 16),
                                      ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],

                // Display AI Feedback when available
                if (widget.displayFeedback) ...[
                  const SizedBox(height: 20),
                  _buildAiFeedbackWidget(),
                  
                  // Try Again Button
                  const SizedBox(height: 20),
                  Center(
                    child: ElevatedButton(
                      onPressed: () {
                        widget.onShowActivitySection();
                        setState(() {
                          _isActivityVisible = true;
                          // Reset for new attempt
                          for (final p in _activityPrompts) {
                            final name = p['name'];
                            _answers[name] = '';
                            _textControllers[name]?.clear();
                          }
                          _isTimedOut = false;
                          _secondsElapsed = 0;
                          _currentAttemptForDisplay = widget.initialAttemptNumber + 1;
                        });
                        _startTimer();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      ),
                      child: Text(
                        'Try Again (Attempt #${widget.initialAttemptNumber + 2})',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Activity log modal overlay
          if (_showActivityLog) _buildActivityLogModal(),

          // Loading overlay
          if (_loading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Submitting your answers...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
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

// Simple HTML formatter (keeping existing functionality)
class HtmlFormattedText extends StatelessWidget {
  final String htmlString;
  const HtmlFormattedText({super.key, required this.htmlString});

  @override
  Widget build(BuildContext context) {
    // Simple HTML to text conversion - replace with more sophisticated parser if needed
    String processedText = htmlString
        .replaceAll('<strong>', '')
        .replaceAll('</strong>', '')
        .replaceAll('<br/>', '\n')
        .replaceAll('<br>', '\n');
    
    return Text(
      processedText,
      style: const TextStyle(fontSize: 14, height: 1.4),
    );
  }
}