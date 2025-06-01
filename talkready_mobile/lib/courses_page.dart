import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'firebase_service.dart';
import 'modules/module1.dart';
import 'modules/module2.dart';
import 'modules/module3.dart'; // Added import for Module3Page
import 'modules/module4.dart'; // <-- Add this import
import 'modules/module5.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:talkready_mobile/custom_animated_bottom_bar.dart';
import 'homepage.dart';
import 'journal/journal_page.dart';
import 'progress_page.dart';
import 'profile.dart';

// Helper function for creating a slide page route
Route _createSlidingPageRoute({
  required Widget page,
  required int newIndex,
  required int oldIndex,
  required Duration duration, // duration will be ignored
}) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return child; // Return child directly for no animation
    },
    transitionDuration: Duration.zero, // Instant transition
    reverseTransitionDuration: Duration.zero, // Instant reverse transition
  );
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
        {
          'title': 'Lesson 1.1: Nouns and Pronouns',
          'completed': false,
          'firebaseKey': 'lesson1'
        },
        {
          'title': 'Lesson 1.2: Simple Sentences',
          'completed': false,
          'firebaseKey': 'lesson2'
        },
        {
          'title': 'Lesson 1.3: Verb and Tenses (Present Simple)',
          'completed': false,
          'firebaseKey': 'lesson3'
        },
      ],
      'isLocked': false,
      'isCompleted': false,
    },
    {
      'module': 'Module 2: Vocabulary & Everyday Conversations',
      'color': Colors.orange,
      'icon': Icons.chat,
      'lessons': <Map<String, dynamic>>[
        {
          'title': 'Lesson 2.1: Greetings and Introductions',
          'completed': false,
          'firebaseKey': 'lesson1'
        },
        {
          'title': 'Lesson 2.2: Asking for Information',
          'completed': false,
          'firebaseKey': 'lesson2'
        },
        {
          'title': 'Lesson 2.3: Numbers and Dates',
          'completed': false,
          'firebaseKey': 'lesson3'
        },
      ],
      'isLocked': true,
      'isCompleted': false,
    },
    {
      'module': 'Module 3: Listening & Speaking Practice',
      'color': Colors.green,
      'icon': Icons.mic,
      'lessons': <Map<String, dynamic>>[
        {
          'title': 'Lesson 3.1: Listening Comprehension',
          'completed': false,
          'firebaseKey': 'lesson1'
        },
        {
          'title': 'Lesson 3.2: Speaking Practice',
          'completed': false,
          'firebaseKey': 'lesson2'
        },
      ],
      'isLocked': true,
      'isCompleted': false,
    },
    {
      'module': 'Module 4: Practical Grammar & Customer Service Scenarios',
      'color': Colors.purple,
      'icon': Icons.support_agent,
      'lessons': <Map<String, dynamic>>[
        {
          'title': 'Lesson 4.1: Asking for Clarification',
          'completed': false,
          'firebaseKey': 'lesson1'
        },
        {
          'title': 'Lesson 4.2: Providing Solutions',
          'completed': false,
          'firebaseKey': 'lesson2'
        },
      ],
      'isLocked': true,
      'isCompleted': false,
    },
    // Module 5 was here, now moved to intermediateModules
  ];

  // Module 5 is now in intermediateModules
  final List<Map<String, dynamic>> intermediateModules = [
    {
      'module': 'Module 5: Basic Call Simulation Practice',
      'color': Colors.pink,
      'icon': Icons.edit,
      'lessons': <Map<String, dynamic>>[
        {
          'title': 'Lesson 5.1: Basic Simulation - Info Request',
          'completed': false,
          'firebaseKey': 'lesson1'
        },
        {
          'title':
              'Final Test: Lesson 5.2 Basic Simulation - Action Confirmations',
          'completed': false,
          'firebaseKey': 'lesson2'
        },
      ],
      'isLocked': true, // This will be unlocked based on Module 4 completion
      'isCompleted': false,
    },
  ];
  final List<Map<String, dynamic>> advancedModules = [];

  int _selectedIndex = 1; // Courses is index 1

  List<Map<String, dynamic>> _getAllModuleEntries() {
    final List<Map<String, dynamic>> allEntries = [];
    int globalModuleIndex = 1;

    void addModulesToList(List<Map<String, dynamic>> moduleList) {
      for (int i = 0; i < moduleList.length; i++) {
        allEntries.add({
          'config': moduleList[i],
          'id': 'module$globalModuleIndex',
          'listRef': moduleList,
          'originalIndex': i,
        });
        globalModuleIndex++;
      }
    }

    addModulesToList(beginnerModules);
    addModulesToList(intermediateModules);
    addModulesToList(advancedModules);
    return allEntries;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkModuleStatus();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      logger.i("App resumed, re-checking module status.");
      _checkModuleStatus();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkModuleStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      logger.w('No authenticated user, cannot check module status.');
      return;
    }
    logger.i('Starting _checkModuleStatus for user ${user.uid}');

    try {
      final List<Map<String, dynamic>> allModuleConfigurations =
          _getAllModuleEntries();
      bool previousModuleWasCompletedAndUnlocked = true;
      logger.d(
          'Initial previousModuleWasCompletedAndUnlocked: $previousModuleWasCompletedAndUnlocked');

      for (var moduleEntry in allModuleConfigurations) {
        final moduleConfig = moduleEntry['config'] as Map<String, dynamic>;
        final moduleId = moduleEntry['id'] as String;
        final List<Map<String, dynamic>> moduleListRef =
            moduleEntry['listRef'] as List<Map<String, dynamic>>;
        final int originalIndexInList = moduleEntry['originalIndex'] as int;

        logger.i('Processing $moduleId...');
        final progress = await firebaseService.getModuleProgress(moduleId);
        final lessonsFromFirestore =
            (progress['lessons'] as Map<dynamic, dynamic>?)
                    ?.cast<String, bool>() ??
                {};
        final isCompletedFromFirestore =
            progress['isCompleted'] as bool? ?? false;
        bool isUnlockedFromFirestore =
            progress['isUnlocked'] as bool? ?? (moduleId == 'module1');

        logger.d(
            '$moduleId - Firestore Data: isCompleted=$isCompletedFromFirestore, isUnlocked=$isUnlockedFromFirestore, lessons=${lessonsFromFirestore.entries.where((e) => e.value == true).length}/${lessonsFromFirestore.length}');
        logger.d(
            '$moduleId - Before lock check: previousModuleWasCompletedAndUnlocked=$previousModuleWasCompletedAndUnlocked');

        bool currentModuleShouldBeLocked;
        if (moduleId == 'module1') {
          currentModuleShouldBeLocked = !isUnlockedFromFirestore;
          logger.d(
              '$moduleId (module1) - currentModuleShouldBeLocked based on its own isUnlocked: $currentModuleShouldBeLocked');
        } else {
          currentModuleShouldBeLocked = !previousModuleWasCompletedAndUnlocked;
          logger.d(
              '$moduleId - currentModuleShouldBeLocked based on previous: $currentModuleShouldBeLocked');
        }

        if (!currentModuleShouldBeLocked && !isUnlockedFromFirestore) {
          logger.i(
              'Condition MET to unlock $moduleId: currentModuleShouldBeLocked=false, isUnlockedFromFirestore=false. Calling unlockModule...');
          await firebaseService.unlockModule(moduleId);
          isUnlockedFromFirestore = true;
          logger.i(
              '$moduleId has been unlocked. isUnlockedFromFirestore is now true for this iteration.');
        } else {
          if (currentModuleShouldBeLocked) {
            logger.d(
                'Condition NOT MET to unlock $moduleId because currentModuleShouldBeLocked is true.');
          } else if (isUnlockedFromFirestore) {
            logger.d(
                'Condition NOT MET to unlock $moduleId because isUnlockedFromFirestore is already true.');
          }
        }

        if (mounted) {
          setState(() {
            final moduleToUpdate = moduleListRef[originalIndexInList];
            moduleToUpdate['isLocked'] = currentModuleShouldBeLocked;
            moduleToUpdate['isCompleted'] = isCompletedFromFirestore;
            logger.d(
                '$moduleId - UI Update: isLocked=${moduleToUpdate['isLocked']}, isCompleted (Firestore)=${moduleToUpdate['isCompleted']}');

            final uiLessons =
                moduleToUpdate['lessons'] as List<Map<String, dynamic>>;
            for (int i = 0; i < uiLessons.length; i++) {
              String firestoreLessonKey =
                  uiLessons[i]['firebaseKey'] as String? ?? 'lesson${i + 1}';
              uiLessons[i]['completed'] =
                  lessonsFromFirestore[firestoreLessonKey] ?? false;
            }
          });
        }
        previousModuleWasCompletedAndUnlocked =
            isCompletedFromFirestore && isUnlockedFromFirestore;
        logger.i(
            '$moduleId - At end of its processing, setting previousModuleWasCompletedAndUnlocked for NEXT module to: $previousModuleWasCompletedAndUnlocked (isCompletedFromFirestore=$isCompletedFromFirestore && isUnlockedFromFirestore=$isUnlockedFromFirestore)');
      }

      logger.i('Module status and unlock check complete.');
      if (mounted) {
        setState(() {});
      }
    } catch (e, stacktrace) {
      logger.e('Error checking module status: $e',
          error: e, stackTrace: stacktrace);
    }
  }

  double _calculateProgress() {
    int totalLessons = 0;
    int completedLessons = 0;

    for (var moduleList in [
      beginnerModules,
      intermediateModules,
      advancedModules
    ]) {
      for (var module in moduleList) {
        final lessons = module['lessons'] as List<Map<String, dynamic>>;
        totalLessons += lessons.length;
        completedLessons += lessons
            .where((lesson) => lesson['completed'] as bool? ?? false)
            .length;
      }
    }
    return totalLessons > 0 ? completedLessons / totalLessons : 0.0;
  }

  String _formatLessonTitle(String lessonId) {
    return lessonId.replaceAll(': ', ':\n').replaceAll(' - ', '\n');
  }

  Future<void> _showActivityLog(
      String moduleId, String lessonTitleForLog, Color moduleColor) async {
    try {
      logger.i(
          'Fetching activity logs for moduleId: $moduleId, lessonTitleForLog: $lessonTitleForLog');
      final List<Map<String, dynamic>> activityLogs =
          await firebaseService.getActivityLogs(moduleId, lessonTitleForLog);
      logger.i(
          'Found ${activityLogs.length} activity logs for $lessonTitleForLog');

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
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(16)),
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
                          'Activity Log for\n${_formatLessonTitle(lessonTitleForLog)}',
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
                  child: activityLogs.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Text(
                              'No activity logs found for this lesson.',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black54,
                                fontStyle: FontStyle.italic,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          child: Column(
                            children: activityLogs.map((logData) {
                              final data = logData;
                              final score = data['score'] as int? ?? 0;
                              final totalScore =
                                  data['totalScore'] as int? ?? 8;
                              final attemptNumber =
                                  data['attemptNumber'] as int? ?? 0;
                              final timeSpent = data['timeSpent'] as int? ?? 0;
                              final timestampValue = data['attemptTimestamp'];
                              DateTime timestamp;
                              if (timestampValue is Timestamp) {
                                timestamp = timestampValue.toDate();
                              } else if (timestampValue is String) {
                                timestamp = DateTime.tryParse(timestampValue) ??
                                    DateTime.now();
                              } else {
                                timestamp = DateTime.now();
                              }

                              return Container(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
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
                                      backgroundColor:
                                          moduleColor.withOpacity(0.1),
                                      child: Text(
                                        '#$attemptNumber', // <-- This already shows the attempt number
                                        style: TextStyle(
                                          color: moduleColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('Attempt: $attemptNumber',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight
                                                      .bold)), // <-- Add this line for clarity
                                          Text('Score: $score / $totalScore',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                          Text(
                                              'Time Spent: $timeSpent seconds'),
                                          Text(
                                              'Date: ${timestamp.toLocal().toString().substring(0, 16)}'),
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
                    borderRadius:
                        BorderRadius.vertical(bottom: Radius.circular(16)),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
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
    } catch (e, stacktrace) {
      logger.e(
          'Error showing activity logs for $moduleId/$lessonTitleForLog: $e',
          error: e,
          stackTrace: stacktrace);
      if (mounted) {
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
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
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;

    final int oldNavIndex = _selectedIndex;
    setState(() {
      _selectedIndex = index;
    });

    Widget nextPage;
    switch (index) {
      case 0:
        nextPage = const HomePage();
        break;
      case 1:
        // Already on CoursesPage
        nextPage =
            const CoursesPage(); // Should not happen if check above is active
        break;
      case 2:
        nextPage = const JournalPage();
        break;
      case 3:
        nextPage = const ProgressTrackerPage();
        break;
      case 4:
        nextPage = const ProfilePage();
        break;
      default:
        return;
    }

    Navigator.pushReplacement(
      context,
      _createSlidingPageRoute(
        page: nextPage,
        newIndex: index,
        oldIndex: oldNavIndex,
        duration:
            const Duration(milliseconds: 300), // This duration is now ignored
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double progress = _calculateProgress();

    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Courses', style: TextStyle(color: Color(0xFF00568D))),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF00568D),
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ScrollConfiguration(
            behavior: const ScrollBehavior().copyWith(overscroll: false),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8.0, vertical: 8.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.grey[300],
                        color: const Color(0xFF2973B2),
                        minHeight: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Beginner',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00568D),
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
                  _buildModuleSection('Beginner', beginnerModules, 1),

                  // Conditionally display Intermediate section if there are modules
                  if (intermediateModules.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Intermediate',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00568D),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Challenge yourself with comprehensive reviews and assessments.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildModuleSection('Intermediate', intermediateModules,
                        beginnerModules.length + 1),
                  ],
                  // Advanced section (if any in the future)
                  if (advancedModules.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Advanced',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00568D),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Master advanced concepts and refine your skills.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildModuleSection(
                        'Advanced',
                        advancedModules,
                        beginnerModules.length +
                            intermediateModules.length +
                            1),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: AnimatedBottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: [
          CustomBottomNavItem(icon: Icons.home, label: 'Home'),
          CustomBottomNavItem(icon: Icons.book, label: 'Courses'),
          CustomBottomNavItem(icon: Icons.library_books, label: 'Journal'),
          CustomBottomNavItem(icon: Icons.trending_up, label: 'Progress'),
          CustomBottomNavItem(icon: Icons.person, label: 'Profile'),
        ],
        activeColor: Colors.white,
        inactiveColor: Colors.grey[600]!,
        notchColor: Colors.blue,
        backgroundColor: Colors.white,
        selectedIconSize: 28.0,
        iconSize: 25.0,
        barHeight: 55,
        selectedIconPadding: 10,
        animationDuration: const Duration(milliseconds: 300),
        customNotchWidthFactor: 1.8,
      ),
    );
  }

  Widget _buildModuleSection(String level,
      List<Map<String, dynamic>> modulesInLevel, int globalStartIndexOffset) {
    return Column(
      children: modulesInLevel.asMap().entries.map((entry) {
        final localIndex = entry.key;
        final moduleData = entry.value;
        final bool isLocked = moduleData['isLocked'] as bool? ?? true;
        final lessons = moduleData['lessons'] as List<Map<String, dynamic>>;
        final bool allLessonsLocallyCompleted =
            lessons.every((lesson) => lesson['completed'] as bool? ?? false);
        final bool isInProgress = !isLocked &&
            !allLessonsLocallyCompleted &&
            lessons.any((lesson) => lesson['completed'] as bool? ?? false);

        final moduleId = 'module${globalStartIndexOffset + localIndex}';

        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
              side: BorderSide(
                color: (moduleData['color'] as Color).withOpacity(0.5),
                width: 1,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                gradient: LinearGradient(
                  colors: [
                    Colors.white,
                    (moduleData['color'] as Color).withOpacity(0.05),
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
                          moduleData['icon'] as IconData,
                          color: moduleData['color'] as Color,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            moduleData['module'] as String,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: moduleData['color'] as Color,
                            ),
                          ),
                        ),
                        if (isLocked)
                          const Icon(
                            Icons.lock_outline,
                            color: Colors.grey,
                            size: 24,
                          ),
                        if (!isLocked && allLessonsLocallyCompleted)
                          Icon(
                            Icons.check_circle_outline,
                            color: Colors.green[600],
                            size: 24,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (!isLocked) ...[
                      ...lessons.asMap().entries.map<Widget>((lessonEntry) {
                        final lesson = lessonEntry.value;
                        final lessonTitle = lesson['title'] as String;
                        final lessonFirebaseKey =
                            lesson['firebaseKey'] as String? ??
                                'lesson${lessonEntry.key + 1}';
                        String lessonTitleForLog = lessonTitle;

                        return Padding(
                          padding:
                              const EdgeInsets.only(bottom: 8.0, left: 8.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Icon(
                                (lesson['completed'] as bool? ?? false)
                                    ? Icons.check_box_outlined
                                    : Icons.check_box_outline_blank,
                                color: (lesson['completed'] as bool? ?? false)
                                    ? Colors.green
                                    : Colors.grey,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    // Navigation logic for lesson revisit
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) {
                                          if (moduleId == 'module1') {
                                            return Module1Page(
                                                targetLessonKey:
                                                    lessonFirebaseKey);
                                          } else if (moduleId == 'module2') {
                                            return Module2Page(
                                                targetLessonKey:
                                                    lessonFirebaseKey);
                                          } else if (moduleId == 'module3') {
                                            return Module3Page(
                                                targetLessonKey:
                                                    lessonFirebaseKey);
                                          } else if (moduleId == 'module4') {
                                            return Module4Page(
                                                targetLessonKey:
                                                    lessonFirebaseKey);
                                          } else if (moduleId == 'module5') {
                                            return Module5Page(
                                                targetLessonKey:
                                                    lessonFirebaseKey);
                                          } else {
                                            return Scaffold(
                                                body: Center(
                                                    child: Text(
                                                        'Module $moduleId not implemented')));
                                          }
                                        },
                                      ),
                                    );
                                  },
                                  child: Text(
                                    lessonTitle,
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: Colors.black87,
                                      decoration:
                                          (lesson['completed'] as bool? ??
                                                  false)
                                              ? TextDecoration.lineThrough
                                              : TextDecoration.none,
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon:
                                    Icon(Icons.history_edu_outlined, size: 20),
                                color: const Color(0xFF00568D).withOpacity(0.8),
                                onPressed: () async {
                                  await _showActivityLog(
                                      moduleId,
                                      lessonTitleForLog,
                                      moduleData['color'] as Color);
                                },
                                tooltip: 'View Activity Log',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        );
                      }),
                    ] else ...[
                      const Padding(
                        padding: EdgeInsets.only(top: 8.0, left: 8.0),
                        child: Text(
                          'Locked - Complete previous module to unlock.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: Icon(isLocked
                            ? Icons.lock_outline
                            : allLessonsLocallyCompleted
                                ? Icons.check_circle_outline
                                : isInProgress
                                    ? Icons.play_circle_outline
                                    : Icons.play_arrow_outlined),
                        label: Text(
                          isLocked
                              ? 'Module Locked'
                              : allLessonsLocallyCompleted
                                  ? 'Module Completed'
                                  : isInProgress
                                      ? 'Continue Module'
                                      : 'Start Module',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        // Disable the button if the module is completed
                        onPressed: isLocked || allLessonsLocallyCompleted
                            ? null
                            : () async {
                                logger.i(
                                    'Navigating to ${moduleData['module']} (ID: $moduleId) - Go to Module button');
                                Widget destination;
                                switch (moduleId) {
                                  case 'module1':
                                    destination = const Module1Page();
                                    break;
                                  case 'module2':
                                    destination = const Module2Page();
                                    break;
                                  case 'module3':
                                    destination = const Module3Page();
                                    break;
                                  case 'module4':
                                    destination = const Module4Page();
                                    break;
                                  case 'module5':
                                    destination = const Module5Page();
                                    break;
                                  default:
                                    destination = Scaffold(
                                      appBar: AppBar(
                                        title: Text(
                                            moduleData['module'] as String),
                                      ),
                                      body: Center(
                                        child: Text(
                                            '$moduleId: ${moduleData['module']} is unlocked but the page is not implemented yet.'),
                                      ),
                                    );
                                }
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => destination),
                                );
                                logger.i(
                                    "Returned from $moduleId (Go to Module button), re-checking module status.");
                                await _checkModuleStatus();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isLocked
                              ? Colors.grey[350]
                              : allLessonsLocallyCompleted
                                  ? Colors.green[600]
                                  : isInProgress
                                      ? Colors.orange[600]
                                      : const Color(0xFF00568D),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation:
                              isLocked || allLessonsLocallyCompleted ? 1 : 3,
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