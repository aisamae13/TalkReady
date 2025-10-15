import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RolePlayConversationPage extends StatefulWidget {
  final String difficulty;
  final String scenarioType;

  const RolePlayConversationPage({
    Key? key,
    required this.difficulty,
    required this.scenarioType,
  }) : super(key: key);

  @override
  State<RolePlayConversationPage> createState() =>
      _RolePlayConversationPageState();
}

class _RolePlayConversationPageState extends State<RolePlayConversationPage> {
  final Logger _logger = Logger();
  final _user = FirebaseAuth.instance.currentUser;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  bool _isSending = false;
  Map<String, dynamic>? _scenario;
  List<Map<String, dynamic>> _conversationHistory = [];
  Map<String, dynamic>? _latestEvaluation;
  String _conversationStatus = 'ongoing';
  int _turnNumber = 1;
  DateTime? _sessionStartTime;

  // Scores tracking
  List<Map<String, dynamic>> _allEvaluations = [];

  static const String _backendUrl = 'https://talkready-backend.onrender.com';

  @override
  void initState() {
    super.initState();
    _sessionStartTime = DateTime.now();
    _loadScenario();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadScenario() async {
    setState(() => _isLoading = true);

    try {
      _logger.i('Loading scenario...');

      final response = await http
          .post(
            Uri.parse('$_backendUrl/generate-roleplay-scenario'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'difficulty': widget.difficulty,
              'scenarioType': widget.scenarioType,
              'userId': _user?.uid,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['scenario'] != null) {
          setState(() {
            _scenario = data['scenario'];
            _isLoading = false;

            // Add initial customer message
            _conversationHistory.add({
              'role': 'customer',
              'message': _scenario!['initialMessage'],
              'timestamp': DateTime.now().toIso8601String(),
            });
          });

          _logger.i('Loaded scenario: ${_scenario!['title']}');
          _scrollToBottom();
        }
      }
    } catch (e) {
      _logger.e('Error loading scenario: $e');
      if (!mounted) return;

      setState(() => _isLoading = false);
      _showError('Failed to load scenario: ${e.toString()}');
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
      _conversationHistory.add({
        'role': 'agent',
        'message': message,
        'timestamp': DateTime.now().toIso8601String(),
      });
      _messageController.clear();
    });

    _scrollToBottom();

    try {
      final response = await http
          .post(
            Uri.parse('$_backendUrl/process-roleplay-response'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'scenarioId': _scenario!['id'],
              'conversationHistory': _conversationHistory,
              'userResponse': message,
              'customerProfile': _scenario!['customerProfile'],
              'scenarioType': widget.scenarioType,
              'turnNumber': _turnNumber,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          setState(() {
            // Add customer response
            _conversationHistory.add({
              'role': 'customer',
              'message': data['customerResponse'],
              'timestamp': DateTime.now().toIso8601String(),
            });

            _latestEvaluation = {
              'evaluation': data['evaluation'],
              'feedback': data['feedback'],
              'responseQuality': data['responseQuality'],
            };

            _allEvaluations.add(_latestEvaluation!);

            _conversationStatus = data['conversationStatus'] ?? 'ongoing';
            _turnNumber = data['turnNumber'] ?? _turnNumber + 1;
            _isSending = false;
          });

          _scrollToBottom();

          // Check if conversation ended
          if (_conversationStatus != 'ongoing') {
            _completeSession();
          }
        }
      }
    } catch (e) {
      _logger.e('Error sending message: $e');
      if (!mounted) return;

      setState(() => _isSending = false);
      _showError('Failed to send message: ${e.toString()}');
    }
  }

  Future<void> _getHint() async {
    try {
      final response = await http
          .post(
            Uri.parse('$_backendUrl/get-roleplay-hint'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'conversationHistory': _conversationHistory,
              'customerProfile': _scenario!['customerProfile'],
              'scenarioType': widget.scenarioType,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _showHintDialog(data['hint'], data['category']);
        }
      }
    } catch (e) {
      _logger.e('Error getting hint: $e');
      _showError('Failed to get hint');
    }
  }

