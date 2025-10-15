import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'pronunciation/pronunciation_practice_page.dart';
import 'fluency/fluency_practice_page.dart';
import 'grammar/grammar_practice_page.dart';
import 'vocabulary/vocabulary_builder_page.dart';
import 'roleplay/roleplay_scenarios_page.dart';

class PracticeCenterPage extends StatefulWidget {
  const PracticeCenterPage({Key? key}) : super(key: key);

  @override
  State<PracticeCenterPage> createState() => _PracticeCenterPageState();
}

class _PracticeCenterPageState extends State<PracticeCenterPage> {
  final _user = FirebaseAuth.instance.currentUser;
  bool _isLoading = true;

  // ✅ ENHANCED: Store all practice stats
  Map<String, dynamic> _allStats = {
    'pronunciation': null,
    'fluency': null,
    'grammar': null,
    'vocabulary': null,
    'vocabularyQuiz': null,
    'roleplay': null,
  };

  static const String _backendUrl = 'https://talkready-backend.onrender.com';

  @override
  void initState() {
    super.initState();
    _loadPracticeStats();
  }

  // ✅ UPDATED: Load all stats from unified endpoint
  Future<void> _loadPracticeStats() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final response = await http
          .post(
            Uri.parse('$_backendUrl/get-unified-practice-stats'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'userId': _user?.uid}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true && data['stats'] != null) {
          if (!mounted) return;
          setState(() {
            _allStats = data['stats']; // Store all stats
          });
          print('✅ Practice stats loaded successfully');
        }
      }
    } catch (e) {
      print('❌ Error loading practice stats: $e');
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPronunciationStats() async {
    try {
      final response = await http
          .post(
            Uri.parse('$_backendUrl/get-pronunciation-history'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'userId': _user?.uid, 'limit': 10}),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _allStats['pronunciation'] = data['overallStats'];
        }
      }
    } catch (e) {
      print('Error loading pronunciation stats: $e');
    }
  }

  Future<void> _loadFluencyStats() async {
    try {
      // Note: You'll need to create a /get-fluency-history endpoint similar to pronunciation
      final response = await http
          .post(
            Uri.parse('$_backendUrl/get-fluency-history'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'userId': _user?.uid, 'limit': 10}),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _allStats['fluency'] = data['overallStats'];
        }
      }
    } catch (e) {
      print('Error loading fluency stats: $e');
    }
  }

  Future<void> _loadGrammarStats() async {
    try {
      final response = await http
          .post(
            Uri.parse('$_backendUrl/get-grammar-history'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'userId': _user?.uid, 'limit': 10}),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _allStats['grammar'] = data['overallStats'];
        }
      }
    } catch (e) {
      print('Error loading grammar stats: $e');
    }
  }

  Future<void> _loadVocabularyStats() async {
    try {
      final response = await http
          .post(
            Uri.parse('$_backendUrl/get-vocabulary-progress'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'userId': _user?.uid, 'limit': 50}),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _allStats['vocabulary'] = data['overallStats']?['vocabulary'];
          _allStats['vocabularyQuiz'] = data['overallStats']?['vocabularyQuiz'];
        }
      }
    } catch (e) {
      print('Error loading vocabulary stats: $e');
    }
  }

  Future<void> _loadRoleplayStats() async {
    try {
      final response = await http
          .post(
            Uri.parse('$_backendUrl/get-roleplay-history'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'userId': _user?.uid, 'limit': 10}),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _allStats['roleplay'] = data['overallStats'];
        }
      }
    } catch (e) {
      print('Error loading roleplay stats: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎯 Practice Center'),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPracticeStats,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWelcomeCard(),
                    const SizedBox(height: 24),
                    _buildTodayProgressCard(),
                    const SizedBox(height: 24),
                    const Text(
                      '🎯 Choose Your Practice',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildPracticeCard(
                      title: '🎤 Pronunciation Practice',
                      description:
                          'Master call-center phrases with AI feedback',
                      stats: _getPronunciationStats(),
                      onTap: _navigateToPronunciationPractice,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 12),
                    _buildPracticeCard(
                      title: '📖 Fluency Practice',
                      description: 'Read passages smoothly',
                      stats: _getFluencyStats(),
                      onTap: _navigateToFluencyPractice,
                      color: Colors.green,
                    ),
                    const SizedBox(height: 12),
                    _buildPracticeCard(
                      title: '✍️ Grammar Exercises',
                      description: 'Improve written communication',
                      stats: _getGrammarStats(),
                      onTap: _navigateToGrammarPractice,
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 12),
                    _buildPracticeCard(
                      title: '📚 Vocabulary Builder',
                      description: 'Expand your word knowledge',
                      stats: _getVocabularyStats(),
                      onTap: _navigateToVocabulary,
                      color: Colors.purple,
                    ),
                    const SizedBox(height: 12),
                    _buildPracticeCard(
                      title: '🎭 Role-play Scenarios',
                      description: 'Practice real conversations',
                      stats: _getRoleplayStats(),
                      onTap: _navigateToRoleplay,
                      color: Colors.teal,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildWelcomeCard() {
    final userName = _user?.displayName?.split(' ')[0] ?? 'there';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple, Colors.deepPurple.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back, $userName! 👋',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Continue building your English skills',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ✅ ENHANCED: Show real today's progress
  Widget _buildTodayProgressCard() {
    // ✅ COMPLETE FIX: Count all sessions correctly
    int totalSessionsToday = 0;
    int activeTypes = 0;
    int totalPracticeMinutes = 0;

    final pronunciation = _allStats['pronunciation'];
    final fluency = _allStats['fluency'];
    final grammar = _allStats['grammar'];
    final vocabulary = _allStats['vocabulary'];
    final roleplay = _allStats['roleplay'];

    // Count pronunciation sessions
    if (pronunciation != null && pronunciation['totalSessions'] != null) {
      totalSessionsToday += (pronunciation['totalSessions'] ?? 0) as int;
      if ((pronunciation['totalSessions'] ?? 0) > 0) activeTypes++;
    }

    // ✅ FIX: Count fluency sessions (WAS MISSING)
    if (fluency != null && fluency['totalSessions'] != null) {
      totalSessionsToday += (fluency['totalSessions'] ?? 0) as int;
      if ((fluency['totalSessions'] ?? 0) > 0) activeTypes++;
    }

    // Count grammar sessions
    if (grammar != null && grammar['totalSessions'] != null) {
      totalSessionsToday += (grammar['totalSessions'] ?? 0) as int;
      if ((grammar['totalSessions'] ?? 0) > 0) activeTypes++;
    }

    // Count vocabulary (doesn't have sessions, just word count)
    if (vocabulary != null && vocabulary['totalWordsStudied'] != null) {
      if ((vocabulary['totalWordsStudied'] ?? 0) > 0) activeTypes++;
    }

    // Count roleplay sessions
    if (roleplay != null && roleplay['totalSessions'] != null) {
      totalSessionsToday += (roleplay['totalSessions'] ?? 0) as int;
      if ((roleplay['totalSessions'] ?? 0) > 0) activeTypes++;
    }

    // Calculate practice time
    totalPracticeMinutes = totalSessionsToday * 3;

    // ✅ DEBUG (optional - remove after testing)
    print('🔍 Total Sessions: $totalSessionsToday');
    print('🔍 Active Types: $activeTypes');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_today,
                size: 20,
                color: Colors.deepPurple,
              ),
              const SizedBox(width: 8),
              const Text(
                '📊 Your Practice Summary',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  icon: '🎯',
                  label: 'Total Sessions',
                  value: '$totalSessionsToday', // ✅ Now correct
                ),
              ),
              Container(width: 1, height: 40, color: Colors.grey.shade300),
              Expanded(
                child: _buildStatItem(
                  icon: '⏱️',
                  label: 'Practice Time',
                  value: '~$totalPracticeMinutes min',
                ),
              ),
              Container(width: 1, height: 40, color: Colors.grey.shade300),
              Expanded(
                child: _buildStatItem(
                  icon: '🔥',
                  label: 'Active Types',
                  value: '$activeTypes',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  int _getActivePracticeTypes() {
    int active = 0;
    if (_allStats['pronunciation'] != null &&
        (_allStats['pronunciation']['totalSessions'] ?? 0) > 0)
      active++;
    if (_allStats['fluency'] != null &&
        (_allStats['fluency']['totalSessions'] ?? 0) > 0)
      active++;
    if (_allStats['grammar'] != null &&
        (_allStats['grammar']['totalSessions'] ?? 0) > 0)
      active++;
    if (_allStats['vocabulary'] != null &&
        (_allStats['vocabulary']['totalWordsStudied'] ?? 0) > 0)
      active++;
    if (_allStats['roleplay'] != null &&
        (_allStats['roleplay']['totalSessions'] ?? 0) > 0)
      active++;
    return active;
  }

  Widget _buildStatItem({
    required String icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPracticeCard({
    required String title,
    required String description,
    required String stats,
    required VoidCallback? onTap,
    required Color color,
  }) {
    final isEnabled = onTap != null;

    return Card(
      elevation: isEnabled ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isEnabled ? color.withOpacity(0.3) : Colors.grey.shade300,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 60,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isEnabled ? Colors.black87 : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: isEnabled ? Colors.grey.shade700 : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      stats,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isEnabled ? color : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isEnabled ? Icons.arrow_forward_ios : Icons.lock,
                size: 16,
                color: isEnabled ? color : Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ STATS GETTER FUNCTIONS (using real data)
  String _getPronunciationStats() {
    final stats = _allStats['pronunciation'];
    if (stats == null || stats['totalSessions'] == 0) {
      return 'Start your first session!';
    }

    final totalSessions = stats['totalSessions'] ?? 0;
    final avgAccuracy = (stats['averageAccuracy'] ?? 0).toInt();

    return '$totalSessions sessions • ${avgAccuracy}% avg accuracy';
  }

  String _getFluencyStats() {
    final stats = _allStats['fluency'];
    if (stats == null || stats['totalSessions'] == 0) {
      return 'Start your first session!';
    }

    final totalSessions = stats['totalSessions'] ?? 0;
    final avgScore = (stats['averageScore'] ?? 0).toInt();

    return '$totalSessions sessions • ${avgScore}% avg score';
  }

  String _getGrammarStats() {
    final stats = _allStats['grammar'];
    if (stats == null || stats['totalSessions'] == 0) {
      return 'Start your first quiz!';
    }

    final totalSessions = stats['totalSessions'] ?? 0;
    final accuracy = (stats['accuracy'] ?? 0).toInt();

    return '$totalSessions quizzes • ${accuracy}% accuracy';
  }

  String _getVocabularyStats() {
    final stats = _allStats['vocabulary'];
    if (stats == null || stats['totalWordsStudied'] == 0) {
      return 'Start learning words!';
    }

    final wordsStudied = stats['totalWordsStudied'] ?? 0;
    final wordsLearned = stats['wordsLearned'] ?? 0;

    return '$wordsStudied words studied • $wordsLearned learned';
  }

  String _getRoleplayStats() {
    final stats = _allStats['roleplay'];
    if (stats == null || stats['totalSessions'] == 0) {
      return 'Start your first conversation!';
    }

    final totalSessions = stats['totalSessions'] ?? 0;
    final avgOverall = (stats['averageOverall'] ?? 0).toInt();

    return '$totalSessions scenarios • ${avgOverall}% avg score';
  }

  // Navigation methods (keep your existing ones)
  void _navigateToPronunciationPractice() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PronunciationPracticePage(),
      ),
    ).then((_) => _loadPracticeStats());
  }

  void _navigateToFluencyPractice() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FluencyPracticePage()),
    ).then((_) => _loadPracticeStats());
  }

  void _navigateToGrammarPractice() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const GrammarPracticePage()),
    ).then((_) => _loadPracticeStats());
  }

  void _navigateToVocabulary() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const VocabularyBuilderPage()),
    ).then((_) => _loadPracticeStats());
  }

  void _navigateToRoleplay() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RolePlayScenariosPage()),
    ).then((_) => _loadPracticeStats());
  }
}
