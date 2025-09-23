// lib/lessons/lesson4_2_activity_page.dart
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../services/unified_progress_service.dart';
import '../widgets/ai_feedback_display_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class Lesson4_2ActivityPage extends StatefulWidget {
  final String lessonId;
  final String lessonTitle;
  final Map<String, dynamic> lessonData;
  final int attemptNumber;

  const Lesson4_2ActivityPage({
    super.key,
    required this.lessonId,
    required this.lessonTitle,
    required this.lessonData,
    required this.attemptNumber,
  });

  @override
  State<Lesson4_2ActivityPage> createState() => _Lesson4_2ActivityPageState();
}

class _Lesson4_2ActivityPageState extends State<Lesson4_2ActivityPage> {
  final Logger _logger = Logger();
  final UnifiedProgressService _progressService = UnifiedProgressService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  Map<String, String> _solutionResponses = {};
  Map<String, Map<String, dynamic>> _aiFeedback = {};
  Map<String, TextEditingController> _textControllers = {};
  bool _isSubmitting = false;
  bool _showResults = false;
  double _overallScore = 0.0;
  int _currentScenarioIndex = 0;
  bool _isAudioLoading = false;
  bool _isScriptVisible = false;

  final int _timeLimit = 900; // 15 minutes
  late int _timeRemaining;
  bool _isTimerActive = false;

  @override
  void initState() {
    super.initState();
    _timeRemaining = _timeLimit;
    _initializeSolutionResponses();
    _initializeTextControllers();
    _startTimer();
  }

  @override
  void dispose() {
    // Dispose all text controllers
    _textControllers.values.forEach((controller) => controller.dispose());
    _audioPlayer.dispose();
    super.dispose();
  }

  void _initializeTextControllers() {
    final solutionPrompts =
        widget.lessonData['activity']?['solutionPrompts'] as List<dynamic>? ??
        [];
    for (var prompt in solutionPrompts) {
      final scenarioName = prompt['name'];
      _textControllers[scenarioName] = TextEditingController(
        text: _solutionResponses[scenarioName] ?? '',
      );

      // Add listener to sync with _solutionResponses
      _textControllers[scenarioName]!.addListener(() {
        _solutionResponses[scenarioName] = _textControllers[scenarioName]!.text;
      });
    }
  }

  void _initializeSolutionResponses() {
    final solutionPrompts =
        widget.lessonData['activity']?['solutionPrompts'] as List<dynamic>? ??
        [];
    for (var prompt in solutionPrompts) {
      _solutionResponses[prompt['name']] = '';
    }
  }

  void _startTimer() {
    setState(() => _isTimerActive = true);
    _runTimer();
  }

