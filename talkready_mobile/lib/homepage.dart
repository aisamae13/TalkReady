import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import 'ai_bot.dart';
import 'profile.dart';
import 'package:logger/logger.dart';
import 'courses_page.dart';
import 'journal/journal_page.dart';
import 'package:talkready_mobile/all_notifications_page.dart';
import 'progress_page.dart';
import 'package:talkready_mobile/custom_animated_bottom_bar.dart';

// Helper function for creating a slide page route
Route _createSlidingPageRoute({
  required Widget page,
  required int newIndex,
  required int oldIndex,
  required Duration duration,
}) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final offset = oldIndex < newIndex ? Offset(1.0, 0.0) : Offset(-1.0, 0.0);
      return SlideTransition(
        position: Tween<Offset>(begin: offset, end: Offset.zero).animate(animation),
        child: child,
      );
    },
    transitionDuration: duration,
    reverseTransitionDuration: duration,
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0; // Home is index 0
  String? selectedSkill;
  final Map<String, double> skillPercentages = {
    'Fluency': 0.0,
    'Grammar': 0.0,
    'Pronunciation': 0.0,
    'Vocabulary': 0.0,
    'Interaction': 0.0,
  };
  final Map<String, String> skillDescriptions = {
    'Grammar': 'Your Grammar score is derived from your performance in lessons focusing on written accuracy and structure. This includes your scores from text-based scenario exercises (e.g., in Modules 2, 3, and 4, such as L2.1, L2.2, L2.3, L3.1, L4.1, L4.2) where AI evaluates your responses. It reflects your ability to form correct sentences and use appropriate language.',
    'Fluency': 'Your Fluency score is calculated from your performance in dedicated speaking practice lessons (e.g., Lessons L3.2, L5.1, L5.2). Our AI analyzes aspects like the smoothness, naturalness, and flow of your speech, including how well you connect words without undue hesitation.',
    'Interaction': 'Your Interaction score is based on your performance in speaking lessons that involve dialogues or call simulations (e.g., Lessons L3.2, L5.1, L5.2). It primarily reflects how effectively you complete conversational turns and cover the required information, based on the AI\'s analysis of speech completeness.',
    'Pronunciation': 'Your Pronunciation score is assessed during speaking exercises (e.g., Lessons L3.2, L5.1, L5.2). The AI evaluates the clarity of your speech, accuracy of sounds, rhythm, and intonation (prosody) to determine how well you are likely to be understood.',
    'Vocabulary': 'Your Vocabulary score reflects your understanding and use of a range of words appropriate for different contexts. It\'s based on your performance in text-based AI-evaluated exercises (e.g., in Modules 2, 3, and 4, such as L2.1, L2.2, L2.3, L3.1, L4.1, L4.2) where AI assesses how effectively you use vocabulary in context.'
  };

  final Logger logger = Logger();

  @override
  void initState() {
    super.initState();
    _fetchProgress();
  }

  Future<void> _fetchProgress() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      logger.e('No user logged in');
      return;
    }
    try {
      if (user.uid.isEmpty) {
        logger.e('Invalid user UID: empty');
        throw ArgumentError('User UID cannot be empty');
      }
      logger.i('Fetching progress for user: ${user.uid}');
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      Map<String, dynamic>? userData = doc.data() as Map<String, dynamic>?;
      if (userData != null && userData.containsKey('progress')) {
        Map<String, dynamic> progress = userData['progress'];
        setState(() {
          skillPercentages['Fluency'] =
              (progress['Fluency'] as num?)?.toDouble() ?? 0.0;
          skillPercentages['Grammar'] =
              (progress['Grammar'] as num?)?.toDouble() ?? 0.0;
          skillPercentages['Pronunciation'] =
              (progress['Pronunciation'] as num?)?.toDouble() ?? 0.0;
          skillPercentages['Vocabulary'] =
              (progress['Vocabulary'] as num?)?.toDouble() ?? 0.0;
          skillPercentages['Interaction'] =
              (progress['Interaction'] as num?)?.toDouble() ?? 0.0;
        });
        logger.i('Fetched progress: $skillPercentages');
      } else {
        logger.i('No progress data found for user: ${user.uid}, using defaults');
      }
    } catch (e, stackTrace) {
      logger.e('Error fetching progress: $e, stackTrace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading progress: $e')),
        );
      }
    }
  }

  double get overallPercentage {
    if (skillPercentages.isEmpty) return 0.0;
    return skillPercentages.values.reduce((a, b) => a + b) /
        skillPercentages.length;
  }

  void _handleSkillSelected(String skill) {
    setState(() {
      selectedSkill = skill;
    });
  }

  void _onItemTapped(int index) {
    logger.d('Tapped navigation item. Index: $index, currentIndex: $_selectedIndex');
    if (_selectedIndex == index) {
      logger.d('Already on selected page, skipping navigation');
      return;
    }

    final int oldNavIndex = _selectedIndex;

    setState(() {
      _selectedIndex = index;
    });

    Widget nextPage;
    switch (index) {
      case 0:
        logger.d('Already on HomePage, skipping navigation');
        return;
      case 1:
        nextPage = const CoursesPage();
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
        logger.w('Unhandled navigation index: $index');
        return;
    }

    Navigator.push(
      context,
      _createSlidingPageRoute(
        page: nextPage,
        newIndex: index,
        oldIndex: oldNavIndex,
        duration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        logger.i('Back button pressed on HomePage - prevented');
        return false; // Prevent back navigation
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Student Dashboard'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: const Color(0xFF00568D),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications),
              tooltip: 'Notifications',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AllNotificationsPage()),
                );
              },
            ),
          ],
        ),
        body: ScrollConfiguration(
          behavior: const ScrollBehavior().copyWith(overscroll: false),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Speaking Level Test',
                    style: TextStyle(
                      fontSize: 24,
                      color: Color(0xFF00568D),
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Find out your English level and get level up recommendation',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      PentagonGraph(
                        size: 200,
                        progress: overallPercentage,
                        selectedSkill: selectedSkill,
                      ),
                      Text(
                        '${((selectedSkill != null ? skillPercentages[selectedSkill]! : overallPercentage) * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Skill Progress Tracker',
                    style: TextStyle(
                      fontSize: 20,
                      color: Color(0xFF00568D),
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: skillPercentages.keys.map((skill) {
                      final Map<String, Color> skillColors = {
                        "Grammar": const Color(0xFFD8F6F7),
                        "Fluency": const Color(0xFFDEE3FF),
                        "Interaction": const Color(0xFFFFD6D6),
                        "Pronunciation": const Color(0xFFFFF0C3),
                        "Vocabulary": const Color(0xFFE0FFD6),
                      };
                      bool isSelected = selectedSkill == skill;
                      return InkWell(
                        onTap: () {
                          _handleSkillSelected(skill);
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? skillColors[skill]?.withOpacity(0.5)
                                : skillColors[skill] ?? Colors.grey,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            skill,
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if (selectedSkill != null) ...[
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0),
                      child: Text(
                        skillDescriptions[selectedSkill] ?? 'No description available.',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[700],
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  if (selectedSkill == null &&
                      FirebaseAuth.instance.currentUser != null &&
                      skillPercentages.values.every((value) => value == 0.0)) ...[
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0),
                      child: Text(
                        'Complete speaking exercises in the courses to see your skill progress here!',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Text(
                    'AI-Powered Vocabulary Booster',
                    style: TextStyle(
                      fontSize: 20,
                      color: Color(0xFF00568D),
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Learn new words that our AI thinks fit your interests and English level',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 5),
                  Image.asset(
                    'images/ai_robot.gif',
                    width: 250,
                    height: 250,
                  ),
                  SizedBox(
                    width: 250,
                    height: 40,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AIBotScreen(
                              onBackPressed: () {
                                Navigator.pop(context);
                              },
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00568D),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 5),
                      ),
                      child: const Text(
                        'Start Practice',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
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
      ),
    );
  }
}

class PentagonGraph extends StatelessWidget {
  final double size;
  final double progress;
  final String? selectedSkill;

  static const Map<String, Color> skillColors = {
    "Grammar": Color(0xFFD8F6F7),
    "Fluency": Color(0xFFDEE3FF),
    "Interaction": Color(0xFFFFD6D6),
    "Pronunciation": Color(0xFFFFF0C3),
    "Vocabulary": Color(0xFFE0FFD6),
  };

  const PentagonGraph({
    super.key,
    this.size = 200,
    required this.progress,
    this.selectedSkill,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: PentagonPainter(
        progress: progress,
        selectedSkill: selectedSkill,
        skillColor: selectedSkill != null ? skillColors[selectedSkill] : null,
      ),
    );
  }
}

class PentagonPainter extends CustomPainter {
  final double progress;
  final String? selectedSkill;
  final Color? skillColor;
  static const greyColor = Color(0xFF6B7280);

  PentagonPainter({
    required this.progress,
    this.selectedSkill,
    this.skillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final basePaint = Paint()
      ..color = greyColor.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int i = 5; i > 0; i--) {
      _drawPentagon(canvas, center, radius * (i / 5), basePaint);
    }

    final progressPaint = Paint()..style = PaintingStyle.fill;

    if (skillColor != null) {
      progressPaint.shader = LinearGradient(
        colors: [
          skillColor!.withOpacity(0.4),
          skillColor!,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    } else {
      progressPaint.shader = LinearGradient(
        colors: [
          greyColor.withOpacity(0.4),
          greyColor,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    }

    final progressPath = Path();
    _createPentagonPath(progressPath, center, radius * progress);
    canvas.drawPath(progressPath, progressPaint);

    final outlinePaint = Paint()
      ..color = skillColor ?? greyColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    _drawPentagon(canvas, center, radius, outlinePaint);
  }

  void _drawPentagon(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    _createPentagonPath(path, center, radius);
    canvas.drawPath(path, paint);
  }

  void _createPentagonPath(Path path, Offset center, double radius) {
    for (int i = 0; i < 5; i++) {
      final angle = 2 * math.pi / 5 * i - math.pi / 2;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
  }

  @override
  bool shouldRepaint(covariant PentagonPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.selectedSkill != selectedSkill ||
      oldDelegate.skillColor != skillColor;
}