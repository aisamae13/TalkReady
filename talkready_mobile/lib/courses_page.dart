import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'firebase_service.dart';
import 'modules/module1.dart';
import 'modules/module2.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const CoursesPage(),
    );
  }
}

class CoursesPage extends StatefulWidget {
  const CoursesPage({super.key});

  @override
  _CoursesPageState createState() => _CoursesPageState();
}

class _CoursesPageState extends State<CoursesPage> with WidgetsBindingObserver {
  final Logger logger = Logger();
  final FirebaseService firebaseService = FirebaseService();
  List<Map<String, dynamic>> beginnerModules = [
    {
      'module': 'Module 1: Basic English Grammar',
      'color': Colors.red,
      'icon': Icons.book,
      'lessons': <Map<String, dynamic>>[
        {'title': 'Lesson 1.1: Nouns and Pronouns', 'completed': false},
        {'title': 'Lesson 1.2: Simple Sentences', 'completed': false},
        {'title': 'Lesson 1.3: Verb and Tenses (Present Simple)', 'completed': false},
      ],
      'isLocked': false,
      'isCompleted': false,
    },
    {
      'module': 'Module 2: Vocabulary & Everyday Conversations',
      'color': Colors.orange,
      'icon': Icons.chat,
      'lessons': <Map<String, dynamic>>[
        {'title': 'Lesson 2.1: Greetings and Introductions', 'completed': false},
        {'title': 'Lesson 2.2: Asking for Information', 'completed': false},
        {'title': 'Lesson 2.3: Numbers and Dates', 'completed': false},
      ],
      'isLocked': true,
      'isCompleted': false,
    },
    {
      'module': 'Module 3: Listening & Speaking Practice',
      'color': Colors.green,
      'icon': Icons.mic,
      'lessons': <Map<String, dynamic>>[
        {'title': 'Lesson 3.1: Listening Comprehension', 'completed': false},
        {'title': 'Lesson 3.2: Speaking Practice', 'completed': false},
      ],
      'isLocked': true,
      'isCompleted': false,
    },
    {
      'module': 'Module 4: Practical Grammar & Customer Service Scenarios',
      'color': Colors.purple,
      'icon': Icons.support_agent,
      'lessons': <Map<String, dynamic>>[
        {'title': 'Lesson 4.1: Asking for Clarification', 'completed': false},
        {'title': 'Lesson 4.2: Providing Solutions', 'completed': false},
      ],
      'isLocked': true,
      'isCompleted': false,
    },
    {
      'module': 'Module 5: Review and Assessment',
      'color': Colors.pink,
      'icon': Icons.edit,
      'lessons': <Map<String, dynamic>>[
        {'title': 'Review: Go through key concepts', 'completed': false},
        {'title': 'Final Test: A combination of grammar, vocabulary, and practical speaking exercises', 'completed': false},
      ],
      'isLocked': true,
      'isCompleted': false,
    },
  ];

  final List<Map<String, dynamic>> intermediateModules = [
    {
      'module': 'Module 6: Intermediate Grammar & Complex Sentences',
      'color': Colors.teal,
      'icon': Icons.library_books,
      'lessons': <Map<String, dynamic>>[
        {'title': 'Lesson 6.1: Complex Sentences', 'completed': false},
        {'title': 'Lesson 6.2: Past and Future Tenses', 'completed': false},
      ],
      'isLocked': true,
      'isCompleted': false,
    },
    {
      'module': 'Module 7: Business Vocabulary & Emails',
      'color': Colors.indigo,
      'icon': Icons.business,
      'lessons': <Map<String, dynamic>>[
        {'title': 'Lesson 7.1: Business Terms', 'completed': false},
        {'title': 'Lesson 7.2: Email Writing', 'completed': false},
      ],
      'isLocked': true,
      'isCompleted': false,
    },
    {
      'module': 'Module 8: Advanced Listening Skills',
      'color': Colors.lime,
      'icon': Icons.headset,
      'lessons': <Map<String, dynamic>>[
        {'title': 'Lesson 8.1: Accents & Dialects', 'completed': false},
        {'title': 'Lesson 8.2: Note-taking', 'completed': false},
      ],
      'isLocked': true,
      'isCompleted': false,
    },
    {
      'module': 'Module 9: Customer Interaction Scenarios',
      'color': Colors.amber,
      'icon': Icons.people,
      'lessons': <Map<String, dynamic>>[
        {'title': 'Lesson 9.1: Handling Complaints', 'completed': false},
        {'title': 'Lesson 9.2: Upselling', 'completed': false},
      ],
      'isLocked': true,
      'isCompleted': false,
    },
    {
      'module': 'Module 10: Intermediate Assessment',
      'color': Colors.cyan,
      'icon': Icons.check_circle,
      'lessons': <Map<String, dynamic>>[
        {'title': 'Review: Intermediate Concepts', 'completed': false},
        {'title': 'Test: Mixed Skills', 'completed': false},
      ],
      'isLocked': true,
      'isCompleted': false,
    },
  ];

