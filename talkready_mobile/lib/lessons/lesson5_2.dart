// lib/lessons/lesson5_2.dart
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../services/unified_progress_service.dart';
import '../widgets/skill_pill_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/ai_feedback_display_card.dart';

class Lesson5_2Page extends StatefulWidget {
  final String lessonId;
  final String lessonTitle;
  final Map<String, dynamic> lessonData;
  final int attemptNumber;

  const Lesson5_2Page({
    super.key,
    this.lessonId = 'Lesson-5-2',
    this.lessonTitle = 'Lesson 5.2: Advanced Simulation - Problem Resolution',
    this.lessonData = const {},
    this.attemptNumber = 1,
  });

  @override
  State<Lesson5_2Page> createState() => _Lesson5_2PageState();
}

class _Lesson5_2PageState extends State<Lesson5_2Page>
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
          'To practice handling a complex customer service scenario where a customer reports a problem with their order, requiring active listening, problem-solving skills, empathy, and the ability to provide solutions while maintaining professionalism throughout the interaction.',
    },
    'introduction': {
      'heading': 'Advanced Skills Integration',
      'points': [
        {
          'skill': 'Module 1 (Grammar)',
          'description':
              'Using complex sentence structures, conditional statements, and appropriate tenses for problem resolution.',
        },
        {
          'skill': 'Module 2 (Conversation)',
          'description':
              'Applying advanced conversation techniques including empathy statements and solution-focused language.',
        },
        {
          'skill': 'Module 3 (Speaking)',
          'description':
              'Demonstrating clear articulation under pressure while maintaining professional tone and pace.',
        },
        {
          'skill': 'Module 4 (Handling)',
          'description':
              'Implementing advanced problem-solving strategies, de-escalation techniques, and follow-up procedures.',
        },
      ],
    },
    'callFlow': {
      'heading': 'Advanced Call Flow Management',
      'steps': [
        {
          'title': '1. Professional Opening & Problem Identification',
          'text':
              'Greet professionally, acknowledge the issue, and demonstrate active listening to understand the customer\'s problem.',
        },
        {
          'title': '2. Empathetic Response & Information Gathering',
          'text':
              'Show understanding of customer frustration, ask relevant questions to gather details needed for resolution.',
        },
        {
          'title': '3. Problem Analysis & Solution Presentation',
          'text':
              'Analyze the issue, explain what happened, and present clear, actionable solutions to the customer.',
        },
        {
          'title': '4. Resolution Implementation & Follow-up',
          'text':
              'Implement the agreed solution, confirm customer satisfaction, and provide follow-up assurance.',
        },
      ],
    },
    'preAssessment': {
      'title': 'Pre-Lesson Check-in: Problem Resolution Scenarios',
      'instruction':
          'Drag each customer complaint into the appropriate response category that shows the best initial approach.',
      'columns': {
        'requests': {
          'name': 'Customer Complaints',
          'items': [
            {
              'id': 'item-1',
              'content':
                  '"My order arrived damaged and I need this for a gift tomorrow!"',
              'correctColumn': 'col_urgent',
            },
            {
              'id': 'item-2',
              'content':
                  '"I\'ve been waiting on hold for 20 minutes. This is ridiculous!"',
              'correctColumn': 'col_empathy',
            },
            {
              'id': 'item-3',
              'content': '"Your website charged me twice for the same order."',
              'correctColumn': 'col_investigate',
            },
            {
              'id': 'item-4',
              'content': '"I received the wrong item completely."',
              'correctColumn': 'col_urgent',
            },
          ],
        },
        'col_urgent': {
          'name': 'Immediate Action Required',
          'items': <Map<String, dynamic>>[],
        },
        'col_empathy': {
          'name': 'Empathy & De-escalation First',
          'items': <Map<String, dynamic>>[],
        },
        'col_investigate': {
          'name': 'Investigation & Verification',
          'items': <Map<String, dynamic>>[],
        },
      },
      'feedback': {
        'heading': 'Excellent Problem Assessment!',
        'paragraph':
            'You understand how to prioritize different types of customer issues. Now let\'s practice handling a complex problem resolution scenario.',
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

    final requestsColumn = columns['requests'] as Map<String, dynamic>;
    final requestsItems = requestsColumn['items'] as List;

    final urgentColumn = columns['col_urgent'] as Map<String, dynamic>;
    final empathyColumn = columns['col_empathy'] as Map<String, dynamic>;
    final investigateColumn =
        columns['col_investigate'] as Map<String, dynamic>;

    _columns = {
      'requests': {
        'name': requestsColumn['name'] as String,
        'items': requestsItems
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList(),
      },
      'col_urgent': {
        'name': urgentColumn['name'] as String,
        'items': <Map<String, dynamic>>[],
      },
      'col_empathy': {
        'name': empathyColumn['name'] as String,
        'items': <Map<String, dynamic>>[],
      },
      'col_investigate': {
        'name': investigateColumn['name'] as String,
        'items': <Map<String, dynamic>>[],
      },
    };
  }

  Future<void> _checkUserProgress() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final progress = await _progressService.getUserProgress();

        final preAssessmentsCompleted =
            progress['preAssessmentsCompleted'] as Map<String, dynamic>? ?? {};
        final isPreAssessmentDone =
            preAssessmentsCompleted[widget.lessonId] == true;

        final allLessonAttempts =
            progress['lessonAttempts'] as Map<String, dynamic>? ?? {};
        final attempts = List<Map<String, dynamic>>.from(
          allLessonAttempts[widget.lessonId] ?? [],
        );

        if (mounted) {
          setState(() {
            _isPreAssessmentComplete = isPreAssessmentDone;
            _hasStudied = isPreAssessmentDone;
            _activityLog = attempts;
            _attemptNumber = attempts.length;
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
      '/lesson_activity_log',
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
      _initializePreAssessment();
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
      _columns.forEach((key, value) {
        final items = value['items'] as List<Map<String, dynamic>>;
        items.removeWhere((existingItem) => existingItem['id'] == item['id']);
      });

      final targetItems =
          _columns[columnId]!['items'] as List<Map<String, dynamic>>;
      targetItems.add(item);
    });
  }

  void _checkPreAssessment() {
    if (_preAssessmentSubmitted) return;

    setState(() => _preAssessmentSubmitted = true);

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
          await _progressService.markPreAssessmentAsComplete('Lesson-5-2');
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

  void _navigateToActivity() {
    Navigator.pushNamed(
      context,
      '/lesson5_2_activity',
      arguments: {
        'lessonId': 'Lesson-5-2',
        'lessonTitle': 'Lesson 5.2: Advanced Simulation - Problem Resolution',
        'lessonData': widget.lessonData,
        'attemptNumber': _attemptNumber,
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
          // Module and Lesson Title Section
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
                  'Module 5: Professional Communication',
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
                        Icons.support_agent,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Lesson 5.2: Advanced Simulation - Problem Resolution',
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

          // Pre-assessment section if not completed
          if (!_isPreAssessmentComplete) ...[
            _buildPreAssessmentPrompt(),
            const SizedBox(height: 24),
          ],

          _buildObjectiveSection(),
          const SizedBox(height: 24),
          _buildSkillsSection(),
          const SizedBox(height: 24),
          _buildCallFlowSection(),
          const SizedBox(height: 32),

          // Start button only shows if pre-assessment is complete
          if (_isPreAssessmentComplete) _buildStartButton(),
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
            'Before handling complex problems, let\'s assess your understanding of different customer service scenarios.',
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
                    const Icon(Icons.support, color: Colors.red, size: 28),
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
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.drag_indicator,
                          color: Colors.orange.shade600,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Drag each complaint to the best response approach.',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Three columns for this assessment
                  _buildHorizontalDropZone('col_urgent'),
                  const SizedBox(height: 20),
                  _buildHorizontalSourceSection(),
                  const SizedBox(height: 20),
                  _buildHorizontalDropZone('col_empathy'),
                  const SizedBox(height: 20),
                  _buildHorizontalDropZone('col_investigate'),
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
                              'Think about what each customer needs most urgently.',
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
                  'Submit Assessment',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }

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
              'Customer Complaints',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
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
                          'All complaints categorized!',
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

  Widget _buildHorizontalDropZone(String columnId) {
    final column = _columns[columnId]!;
    final items = column['items'] as List<Map<String, dynamic>>;
    final columnName = column['name'] as String;

    Color headerColor;
    Color backgroundColor;
    IconData categoryIcon;

    if (columnId == 'col_urgent') {
      headerColor = Colors.red.shade600;
      backgroundColor = Colors.red.shade50;
      categoryIcon = Icons.priority_high;
    } else if (columnId == 'col_empathy') {
      headerColor = Colors.blue.shade600;
      backgroundColor = Colors.blue.shade50;
      categoryIcon = Icons.favorite;
    } else {
      headerColor = Colors.orange.shade600;
      backgroundColor = Colors.orange.shade50;
      categoryIcon = Icons.search;
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
                              'Empty - Drag complaints here',
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
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.flag, color: Colors.red, size: 24),
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
            crossAxisAlignment: CrossAxisAlignment.start, // Add this
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
              // 🔧 FIX: Wrap the text in Expanded to prevent overflow
              Expanded(
                child: Text(
                  introduction['heading'],
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7B1FA2),
                  ),
                  // 🔧 FIX: Add overflow handling
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Hover over each skill to see what advanced techniques are covered.',
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
            crossAxisAlignment: CrossAxisAlignment.start,
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
              // 🔧 FIX: Wrap the text in Expanded to prevent overflow
              Expanded(
                child: Text(
                  callFlow['heading'],
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF388E3C),
                  ),
                  // 🔧 FIX: Add overflow handling
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
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
          icon: const Icon(Icons.support_agent, size: 24),
          label: const Text(
            'Start Advanced Problem Resolution',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            elevation: 4,
            shadowColor: Colors.red.withOpacity(0.4),
          ),
        ),
      ),
    );
  }
}
