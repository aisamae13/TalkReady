// lib/lessons/lesson4_1_activity_page.dart
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';
import '../services/unified_progress_service.dart';

class Lesson4_1ActivityPage extends StatefulWidget {
  final String lessonId;
  final String lessonTitle;
  final Map<String, dynamic> lessonData;
  final int attemptNumber;

  const Lesson4_1ActivityPage({
    super.key,
    required this.lessonId,
    required this.lessonTitle,
    required this.lessonData,
    required this.attemptNumber,
  });

  @override
  State<Lesson4_1ActivityPage> createState() => _Lesson4_1ActivityPageState();
}

class _Lesson4_1ActivityPageState extends State<Lesson4_1ActivityPage> {
  final Logger _logger = Logger();
  final UnifiedProgressService _progressService = UnifiedProgressService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Form controllers and state
  Map<String, TextEditingController> _controllers = {};
  Map<String, String> _answers = {};
  Map<String, dynamic> _feedback = {};
  bool _isSubmitting = false;
  bool _showResults = false;
  int? _overallScore;

  // ✅ REMOVED: Timer completely (no timer variables)

  // Activity configuration
  List<Map<String, dynamic>> _scenarios = [];
  int _currentScenarioIndex = 0;

  // New state for web-like functionality
  Map<String, bool> _isScriptVisible = {};
  Map<String, bool> _isAudioLoading = {};
  Map<String, bool> _isCheckingAnswer = {};

  @override
  void initState() {
    super.initState();
    _initializeActivity();
    // ✅ REMOVED: _startTimer() call
  }

