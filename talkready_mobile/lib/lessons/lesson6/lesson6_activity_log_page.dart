// lib/lessons/lesson6/lesson6_activity_log_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/unified_progress_service.dart';
import 'package:logger/logger.dart';
import 'package:intl/intl.dart';

class Lesson6ActivityLogPage extends StatefulWidget {
  const Lesson6ActivityLogPage({super.key});

  @override
  State<Lesson6ActivityLogPage> createState() => _Lesson6ActivityLogPageState();
}

class _Lesson6ActivityLogPageState extends State<Lesson6ActivityLogPage>
    with TickerProviderStateMixin {
  final Logger _logger = Logger();
  final UnifiedProgressService _progressService = UnifiedProgressService();

  List<Map<String, dynamic>> _attempts = [];
  bool _isLoading = true;
  String _selectedFilter = 'all';
  Map<String, dynamic>? _selectedAttempt;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _loadAttempts();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadAttempts() async {
    try {
      setState(() => _isLoading = true);

      final attempts = await _progressService.getLessonAttempts('Lesson-6-1');

      // Sort attempts by most recent first
      attempts.sort((a, b) {
        final dateA = a['attemptTimestamp'] as DateTime?;
        final dateB = b['attemptTimestamp'] as DateTime?;
        if (dateA == null || dateB == null) return 0;
        return dateB.compareTo(dateA);
      });

      setState(() {
        _attempts = attempts;
        _isLoading = false;
      });

      _animationController.forward();
      _logger.i('Loaded ${attempts.length} Lesson 6 attempts');
    } catch (e) {
      _logger.e('Error loading Lesson 6 attempts: $e');
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredAttempts {
    if (_selectedFilter == 'all') return _attempts;

    return _attempts.where((attempt) {
      // ✅ FIXED: Handle both int and double types for score
      final scoreValue = attempt['score'];
      final score = scoreValue is int
          ? scoreValue
          : (scoreValue is double ? scoreValue.round() : 0);

      switch (_selectedFilter) {
        case 'excellent':
          return score >= 85;
        case 'good':
          return score >= 70 && score < 85;
        case 'developing':
          return score >= 55 && score < 70;
        case 'needs_improvement':
          return score < 55;
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: _isLoading ? _buildLoadingState() : _buildContent(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF1E40AF),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Module 6 Activity Log',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: _loadAttempts,
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF1E40AF)),
          SizedBox(height: 16),
          Text(
            'Loading your simulation history...',
            style: TextStyle(fontSize: 16, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_attempts.isEmpty) {
      return _buildEmptyState();
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          _buildStatsHeader(),
          _buildFilterTabs(),
          Expanded(
            child: _selectedAttempt == null
                ? _buildAttemptsList()
                : _buildAttemptDetail(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E40AF).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.headset_mic,
              size: 64,
              color: Color(0xFF1E40AF),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Simulations Yet',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Complete your first call simulation to see\nyour performance history here.',
            style: TextStyle(fontSize: 16, color: Color(0xFF64748B)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.mic),
            label: const Text('Start First Simulation'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E40AF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader() {
    final totalAttempts = _attempts.length;

    // ✅ FIXED: Handle both int and double types
    final avgScore = _attempts.isEmpty
        ? 0.0
        : _attempts
                  .map((a) {
                    final score = a['score'];
                    if (score is int) return score.toDouble();
                    if (score is double) return score;
                    return 0.0;
                  })
                  .reduce((a, b) => a + b) /
              totalAttempts;

    final bestScore = _attempts.isEmpty
        ? 0
        : _attempts
              .map((a) {
                final score = a['score'];
                if (score is int) return score;
                if (score is double) return score.round();
                return 0;
              })
              .reduce((a, b) => a > b ? a : b);

    final totalTime = _attempts.fold<int>(
      0,
      (sum, attempt) => sum + (attempt['timeSpent'] as int? ?? 0),
    );

    // ... rest of the method stays the same
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 3),
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
                  color: const Color(0xFF1E40AF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.analytics,
                  color: Color(0xFF1E40AF),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Performance Overview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Attempts',
                  '$totalAttempts',
                  Icons.repeat,
                  const Color(0xFF8B5CF6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Average Score',
                  '${avgScore.round()}%',
                  Icons.trending_up,
                  const Color(0xFF3B82F6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Best Score',
                  '$bestScore%',
                  Icons.star,
                  const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Total Practice',
                  '${_formatDuration(totalTime)}',
                  Icons.schedule,
                  const Color(0xFF10B981),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    final filters = [
      {'key': 'all', 'label': 'All', 'count': _attempts.length},
      {
        'key': 'excellent',
        'label': 'Excellent',
        'count': _attempts.where((a) => (a['score'] ?? 0) >= 85).length,
      },
      {
        'key': 'good',
        'label': 'Good',
        'count': _attempts
            .where((a) => (a['score'] ?? 0) >= 70 && (a['score'] ?? 0) < 85)
            .length,
      },
      {
        'key': 'developing',
        'label': 'Developing',
        'count': _attempts
            .where((a) => (a['score'] ?? 0) >= 55 && (a['score'] ?? 0) < 70)
            .length,
      },
      {
        'key': 'needs_improvement',
        'label': 'Needs Work',
        'count': _attempts.where((a) => (a['score'] ?? 0) < 55).length,
      },
    ];

    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedFilter == filter['key'];
          final count = filter['count'] as int;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedFilter = filter['key'] as String;
                _selectedAttempt = null; // Reset detail view
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF1E40AF) : Colors.white,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF1E40AF)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    filter['label'] as String,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF64748B),
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withOpacity(0.2)
                            : const Color(0xFF1E40AF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF1E40AF),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAttemptsList() {
    final filteredAttempts = _filteredAttempts;

    if (filteredAttempts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.filter_list_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No attempts found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filter selection',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAttempts,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredAttempts.length,
        itemBuilder: (context, index) {
          final attempt = filteredAttempts[index];
          return _buildAttemptCard(attempt, index);
        },
      ),
    );
  }

  Widget _buildAttemptCard(Map<String, dynamic> attempt, int index) {
    // ✅ FIXED: Handle both int and double types for score
    final scoreValue = attempt['score'];
    final score = scoreValue is int
        ? scoreValue
        : (scoreValue is double ? scoreValue.round() : 0);

    final attemptNumber = attempt['attemptNumber'] as int? ?? (index + 1);
    final timestamp = attempt['attemptTimestamp'] as DateTime?;
    final timeSpent = attempt['timeSpent'] as int? ?? 0;

    // Extract scenario info from detailed responses
    final detailedResponses =
        attempt['detailedResponses'] as Map<String, dynamic>?;
    final scenarioTitle =
        detailedResponses?['scenarioTitle'] as String? ?? 'Unknown Scenario';
    final transcript =
        detailedResponses?['finalTranscript'] as List<dynamic>? ?? [];
    final feedbackReport =
        detailedResponses?['feedbackReport'] as Map<String, dynamic>?;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedAttempt = attempt;
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E40AF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Attempt #$attemptNumber',
                        style: const TextStyle(
                          color: Color(0xFF1E40AF),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getScoreColor(
                          score.toDouble(),
                        ).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getScoreIcon(score),
                            size: 14,
                            color: _getScoreColor(score.toDouble()),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$score%',
                            style: TextStyle(
                              color: _getScoreColor(score.toDouble()),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  scenarioTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      timestamp != null
                          ? DateFormat('MMM dd, yyyy • HH:mm').format(timestamp)
                          : 'Date unknown',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.timer, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '${_formatDuration(timeSpent)} practice',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${transcript.length} exchanges',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: Colors.grey[400],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttemptDetail() {
    if (_selectedAttempt == null) return const SizedBox();

    final detailedResponses =
        _selectedAttempt!['detailedResponses'] as Map<String, dynamic>?;
    final feedbackReport =
        detailedResponses?['feedbackReport'] as Map<String, dynamic>?;
    final transcript =
        detailedResponses?['finalTranscript'] as List<dynamic>? ?? [];
    final scenarioTitle =
        detailedResponses?['scenarioTitle'] as String? ?? 'Unknown Scenario';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailHeader(),
          const SizedBox(height: 16),
          if (feedbackReport != null) _buildDetailedFeedback(feedbackReport),
          const SizedBox(height: 16),
          _buildTranscriptSection(transcript),
          const SizedBox(height: 80), // Bottom padding
        ],
      ),
    );
  }

  Widget _buildDetailHeader() {
    // ✅ FIXED: Handle both int and double types for score
    final scoreValue = _selectedAttempt!['score'];
    final score = scoreValue is int
        ? scoreValue
        : (scoreValue is double ? scoreValue.round() : 0);

    final attemptNumber = _selectedAttempt!['attemptNumber'] as int? ?? 0;
    final timestamp = _selectedAttempt!['attemptTimestamp'] as DateTime?;
    final detailedResponses =
        _selectedAttempt!['detailedResponses'] as Map<String, dynamic>?;
    final scenarioTitle =
        detailedResponses?['scenarioTitle'] as String? ?? 'Unknown Scenario';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFF1E40AF), const Color(0xFF3B82F6)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedAttempt = null;
                  });
                },
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              const Expanded(
                child: Text(
                  'Attempt Details',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Attempt #$attemptNumber',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            scenarioTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                timestamp != null
                    ? DateFormat('MMMM dd, yyyy • HH:mm').format(timestamp)
                    : 'Date unknown',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$score%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedFeedback(Map<String, dynamic> feedbackReport) {
    final criteria = feedbackReport['criteria'] as List<dynamic>? ?? [];
    final detailedAnalysis =
        feedbackReport['detailedAnalysis'] as Map<String, dynamic>?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Performance Analysis',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 16),
        if (criteria.isNotEmpty) _buildCriteriaCards(criteria),
        if (detailedAnalysis != null) ...[
          const SizedBox(height: 16),
          _buildAnalysisInsights(detailedAnalysis),
        ],
      ],
    );
  }

  Widget _buildCriteriaCards(List<dynamic> criteria) {
    return Column(
      children: criteria.map((criterion) {
        final name = criterion['name'] as String? ?? 'Unknown';

        // ✅ FIXED: Handle both int and double types for score
        final scoreValue = criterion['score'];
        final score = scoreValue is int
            ? scoreValue
            : (scoreValue is double ? scoreValue.round() : 0);

        final feedback =
            criterion['feedback'] as String? ?? 'No feedback available';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  Text(
                    '$score%',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _getScoreColor(score.toDouble()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: score / 100,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  _getScoreColor(score.toDouble()),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                feedback,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAnalysisInsights(Map<String, dynamic> analysis) {
    final strengths = analysis['strengths'] as List<dynamic>? ?? [];
    final improvements =
        analysis['criticalImprovements'] as List<dynamic>? ?? [];

    return Column(
      children: [
        if (strengths.isNotEmpty)
          _buildInsightCard(
            'Strengths',
            strengths.cast<String>(),
            const Color(0xFF10B981),
            Icons.check_circle,
          ),
        if (strengths.isNotEmpty && improvements.isNotEmpty)
          const SizedBox(height: 12),
        if (improvements.isNotEmpty)
          _buildInsightCard(
            'Areas to Improve',
            improvements.cast<String>(),
            const Color(0xFFF59E0B),
            Icons.lightbulb_outline,
          ),
      ],
    );
  }

  Widget _buildInsightCard(
    String title,
    List<String> items,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                            height: 1.4,
                          ),
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

  Widget _buildTranscriptSection(List<dynamic> transcript) {
    if (transcript.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: const Center(
          child: Text(
            'No transcript available for this attempt',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Conversation Transcript',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            children: transcript.map((entry) {
              final speaker = entry['speaker'] as String? ?? 'Unknown';
              final text = entry['text'] as String? ?? '';
              final isUser = speaker == 'User';

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isUser
                            ? const Color(0xFF3B82F6)
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        isUser ? Icons.person : Icons.support_agent,
                        size: 16,
                        color: isUser ? Colors.white : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isUser ? 'You' : 'Customer',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isUser
                                  ? const Color(0xFF3B82F6)
                                  : Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            text,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF1E293B),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // Helper methods
  Color _getScoreColor(double score) {
    if (score >= 85) return const Color(0xFF10B981);
    if (score >= 70) return const Color(0xFF3B82F6);
    if (score >= 55) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  IconData _getScoreIcon(int score) {
    if (score >= 85) return Icons.star;
    if (score >= 70) return Icons.thumb_up;
    if (score >= 55) return Icons.trending_up;
    return Icons.trending_down;
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) {
      return '${seconds}s';
    } else {
      final minutes = seconds ~/ 60;
      final remainingSeconds = seconds % 60;
      if (remainingSeconds == 0) {
        return '${minutes}m';
      } else {
        return '${minutes}m ${remainingSeconds}s';
      }
    }
  }
}