  final List<Map<String, dynamic>> advancedModules = [
    {
      'module': 'Module 11: Advanced Grammar & Nuance',
      'color': Colors.deepPurple,
      'icon': Icons.bookmark,
      'lessons': <Map<String, dynamic>>[
        {'title': 'Lesson 11.1: Subtle Grammar', 'completed': false},
        {'title': 'Lesson 11.2: Idioms', 'completed': false},
      ],
      'isLocked': true,
      'isCompleted': false,
    },
    {
      'module': 'Module 12: Professional Presentations',
      'color': Colors.blueGrey,
      'icon': Icons.microwave,
      'lessons': <Map<String, dynamic>>[
        {'title': 'Lesson 12.1: Structuring Talks', 'completed': false},
        {'title': 'Lesson 12.2: Delivery', 'completed': false},
      ],
      'isLocked': true,
      'isCompleted': false,
    },
    {
      'module': 'Module 13: Negotiation Skills',
      'color': Colors.brown,
      'icon': Icons.handshake,
      'lessons': <Map<String, dynamic>>[
        {'title': 'Lesson 13.1: Persuasion', 'completed': false},
        {'title': 'Lesson 13.2: Closing Deals', 'completed': false},
      ],
      'isLocked': true,
      'isCompleted': false,
    },
    {
      'module': 'Module 14: Advanced Call Handling',
      'color': Colors.deepOrange,
      'icon': Icons.phone_callback,
      'lessons': <Map<String, dynamic>>[
        {'title': 'Lesson 14.1: Escalation', 'completed': false},
        {'title': 'Lesson 14.2: De-escalation', 'completed': false},
      ],
      'isLocked': true,
      'isCompleted': false,
    },
    {
      'module': 'Module 15: Advanced Assessment',
      'color': Colors.purpleAccent,
      'icon': Icons.star,
      'lessons': <Map<String, dynamic>>[
        {'title': 'Review: Advanced Concepts', 'completed': false},
        {'title': 'Final Test: Mastery', 'completed': false},
      ],
      'isLocked': true,
      'isCompleted': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkModuleStatus();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkModuleStatus();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkModuleStatus() async {
    if (firebaseService.userId == null) {
      logger.w('No authenticated user, redirecting to LoginPage');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      });
      return;
    }

    try {
      final allModules = [
        ...beginnerModules.asMap().entries.map((e) => {'index': e.key, 'id': 'module${e.key + 1}', 'list': beginnerModules}),
        ...intermediateModules.asMap().entries.map((e) => {'index': e.key, 'id': 'module${e.key + 6}', 'list': intermediateModules}),
        ...advancedModules.asMap().entries.map((e) => {'index': e.key, 'id': 'module${e.key + 11}', 'list': advancedModules}),
      ];

      bool previousModuleCompleted = true;
      for (var module in allModules) {
        final progress = await firebaseService.getModuleProgress(module['id'] as String);
        final lessons = (progress['lessons'] as Map<dynamic, dynamic>?)?.cast<String, dynamic>() ?? {};
        final isCompleted = progress['isCompleted'] as bool? ?? false;
        logger.i('Module ${module['id']}: isCompleted=$isCompleted, lessons=$lessons');

        if (mounted) {
          setState(() {
            final moduleList = module['list'] as List<Map<String, dynamic>>?;
            final moduleIndex = module['index'] as int?;

            if (moduleList != null && moduleIndex != null) {
              final moduleData = moduleList[moduleIndex];
              moduleData['isLocked'] = !previousModuleCompleted;
              moduleData['isCompleted'] = isCompleted;
              for (int i = 0; i < moduleData['lessons'].length; i++) {
                moduleData['lessons'][i]['completed'] = lessons['lesson${i + 1}'] as bool? ?? false;
                logger.d('Lesson ${i + 1} completed: ${moduleData['lessons'][i]['completed']}');
              }
            } else {
              logger.e('Module list or index is null for module ${module['id']}');
            }
          });
        }

        previousModuleCompleted = isCompleted;
      }

      logger.i('Module status updated');
      setState(() {});
    } catch (e) {
      logger.e('Error checking module status: $e');
      if (mounted) {
        setState(() {});
      }
    }
  }