  void _runTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _isTimerActive && _timeRemaining > 0 && !_showResults) {
        setState(() => _timeRemaining--);
        _runTimer();
      } else if (_timeRemaining <= 0 && !_showResults) {
        _handleTimeOut();
      }
    });
  }

  void _handleTimeOut() {
    setState(() {
      _isTimerActive = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Time\'s up! Your current progress was not submitted.'),
        backgroundColor: Colors.red,
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _playScenarioAudio() async {
    if (_isAudioLoading) return;

    final solutionPrompts =
        widget.lessonData['activity']?['solutionPrompts'] as List<dynamic>? ??
        [];
    if (_currentScenarioIndex >= solutionPrompts.length) return;

    final currentScenario = solutionPrompts[_currentScenarioIndex];
    final parts = currentScenario['parts'] as List<dynamic>? ?? [];

    if (parts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No audio available for this scenario')),
      );
      return;
    }

    setState(() => _isAudioLoading = true);

    try {
      final audioBytes = await _progressService.synthesizeSpeechFromParts(
        parts,
      );
      if (audioBytes != null) {
        final tempDir = await getTemporaryDirectory();
        final audioFile = File(
          '${tempDir.path}/scenario_${DateTime.now().millisecondsSinceEpoch}.wav',
        );
        await audioFile.writeAsBytes(audioBytes);

        await _audioPlayer.setFilePath(audioFile.path);
        await _audioPlayer.play();

        _audioPlayer.playerStateStream.listen((state) {
          if (state.processingState == ProcessingState.completed) {
            if (mounted) {
              setState(() => _isAudioLoading = false);
            }
          }
        });
      } else {
        setState(() => _isAudioLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not play scenario audio')),
        );
      }
    } catch (e) {
      _logger.e('Error playing scenario audio: $e');
      setState(() => _isAudioLoading = false);
    }
  }

  Future<void> _checkSingleSolution(String scenarioName) async {
    final userAnswer = _solutionResponses[scenarioName];
    if (userAnswer == null || userAnswer.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a solution before checking'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // ✅ FIX: Send the solutions in the correct format expected by the backend
      final result = await _progressService.evaluateSolutions(
        {scenarioName: userAnswer},
        "Lesson 4.2", // ✅ Use the exact format the backend expects
      );

      if (result['success'] == true) {
        final feedback = result['feedback'] as Map<String, dynamic>? ?? {};
        setState(() {
          _aiFeedback.addAll(feedback.cast<String, Map<String, dynamic>>());
        });
      } else {
        throw Exception(
          'AI evaluation failed: ${result['error'] ?? 'Unknown error'}',
        );
      }
    } catch (e) {
      _logger.e('Error checking solution: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error getting feedback. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _saveFinalAttempt() async {
    if (!mounted) return;

    setState(() => _isSubmitting = true);

    try {
      // Calculate overall score
      double totalScore = 0.0;
      _aiFeedback.forEach((key, feedback) {
        if (feedback['score'] != null) {
          totalScore += (feedback['score'] as num).toDouble();
        }
      });

      final maxPossibleScore = (_aiFeedback.length * 2.5); // 2.5 per solution
      final scaledScore = maxPossibleScore > 0
          ? (totalScore / maxPossibleScore) * 10
          : 0.0;

      // Update the overall score in state
      _overallScore = scaledScore;

      // Save to Firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final timeSpent = _timeLimit - _timeRemaining;
        final detailedResponses = {
          'solutionResponses_L4_2': Map<String, String>.from(
            _solutionResponses,
          ),
          'solutionFeedback_L4_2': Map<String, dynamic>.from(_aiFeedback),
        };

        // FIXED: Use the correct method from your service
        await _progressService.saveLessonAttempt(
          lessonId: widget.lessonId,
          score: scaledScore.round(), // Convert to int
          maxScore: 10, // Max possible score
          timeSpent: timeSpent,
          detailedResponses: detailedResponses,
        );
      }

      setState(() {
        _showResults = true;
        _isTimerActive = false;
      });
    } catch (e) {
      _logger.e('Error saving final attempt: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error saving results. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _nextScenario() {
    final solutionPrompts =
        widget.lessonData['activity']?['solutionPrompts'] as List<dynamic>? ??
        [];
    if (_currentScenarioIndex < solutionPrompts.length - 1) {
      setState(() {
        _currentScenarioIndex++;
        _isScriptVisible = false;
      });
    }
  }

  void _previousScenario() {
    if (_currentScenarioIndex > 0) {
      setState(() {
        _currentScenarioIndex--;
        _isScriptVisible = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final solutionPrompts =
        widget.lessonData['activity']?['solutionPrompts'] as List<dynamic>? ??
        [];

    if (solutionPrompts.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.lessonTitle),
          backgroundColor: const Color(0xFF8a2be2),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('No solution prompts available')),
      );
    }

    final currentScenario = solutionPrompts[_currentScenarioIndex];
    final scenarioName = currentScenario['name'] ?? '';
    final hasFeedback = _aiFeedback.containsKey(scenarioName);
    final isLastScenario = _currentScenarioIndex == solutionPrompts.length - 1;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lessonTitle),
        backgroundColor: const Color(0xFF8a2be2),
        foregroundColor: Colors.white,
        actions: [
          if (_isTimerActive && !_showResults)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Text(
                  _formatTime(_timeRemaining),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isSubmitting
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Processing your solution...'),
                ],
              ),
            )
          : _showResults
          ? _buildResultsView()
          : _buildActivityView(
              currentScenario,
              scenarioName,
              hasFeedback,
              isLastScenario,
            ),
    );
  }

  Widget _buildActivityView(
    Map<String, dynamic> currentScenario,
    String scenarioName,
    bool hasFeedback,
    bool isLastScenario,
  ) {
    final solutionPrompts =
        widget.lessonData['activity']?['solutionPrompts'] as List<dynamic>? ??
        [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF8a2be2).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF8a2be2).withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Scenario ${_currentScenarioIndex + 1} of ${solutionPrompts.length}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8a2be2),
                      ),
                    ),
                    Text(
                      'Attempt ${widget.attemptNumber}',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Listen to the customer\'s problem:',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isAudioLoading ? null : _playScenarioAudio,
                      icon: _isAudioLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.volume_up),
                      label: Text(
                        _isAudioLoading ? 'Loading...' : 'Play Audio',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8a2be2),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                if (_isScriptVisible) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      currentScenario['parts']
                              ?.map((part) => part['text'])
                              ?.join(' ') ??
                          'No script available',
                      style: const TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => setState(() => _isScriptVisible = true),
                    child: const Text(
                      'Show Script',
                      style: TextStyle(color: Color(0xFF8a2be2)),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  currentScenario['task'] ?? 'Provide a professional solution.',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Solution Input
          const Text(
            'Your Solution:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller:
                _textControllers[scenarioName], // ✅ USE PERSISTENT CONTROLLER
            maxLines: 4,
            textDirection: TextDirection.ltr,
            enabled: !hasFeedback,
            decoration: InputDecoration(
              hintText: 'Type your professional solution here...',
              border: const OutlineInputBorder(),
              enabled: !hasFeedback,
            ),
          ),

          const SizedBox(height: 16),

          // Feedback Display
          if (hasFeedback) ...[
            AiFeedbackDisplayCard(
              feedbackData: _aiFeedback[scenarioName] ?? {},
            ),
            const SizedBox(height: 20),
          ],

          // Navigation Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton(
                onPressed: _currentScenarioIndex > 0 ? _previousScenario : null,
                child: const Text('Previous'),
              ),
              if (!hasFeedback)
                ElevatedButton(
                  onPressed:
                      (_solutionResponses[scenarioName]?.trim().isEmpty ?? true)
                      ? null
                      : () => _checkSingleSolution(scenarioName),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Check Solution'),
                )
              else if (isLastScenario)
                ElevatedButton(
                  onPressed: _saveFinalAttempt,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Finish & Save'),
                )
              else
                ElevatedButton(
                  onPressed: _nextScenario,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8a2be2),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Next Scenario'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultsView() {
    final solutionPrompts =
        widget.lessonData['activity']?['solutionPrompts'] as List<dynamic>? ??
        [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Overall Score
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8a2be2), Color(0xFF663399)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Text(
                  'Activity Complete!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Overall Score: ${_overallScore.toStringAsFixed(1)}/10',
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Individual Scenario Results
          ...solutionPrompts.map((prompt) {
            final scenarioName = prompt['name'];
            final userResponse = _solutionResponses[scenarioName] ?? '';
            final feedback = _aiFeedback[scenarioName];

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Scenario: ${prompt['parts']?.map((p) => p['text'])?.join(' ') ?? 'N/A'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your Solution: "$userResponse"',
                    style: const TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  if (feedback != null) ...[
                    const SizedBox(height: 12),
                    AiFeedbackDisplayCard(feedbackData: feedback),
                  ],
                ],
              ),
            );
          }).toList(),

          const SizedBox(height: 20),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushReplacementNamed(
                    context,
                    '/lesson4_2_activity',
                    arguments: {
                      'lessonId': widget.lessonId,
                      'lessonTitle': widget.lessonTitle,
                      'lessonData': widget.lessonData,
                      'attemptNumber': widget.attemptNumber + 1,
                    },
                  );
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.popUntil(context, (route) => route.isFirst);
                  Navigator.pushReplacementNamed(context, '/lesson4_2');
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to Lesson'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8a2be2),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
