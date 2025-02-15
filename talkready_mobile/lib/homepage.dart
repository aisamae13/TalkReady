import 'package:flutter/material.dart';
import 'dart:math';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? selectedSkill;
  final Map<String, double> skillPercentages = {
    'Fluency': 0.75,
    'Grammar': 0.82,
    'Pronunciation': 0.65,
    'Vocabulary': 0.90,
    'Interaction': 0.70,
  };

  double get overallPercentage {
    return skillPercentages.values.reduce((a, b) => a + b) / skillPercentages.length;
  }

  void _handleSkillSelected(String skill) {
    setState(() {
      selectedSkill = skill;
    });
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
                    fontWeight: FontWeight.bold),
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
                      selectedSkill: selectedSkill,  // Pass the selected skill
                    ),
                  Text(
                    '${((selectedSkill != null ? skillPercentages[selectedSkill]! : overallPercentage) * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700]),
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
                        setState(() {
                          selectedSkill = skill;
                        });
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? skillColors[skill]?.withOpacity(0.5) // Darker shade if selected
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
                height: 40, // Palitan mo ng gusto mong width
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
                    padding: const EdgeInsets.symmetric(vertical: 5), // Adjust height
                  ),
                  child: const Text('Start Practice', style: TextStyle(fontSize: 16)),
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
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.rocket_launch), label: 'Launch'),
          BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Book'),
          BottomNavigationBarItem(icon: Icon(Icons.note), label: 'Note'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
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
    final center = Offset(size.width/2, size.height/2);
    final radius = size.width/2;

    // Draw base tiers
    final basePaint = Paint()
      ..color = greyColor.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int i = 5; i > 0; i--) {
      _drawPentagon(canvas, center, radius * (i/5), basePaint);
    }

    // Draw progress fill with selected color or default grey
    final progressPaint = Paint()
      ..style = PaintingStyle.fill;

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
      ..color = skillColor ?? greyColor  // Use skill color for outline too
      ..style = PaintingStyle.stroke
      ..strokeWidth = (2.5);
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