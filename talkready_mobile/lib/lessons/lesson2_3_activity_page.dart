// lib/lessons/lesson2_3_activity_page.dart
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../services/unified_progress_service.dart';
import '../widgets/ai_feedback_display_card.dart';

class Lesson2_3ActivityPage extends StatefulWidget {
  final String lessonId;
  final String lessonTitle;
  final Map<String, dynamic> lessonData;
  final int attemptNumber;

  const Lesson2_3ActivityPage({
    super.key,
    required this.lessonId,
    required this.lessonTitle,
    required this.lessonData,
    required this.attemptNumber,
  });

  @override
  State<Lesson2_3ActivityPage> createState() => _Lesson2_3ActivityPageState();
}

class _Lesson2_3ActivityPageState extends State<Lesson2_3ActivityPage> {
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
      if (prompt['type'] == 'multiple-choice') {
        _answers[key] = '';
      } else {
        _controllers[key] = TextEditingController(
          text: prompt['prefilledText'] as String?,
        );
        _answers[key] = prompt['prefilledText'] ?? '';
      }
    }
  }

  Future<void> _getInitialFeedback() async {
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    _controllers.forEach((key, controller) {
      _answers[key] = controller.text;
    });

    if (_answers.values.any(
      (answer) => (answer as String? ?? '').trim().isEmpty,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please answer all prompts.'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoading = false);
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveFinalAttempt() async {
    setState(() => _isLoading = true);
    int totalScore = 0;
    _feedback.forEach((_, value) {
      totalScore += (value['score'] as int? ?? 0);
    });

    final detailedResponses = {
      'scenarioAnswers_L2_3': _answers,
      'scenarioFeedback_L2_3': _feedback,
    };

    try {
      await _progressService.saveLessonAttempt(
        lessonId: widget.lessonId,
        score: totalScore,
        maxScore:
            widget.lessonData['activity']['maxPossibleAIScore'] as int? ?? 25,
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
    _controllers.values.forEach((c) => c.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showFinalResults) return _buildResultsView();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lessonData['activity']['title'] ?? 'Activity'),
        backgroundColor: const Color(0xFFF4D03F),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildInstructionsCard(),
            const SizedBox(height: 16),
            ..._buildScenarioWidgets(),
            const SizedBox(height: 24),
            _buildActionButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionsCard() {
    final instructions =
        widget.lessonData['activity']['instructions']
            as Map<String, dynamic>? ??
        {};
    final listItems = List<String>.from(instructions['listItems'] ?? []);
    return Card(
      color: Colors.yellow[50],
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📘 ${instructions['heading'] ?? 'Instructions'}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(instructions['introParagraph'] ?? ''),
            ...listItems.map(
              (item) => Padding(
                padding: const EdgeInsets.only(left: 16.0, top: 4.0),
                child: Text("• ${item.replaceAll(RegExp(r'<[^>]*>'), '')}"),
              ),
            ),
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
      // **FIX:** The Card is now directly returned by the map function
      return _buildSingleScenario(prompt: entry.value, index: entry.key);
    }).toList();
  }

  // **FIX:** This function now correctly returns a single Card widget
  Widget _buildSingleScenario({
    required Map<String, dynamic> prompt,
    required int index,
  }) {
    final key = prompt['name'] as String;
    final feedbackData = _feedback[key] as Map<String, dynamic>?;
    final isFieldDisabled =
        _isLoading || (_initialFeedbackReceived && !_isRevising);
    final isMCQ = prompt['type'] == 'multiple-choice';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${index + 1}. ${prompt['promptText']}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${prompt['information']}',
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
                  if (prompt['customerText'] != null)
                    Text(
                      '${prompt['customerText']}',
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                  if (prompt['agentText'] != null)
                    Text(
                      '${prompt['agentText']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (isMCQ)
              ...List<String>.from(prompt['options']).map(
                (opt) => RadioListTile<String>(
                  title: Text(opt),
                  value: opt,
                  groupValue: _answers[key],
                  onChanged: isFieldDisabled
                      ? null
                      : (val) => setState(() => _answers[key] = val!),
                ),
              ),
            if (!isMCQ)
              TextField(
                controller: _controllers[key],
                decoration: InputDecoration(
                  hintText: prompt['placeholder'],
                  border: const OutlineInputBorder(),
                  filled: isFieldDisabled,
                  fillColor: Colors.grey[200],
                ),
                enabled: !isFieldDisabled,
              ),
            if (_initialFeedbackReceived && feedbackData != null)
              AiFeedbackDisplayCard(feedbackData: feedbackData),
          ],
        ),
      ),
    );
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
