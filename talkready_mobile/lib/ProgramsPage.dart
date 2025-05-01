import 'package:flutter/material.dart';
import 'homepage.dart'; // or any landing screen

class ProgramsPage extends StatelessWidget {
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
    return Scaffold(
      appBar: AppBar(
        title: Text('English for Work'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Master workplace communication with AI-powered speech training, pronunciation coaching, and real-world Call Center simulations.',
              style: TextStyle(fontSize: 16, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85,
                children: programs.map((program) => _ProgramCard(program)).toList(),
              ),
            ),
          ],
        ),
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

  const _ProgramCard(this.program);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(program.icon, size: 40, color: Colors.blueAccent),
            Text(
              program.title,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            Text(
              program.subtitle,
              style: TextStyle(color: Colors.black54, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            TextButton(
              onPressed: () {},
              child: Text("Start Simulation"),
              style: TextButton.styleFrom(foregroundColor: Colors.blue),
            ),
          ],
        ),
      ),
    );
  }
}