  @override
  void dispose() {
    // ✅ REMOVED: _timerInstance?.cancel();
    _audioPlayer.dispose();
    _controllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  void _initializeActivity() {
    // ✅ FIXED: Extract scenarios from lesson data (from Firebase)
    final activityData = widget.lessonData['activity'];
    if (activityData != null && activityData['scenarios'] != null) {
      _scenarios = List<Map<String, dynamic>>.from(activityData['scenarios']);
      _logger.i('Loaded ${_scenarios.length} scenarios from lesson data');
    } else {
      _logger.w('No scenarios found in lesson data, using defaults');
      // Fallback to defaults only if Firebase data is missing
      _scenarios = _getDefaultClarificationScenarios();
    }

    // Initialize controllers and state for each scenario
    final newAnswers = <String, String>{};
    final newControllers = <String, TextEditingController>{};

    for (int i = 0; i < _scenarios.length; i++) {
      final scenario = _scenarios[i];
      final scenarioId = scenario['id'] ?? 'scenario${i + 1}';

      newAnswers[scenarioId] = '';
      newControllers[scenarioId] = TextEditingController();
      _isScriptVisible[scenarioId] = false;
      _isAudioLoading[scenarioId] = false;
      _isCheckingAnswer[scenarioId] = false;
    }

    setState(() {
      _answers = newAnswers;
      _controllers = newControllers;
    });
  }

  // ✅ FIXED: Generate customer statement from parts
  String _getCustomerStatementFromParts(Map<String, dynamic> scenario) {
    if (scenario['parts'] != null && scenario['parts'] is List) {
      final parts = scenario['parts'] as List;
      return parts.map((part) => part['text'] ?? '').join(' ');
    }

    // Fallback to customerStatement if it exists
    if (scenario['customerStatement'] != null) {
      return scenario['customerStatement'];
    }

    // Default fallback
    return 'Customer statement not available';
  }

  List<Map<String, dynamic>> _getDefaultClarificationScenarios() {
    // Keep this as fallback only
    return [
      {
        'id': 'scenario1',
        'parts': [
          {'text': 'Yes, my order was', 'effect': 'normal'},
          {'text': 'something about the delivery', 'effect': 'muffled'},
          {'text': 'and I need to change the delivery.', 'effect': 'normal'},
        ],
      },
      {
        'id': 'scenario2',
        'parts': [
          {'text': 'My email is zlaytsev_b12@yahoo.com.', 'effect': 'fast'},
        ],
      },
      {
        'id': 'scenario3',
        'parts': [
          {'text': 'The item number is 47823A.', 'effect': 'normal'},
        ],
      },
      {
        'id': 'scenario4',
        'parts': [
          {
            'text':
                'Yeah I called yesterday and they said it\'d be fixed in two days but it\'s not.',
            'effect': 'frustrated',
          },
        ],
      },
    ];
  }

  // Audio playback for scenarios
  Future<void> _playScenarioAudio(String scenarioId) async {
    final scenario = _scenarios.firstWhere((s) => s['id'] == scenarioId);
    if (scenario['parts'] == null) return;

    setState(() => _isAudioLoading[scenarioId] = true);

    try {
      final response = await _progressService.synthesizeSpeechFromTurns(
        scenario['parts'],
      );

      if (response != null) {
        final tempDir = await getTemporaryDirectory();
        final audioFile = File('${tempDir.path}/scenario_$scenarioId.wav');
        await audioFile.writeAsBytes(response);

        await _audioPlayer.setFilePath(audioFile.path);
        await _audioPlayer.play();

        _audioPlayer.playerStateStream.listen((state) {
          if (state.processingState == ProcessingState.completed) {
            if (mounted) {
              setState(() => _isAudioLoading[scenarioId] = false);
            }
          }
        });
      } else {
        setState(() => _isAudioLoading[scenarioId] = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Audio service unavailable')),
        );
      }
    } catch (e) {
      _logger.e('Error playing scenario audio: $e');
      setState(() => _isAudioLoading[scenarioId] = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Error playing audio')));
    }
  }

  // Alternative using service method
  // Check individual answer - FIXED to use same endpoint as web
  Future<void> _checkSingleAnswer(String scenarioId) async {
    final userAnswer = _controllers[scenarioId]?.text ?? '';
    if (userAnswer.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide an answer before checking.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isCheckingAnswer[scenarioId] = true);

    try {
      // ✅ FIXED: Use the same endpoint as web (/evaluate-clarification)
      final baseUrl = await _progressService.getApiBaseUrl();
      final response = await http.post(
        Uri.parse('$baseUrl/evaluate-clarification'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'TalkReady-Mobile/1.0',
        },
        body: jsonEncode({
          'answers': {
            scenarioId: userAnswer,
          }, // Send only the current scenario's answer
          'lesson': '4.1',
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('AI Evaluation failed.');
      }

      final result = jsonDecode(response.body);

      // Update the main feedback state with the new feedback for this specific scenario
      setState(() {
        if (result['feedback'] != null) {
          _feedback[scenarioId] = result['feedback'][scenarioId];
        }
        _isCheckingAnswer[scenarioId] = false;
      });
    } catch (e) {
      _logger.e('Error checking single scenario: $e');
      setState(() => _isCheckingAnswer[scenarioId] = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error checking answer. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ✅ REMOVED: Timer methods completely

  // In lib/lessons/lesson4_1_activity_page.dart

  Future<void> _handleFinalSubmit() async {
    if (_isSubmitting || _showResults) return;

    // Update the final answers map from the text controllers
    _controllers.forEach((key, controller) => _answers[key] = controller.text);

    setState(() => _isSubmitting = true);

    try {
      // --- THIS IS THE FIX ---
      // The keys in this map must match the web version exactly.
      final detailedResponsesPayload = {
        'scenarioResponses': _answers, // CHANGED from 'scenarioAnswers'
        'aiFeedbackForScenarios': _feedback, // CHANGED from 'scenarioFeedback'
      };
      // The other fields (timeSpent, etc.) are already at the top level
      // of the attempt record, so they are not needed inside this map.
      // --- END OF FIX ---

      // Calculate the overall score out of 10, just like the web version
      double calculatedScore = 0;
      _feedback.forEach((_, value) {
        final scoreValue = (value is Map) ? value['score'] : null;
        if (scoreValue is num) {
          // The score per scenario is out of 2.5 on the web version
          calculatedScore += scoreValue;
        }
      });

      await _progressService.saveLessonAttempt(
        lessonId: widget.lessonId,
        score: calculatedScore.round(), // Save the final calculated score
        maxScore: 10, // The max possible score for this activity is 10
        timeSpent: 0, // You removed the timer, so this is correct
        detailedResponses: detailedResponsesPayload,
      );

      if (mounted) {
        setState(() {
          _overallScore = calculatedScore.round();
          _showResults = true;
          _isSubmitting = false;
        });
      }
    } catch (e) {
      _logger.e('Error during final submission: $e');
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error submitting your responses. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _nextScenario() {
    if (_currentScenarioIndex < _scenarios.length - 1) {
      setState(() => _currentScenarioIndex++);
    }
  }

  void _previousScenario() {
    if (_currentScenarioIndex > 0) {
      setState(() => _currentScenarioIndex--);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _showResults ? "Activity Results" : "Clarification Role-Play",
        ),
        backgroundColor: const Color(0xFF9C27B0),
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      body: _isSubmitting
          ? _buildLoadingScreen()
          : _showResults
          ? _buildResultsView()
          : _buildActivityContent(),
    );
  }

  Widget _buildActivityContent() {
    if (_scenarios.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No scenarios available for this lesson.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildCurrentScenario(),
          const SizedBox(height: 24),
          _buildNavigationButtons(),
          const SizedBox(height: 20),
          if (_allScenariosCompleted()) _buildFinalSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF9C27B0), Color(0xFF7B1FA2)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.record_voice_over,
                      color: Colors.white,
                      size: 24,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Clarification Role-Play',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Scenario ${_currentScenarioIndex + 1} of ${_scenarios.length}',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Attempt: ${widget.attemptNumber}',
                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (_currentScenarioIndex + 1) / _scenarios.length,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 6,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentScenario() {
    final currentScenario = _scenarios[_currentScenarioIndex];
    final scenarioId = currentScenario['id'];
    final hasFeedback = _feedback.containsKey(scenarioId);

    // ✅ FIXED: Get customer statement from parts
    final customerStatement = _getCustomerStatementFromParts(currentScenario);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Scenario instruction (like web version)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Scenario ${_currentScenarioIndex + 1} of ${_scenarios.length}: Listen to the customer\'s statement.',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // ✅ FIXED: Show script functionality with proper customer statement
                        if (_isScriptVisible[scenarioId] == true)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(top: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Text(
                              '"$customerStatement"',
                              style: const TextStyle(
                                fontSize: 16,
                                fontStyle: FontStyle.italic,
                                color: Colors.blue,
                              ),
                            ),
                          )
                        else
                          TextButton(
                            onPressed: () {
                              setState(
                                () => _isScriptVisible[scenarioId] = true,
                              );
                            },
                            child: const Text(
                              'Show Script',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Play button (like web)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade500,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: (_isAudioLoading[scenarioId] == true)
                          ? null
                          : () => _playScenarioAudio(scenarioId),
                      icon: Icon(
                        (_isAudioLoading[scenarioId] == true)
                            ? Icons.hourglass_empty
                            : Icons.volume_up,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Answer text field (like web)
            TextField(
              controller: _controllers[scenarioId],
              enabled: !hasFeedback,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Your clarification response...',
                border: const OutlineInputBorder(),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF9C27B0), width: 2),
                ),
                filled: hasFeedback,
                fillColor: hasFeedback ? Colors.grey[100] : null,
              ),
            ),

            const SizedBox(height: 16),

            // Action buttons row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Previous button
                ElevatedButton(
                  onPressed: _currentScenarioIndex > 0
                      ? _previousScenario
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade600,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Previous'),
                ),

                // ✅ SIMPLIFIED: Only Check Answer or Next buttons
                if (!hasFeedback)
                  ElevatedButton(
                    onPressed: (_isCheckingAnswer[scenarioId] == true)
                        ? null
                        : () => _checkSingleAnswer(scenarioId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                    ),
                    child: (_isCheckingAnswer[scenarioId] == true)
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text('Check Answer'),
                  )
                else if (_currentScenarioIndex < _scenarios.length - 1)
                  ElevatedButton(
                    onPressed: _nextScenario,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.shade500,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Next Scenario'),
                  ),
                // ✅ NO else clause - removed duplicate button
              ],
            ),

            // Feedback display (like web)
            if (hasFeedback) _buildFeedbackDisplay(scenarioId),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackDisplay(String scenarioId) {
    final feedback = _feedback[scenarioId];
    if (feedback == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.indigo.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with score
          Row(
            children: [
              const Icon(Icons.psychology, color: Colors.indigo, size: 20),
              const SizedBox(width: 8),
              const Text(
                'AI Feedback',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              if (feedback['score'] != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getScoreColor(
                      (feedback['score'] as num).toDouble() * 20,
                    ), // ✅ FIXED
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Score: ${(feedback['score'] as num).toStringAsFixed(1)}/2.5', // ✅ FIXED
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Score Progress Bar
          if (feedback['score'] != null) ...[
            Container(
              width: double.infinity,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: ((feedback['score'] as num).toDouble() / 2.5)
                    .clamp(0.0, 1.0), // ✅ FIXED
                child: Container(
                  decoration: BoxDecoration(
                    color: _getScoreColor(
                      (feedback['score'] as num).toDouble() * 20,
                    ), // ✅ FIXED
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Parse and display feedback sections
          ..._parseFeedbackSections(feedback['text'] ?? ''),
        ],
      ),
    );
  }

  // Fixed method with valid Flutter icons
  // Updated method to handle JSON structure from server
  List<Widget> _parseFeedbackSections(String feedbackText) {
    List<Widget> sections = [];

    try {
      // First, try to parse the feedback as JSON
      final feedbackData = jsonDecode(feedbackText);

      if (feedbackData is Map && feedbackData.containsKey('sections')) {
        final sectionsArray = feedbackData['sections'] as List;

        for (int index = 0; index < sectionsArray.length; index++) {
          final section = sectionsArray[index];
          if (section is Map &&
              section.containsKey('title') &&
              section.containsKey('text')) {
            final title = section['title'] as String;
            final content = section['text'] as String;

            // Map the titles to appropriate icons and colors
            final iconData = _getIconForFeedbackTitle(title);
            final color = _getColorForFeedbackTitle(title);

            sections.add(
              _buildFeedbackSection(title, content, iconData, color, index),
            );
          }
        }
      }
    } catch (e) {
      // If JSON parsing fails, try the old text-based parsing
      _logger.w('Failed to parse JSON feedback, trying text parsing: $e');
      sections = _parseTextBasedFeedback(feedbackText);
    }

    // If no sections were parsed, show the raw feedback
    if (sections.isEmpty && feedbackText.isNotEmpty) {
      sections.add(
        _buildFeedbackSection(
          'Detailed Feedback',
          feedbackText,
          Icons.info,
          Colors.grey.shade600,
          0,
        ),
      );
    }

    return sections;
  }

  // Helper method to get icons based on feedback titles
  IconData _getIconForFeedbackTitle(String title) {
    final titleLower = title.toLowerCase();

    if (titleLower.contains('effectiveness') ||
        titleLower.contains('clarification')) {
      return Icons.gps_fixed;
    } else if (titleLower.contains('politeness') ||
        titleLower.contains('professionalism')) {
      return Icons.handshake;
    } else if (titleLower.contains('clarity') ||
        titleLower.contains('conciseness')) {
      return Icons.search;
    } else if (titleLower.contains('grammar') ||
        titleLower.contains('phrasing')) {
      return Icons.spellcheck;
    } else if (titleLower.contains('suggestion') ||
        titleLower.contains('improvement')) {
      return Icons.star;
    } else if (titleLower.contains('greeting')) {
      return Icons.waving_hand;
    } else {
      return Icons.info;
    }
  }

  // Helper method to get colors based on feedback titles
  Color _getColorForFeedbackTitle(String title) {
    final titleLower = title.toLowerCase();

    if (titleLower.contains('effectiveness') ||
        titleLower.contains('clarification')) {
      return Colors.blue.shade600;
    } else if (titleLower.contains('politeness') ||
        titleLower.contains('professionalism')) {
      return Colors.green.shade600;
    } else if (titleLower.contains('clarity') ||
        titleLower.contains('conciseness')) {
      return Colors.amber.shade700;
    } else if (titleLower.contains('grammar') ||
        titleLower.contains('phrasing')) {
      return Colors.purple.shade600;
    } else if (titleLower.contains('suggestion') ||
        titleLower.contains('improvement')) {
      return Colors.orange.shade600;
    } else if (titleLower.contains('greeting')) {
      return Colors.teal.shade600;
    } else {
      return Colors.grey.shade600;
    }
  }

  // Fallback method for text-based parsing (your original logic)
  List<Widget> _parseTextBasedFeedback(String feedbackText) {
    final feedbackCategories = [
      {
        'title': 'Effectiveness of Clarification',
        'icon': Icons.gps_fixed,
        'color': Colors.blue.shade600,
      },
      {
        'title': 'Politeness and Professionalism',
        'icon': Icons.handshake,
        'color': Colors.green.shade600,
      },
      {
        'title': 'Clarity and Conciseness',
        'icon': Icons.search,
        'color': Colors.amber.shade700,
      },
      {
        'title': 'Grammar and Phrasing',
        'icon': Icons.spellcheck,
        'color': Colors.purple.shade600,
      },
      {
        'title': 'Suggestion for Improvement',
        'icon': Icons.star,
        'color': Colors.orange.shade600,
      },
    ];

    List<Widget> sections = [];
    String remainingText = feedbackText;

    for (int index = 0; index < feedbackCategories.length; index++) {
      final category = feedbackCategories[index];
      final title = category['title'] as String;

      final titleRegex = RegExp(
        '\\*\\*${RegExp.escape(title)}:?\\*\\*',
        caseSensitive: false,
      );

      final match = titleRegex.firstMatch(remainingText);

      if (match != null) {
        final contentStartIndex = match.end;
        int contentEndIndex = remainingText.length;

        if (index + 1 < feedbackCategories.length) {
          final nextCategory = feedbackCategories[index + 1];
          final nextTitle = nextCategory['title'] as String;
          final nextTitleRegex = RegExp(
            '\\*\\*${RegExp.escape(nextTitle)}:?\\*\\*',
            caseSensitive: false,
          );

          final nextMatch = nextTitleRegex.firstMatch(
            remainingText.substring(contentStartIndex),
          );

          if (nextMatch != null) {
            contentEndIndex = contentStartIndex + nextMatch.start;
          }
        }

        final sectionContent = remainingText
            .substring(contentStartIndex, contentEndIndex)
            .trim();

        if (sectionContent.isNotEmpty) {
          sections.add(
            _buildFeedbackSection(
              title,
              sectionContent,
              category['icon'] as IconData,
              category['color'] as Color,
              index,
            ),
          );
        }
      }
    }

    return sections;
  }

  Widget _buildFeedbackSection(
    String title,
    String content,
    IconData icon,
    Color color,
    int index,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: index % 2 == 0 ? Colors.grey.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black87,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ... (rest of the methods remain the same: _buildNavigationButtons, _buildFinalSubmitButton, etc.)

  Widget _buildNavigationButtons() {
    return Row(
      children: [
        if (_currentScenarioIndex > 0)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _previousScenario,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Previous'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        if (_currentScenarioIndex > 0 &&
            _currentScenarioIndex < _scenarios.length - 1)
          const SizedBox(width: 12),
        if (_currentScenarioIndex < _scenarios.length - 1)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _nextScenario,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Next Scenario'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9C27B0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFinalSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSubmitting ? null : _handleFinalSubmit,
        icon: const Icon(Icons.send),
        label: const Text(
          'Submit All Responses',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  bool _allScenariosCompleted() {
    return _scenarios.every(
      (scenario) => _feedback.containsKey(scenario['id']),
    );
  }

  Widget _buildLoadingScreen() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF9C27B0)),
          SizedBox(height: 24),
          Text(
            'Processing your responses...',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8),
          Text(
            'Our AI is providing personalized feedback.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsView() {
    final maxScore = _scenarios.length * 10;
    final percentage = maxScore > 0
        ? ((_overallScore ?? 0) / maxScore * 100).round()
        : 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Results summary
          Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF9C27B0).withOpacity(0.1),
                    Colors.purple.shade50,
                  ],
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(
                    Icons.emoji_events,
                    size: 64,
                    color: Color(0xFF9C27B0),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Activity Complete!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF9C27B0),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your Total Score: ${_overallScore ?? 0} / $maxScore',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  Text(
                    '$percentage%',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: _getScoreColor(percentage.toDouble()),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getPerformanceLabel(percentage),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: _getScoreColor(percentage.toDouble()),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to Lesson'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => Lesson4_1ActivityPage(
                          lessonId: widget.lessonId,
                          lessonTitle: widget.lessonTitle,
                          lessonData: widget.lessonData,
                          attemptNumber: widget.attemptNumber + 1,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9C27B0),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 90) return Colors.green;
    if (score >= 75) return Colors.lightGreen;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  String _getPerformanceLabel(int score) {
    if (score >= 90) return 'Excellent Performance!';
    if (score >= 80) return 'Great Work!';
    if (score >= 70) return 'Good Progress!';
    if (score >= 60) return 'Keep Practicing!';
    return 'Needs Improvement';
  }
}
