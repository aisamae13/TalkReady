import 'package:flutter/material.dart';

class CoursesPage extends StatefulWidget {
  const CoursesPage({super.key});

  @override
  _CoursesPageState createState() => _CoursesPageState();
}

class _CoursesPageState extends State<CoursesPage> {
  // List of expanded sections
  final List<bool> _isExpandedList = List.generate(8, (index) => false);

  // Course Outline Data
  final List<Map<String, dynamic>> courseOutline = [
    {
      'week': 'Week 1',
      'title': 'Introduction to English Sounds and Pronunciation',
      'icon': Icons.volume_up, // Icon for pronunciation
      'goals': [
        'Introduce basic English sounds (vowels and consonants).',
        'Practice pronunciation with simple words and sentences.'
      ],
      'activities': [
        'Phonetic chart practice.',
        'Listening and repeating words.',
        'Record and playback pronunciation.'
      ],
    },
    {
      'week': 'Week 2',
      'title': 'Basic Sentence Structure & Vocabulary',
      'icon': Icons.menu_book, // Icon for vocabulary
      'goals': [
        'Learn simple sentence structures (subject-verb-object).',
        'Build a basic vocabulary for daily use.'
      ],
      'activities': [
        'Vocabulary understanding.',
        'Simple conversations (e.g., greetings, introductions).',
        'Role-playing situations (shopping, ordering food).'
      ],
    },
    {
      'week': 'Week 3',
      'title': 'Common Verbs and Tenses',
      'icon': Icons.timeline, // Icon for tenses
      'goals': [
        'Understand and use present, past, and future tenses.',
        'Introduce action verbs and commonly used irregular verbs.'
      ],
      'activities': [
        'Practice using verbs in sentences.',
        'Write short passages in different tenses.',
        'Fluency drills with tenses.'
      ],
    },
    {
      'week': 'Week 4',
      'title': 'Pronunciation and Intonation',
      'icon': Icons.hearing, // Icon for listening skills
      'goals': [
        'Practice English stress patterns (syllable stress, word stress).',
        'Understand rising and falling intonation in questions and statements.'
      ],
      'activities': [
        'Listen to native speakers.',
        'Practice mimicking sentence intonation.',
        'Record and evaluate own speaking.'
      ],
    },
    {
      'week': 'Week 5',
      'title': 'Speaking with Fluency (Conversations and Dialogues)',
      'icon': Icons.record_voice_over, // Icon for fluency
      'goals': [
        'Improve fluency and comfort in real-life conversations.',
        'Work on fluidity and avoiding long pauses.'
      ],
      'activities': [
        'Paired conversation practice.',
        'Engage in guided dialogues with corrections.',
        'Listening exercises with Q&A.'
      ],
    },
    {
      'week': 'Week 6',
      'title': 'Grammar Focus - Sentence Building and Complex Sentences',
      'icon': Icons.article, // Icon for grammar
      'goals': [
        'Understand basic grammar rules: subject-verb agreement, sentence types (affirmative, negative, interrogative).',
        'Learn to form more complex sentences.'
      ],
      'activities': [
        'Sentence correction exercises.',
        'Write and speak complex sentences (e.g., using conjunctions like "because," "although").',
        'Role-play conversations using complex sentences.'
      ],
    },
    {
      'week': 'Week 7',
      'title': 'Pronunciation of Difficult Sounds & Words',
      'icon': Icons.mic, // Icon for pronunciation drills
      'goals': [
        'Identify and practice challenging sounds for the learner (e.g., “th,” “r” vs. “l”).',
        'Improve word stress in longer words.'
      ],
      'activities': [
        'Pronunciation drills of challenging words.',
        'Record speaking and listen for specific sounds.',
        'Practice speaking at different speeds for fluency.'
      ],
    },
    {
      'week': 'Week 8',
      'title': 'Advanced Fluency and Grammar Practice',
      'icon': Icons.school, // Icon for advanced learning
      'goals': [
        'Practice speaking with minimal hesitation.',
        'Refine use of tenses, prepositions, and articles.'
      ],
      'activities': [
        'Engaging in longer discussions.',
        'Complex sentence construction with advanced grammar rules.',
        'Presenting a short story or opinion.'
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Courses'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF00568D),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView.builder(
          itemCount: courseOutline.length,
          itemBuilder: (context, index) {
            final course = courseOutline[index];

            return Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: ExpansionTile(
                leading: Icon(course['icon'], color: Colors.blue),
                title: Text(
                  '${course['week']}: ${course['title']}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '🎯 Goals:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        ...course['goals'].map<Widget>(
                          (goal) => ListTile(
                            leading: const Icon(Icons.check_circle,
                                color: Colors.green),
                            title: Text(goal),
                          ),
                        ),
                        const Text(
                          '📌 Activities:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        ...course['activities'].map<Widget>(
                          (activity) => ListTile(
                            leading:
                                const Icon(Icons.star, color: Colors.orange),
                            title: Text(activity),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text('Enrolled in ${course['title']}'),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00568D),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Start Now'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
