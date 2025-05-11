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

class _CoursesPageState extends State<CoursesPage> {
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
    _checkModuleStatus();
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
      // Load progress for all modules
      final allModules = [
        ...beginnerModules.asMap().entries.map((e) => {'index': e.key, 'id': 'module${e.key + 1}', 'list': beginnerModules}),
        ...intermediateModules.asMap().entries.map((e) => {'index': e.key, 'id': 'module${e.key + 6}', 'list': intermediateModules}),
        ...advancedModules.asMap().entries.map((e) => {'index': e.key, 'id': 'module${e.key + 11}', 'list': advancedModules}),
      ];

      bool previousModuleCompleted = true; // Module 1 is always unlocked
      for (var module in allModules) {
        final progress = await firebaseService.getModuleProgress(module['id'] as String);
        // Convert lessons to Map<String, dynamic> to handle Firestore's dynamic map
        final lessons = (progress['lessons'] as Map<dynamic, dynamic>?)?.cast<String, dynamic>() ?? {};
        final isCompleted = progress['isCompleted'] as bool? ?? false;

        if (mounted) {
          setState(() {
            final moduleData = (module['list'] as List<Map<String, dynamic>>)[module['index'] as int];
            moduleData['isLocked'] = !previousModuleCompleted;
            moduleData['isCompleted'] = isCompleted;
            for (int i = 0; i < moduleData['lessons'].length; i++) {
              moduleData['lessons'][i]['completed'] = lessons['lesson${i + 1}'] as bool? ?? false;
            }
          });
        }

        previousModuleCompleted = isCompleted;
      }

      logger.i('Module status updated');
    } catch (e) {
      logger.e('Error checking module status: $e');
      if (mounted) {
        setState(() {
          // Optionally display an error message
        });
      }
    }
  }

  double _calculateProgress() {
    int totalLessons = 0;
    int completedLessons = 0;

    for (var module in beginnerModules) {
      final lessons = module['lessons'] as List<Map<String, dynamic>>;
      totalLessons += lessons.length;
      completedLessons += lessons.where((lesson) => lesson['completed'] as bool).length;
    }

    return totalLessons > 0 ? completedLessons / totalLessons : 0.0;
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
                        if (module['isLocked'] as bool)
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
                    if (!(module['isLocked'] as bool)) ...[
                      ...(module['lessons'] as List<Map<String, dynamic>>).asMap().entries.map<Widget>((entry) {
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
                            ],
                          ),
                        );
                      }).toList(),
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
                        onPressed: module['isLocked'] as bool
                            ? null
                            : () {
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
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => destination),
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: module['isLocked'] as bool
                              ? Colors.grey
                              : isCompleted
                                  ? Colors.green
                                  : const Color(0xFF00568D),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 5,
                          shadowColor: Colors.black.withOpacity(0.3),
                        ),
                        child: Text(
                          module['isLocked'] as bool
                              ? 'Locked'
                              : isCompleted
                                  ? 'Completed ${module['module'].split(':')[0]}'
                                  : 'Go to ${module['module'].split(':')[0]}',
                          style: const TextStyle(fontSize: 16),
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