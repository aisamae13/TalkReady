// lib/modules/module1.dart
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../services/unified_progress_service.dart';

class Module1Page extends StatefulWidget {
  const Module1Page({super.key});
  @override
  State<Module1Page> createState() => Module1PageState();
}

class Module1PageState extends State<Module1Page> {
  final Logger _logger = Logger();
  final UnifiedProgressService _progressService = UnifiedProgressService();

  bool _isLoading = true;
  Map<String, dynamic> _moduleProgress = {};
  Map<String, List<Map<String, dynamic>>> _lessonAttempts = {};
  List<Map<String, dynamic>> _assessmentAttempts = [];
  bool _allLessonsCompleted = false;

  final List<Map<String, dynamic>> _lessonConfigs = [
    {
      'id': 'Lesson 1.1',
      'title': 'Lesson 1.1: Nouns and Pronouns',
      'description':
          'Learn about nouns and pronouns in customer service context.',
      'color': const Color(0xFFFF6347),
      'firestoreId': 'Lesson-1-1',
      'totalQuestions': 7,
    },
    {
      'id': 'Lesson 1.2',
      'title': 'Lesson 1.2: Simple Sentences',
      'description': 'Master basic sentence structure for clear communication.',
      'color': const Color(0xFFFF6347),
      'firestoreId': 'Lesson-1-2',
      'totalQuestions': 5,
    },
    {
      'id': 'Lesson 1.3',
      'title': 'Lesson 1.3: Verb and Tenses (Present Simple)',
      'description': 'Understand present tense usage in professional settings.',
      'color': const Color(0xFFFF6347),
      'firestoreId': 'Lesson-1-3',
      'totalQuestions': 11,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadModuleProgress();
  }

  Future<void> _loadModuleProgress() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _progressService.getModuleProgress('module1'),
        _progressService.getModuleAssessmentAttempts('module_1_final'),
        ..._lessonConfigs.map(
          (c) => _progressService.getLessonAttempts(c['firestoreId'] as String),
        ),
      ]);

      final moduleProgress = results[0] as Map<String, dynamic>;
      final assessmentAttempts = results[1] as List<Map<String, dynamic>>;

      Map<String, List<Map<String, dynamic>>> lessonAttempts = {};
      for (int i = 0; i < _lessonConfigs.length; i++) {
        final lessonId = _lessonConfigs[i]['firestoreId'] as String;
        lessonAttempts[lessonId] = results[i + 2] as List<Map<String, dynamic>>;
      }

      final allDone = _lessonConfigs.every(
        (c) => (lessonAttempts[c['firestoreId']]?.isNotEmpty ?? false),
      );

      if (mounted) {
        setState(() {
          _moduleProgress = moduleProgress;
          _assessmentAttempts = assessmentAttempts;
          _lessonAttempts = lessonAttempts;
          _allLessonsCompleted = allDone;
          _isLoading = false;
        });
      }
    } catch (e) {
      _logger.e('Error loading Module 1 progress: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _isLessonUnlocked(int lessonIndex) {
    if (lessonIndex == 0) return true;
    final prevLessonId =
        _lessonConfigs[lessonIndex - 1]['firestoreId'] as String;
    return (_lessonAttempts[prevLessonId]?.isNotEmpty ?? false);
  }

  void _showAssessmentLog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 500, maxWidth: 400),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6347),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.assessment, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Assessment Log: Module 1',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _assessmentAttempts.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.assignment_outlined,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No assessment attempts found.',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _assessmentAttempts.length,
                        itemBuilder: (context, index) {
                          final attempt = _assessmentAttempts[index];
                          final timestamp =
                              attempt['attemptTimestamp'] as DateTime?;
                          final score = attempt['score'] as int? ?? 0;
                          final maxScore = attempt['maxScore'] as int? ?? 100;
                          final percentage = maxScore > 0
                              ? ((score / maxScore) * 100).round()
                              : 0;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: percentage >= 70
                                    ? Colors.green
                                    : percentage >= 50
                                    ? Colors.orange
                                    : Colors.red,
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                'Attempt ${index + 1}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Score: $score / $maxScore ($percentage%)',
                                  ),
                                  if (timestamp != null)
                                    Text(
                                      'Date: ${timestamp.toLocal().toString().substring(0, 16)}',
                                      style: const TextStyle(fontSize: 12),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Module 1',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFFF6347),
        elevation: 4,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFFFF6347)),
                  SizedBox(height: 16),
                  Text('Loading module progress...'),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadModuleProgress,
              color: const Color(0xFFFF6347),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildModuleHeader(),
                    const SizedBox(height: 24),
                    _buildLessonsSection(),
                    _buildAssessmentCard(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildModuleHeader() {
    final completed = _lessonConfigs
        .where((c) => (_lessonAttempts[c['firestoreId']]?.isNotEmpty ?? false))
        .length;
    final total = _lessonConfigs.length;
    final progress = total > 0 ? completed / total : 0.0;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFFFF6347), const Color(0xFFFF4500)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6347).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.school,
                    size: 32,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Module 1',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Basic English Grammar',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Build a solid foundation in English grammar essentials including nouns, pronouns, sentence structure, and present tense verbs for professional communication.',
              style: TextStyle(fontSize: 16, color: Colors.white, height: 1.4),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Progress',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$completed of $total lessons completed',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.menu_book, color: Colors.grey[700], size: 24),
            const SizedBox(width: 8),
            Text(
              'Lessons',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ..._lessonConfigs.asMap().entries.map(
          (e) => _buildLessonCard(e.value, e.key),
        ),
      ],
    );
  }

  Widget _buildLessonCard(Map<String, dynamic> config, int index) {
    final attempts = _lessonAttempts[config['firestoreId']] ?? [];
    final isCompleted = attempts.isNotEmpty;
    final isUnlocked = _isLessonUnlocked(index);
    final lastScore = isCompleted ? attempts.last['score'] as int? ?? 0 : 0;

    return Opacity(
      opacity: isUnlocked ? 1.0 : 0.6,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isCompleted
                  ? const Color(0xFFFF6347).withOpacity(0.3)
                  : Colors.grey.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: isUnlocked ? () => _navigateToLesson(config['id']) : null,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? const Color(0xFFFF6347)
                          : (isUnlocked
                                ? const Color(0xFFFF6347).withOpacity(0.1)
                                : Colors.grey.withOpacity(0.1)),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: isCompleted
                            ? const Color(0xFFFF6347)
                            : (isUnlocked
                                  ? const Color(0xFFFF6347).withOpacity(0.3)
                                  : Colors.grey.withOpacity(0.3)),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      isCompleted
                          ? Icons.check_circle
                          : (isUnlocked
                                ? Icons.play_circle_outline
                                : Icons.lock),
                      color: isCompleted
                          ? Colors.white
                          : (isUnlocked
                                ? const Color(0xFFFF6347)
                                : Colors.grey),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          config['title'],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          config['description'],
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            height: 1.3,
                          ),
                        ),
                        if (isUnlocked && isCompleted) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6347).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Attempts: ${attempts.length} | Last Score: $lastScore / ${config['totalQuestions']}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFFFF6347),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (isUnlocked)
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.grey[400],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAssessmentCard() {
    final isAssessmentTaken = _assessmentAttempts.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(top: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _allLessonsCompleted
                ? const Color(0xFFFF6347).withOpacity(0.2)
                : Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Card(
        elevation: 0,
        color: _allLessonsCompleted
            ? const Color(0xFFFF6347).withOpacity(0.05)
            : Colors.grey[50],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: _allLessonsCompleted
                ? const Color(0xFFFF6347).withOpacity(0.3)
                : Colors.grey.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _allLessonsCompleted
                          ? const Color(0xFFFF6347).withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.assignment_turned_in,
                      color: _allLessonsCompleted
                          ? const Color(0xFFFF6347)
                          : Colors.grey,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Module 1 Final Assessment',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _allLessonsCompleted
                              ? 'Test your grammar knowledge'
                              : 'Complete all lessons to unlock',
                          style: TextStyle(
                            color: _allLessonsCompleted
                                ? const Color(0xFFFF6347)
                                : Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!_allLessonsCompleted)
                    Icon(Icons.lock, color: Colors.grey[400]),
                ],
              ),
              const SizedBox(height: 16),
              if (_allLessonsCompleted)
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pushNamed(
                          context,
                          '/assessment',
                          arguments: 'module_1_final',
                        ),
                        icon: Icon(
                          isAssessmentTaken ? Icons.refresh : Icons.play_arrow,
                          size: 20,
                        ),
                        label: Text(
                          isAssessmentTaken
                              ? 'Practice Again'
                              : 'Take Assessment',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isAssessmentTaken
                              ? Colors.blue
                              : const Color(0xFFFF6347),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                    if (isAssessmentTaken) ...[
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: _showAssessmentLog,
                        icon: const Icon(Icons.history, size: 18),
                        label: const Text('View Log'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFF6347),
                          side: const BorderSide(color: Color(0xFFFF6347)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToLesson(String lessonId) {
    String? routeName;
    switch (lessonId) {
      case 'Lesson 1.1':
        routeName = '/lesson1_1';
        break;
      case 'Lesson 1.2':
        routeName = '/lesson1_2';
        break;
      case 'Lesson 1.3':
        routeName = '/lesson1_3';
        break;
    }
    if (routeName != null) Navigator.pushNamed(context, routeName);
  }
}
