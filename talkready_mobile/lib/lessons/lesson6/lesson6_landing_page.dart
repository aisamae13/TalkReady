// lib/lessons/lesson6/lesson6_landing_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/unified_progress_service.dart';

class Lesson6LandingPage extends StatefulWidget {
  const Lesson6LandingPage({super.key});

  @override
  State<Lesson6LandingPage> createState() => _Lesson6LandingPageState();
}

class _Lesson6LandingPageState extends State<Lesson6LandingPage> {
  final UnifiedProgressService _progressService = UnifiedProgressService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _previousAttempts = [];
  int _nextAttemptNumber = 1;

  @override
  void initState() {
    super.initState();
    _loadPreviousAttempts();
  }

  Future<void> _loadPreviousAttempts() async {
    try {
      final attempts = await _progressService.getLessonAttempts('Lesson-6-1');
      setState(() {
        _previousAttempts = attempts;
        _nextAttemptNumber = attempts.length + 1;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E40AF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Module 6: Advanced Call Simulation',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeroSection(),
          const SizedBox(height: 24),
          _buildDescriptionSection(),
          const SizedBox(height: 24),
          _buildFeaturesSection(),
          const SizedBox(height: 24),
          if (_previousAttempts.isNotEmpty) _buildPreviousAttemptsSection(),
          const SizedBox(height: 32),
          _buildActionButton(),
          const SizedBox(height: 100), // Bottom padding for navigation
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
        ),
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.headset_mic, size: 80, color: Colors.white),
          ),
          const SizedBox(height: 20),
          const Text(
            'Advanced Call Simulation',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Live, unscripted AI conversation practice',
            style: TextStyle(fontSize: 16, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.info_outline,
                  color: Color(0xFF3B82F6),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'What You\'ll Do',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'In this final challenge, you will engage in a live, unscripted mock call with an AI-powered customer. Your goal is to use all the skills you\'ve learned—from grammar and vocabulary to empathy and problem-solving—to successfully handle the interaction.',
            style: TextStyle(
              fontSize: 15,
              color: Color(0xFF64748B),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'After the call, you will receive a detailed performance report with actionable feedback to help you excel in real call center environments.',
            style: TextStyle(
              fontSize: 15,
              color: Color(0xFF64748B),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesSection() {
    final features = [
      {
        'icon': Icons.mic_external_on,
        'title': 'Real-time Conversation',
        'description': 'Speak naturally with AI customers using your voice',
        'color': const Color(0xFF10B981),
      },
      {
        'icon': Icons.psychology,
        'title': 'AI-Powered Scenarios',
        'description': 'Handle realistic customer service situations',
        'color': const Color(0xFF8B5CF6),
      },
      {
        'icon': Icons.analytics,
        'title': 'Advanced Analysis',
        'description': 'Get detailed performance metrics and feedback',
        'color': const Color(0xFF06B6D4),
      },
      {
        'icon': Icons.school,
        'title': 'Call Center Ready',
        'description': 'Practice skills directly applicable to real work',
        'color': const Color(0xFFF59E0B),
      },
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 16),
            child: Text(
              'Key Features',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
          ...features
              .map(
                (feature) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        spreadRadius: 1,
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (feature['color'] as Color).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          feature['icon'] as IconData,
                          color: feature['color'] as Color,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              feature['title'] as String,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              feature['description'] as String,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ],
      ),
    );
  }

  Widget _buildPreviousAttemptsSection() {
    // ✅ FIXED: Handle both int and double types from Firebase
    final bestScore = _previousAttempts.isEmpty
        ? 0
        : _previousAttempts
              .map((attempt) {
                final score = attempt['score'];
                // Handle both int and double types from Firebase
                if (score is int) return score;
                if (score is double) return score.round();
                return 0;
              })
              .reduce((a, b) => a > b ? a : b);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.history,
                  color: Color(0xFF3B82F6),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Your Progress',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Attempts',
                  '${_previousAttempts.length}',
                  Icons.repeat,
                  const Color(0xFF8B5CF6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem(
                  'Best Score',
                  '$bestScore%',
                  Icons.star,
                  const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem(
                  'Next Attempt',
                  '#$_nextAttemptNumber',
                  Icons.arrow_forward,
                  const Color(0xFF10B981),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => _navigateToActivityLog(),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF3B82F6).withOpacity(0.2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.analytics,
                    color: Color(0xFF3B82F6),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'View Detailed Activity Log',
                    style: TextStyle(
                      color: Color(0xFF3B82F6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () => _startSimulation(),
              icon: const Icon(Icons.mic, size: 24),
              label: Text(
                _previousAttempts.isEmpty
                    ? 'Begin Simulation'
                    : 'Start Attempt #$_nextAttemptNumber',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 3,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Ready to practice your call center skills?',
            style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _startSimulation() {
    // TODO: Navigate to simulation page
    Navigator.pushNamed(
      context,
      '/lesson6_simulation',
      arguments: {'attemptNumber': _nextAttemptNumber},
    );
  }

  void _navigateToActivityLog() {
    // TODO: Navigate to activity log page
    Navigator.pushNamed(
      context,
      '/lesson6_activity_log',
      arguments: {
        'lessonId': 'Lesson-6-1',
        'lessonTitle': 'Module 6: Advanced Call Simulation',
        'attempts': _previousAttempts,
      },
    );
  }
}
