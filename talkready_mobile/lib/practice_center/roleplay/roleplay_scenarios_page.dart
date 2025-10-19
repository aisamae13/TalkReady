import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'roleplay_conversation_page.dart';

class RolePlayScenariosPage extends StatefulWidget {
  const RolePlayScenariosPage({Key? key}) : super(key: key);

  @override
  State<RolePlayScenariosPage> createState() => _RolePlayScenariosPageState();
}

class _RolePlayScenariosPageState extends State<RolePlayScenariosPage> {
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
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      _logger.i('Loading roleplay stats...');

      final response = await http
          .post(
            Uri.parse('$_backendUrl/get-roleplay-history'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'userId': _user?.uid, 'limit': 10}),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Request timed out');
            },
          );

      if (!mounted) return;

      _logger.i('Response status: ${response.statusCode}');
      _logger.i('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (!mounted) return;

          setState(() {
            _stats = data['overallStats'];
            _isLoading = false;
          });
          _logger.i('Loaded roleplay stats successfully');
          return; // ✅ Exit early on success
        } else {
          throw Exception(data['error'] ?? 'Failed to load stats');
        }
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      _logger.e('Error loading stats: $e');

      if (!mounted) return;

      // ✅ CONTINUE ANYWAY - Don't block the UI
      setState(() {
        _stats = null; // No stats available
        _isLoading = false;
      });

      // Show error but allow user to continue
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not load stats: ${e.toString()}'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Role-Play Scenarios'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
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

                  // Title
                  const Text(
                    'Choose Your Scenario',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Practice real customer service conversations',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),

                  // Difficulty Selection
                  const Text(
                    'Select Difficulty',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  _buildDifficultySection(),
                  const SizedBox(height: 24),

                  // Scenario Types
                  const Text(
                    'Scenario Types',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  _buildScenarioTypes(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsCard() {
    final roleplayStats = _stats ?? {};
    final totalSessions = roleplayStats['totalSessions'] ?? 0;
    final avgEmpathy = (roleplayStats['averageEmpathy'] ?? 0).toInt();
    final avgOverall = (roleplayStats['averageOverall'] ?? 0).toInt();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal.shade50, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Performance',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Sessions', '$totalSessions', Icons.play_circle),
                _buildStatItem('Empathy', '$avgEmpathy%', Icons.favorite),
                _buildStatItem('Overall', '$avgOverall%', Icons.star),
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
        Icon(icon, color: Colors.teal, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.teal,
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

  String _selectedDifficulty = 'beginner';

  Widget _buildDifficultySection() {
    return Row(
      children: [
        Expanded(
          child: _buildDifficultyChip(
            'Beginner',
            'beginner',
            Icons.star_border,
            Colors.green,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildDifficultyChip(
            'Intermediate',
            'intermediate',
            Icons.star_half,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildDifficultyChip(
            'Advanced',
            'advanced',
            Icons.star,
            Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildDifficultyChip(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final isSelected = _selectedDifficulty == value;

    return InkWell(
      onTap: () => setState(() => _selectedDifficulty = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.white,
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScenarioTypes() {
    final scenarios = [
      {
        'type': 'angry_customer',
        'icon': '😠',
        'title': 'Angry Customer',
        'description': 'De-escalate upset customers',
        'color': Colors.red,
      },
      {
        'type': 'refund_request',
        'icon': '💰',
        'title': 'Refund Request',
        'description': 'Process returns professionally',
        'color': Colors.blue,
      },
      {
        'type': 'technical_support',
        'icon': '🔧',
        'title': 'Tech Support',
        'description': 'Troubleshoot issues step-by-step',
        'color': Colors.purple,
      },
      {
        'type': 'billing_dispute',
        'icon': '📊',
        'title': 'Billing Dispute',
        'description': 'Resolve payment concerns',
        'color': Colors.orange,
      },
      {
        'type': 'product_inquiry',
        'icon': '🛍️',
        'title': 'Product Info',
        'description': 'Answer product questions',
        'color': Colors.green,
      },
      {
        'type': 'complaint_handling',
        'icon': '📝',
        'title': 'Complaint',
        'description': 'Handle formal complaints',
        'color': Colors.deepOrange,
      },
      {
        'type': 'account_issues',
        'icon': '👤',
        'title': 'Account Issues',
        'description': 'Fix account problems',
        'color': Colors.indigo,
      },
      {
        'type': 'delivery_problem',
        'icon': '📦',
        'title': 'Delivery Issue',
        'description': 'Resolve shipping problems',
        'color': Colors.brown,
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: scenarios.length,
      itemBuilder: (context, index) {
        final scenario = scenarios[index];
        return _buildScenarioCard(
          type: scenario['type'] as String,
          icon: scenario['icon'] as String,
          title: scenario['title'] as String,
          description: scenario['description'] as String,
          color: scenario['color'] as Color,
        );
      },
    );
  }

  Widget _buildScenarioCard({
    required String type,
    required String icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return InkWell(
      onTap: () => _startScenario(type),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.1), Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(icon, style: const TextStyle(fontSize: 40)),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
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

  void _startScenario(String scenarioType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RolePlayConversationPage(
          difficulty: _selectedDifficulty,
          scenarioType: scenarioType,
        ),
      ),
    ).then((_) => _loadStats());
  }
}
