import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'vocabulary_word_list_page.dart';
import 'vocabulary_flashcards_page.dart';
import 'vocabulary_quiz_page.dart';

class VocabularyBuilderPage extends StatefulWidget {
  const VocabularyBuilderPage({Key? key}) : super(key: key);

  @override
  State<VocabularyBuilderPage> createState() => _VocabularyBuilderPageState();
}

class _VocabularyBuilderPageState extends State<VocabularyBuilderPage> {
  final Logger _logger = Logger();
  final _user = FirebaseAuth.instance.currentUser;

  bool _isLoading = true;
  Map<String, dynamic>? _stats;

  static const String _backendUrl = 'https://talkready-backend.onrender.com';

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    if (!mounted) return; // ✅ Add this
    setState(() => _isLoading = true);

    try {
      final response = await http
          .post(
            Uri.parse('$_backendUrl/get-vocabulary-progress'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'userId': _user?.uid, 'limit': 100}),
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return; // ✅ Add this

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (!mounted) return; // ✅ Add this

          setState(() {
            _stats = data['overallStats'];
            _isLoading = false;
          });
          _logger.i('Loaded vocabulary stats');
        }
      }
    } catch (e) {
      _logger.e('Error loading stats: $e');

      if (!mounted) return; // ✅ Add this

      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📚 Vocabulary Builder'),
        backgroundColor: Colors.purple,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Stats Card
                  _buildStatsCard(),
                  const SizedBox(height: 24),

                  // Main Title
                  const Text(
                    'Choose Your Learning Mode',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // Learning Modes
                  _buildModeCard(
                    icon: Icons.list_alt,
                    title: 'Word Lists',
                    description: 'Browse and learn new vocabulary',
                    color: Colors.purple,
                    onTap: () => _navigateToWordList(),
                  ),
                  const SizedBox(height: 12),

                  _buildModeCard(
                    icon: Icons.style,
                    title: 'Flashcards',
                    description: 'Study with interactive flashcards',
                    color: Colors.deepPurple,
                    onTap: () => _navigateToFlashcards(),
                  ),
                  const SizedBox(height: 12),

                  _buildModeCard(
                    icon: Icons.quiz,
                    title: 'Vocabulary Quiz',
                    description: 'Test your knowledge',
                    color: Colors.indigo,
                    onTap: () => _navigateToQuiz(),
                  ),
                  const SizedBox(height: 24),

                  // Categories Section
                  const Text(
                    'Popular Categories',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  _buildCategoriesGrid(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsCard() {
    final vocabStats = _stats?['vocabulary'] ?? {};
    final quizStats = _stats?['vocabularyQuiz'] ?? {};

    final wordsStudied = vocabStats['totalWordsStudied'] ?? 0;
    final wordsLearned = vocabStats['wordsLearned'] ?? 0;
    final quizAccuracy = quizStats['accuracy']?.toInt() ?? 0;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.purple.shade50, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Progress',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.purple,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Words Studied', '$wordsStudied', Icons.book),
                _buildStatItem(
                  'Words Learned',
                  '$wordsLearned',
                  Icons.check_circle,
                ),
                _buildStatItem('Quiz Accuracy', '$quizAccuracy%', Icons.score),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.purple, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.purple,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildModeCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: color.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: color, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoriesGrid() {
    final categories = [
      {'name': 'Customer Service', 'icon': '🤝', 'value': 'customer_service'},
      {'name': 'Technical Terms', 'icon': '💻', 'value': 'technical_terms'},
      {
        'name': 'Business Vocabulary',
        'icon': '💼',
        'value': 'business_vocabulary',
      },
      {'name': 'Phone Etiquette', 'icon': '📞', 'value': 'phone_etiquette'},
      {'name': 'Problem Solving', 'icon': '🔧', 'value': 'problem_solving'},
      {
        'name': 'Payment & Billing',
        'icon': '💳',
        'value': 'payment_and_billing',
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return _buildCategoryCard(
          emoji: category['icon'] as String,
          name: category['name'] as String,
          value: category['value'] as String,
        );
      },
    );
  }

  Widget _buildCategoryCard({
    required String emoji,
    required String name,
    required String value,
  }) {
    return InkWell(
      onTap: () => _navigateToWordList(category: value),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 32)),
              const SizedBox(height: 8),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToWordList({String? category}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            VocabularyWordListPage(initialCategory: category ?? 'general'),
      ),
    ).then((_) => _loadStats());
  }

  void _navigateToFlashcards() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const VocabularyFlashcardsPage()),
    ).then((_) => _loadStats());
  }

  void _navigateToQuiz() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const VocabularyQuizPage()),
    ).then((_) => _loadStats());
  }
}
