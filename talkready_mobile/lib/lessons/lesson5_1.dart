// lib/lessons/lesson5_1.dart
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../services/unified_progress_service.dart';
import '../widgets/skill_pill_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/ai_feedback_display_card.dart';

class Lesson5_1Page extends StatefulWidget {
  final String lessonId;
  final String lessonTitle;
  final Map<String, dynamic> lessonData;
  final int attemptNumber;

  const Lesson5_1Page({
    super.key,
    required this.lessonId,
    required this.lessonTitle,
    required this.lessonData,
    required this.attemptNumber,
  });

  @override
  State<Lesson5_1Page> createState() => _Lesson5_1PageState();
}

class _Lesson5_1PageState extends State<Lesson5_1Page>
    with TickerProviderStateMixin {
  final Logger _logger = Logger();
  final UnifiedProgressService _progressService = UnifiedProgressService();

  List<Map<String, dynamic>> _activityLog = [];
  int _attemptNumber = 0;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isLoading = true;
  bool _hasStudied = false;
  bool _isPreAssessmentComplete = false;
  bool _showPreAssessment = false;

  // Pre-assessment drag and drop state
  Map<String, Map<String, dynamic>> _columns = {};
  String? _draggedItemId;
  bool _preAssessmentSubmitted = false;
  bool _showPreAssessmentResults = false;
  Map<String, bool> _itemResults = {};
  Timer? _progressTimer;
  double _progressValue = 0.0;

  // Lesson content
  final Map<String, dynamic> _lessonContent = {
    'objective': {
      'heading': 'Lesson Objective',
      'paragraph':
          'To practice handling a simulated call where a customer asks for straightforward information, requiring a basic greeting, understanding the request, providing a simple answer, and concluding the call politely.',
    },
    'introduction': {
      'heading': 'Key Skills Integrated',
      'points': [
        {
          'skill': 'Module 1 (Grammar)',
          'description':
              'Using basic sentence structures and correct present simple tense.',
        },
        {
          'skill': 'Module 2 (Conversation)',
          'description':
              'Applying standard greetings and polite closing phrases.',
        },
        {
          'skill': 'Module 3 (Speaking)',
          'description':
              'Speaking clearly and at an understandable pace, maintaining basic fluency and pronunciation.',
        },
        {
          'skill': 'Module 4 (Handling)',
          'description':
              'Providing simple, direct information and asking clarification questions to resolve the inquiry.',
        },
      ],
    },
    'callFlow': {
      'heading': 'Breaking Down the Call Flow',
      'steps': [
        {
          'title': '1. The Opening',
          'text': 'Greet the customer professionally and state your name.',
        },
        {
          'title': '2. Verification',
          'text':
              'Listen to their request and ask for a key piece of information (like an order number) to verify their account.',
        },
        {
          'title': '3. Information Delivery',
          'text':
              'Politely inform the customer you have the information they need and deliver it clearly.',
        },
        {
          'title': '4. The Closing',
          'text':
              'Ask if they need any more help and end the call with a polite closing phrase.',
        },
      ],
    },
    'preAssessment': {
      'title': 'Pre-Lesson Check-in: Scenario Matching',
      'instruction':
          'Drag each customer request into the box that describes the correct first action for an agent to take.',
      'columns': {
        'requests': {
          'name': 'Customer Requests',
          'items': [
            {
              'id': 'item-1',
              'content': '"What are your store hours on Sunday?"',
              'correctColumn': 'col_direct',
            },
            {
              'id': 'item-2',
              'content':
                  '"Can you tell me if I have any loyalty points on my account?"',
              'correctColumn': 'col_verify',
            },
            {
              'id': 'item-3',
              'content': '"What is the status of my order #55123?"',
              'correctColumn': 'col_verify',
            },
            {
              'id': 'item-4',
              'content': '"Do you ship to my area, in Cebu City?"',
              'correctColumn': 'col_direct',
            },
          ],
        },
        'col_verify': {
          'name': 'Requires Account Verification',
          'items': <Map<String, dynamic>>[],
        },
        'col_direct': {
          'name': 'Can Be Answered Directly',
          'items': <Map<String, dynamic>>[],
        },
      },
      'feedback': {
        'heading': 'Excellent!',
        'paragraph':
            'You\'ve got a good sense of how to categorize customer needs. Let\'s put it into practice in a full simulation.',
      },
    },
  };

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializePreAssessment();
    _checkUserProgress();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _fadeController.forward();
    _slideController.forward();
  }

  void _initializePreAssessment() {
    final preAssessmentData =
        _lessonContent['preAssessment'] as Map<String, dynamic>;
    final columns = preAssessmentData['columns'] as Map<String, dynamic>;

    // Get the requests column data
    final requestsColumn = columns['requests'] as Map<String, dynamic>;
    final requestsItems = requestsColumn['items'] as List;

    // Get other column data
    final verifyColumn = columns['col_verify'] as Map<String, dynamic>;
    final directColumn = columns['col_direct'] as Map<String, dynamic>;

    _columns = {
      'requests': {
        'name': requestsColumn['name'] as String,
        'items': requestsItems
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList(),
      },
      'col_verify': {
        'name': verifyColumn['name'] as String,
        'items': <Map<String, dynamic>>[],
      },
      'col_direct': {
        'name': directColumn['name'] as String,
        'items': <Map<String, dynamic>>[],
      },
    };
  }

  Future<void> _checkUserProgress() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // --- THIS IS THE FIX ---
        // We now fetch the entire progress document at once, which is more efficient.
        final progress = await _progressService.getUserProgress();

        // Get pre-assessment status
        final preAssessmentsCompleted =
            progress['preAssessmentsCompleted'] as Map<String, dynamic>? ?? {};
        final isPreAssessmentDone =
            preAssessmentsCompleted[widget.lessonId] == true;

        // Get lesson attempts for the activity log
        final allLessonAttempts =
            progress['lessonAttempts'] as Map<String, dynamic>? ?? {};
        final attempts = List<Map<String, dynamic>>.from(
          allLessonAttempts[widget.lessonId] ?? [],
        );
        // --- END OF FIX ---

        if (mounted) {
          setState(() {
            _isPreAssessmentComplete = isPreAssessmentDone;
            _hasStudied =
                isPreAssessmentDone; // User can study if pre-assessment is done
            _activityLog = attempts; // Store the fetched attempts
            _attemptNumber = attempts.length; // Update the attempt count
          });
        }
      }
    } catch (e) {
      _logger.e('Error checking user progress: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showActivityLogDialog() {
    Navigator.pushNamed(
      context,
      '/lesson_activity_log', // This route uses your shared log page
      arguments: {
        'lessonId': widget.lessonId,
        'lessonData': widget.lessonData,
        'activityLog': _activityLog,
      },
    );
  }

  void _startPreAssessment() {
    setState(() {
      _showPreAssessment = true;
      _initializePreAssessment(); // Reset the assessment
    });
  }

  void _onDragStarted(Map<String, dynamic> item) {
    setState(() {
      _draggedItemId = item['id'];
    });
  }

  void _onDragEnd() {
    setState(() {
      _draggedItemId = null;
    });
  }

  bool _onWillAccept(String columnId, Map<String, dynamic> item) {
    return columnId != 'requests' && !_preAssessmentSubmitted;
  }

  void _onAccept(String columnId, Map<String, dynamic> item) {
    if (_preAssessmentSubmitted) return;

    setState(() {
      // Remove item from all columns first
      _columns.forEach((key, value) {
        final items = value['items'] as List<Map<String, dynamic>>;
        items.removeWhere((existingItem) => existingItem['id'] == item['id']);
      });

      // Add item to the target column
      final targetItems =
          _columns[columnId]!['items'] as List<Map<String, dynamic>>;
      targetItems.add(item);
    });
  }

  void _checkPreAssessment() {
    if (_preAssessmentSubmitted) return;

    setState(() => _preAssessmentSubmitted = true);

    // Check answers
    Map<String, bool> results = {};
    _columns.forEach((columnId, columnData) {
      if (columnId != 'requests') {
        final items = columnData['items'] as List<Map<String, dynamic>>;
        for (var item in items) {
          final itemId = item['id'] as String;
          final correctColumn = item['correctColumn'] as String;
          results[itemId] = correctColumn == columnId;
        }
      }
    });

    setState(() => _itemResults = results);

    // Show results for 3 seconds, then show feedback
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _showPreAssessmentResults = true);
        _startProgressAnimation();
      }
    });
  }

  void _startProgressAnimation() {
    _progressTimer = Timer.periodic(const Duration(milliseconds: 40), (timer) {
      setState(() {
        _progressValue += 0.025;
        if (_progressValue >= 1.0) {
          _progressValue = 1.0;
          timer.cancel();
          _completePreAssessment();
        }
      });
    });
  }

  void _completePreAssessment() {
    Timer(const Duration(milliseconds: 500), () async {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await _progressService.markPreAssessmentAsComplete('Lesson-5-1');
        }
      } catch (e) {
        _logger.e('Error marking pre-assessment complete: $e');
      }

      if (mounted) {
        setState(() {
          _isPreAssessmentComplete = true;
          _hasStudied = true;
          _showPreAssessment = false;
        });
      }
    });
  }

  void _handleStudyComplete() {
    setState(() => _hasStudied = true);
  }

  void _navigateToActivity() {
    Navigator.pushNamed(
      context,
      '/lesson5_1_activity',
      arguments: {
        'lessonId': 'Lesson-5-1',
        'lessonTitle': 'Lesson 5.1: Basic Simulation - Info Request',
        'lessonData': widget.lessonData,
        'attemptNumber': widget.attemptNumber,
      },
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _progressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: Text(widget.lessonTitle),
          backgroundColor: const Color(0xFF00BCD4),
          foregroundColor: Colors.white,
          elevation: 4,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF00BCD4)),
              SizedBox(height: 16),
              Text('Loading lesson...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          widget.lessonTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF00BCD4),
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: _showPreAssessment
              ? _buildPreAssessment()
              : _buildMainContent(),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ ADD: Module and Lesson Title Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF00BCD4), Color(0xFF0097A7)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00BCD4).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Module 5: Practical Simulation &',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.headset_mic,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Lesson 5.1: Basic Simulation - Info Request',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // ✅ END OF ADDITION

          // Activity Log Button
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.history, color: Color(0xFF00BCD4)),
              label: const Text(
                'View Your Activity Log',
                style: TextStyle(color: Color(0xFF00BCD4)),
              ),
              onPressed: _showActivityLogDialog,
            ),
          ),

          const SizedBox(height: 8),

          _buildObjectiveSection(),
          const SizedBox(height: 24),
          _buildSkillsSection(),
          const SizedBox(height: 24),
          _buildCallFlowSection(),
          const SizedBox(height: 32),
          _buildStartButton(),
        ],
      ),
    );
  }

  Widget _buildPreAssessmentPrompt() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF00BCD4), Color(0xFF0097A7)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00BCD4).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.quiz, size: 48, color: Colors.white),
          const SizedBox(height: 16),
          const Text(
            'Pre-Lesson Check-in',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Before we start the call simulation, let\'s check your understanding of customer service scenarios.',
            style: TextStyle(fontSize: 16, color: Colors.white, height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _startPreAssessment,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF00BCD4),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: const Text(
              'Start Pre-Assessment',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreAssessment() {
    if (_showPreAssessmentResults) {
      return _buildPreAssessmentResults();
    }

    final preAssessmentData =
        _lessonContent['preAssessment'] as Map<String, dynamic>;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.lightbulb, color: Colors.amber, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        preAssessmentData['title'],
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00BCD4),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  preAssessmentData['instruction'],
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ✅ NEW: Horizontal Row-Based Layout
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Instructions Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.drag_indicator,
                          color: Colors.blue.shade600,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Drag each customer request into the correct category.',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // First Category: Requires Account Verification
                  _buildHorizontalDropZone('col_verify'),
                  const SizedBox(height: 20),

                  // Source Section: Customer Requests
                  _buildHorizontalSourceSection(),
                  const SizedBox(height: 20),

                  // Second Category: Can Be Answered Directly
                  _buildHorizontalDropZone('col_direct'),
                  const SizedBox(height: 20),

                  // Helper Tip
                  if (!_preAssessmentSubmitted)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info,
                            color: Colors.amber.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Tip: Tap and hold an item, then drag it to the correct category.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Submit Button
          if ((_columns['requests']!['items'] as List).isEmpty &&
              !_preAssessmentSubmitted)
            Container(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _checkPreAssessment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00BCD4),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  'Submit Answers',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ✅ NEW: Horizontal source section (like "Questions" in your image)
  Widget _buildHorizontalSourceSection() {
    final requestsItems =
        _columns['requests']!['items'] as List<Map<String, dynamic>>;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF00BCD4),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: const Text(
              'Customer Requests',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Content Area
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: requestsItems.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          color: Colors.green.shade400,
                          size: 48,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'All requests sorted!',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: requestsItems.map((item) {
                      final itemContent = item['content'] as String;
                      final isCorrect = _itemResults[item['id']];

                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Draggable<Map<String, dynamic>>(
                          data: item,
                          onDragStarted: () => _onDragStarted(item),
                          onDragEnd: (_) => _onDragEnd(),
                          feedback: Material(
                            elevation: 8,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 320,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00BCD4).withOpacity(0.9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                itemContent,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          childWhenDragging: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey.shade300,
                                style: BorderStyle.solid,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.drag_handle,
                                  color: Colors.grey.shade400,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    itemContent,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color:
                                  _preAssessmentSubmitted && isCorrect != null
                                  ? (isCorrect
                                        ? Colors.green.shade50
                                        : Colors.red.shade50)
                                  : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    _preAssessmentSubmitted && isCorrect != null
                                    ? (isCorrect ? Colors.green : Colors.red)
                                    : Colors.grey.shade300,
                                width:
                                    _preAssessmentSubmitted && isCorrect != null
                                    ? 2
                                    : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.drag_handle,
                                  color: Colors.grey.shade600,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    itemContent,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (_preAssessmentSubmitted &&
                                    isCorrect != null)
                                  Icon(
                                    isCorrect
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    color: isCorrect
                                        ? Colors.green
                                        : Colors.red,
                                    size: 20,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  // ✅ NEW: Horizontal drop zone (like "Open-Ended" and "Closed-Ended" in your image)
  Widget _buildHorizontalDropZone(String columnId) {
    final column = _columns[columnId]!;
    final items = column['items'] as List<Map<String, dynamic>>;
    final columnName = column['name'] as String;

    Color headerColor;
    Color backgroundColor;
    IconData categoryIcon;

    if (columnId == 'col_verify') {
      headerColor = Colors.orange.shade600;
      backgroundColor = Colors.orange.shade50;
      categoryIcon = Icons.verified_user;
    } else {
      headerColor = Colors.green.shade600;
      backgroundColor = Colors.green.shade50;
      categoryIcon = Icons.help_center;
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(categoryIcon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  columnName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Drop Area
          DragTarget<Map<String, dynamic>>(
            onWillAccept: (item) => _onWillAccept(columnId, item!),
            onAccept: (item) => _onAccept(columnId, item),
            builder: (context, candidateData, rejectedData) {
              return Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 100),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: candidateData.isNotEmpty
                      ? headerColor.withOpacity(0.1)
                      : backgroundColor,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                  border: candidateData.isNotEmpty
                      ? Border.all(color: headerColor, width: 2)
                      : null,
                ),
                child: items.isEmpty
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (candidateData.isNotEmpty) ...[
                            Icon(Icons.touch_app, color: headerColor, size: 32),
                            const SizedBox(height: 8),
                            Text(
                              'Drop here!',
                              style: TextStyle(
                                color: headerColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ] else ...[
                            Icon(
                              Icons.inbox,
                              color: Colors.grey.shade400,
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Empty - Drag items here',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      )
                    : Column(
                        children: items.map((item) {
                          final itemContent = item['content'] as String;
                          final itemId = item['id'] as String;
                          final isCorrect = _itemResults[itemId];

                          return Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color:
                                  _preAssessmentSubmitted && isCorrect != null
                                  ? (isCorrect
                                        ? Colors.green.shade100
                                        : Colors.red.shade100)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color:
                                    _preAssessmentSubmitted && isCorrect != null
                                    ? (isCorrect ? Colors.green : Colors.red)
                                    : Colors.grey.shade300,
                                width:
                                    _preAssessmentSubmitted && isCorrect != null
                                    ? 2
                                    : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    itemContent,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                                if (_preAssessmentSubmitted &&
                                    isCorrect != null) ...[
                                  const SizedBox(width: 8),
                                  Icon(
                                    isCorrect
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    color: isCorrect
                                        ? Colors.green
                                        : Colors.red,
                                    size: 18,
                                  ),
                                ],
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDropColumn(String columnId) {
    final column = _columns[columnId]!;
    final isSourceColumn = columnId == 'requests';
    final items = column['items'] as List<Map<String, dynamic>>;
    final columnName = column['name'] as String;

    return Container(
      decoration: BoxDecoration(
        color: isSourceColumn ? Colors.blue.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSourceColumn ? Colors.blue.shade200 : Colors.grey.shade300,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSourceColumn
                  ? Colors.blue.shade100
                  : Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Text(
              columnName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: DragTarget<Map<String, dynamic>>(
              onWillAccept: (item) => _onWillAccept(columnId, item!),
              onAccept: (item) => _onAccept(columnId, item),
              builder: (context, candidateData, rejectedData) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      ...items.map<Widget>((item) {
                        final itemId = item['id'] as String;
                        final itemContent = item['content'] as String;
                        final isCorrect = _itemResults[itemId];
                        Color? backgroundColor;
                        Color? borderColor;

                        if (_preAssessmentSubmitted && isCorrect != null) {
                          backgroundColor = isCorrect
                              ? Colors.green.shade100
                              : Colors.red.shade100;
                          borderColor = isCorrect ? Colors.green : Colors.red;
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: isSourceColumn
                              ? Draggable<Map<String, dynamic>>(
                                  data: item,
                                  onDragStarted: () => _onDragStarted(item),
                                  onDragEnd: (_) => _onDragEnd(),
                                  feedback: Material(
                                    child: Container(
                                      width: 200,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade200,
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.2,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        itemContent,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                  ),
                                  childWhenDragging: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade300,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                    child: Text(
                                      itemContent,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: backgroundColor ?? Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color:
                                            borderColor ?? Colors.grey.shade400,
                                        width: borderColor != null ? 2 : 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      itemContent,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                )
                              : Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: backgroundColor ?? Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color:
                                          borderColor ?? Colors.grey.shade400,
                                      width: borderColor != null ? 2 : 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    itemContent,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                        );
                      }).toList(),
                      if (candidateData.isNotEmpty && !isSourceColumn)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.blue.shade300,
                              width: 2,
                            ),
                          ),
                          child: const Text('Drop here'),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ✅ CORRECTED: Results feedback method
  Widget _buildPreAssessmentResults() {
    final feedbackData =
        _lessonContent['preAssessment']['feedback'] as Map<String, dynamic>;

    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        margin: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 64, color: Colors.green),
            const SizedBox(height: 24),
            Text(
              feedbackData['heading'],
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              feedbackData['paragraph'],
              style: const TextStyle(
                fontSize: 18,
                color: Colors.black87,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Column(
              children: [
                const Text(
                  'Loading lesson...',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: _progressValue,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF00BCD4),
                  ),
                  minHeight: 8,
                ),
                const SizedBox(height: 8),
                Text(
                  '${(_progressValue * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00BCD4),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ✅ NEW: Source items section (draggable items)
  Widget _buildSourceSection() {
    final requestsItems =
        _columns['requests']!['items'] as List<Map<String, dynamic>>;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200, width: 2),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Customer Requests',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.blue,
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (requestsItems.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: const Text(
                '✅ All items have been sorted!',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: requestsItems.map((item) {
                final itemContent = item['content'] as String;
                final isCorrect = _itemResults[item['id']];

                return Draggable<Map<String, dynamic>>(
                  data: item,
                  onDragStarted: () => _onDragStarted(item),
                  onDragEnd: (_) => _onDragEnd(),
                  feedback: Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 280,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        itemContent,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  childWhenDragging: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                    child: Text(
                      itemContent,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _preAssessmentSubmitted && isCorrect != null
                          ? (isCorrect
                                ? Colors.green.shade100
                                : Colors.red.shade100)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _preAssessmentSubmitted && isCorrect != null
                            ? (isCorrect ? Colors.green : Colors.red)
                            : Colors.grey.shade400,
                        width: _preAssessmentSubmitted && isCorrect != null
                            ? 2
                            : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            itemContent,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.drag_indicator,
                          color: Colors.grey,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // ✅ NEW: Drop zones section (vertical layout)
  Widget _buildDropZonesSection() {
    return Column(
      children: [
        _buildMobileDropZone('col_verify'),
        const SizedBox(height: 16),
        _buildMobileDropZone('col_direct'),
      ],
    );
  }

  // ✅ NEW: Mobile-friendly drop zone
  Widget _buildMobileDropZone(String columnId) {
    final column = _columns[columnId]!;
    final items = column['items'] as List<Map<String, dynamic>>;
    final columnName = column['name'] as String;

    Color zoneColor;
    Color borderColor;
    IconData zoneIcon;

    if (columnId == 'col_verify') {
      zoneColor = Colors.orange.shade50;
      borderColor = Colors.orange.shade300;
      zoneIcon = Icons.verified_user;
    } else {
      zoneColor = Colors.green.shade50;
      borderColor = Colors.green.shade300;
      zoneIcon = Icons.help_center;
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: zoneColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: borderColor.withOpacity(0.3),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(zoneIcon, color: borderColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    columnName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: borderColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),

          // Drop area
          DragTarget<Map<String, dynamic>>(
            onWillAccept: (item) => _onWillAccept(columnId, item!),
            onAccept: (item) => _onAccept(columnId, item),
            builder: (context, candidateData, rejectedData) {
              return Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 120),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: candidateData.isNotEmpty
                      ? borderColor.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(10),
                    bottomRight: Radius.circular(10),
                  ),
                ),
                child: items.isEmpty
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.touch_app,
                            color: Colors.grey.shade400,
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            candidateData.isNotEmpty
                                ? 'Drop here!'
                                : 'Drag items here',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: items.map((item) {
                          final itemContent = item['content'] as String;
                          final itemId = item['id'] as String;
                          final isCorrect = _itemResults[itemId];

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color:
                                  _preAssessmentSubmitted && isCorrect != null
                                  ? (isCorrect
                                        ? Colors.green.shade100
                                        : Colors.red.shade100)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color:
                                    _preAssessmentSubmitted && isCorrect != null
                                    ? (isCorrect ? Colors.green : Colors.red)
                                    : Colors.grey.shade400,
                                width:
                                    _preAssessmentSubmitted && isCorrect != null
                                    ? 2
                                    : 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    itemContent,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                                if (_preAssessmentSubmitted &&
                                    isCorrect != null) ...[
                                  const SizedBox(width: 8),
                                  Icon(
                                    isCorrect
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    color: isCorrect
                                        ? Colors.green
                                        : Colors.red,
                                    size: 16,
                                  ),
                                ],
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildObjectiveSection() {
    final objective = _lessonContent['objective'] as Map<String, dynamic>;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.flag, color: Colors.blue, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                objective['heading'],
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00BCD4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            objective['paragraph'],
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillsSection() {
    final introduction = _lessonContent['introduction'] as Map<String, dynamic>;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.integration_instructions,
                  color: Colors.purple,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                introduction['heading'],
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF7B1FA2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Hover over each skill to see what it covers.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: (introduction['points'] as List<dynamic>)
                .map(
                  (point) => SkillPillWidget(
                    skill: point['skill'],
                    description: point['description'],
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCallFlowSection() {
    final callFlow = _lessonContent['callFlow'] as Map<String, dynamic>;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start, // Align items to the top
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.route, color: Colors.green, size: 24),
              ),
              const SizedBox(width: 12),
              // --- THIS IS THE FIX ---
              // The Expanded widget allows the Text to wrap onto multiple lines
              // if it's too long, preventing the overflow.
              Expanded(
                child: Text(
                  callFlow['heading'],
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF388E3C),
                  ),
                ),
              ),
              // --- END OF FIX ---
            ],
          ),
          const SizedBox(height: 20),
          ...(callFlow['steps'] as List<dynamic>).map((step) {
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step['title'],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    step['text'],
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildStartButton() {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: ElevatedButton.icon(
          onPressed: _navigateToActivity,
          icon: const Icon(Icons.headset, size: 24),
          label: const Text(
            'Start Call Simulation',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            elevation: 4,
            shadowColor: Colors.green.withOpacity(0.4),
          ),
        ),
      ),
    );
  }
}
