import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:talkready_mobile/ProgramsPage.dart';
import 'dart:math';
import 'ai_bot.dart';
import 'profile.dart'; // Assume you have this from the previous response
import 'package:logger/logger.dart'; // Add this package for logging
import 'courses_page.dart';
import 'journal_page.dart';

// Placeholder pages for Courses and Journal

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0; // Track the currently selected tab
  String? selectedSkill;
  final Map<String, double> skillPercentages = {
    'Fluency': 0.0,
    'Grammar': 0.0,
    'Pronunciation': 0.0,
    'Vocabulary': 0.0,
    'Interaction': 0.0,
  };

  // Initialize logger
  final Logger logger = Logger();

  @override
  void initState() {
    super.initState();
    _fetchProgress(); // Load progress when the page initializes
  }

  Future<void> _fetchProgress() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      logger.e('No user logged in');
      return;
    }

    try {
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
        logger.i('Fetched progress for homepage: $skillPercentages');
      } else {
        logger.i('No progress data found, using defaults');
      }
    } catch (e) {
      logger.e('Error fetching progress for homepage: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading progress: $e')),
        );
      }
    }
  }

  double get overallPercentage {
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
  if (index == _selectedIndex) return; // Avoid redundant navigation

  setState(() {
    _selectedIndex = index; // Update the selected index for visual feedback
  });

  switch (index) {
    case 1: // Conversation (AIBotScreen)
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AIBotScreen(
            onBackPressed: () {
              setState(() {
                _selectedIndex = 0; // Switch back to Home tab
              });
            },
          ),
        ),
      ).then((progress) async {
        logger.d('Returned from AIBotScreen with progress: $progress');
        if (progress != null && progress is Map<String, double> && mounted) { // Add mounted check
          setState(() {
            skillPercentages['Fluency'] =
                progress['Fluency'] ?? skillPercentages['Fluency']!;
            skillPercentages['Grammar'] =
                progress['Grammar'] ?? skillPercentages['Grammar']!;
            skillPercentages['Pronunciation'] = progress['Pronunciation'] ??
                skillPercentages['Pronunciation']!;
            skillPercentages['Vocabulary'] =
                progress['Vocabulary'] ?? skillPercentages['Vocabulary']!;
            skillPercentages['Interaction'] =
                progress['Interaction'] ?? skillPercentages['Interaction']!;
          });
          await _saveProgressToFirestore();
          // Use the returned progress directly instead of refetching
          logger.i('Updated skillPercentages: $skillPercentages');
          if (mounted) { // Add another mounted check for SnackBar
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Progress updated successfully')),
            );
          }
        }
      });
      break;
    case 2: // Courses
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => CoursesPage()),
      ).then((_) {
        if (mounted) {
          setState(() {
            _selectedIndex = 0; // Switch back to Home tab
          });
        }
      });
      break;

    case 3: // Journal
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ProgressTrackerPage()),
      ).then((_) {
        if (mounted) {
          setState(() {
            _selectedIndex = 0; // Switch back to Home tab
          });
        }
      });
      break;

      case 4: // Programs
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => ProgramsPage()),
  ).then((_) {
    if (mounted) {
      setState(() {
        _selectedIndex = 0; // Switch back to Home tab
      });
    }
  });
  break;
    case 5: // Profile
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ProfilePage()),
      ).then((_) {
        logger.d('Returned from ProfilePage');
        if (mounted) {
          setState(() {
            _selectedIndex = 0; // Switch back to Home tab after returning
          });
        }
      });
      break;
    default:
      break;
  }
}

  Future<void> _saveProgressToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      logger.e('No user logged in');
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'progress': skillPercentages,
      }, SetOptions(merge: true));
      logger.i('Progress saved to Firestore from homepage: $skillPercentages');
    } catch (e) {
      logger.e('Error saving progress to Firestore from homepage: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving progress: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('TalkReady'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF00568D),
      ),
      body: SingleChildScrollView(
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
                    selectedSkill: selectedSkill, // Pass the selected skill
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
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: skillPercentages.keys.map((skill) {
                  final Map<String, Color> skillColors = {
                    "Grammar": const Color(0xFFD8F6F7), // Light Cyan
                    "Fluency": const Color(0xFFDEE3FF), // Light Blue
                    "Interaction": const Color(0xFFFFD6D6), // Light Pink
                    "Pronunciation": const Color(0xFFFFF0C3), // Light Yellow
                    "Vocabulary": const Color(0xFFE0FFD6), // Light Green
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
                            ? skillColors[skill]
                                ?.withOpacity(0.5) // Darker shade if selected
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
                height: 40, // Adjust height as needed
                child: ElevatedButton(
                  onPressed: () {
                    // Add action for the Start Practice button
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00568D),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                    padding: const EdgeInsets.symmetric(
                        vertical: 5), // Adjust height
                  ),
                  child: const Text('Start Practice',
                      style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF00568D),
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex, // Bind the selected index
        onTap: _onItemTapped, // Handle tab taps
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chatbot'),
          BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Courses'),
          BottomNavigationBarItem(
              icon: Icon(Icons.library_books), label: 'Journal'),
          BottomNavigationBarItem(icon: Icon(Icons.apps), label: 'Programs'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class PentagonGraph extends StatelessWidget {
  final double size;
  final double progress;
  final String? selectedSkill;

  // Make skillColors a static constant
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

    // Draw base tiers
    final basePaint = Paint()
      ..color = greyColor.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int i = 5; i > 0; i--) {
      _drawPentagon(canvas, center, radius * (i / 5), basePaint);
    }

    // Draw progress fill with selected color or default grey
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

    // Draw outline
    final outlinePaint = Paint()
      ..color = skillColor ?? greyColor // Use skill color for outline too
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
      final angle = 2 * pi / 5 * i - pi / 2;
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
