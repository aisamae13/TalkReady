import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';

class ProgressTrackerPage extends StatefulWidget {
  const ProgressTrackerPage({super.key});

  @override
  State<ProgressTrackerPage> createState() => _ProgressTrackerPageState();
}

class _ProgressTrackerPageState extends State<ProgressTrackerPage> {
  final Logger logger = Logger();
  final Map<String, double> skillProgress = {
    'Fluency': 0.0,
    'Grammar': 0.0,
    'Pronunciation': 0.0,
    'Vocabulary': 0.0,
    'Interaction': 0.0,
  };

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
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      Map<String, dynamic>? userData = doc.data() as Map<String, dynamic>?;
      if (userData != null && userData.containsKey('progress')) {
        Map<String, dynamic> progress = userData['progress'];
        setState(() {
          skillProgress['Fluency'] =
              (progress['Fluency'] as num?)?.toDouble() ?? 0.0;
          skillProgress['Grammar'] =
              (progress['Grammar'] as num?)?.toDouble() ?? 0.0;
          skillProgress['Pronunciation'] =
              (progress['Pronunciation'] as num?)?.toDouble() ?? 0.0;
          skillProgress['Vocabulary'] =
              (progress['Vocabulary'] as num?)?.toDouble() ?? 0.0;
          skillProgress['Interaction'] =
              (progress['Interaction'] as num?)?.toDouble() ?? 0.0;
        });
        logger.i('Fetched progress: $skillProgress');
      } else {
        logger.i('No progress data found, using defaults');
      }
    } catch (e) {
      logger.e('Error fetching progress: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading progress: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress Tracker'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF00568D),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Your Progress Overview',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00568D),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'Track your improvement in key language skills.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Skill Progress Bars
            ...skillProgress.keys
                .map((skill) => _buildProgressBar(skill, skillProgress[skill]!))
                ,
            const SizedBox(height: 30),

            // Feedback Sections
            _buildFeedbackSection(
              title: 'Nicely Done',
              color: Colors.green[100]!,
              points: [
                '✔ You used five grammatical tenses.',
                '✔ You constructed grammatically correct relative clauses.',
                '✔ 85% of your sentences include a complex structure.',
                '✔ You are fluent using phrasal verbs.',
              ],
            ),
            const SizedBox(height: 20),
            _buildFeedbackSection(
              title: 'Things to Improve',
              color: Colors.yellow[100]!,
              points: [
                '⚠ Improve speaking rate and reduce pauses.',
                '⚠ Avoid filler words like "uh", "um", and "okay".',
                '⚠ Use more varied vocabulary.',
                '⚠ Practice linking words for better flow.',
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(String skill, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            skill,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          LinearProgressIndicator(
            value: value / 5, // Assuming progress is out of 5
            backgroundColor: Colors.grey[300],
            color: Colors.blue,
            minHeight: 10,
          ),
          Text(
              '${(value * 20).toStringAsFixed(0)}%'), // Convert 5-scale to 100%
        ],
      ),
    );
  }

  Widget _buildFeedbackSection({
    required String title,
    required Color color,
    required List<String> points,
  }) {
    return Card(
      color: color,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: points
                  .map((point) => Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Text(
                          point,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