  double _calculateProgress() {
    int totalLessons = 0;
    int completedLessons = 0;

    for (var module in [...beginnerModules, ...intermediateModules, ...advancedModules]) {
      final lessons = module['lessons'] as List<Map<String, dynamic>>;
      totalLessons += lessons.length;
      completedLessons += lessons.where((lesson) => lesson['completed'] as bool).length;
    }

    return totalLessons > 0 ? completedLessons / totalLessons : 0.0;
  }

  String _formatLessonTitle(String lessonId) {
    // Insert \n after colons or at logical breaks for wrapping
    return lessonId.replaceAll(': ', ':\n').replaceAll(' - ', '\n');
  }

  Future<void> _showActivityLog(String moduleId, String lessonId, Color moduleColor) async {
    try {
      logger.i('Fetching activity logs for moduleId: $moduleId, lessonId: $lessonId');
      final activitySnapshots = await firebaseService.getActivityLogs(moduleId, lessonId);
      logger.i('Found ${activitySnapshots.docs.length} activity logs for $lessonId');

      showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8,
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
              maxWidth: 400,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white,
                  moduleColor.withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  decoration: BoxDecoration(
                    color: moduleColor.withOpacity(0.9),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.history,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Activity Log for\n${_formatLessonTitle(lessonId)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          softWrap: true,
                          maxLines: null,
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: activitySnapshots.docs.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Text(
                              'No activity logs found for this lesson.',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          child: Column(
                            children: activitySnapshots.docs.map((doc) {
                              final data = doc.data() as Map<String, dynamic>? ?? {};
                              final score = data['score'] as int? ?? 0;
                              final totalScore = data['totalScore'] as int? ?? 8;
                              final attemptNumber = data['attemptNumber'] as int? ?? 0;
                              final timeSpent = data['timeSpent'] as int? ?? 0;
                              final timestamp = data['attemptTimestamp']?.toDate() ?? DateTime.now();
                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: moduleColor.withOpacity(0.1),
                                      child: Text(
                                        '#$attemptNumber',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: moduleColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Score: $score/$totalScore',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: moduleColor,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Time: ${timeSpent}s | ${timestamp.day}/${timestamp.month}/${timestamp.year}',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                  ),
                  child: Center(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: moduleColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        elevation: 2,
                      ),
                      child: const Text(
                        'Close',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      logger.e('Error fetching activity logs for $moduleId/$lessonId: $e');
      showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white,
                  moduleColor.withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Error',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: moduleColor,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Failed to load activity logs. Please try again later.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: moduleColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    elevation: 2,
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    double progress = _calculateProgress();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Courses'),
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF00568D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            logger.i('Back button pressed on CoursesPage');
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey[300],
                  color: const Color(0xFF00568D),
                  minHeight: 8,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Beginner',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Start your journey to master English communication skills step-by-step.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 16),
                _buildModuleSection('Beginner', beginnerModules),
                const SizedBox(height: 16),
                const Text(
                  'Intermediate',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Next: Intermediate - ${beginnerModules.every((m) => m['isCompleted']) ? 'Unlocked' : 'Locked'}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                _buildModuleSection('Intermediate', intermediateModules),
                const SizedBox(height: 16),
                const Text(
                  'Advanced',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Next: Advanced - ${intermediateModules.every((m) => m['isCompleted']) ? 'Unlocked' : 'Locked'}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                _buildModuleSection('Advanced', advancedModules),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModuleSection(String level, List<Map<String, dynamic>> modules) {
    return Column(
      children: modules.asMap().entries.map((entry) {
        final module = entry.value;
        final bool isCompleted = module['isCompleted'] as bool;
        final bool isLocked = module['isLocked'] as bool;
        final lessons = module['lessons'] as List<Map<String, dynamic>>;
        final bool isInProgress = !isLocked && !isCompleted && lessons.any((lesson) => lesson['completed'] as bool);
        final moduleId = 'module${entry.key + (level == 'Beginner' ? 1 : level == 'Intermediate' ? 6 : 11)}';

        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Card(
            elevation: 5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: (module['color'] as Color).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [
                    Colors.white,
                    (module['color'] as Color).withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          module['icon'] as IconData,
                          color: module['color'] as Color,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            module['module'] as String,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: module['color'] as Color,
                            ),
                          ),
                        ),
                        if (isLocked)
                          const Icon(
                            Icons.lock,
                            color: Colors.grey,
                            size: 20,
                          ),
                        if (isCompleted)
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 20,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (!isLocked) ...[
                      ...lessons.asMap().entries.map<Widget>((entry) {
                        final lesson = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '• ',
                                style: TextStyle(fontSize: 16),
                              ),
                              Expanded(
                                child: Text(
                                  lesson['title'] as String,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: (lesson['completed'] as bool) ? Colors.green : Colors.black,
                                  ),
                                ),
                              ),
                              if (lesson['completed'] as bool)
                                const Icon(
                                  Icons.check,
                                  color: Colors.green,
                                  size: 16,
                                ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.history, size: 16),
                                color: const Color(0xFF00568D),
                                onPressed: () async {
                                  await _showActivityLog(moduleId, lesson['title'], module['color'] as Color);
                                },
                                tooltip: 'View Activity Log',
                              ),
                            ],
                          ),
                        );
                      }),
                    ] else ...[
                      const Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Locked - Complete previous module to unlock',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isLocked
                            ? null
                            : () async {
                                logger.i('Navigating to ${module['module']}');
                                Widget destination;
                                if (module['module'].contains('Module 1')) {
                                  destination = const Module1Page();
                                } else if (module['module'].contains('Module 2')) {
                                  destination = const Module2Page();
                                } else {
                                  destination = Scaffold(
                                    appBar: AppBar(
                                      title: Text(module['module'] as String),
                                    ),
                                    body: Center(
                                      child: Text('${module['module']} is unlocked but not implemented yet.'),
                                    ),
                                  );
                                }
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => destination),
                                );
                                await _checkModuleStatus();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isLocked
                              ? Colors.grey[400]
                              : isCompleted
                                  ? Colors.green
                                  : isInProgress
                                      ? Colors.orange
                                      : const Color(0xFF00568D),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: isLocked ? 0 : 5,
                          shadowColor: Colors.black.withOpacity(0.3),
                        ),
                        child: Tooltip(
                          message: isLocked ? 'Complete the previous module to unlock' : '',
                          child: Text(
                            isLocked
                                ? 'Locked'
                                : isCompleted
                                    ? 'Completed ${module['module'].split(':')[0]}'
                                    : isInProgress
                                        ? 'In Progress'
                                        : 'Go to ${module['module'].split(':')[0]}',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}