// lib/lessons/lesson2_2_activity_page.dart
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../services/unified_progress_service.dart';
import '../widgets/ai_feedback_display_card.dart';

class Lesson2_2ActivityPage extends StatefulWidget {
  final String lessonId;
  final String lessonTitle;
  final Map<String, dynamic> lessonData;
  final int attemptNumber;

  const Lesson2_2ActivityPage({
    super.key,
    required this.lessonId,
    required this.lessonTitle,
    required this.lessonData,
    required this.attemptNumber,
  });

  @override
  State<Lesson2_2ActivityPage> createState() => _Lesson2_2ActivityPageState();
}

class _Lesson2_2ActivityPageState extends State<Lesson2_2ActivityPage> {
  final UnifiedProgressService _progressService = UnifiedProgressService();
  final Logger _logger = Logger();

  final Map<String, TextEditingController> _controllers = {};
  Map<String, dynamic> _answers = {};
  Map<String, dynamic> _feedback = {};

  bool _isLoading = false;
  bool _initialFeedbackReceived = false;
  bool _isRevising = false;
  bool _showFinalResults = false;

  @override
  void initState() {
    super.initState();
    _initializeActivity();
  }

  void _initializeActivity() {
    final prompts = List<Map<String, dynamic>>.from(
      widget.lessonData['activity']['prompts'] ?? [],
    );
    for (var prompt in prompts) {
      final key = prompt['name'] as String;
      _controllers[key] = TextEditingController();
      _answers[key] = '';
    }
  }

  Future<void> _getInitialFeedback() async {
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    _controllers.forEach((key, controller) {
      _answers[key] = controller.text;
    });

    if (_answers.values.any((answer) => (answer as String).trim().isEmpty)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please provide an answer for all scenarios.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      final feedbackResult = await _progressService.getScenarioFeedback(
        widget.lessonId,
        _answers.cast<String, String>(),
      );
      if (mounted) {
        setState(() {
          _feedback = feedbackResult;
          _initialFeedbackReceived = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      _logger.e('Failed to get feedback: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error getting feedback. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveFinalAttempt() async {
    setState(() => _isLoading = true);
    int totalScore = 0;
    _feedback.forEach((key, value) {
      totalScore += (value['score'] as int? ?? 0);
    });

    // **CRITICAL:** Use keys specific to Lesson 2.2 for data synchronization
    final detailedResponses = {
      'scenarioAnswers_L2_2': _answers,
      'scenarioFeedback_L2_2': _feedback,
    };

    try {
      await _progressService.saveLessonAttempt(
        lessonId: widget.lessonId,
        score: totalScore,
        maxScore:
            widget.lessonData['activity']['maxPossibleAIScore'] as int? ?? 10,
        timeSpent: 0,
        detailedResponses: detailedResponses,
      );
      if (mounted) setState(() => _showFinalResults = true);
    } catch (e) {
      _logger.e('Failed to save final attempt: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showFinalResults) return _buildResultsView();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lessonData['activity']['title'] ?? 'Activity'),
        backgroundColor: const Color(0xFF48C9B0),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              color: Colors.teal[50],
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📘 Instructions',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• ${widget.lessonData['activity']['instruction'] ?? ''}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ..._buildScenarioWidgets(),
            const SizedBox(height: 24),
            _buildActionButton(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildScenarioWidgets() {
    final prompts = List<Map<String, dynamic>>.from(
      widget.lessonData['activity']['prompts'] ?? [],
    );
    return prompts.asMap().entries.map((entry) {
      int idx = entry.key;
      Map<String, dynamic> prompt = entry.value;

      final key = prompt['name'] as String;
      final feedbackData = _feedback[key] as Map<String, dynamic>?;
      final isTextFieldDisabled =
          _isLoading || (_initialFeedbackReceived && !_isRevising);

      return Card(
        elevation: 2,
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${idx + 1}. ${prompt['label']}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Text(
                  '${prompt['customerText']}',
                  style: const TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controllers[key],
                decoration: InputDecoration(
                  hintText: 'Your professional response...',
                  border: const OutlineInputBorder(),
                  filled: isTextFieldDisabled,
                  fillColor: Colors.grey[200],
                ),
                maxLines: 4,
                enabled: !isTextFieldDisabled,
                textCapitalization: TextCapitalization.sentences,
              ),
              if (_initialFeedbackReceived && feedbackData != null)
                AiFeedbackDisplayCard(feedbackData: feedbackData),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildActionButton() {
    if (_isLoading) {
      return const CircularProgressIndicator();
    }
    if (!_initialFeedbackReceived) {
      return ElevatedButton.icon(
        icon: const Icon(Icons.send),
        onPressed: _getInitialFeedback,
        label: const Text('Submit for Feedback'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      );
    }
    if (_isRevising) {
      return ElevatedButton.icon(
        icon: const Icon(Icons.check),
        onPressed: _getInitialFeedback,
        label: const Text('Submit Revised Answers'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        TextButton.icon(
          icon: const Icon(Icons.edit),
          onPressed: () => setState(() => _isRevising = true),
          label: const Text('Revise Answers'),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.save),
          onPressed: _saveFinalAttempt,
          label: const Text('Finish & Save'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
        ),
      ],
    );
  }

  Widget _buildResultsView() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 80),
            const SizedBox(height: 16),
            const Text(
              'Progress Saved!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                int count = 0;
                Navigator.of(context).popUntil((_) => count++ >= 2);
              },
              child: const Text('Back to Module Overview'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Review Lesson'),
            ),
          ],
        ),
      ),
    );
  }
}