  void _showHintDialog(String hint, String category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.lightbulb, color: Colors.amber),
            const SizedBox(width: 8),
            Text('Hint: ${_formatCategory(category)}'),
          ],
        ),
        content: Text(hint),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  Future<void> _completeSession() async {
    final avgScores = _calculateAverageScores();

    // Save session
    try {
      final duration = DateTime.now().difference(_sessionStartTime!).inSeconds;

      await http
          .post(
            Uri.parse('$_backendUrl/save-roleplay-session'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'userId': _user?.uid,
              'sessionData': {
                'startedAt': _sessionStartTime!.toIso8601String(),
                'scenarioId': _scenario!['id'],
                'scenarioTitle': _scenario!['title'],
                'scenarioType': widget.scenarioType,
                'difficulty': widget.difficulty,
                'conversationHistory': _conversationHistory,
                'turnCount': _turnNumber - 1,
                'finalStatus': _conversationStatus,
                'finalEvaluation': _latestEvaluation,
                'averageScores': avgScores,
                'duration': duration,
              },
            }),
          )
          .timeout(const Duration(seconds: 10));

      _logger.i('Session saved');
    } catch (e) {
      _logger.e('Failed to save session: $e');
    }

    _showCompletionDialog(avgScores);
  }

  Map<String, double> _calculateAverageScores() {
    if (_allEvaluations.isEmpty) {
      return {
        'empathy': 0,
        'professionalism': 0,
        'problemSolving': 0,
        'communication': 0,
        'overall': 0,
      };
    }

    double sumEmpathy = 0;
    double sumProfessionalism = 0;
    double sumProblemSolving = 0;
    double sumCommunication = 0;
    double sumOverall = 0;

    for (var eval in _allEvaluations) {
      final evaluation = eval['evaluation'];
      sumEmpathy += evaluation['empathyScore'] ?? 0;
      sumProfessionalism += evaluation['professionalismScore'] ?? 0;
      sumProblemSolving += evaluation['problemSolvingScore'] ?? 0;
      sumCommunication += evaluation['communicationScore'] ?? 0;
      sumOverall += evaluation['overallScore'] ?? 0;
    }

    final count = _allEvaluations.length;

    return {
      'empathy': sumEmpathy / count,
      'professionalism': sumProfessionalism / count,
      'problemSolving': sumProblemSolving / count,
      'communication': sumCommunication / count,
      'overall': sumOverall / count,
    };
  }

  void _showCompletionDialog(Map<String, double> avgScores) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🎉 Scenario Complete!'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Great work, ${_user?.displayName?.split(' ')[0] ?? 'there'}!',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              _buildScoreBar('Empathy', avgScores['empathy']!.toInt()),
              _buildScoreBar(
                'Professionalism',
                avgScores['professionalism']!.toInt(),
              ),
              _buildScoreBar(
                'Problem Solving',
                avgScores['problemSolving']!.toInt(),
              ),
              _buildScoreBar(
                'Communication',
                avgScores['communication']!.toInt(),
              ),
              const Divider(height: 32),
              _buildScoreBar(
                'Overall',
                avgScores['overall']!.toInt(),
                isOverall: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            child: const Text('Try Another'),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreBar(String label, int score, {bool isOverall = false}) {
    final color = _getScoreColor(score);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: isOverall ? 16 : 14,
                  fontWeight: isOverall ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              Text(
                '$score%',
                style: TextStyle(
                  fontSize: isOverall ? 16 : 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: isOverall ? 12 : 8,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.blue;
    if (score >= 40) return Colors.orange;
    return Colors.red;
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatCategory(String category) {
    return category
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('🎭 Role-Play'),
          backgroundColor: Colors.teal,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.teal),
              SizedBox(height: 16),
              Text('Loading scenario...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_scenario!['title']),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.lightbulb_outline),
            onPressed: _getHint,
            tooltip: 'Get hint',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showScenarioInfo,
            tooltip: 'Scenario info',
          ),
        ],
      ),
      body: Column(
        children: [
          // Scenario banner
          _buildScenarioBanner(),

          // Conversation area
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _conversationHistory.length,
              itemBuilder: (context, index) {
                return _buildMessageBubble(_conversationHistory[index]);
              },
            ),
          ),

          // Latest evaluation
          if (_latestEvaluation != null) _buildEvaluationCard(),

          // Input area
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildScenarioBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.teal.shade50,
      child: Row(
        children: [
          const Icon(Icons.person, color: Colors.teal),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Customer: ${_scenario!['customerProfile']['name']} (${_scenario!['customerProfile']['mood']})',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.teal,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Turn $_turnNumber',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isCustomer = message['role'] == 'customer';

    return Align(
      alignment: isCustomer ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: isCustomer
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isCustomer) ...[
                  const Icon(Icons.person, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                ],
                Text(
                  isCustomer ? 'Customer' : 'You',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (!isCustomer) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.support_agent, size: 16, color: Colors.grey),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isCustomer ? Colors.grey.shade200 : Colors.teal.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                message['message'],
                style: const TextStyle(fontSize: 15, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEvaluationCard() {
    final eval = _latestEvaluation!;
    final quality = eval['responseQuality'];
    final feedback = eval['feedback'];

    Color qualityColor = Colors.grey;
    IconData qualityIcon = Icons.info;

    switch (quality) {
      case 'excellent':
        qualityColor = Colors.green;
        qualityIcon = Icons.emoji_events;
        break;
      case 'good':
        qualityColor = Colors.blue;
        qualityIcon = Icons.thumb_up;
        break;
      case 'needs_improvement':
        qualityColor = Colors.orange;
        qualityIcon = Icons.trending_up;
        break;
      case 'poor':
        qualityColor = Colors.red;
        qualityIcon = Icons.warning;
        break;
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: qualityColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: qualityColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(qualityIcon, color: qualityColor, size: 20),
              const SizedBox(width: 8),
              Text(
                quality.replaceAll('_', ' ').toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: qualityColor,
                ),
              ),
            ],
          ),
          if (feedback['suggestion'] != null) ...[
            const SizedBox(height: 8),
            Text(feedback['suggestion'], style: const TextStyle(fontSize: 13)),
          ],
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type your response...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              enabled: !_isSending && _conversationStatus == 'ongoing',
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            onPressed: _isSending || _conversationStatus != 'ongoing'
                ? null
                : _sendMessage,
            backgroundColor: Colors.teal,
            mini: true,
            child: _isSending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send),
          ),
        ],
      ),
    );
  }

  void _showScenarioInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_scenario!['title']),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _scenario!['description'],
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              const Text(
                'Learning Objectives:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...((_scenario!['learningObjectives'] ?? []) as List).map(
                (obj) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• '),
                      Expanded(child: Text(obj)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Key Phrases to Use:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...((_scenario!['keyPhrases'] ?? []) as List).map(
                (phrase) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '"$phrase"',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
