import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:talkready_mobile/ai_bot.dart';

class ProgramsPage extends StatelessWidget {
  final VoidCallback? onBackPressed;
  final Logger logger = Logger();

  ProgramsPage({super.key, this.onBackPressed});

  final List<_ProgramItem> programs = [
    _ProgramItem(
      title: 'Customer Service Simulation',
      subtitle: 'Handle customer inquiries and complaints with AI-generated responses and speech analysis.',
      icon: Icons.support_agent,
    ),
    _ProgramItem(
      title: 'Email Etiquette Test',
      subtitle: 'Enhance professional email writing skills with AI feedback on clarity and tone.',
      icon: Icons.email,
    ),
    _ProgramItem(
      title: 'Active Listening & Accent Recognition',
      subtitle: 'Understand diverse English accents and improve response accuracy.',
      icon: Icons.headphones,
    ),
    _ProgramItem(
      title: 'Listening & Note-taking Training',
      subtitle: 'Develop call transcription skills and practice real-time note-taking.',
      icon: Icons.edit_note,
    ),
    _ProgramItem(
      title: 'Mock Call Roleplay with AI Feedback',
      subtitle: 'Engage in AI-powered call simulations with real-time pronunciation evaluation.',
      icon: Icons.phone,
    ),
    _ProgramItem(
      title: 'Pronunciation & Fluency Assessment',
      subtitle: 'Get real-time AI feedback on pronunciation, fluency, and tone.',
      icon: Icons.record_voice_over,
    ),
    _ProgramItem(
      title: 'Accent Neutralization Training',
      subtitle: 'Reduce strong regional accents for clear, professional communication.',
      icon: Icons.language,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final textScaleFactor = MediaQuery.of(context).textScaleFactor;
    // Adjust aspect ratio to provide more height, accounting for text scaling
    final childAspectRatio = screenWidth < 400 ? 0.75 : 0.7;

    logger.d('Building ProgramsPage: screenWidth=$screenWidth, textScaleFactor=$textScaleFactor, childAspectRatio=$childAspectRatio');

    return Scaffold(
      appBar: AppBar(
        title: const Text('English for Work'),
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF00568D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            logger.i('Back button pressed on ProgramsPage');
            onBackPressed?.call();
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Text(
                'Master workplace communication with AI-powered speech training, pronunciation coaching, and real-world Call Center simulations.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: childAspectRatio,
                  children: programs
                      .map((program) => _ProgramCard(
                            program: program,
                            onStartPressed: () {
                              logger.i('Start Simulation pressed for: ${program.title}');
                              _showSimulationDialog(context, program.title);
                            },
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSimulationDialog(BuildContext context, String programTitle) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(programTitle),
        content: Text('Start the $programTitle simulation? (Placeholder action)'),
        actions: [
          TextButton(
            onPressed: () {
              logger.i('Cancelled simulation for: $programTitle');
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              logger.i('Started simulation for: $programTitle');
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Started $programTitle simulation!')),
              );
            },
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }
}

class _ProgramItem {
  final String title;
  final String subtitle;
  final IconData icon;

  _ProgramItem({required this.title, required this.subtitle, required this.icon});
}

class _ProgramCard extends StatelessWidget {
  final _ProgramItem program;
  final VoidCallback onStartPressed;

  const _ProgramCard({required this.program, required this.onStartPressed});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          logger.d('ProgramCard constraints: w=${constraints.maxWidth}, h=${constraints.maxHeight}');
          return Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  program.icon,
                  size: 32, // Reduced from 36
                  color: const Color(0xFF00568D),
                ),
                const SizedBox(height: 6), // Reduced from 8
                Text(
                  program.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13, // Reduced from 14
                    color: Color(0xFF00568D),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6), // Reduced from 8
                Expanded(
                  child: Text(
                    program.subtitle,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 11, // Reduced from 12
                      height: 1.2, // Tighter line height
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 6), // Reduced from 8
                TextButton(
                  onPressed: onStartPressed,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF00568D),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), // Reduced padding
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    minimumSize: const Size(0, 0), // Allow button to shrink
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Start Simulation',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600), // Reduced from 12
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}