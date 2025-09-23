// lib/lessons/lesson3_1_activity_page.dart
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'dart:async';
import 'package:just_audio/just_audio.dart';
import '../services/unified_progress_service.dart';
import '../widgets/ai_feedback_display_card.dart';
import '../widgets/listen_and_identify_widget.dart'; // For the BytesAudioSource helper

class Lesson3_1ActivityPage extends StatefulWidget {
  final String lessonId;
  final String lessonTitle;
  final Map<String, dynamic> lessonData;
  final int attemptNumber;

  const Lesson3_1ActivityPage({
    super.key,
    required this.lessonId,
    required this.lessonTitle,
    required this.lessonData,
    required this.attemptNumber,
  });

  @override
  State<Lesson3_1ActivityPage> createState() => _Lesson3_1ActivityPageState();
}

class _Lesson3_1ActivityPageState extends State<Lesson3_1ActivityPage> {
  final Logger _logger = Logger();
  final UnifiedProgressService _progressService = UnifiedProgressService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  Map<String, TextEditingController> _controllers = {};
  Map<String, String> _answers = {};
  Map<String, dynamic> _feedback = {};
  bool _isSubmitting = false;
  bool _showResults = false;
  int? _overallScore;
  Timer? _timerInstance;
  int _timerSeconds = 1200; // 20 minutes
  bool _isTimedOut = false;
  String? _loadingAudioId;
  Map<String, bool> _transcriptVisibility = {};

  final int _initialTime = 1200;

  @override
  void initState() {
    super.initState();
    _initializeActivity();
    _startTimer();
  }

  @override
  void dispose() {
    _timerInstance?.cancel();
    _audioPlayer.dispose();
    _controllers.values.forEach((c) => c.dispose());
    super.dispose();
  }

  void _initializeActivity() {
    final questionSets = List<Map<String, dynamic>>.from(
      widget.lessonData['activity']?['questionSets'] ?? [],
    );
    final newAnswers = <String, String>{};
    final newControllers = <String, TextEditingController>{};
    final newVisibility = <String, bool>{};

    for (var set in questionSets) {
      newVisibility[set['callId']] = false;
      for (var question in List<Map<String, dynamic>>.from(
        set['questions'] ?? [],
      )) {
        final qId = question['id'] as String;
        newAnswers[qId] = '';
        newControllers[qId] = TextEditingController();
      }
    }
    setState(() {
      _answers = newAnswers;
      _controllers = newControllers;
      _transcriptVisibility = newVisibility;
    });
  }

  void _startTimer() {
    _timerInstance = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSeconds > 0 && mounted && !_showResults && !_isTimedOut) {
        setState(() => _timerSeconds--);
      } else if (_timerSeconds <= 0 && !_showResults && !_isTimedOut) {
        timer.cancel();
        if (mounted) {
          setState(() => _isTimedOut = true);
          _handleSubmit();
        }
      }
    });
  }

  Future<void> _playScript(String callId) async {
    if (_loadingAudioId != null) return;

    final transcripts =
        widget.lessonData['activity']?['transcripts'] as Map<String, dynamic>?;
    final scriptToPlay = transcripts?[callId] as List<dynamic>?;

    if (scriptToPlay == null || scriptToPlay.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not find the script text.')),
      );
      return;
    }

    setState(() => _loadingAudioId = callId);

    try {
      final audioData = await _progressService.synthesizeSpeechFromTurns(
        scriptToPlay,
      );

      if (audioData != null && mounted) {
        await _audioPlayer.setAudioSource(BytesAudioSource(audioData));
        _audioPlayer.play();
        // This line waits for playback to complete before proceeding
        await _audioPlayer.playerStateStream.firstWhere(
          (s) => s.processingState == ProcessingState.completed,
        );
      } else {
        throw Exception("Audio data from server was null.");
      }
    } catch (error) {
      _logger.e('Error fetching or playing TTS audio for script: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not play the audio script. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingAudioId = null);
      }
    }
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting || _showResults) return;

    _controllers.forEach((key, controller) => _answers[key] = controller.text);

    if (_answers.values.any((a) => a.trim().isEmpty) && !_isTimedOut) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please answer all questions before submitting.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    _timerInstance?.cancel();

    try {
      final feedbackResult = await _progressService.getScenarioFeedback(
        widget.lessonId,
        _answers,
        widget.lessonData['activity']['transcripts'], // Pass the transcripts
      );

      int totalScore = 0;
      feedbackResult.forEach(
        (_, value) => totalScore += (value['score'] as int? ?? 0),
      );

      final detailedResponses = {
        'answers': _answers,
        'feedbackForAnswers': feedbackResult,
      };

      await _progressService.saveLessonAttempt(
        lessonId: widget.lessonId,
        score: totalScore,
        maxScore:
            widget.lessonData['activity']['maxPossibleAIScore'] as int? ?? 60,
        timeSpent: _initialTime - _timerSeconds,
        detailedResponses: detailedResponses,
      );

      if (mounted) {
        setState(() {
          _feedback = feedbackResult;
          _overallScore = totalScore;
          _showResults = true;
          _isSubmitting = false;
        });
      }
    } catch (e) {
      _logger.e('Error during submission: $e');
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('There was an error submitting your results.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _tryAgain() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => Lesson3_1ActivityPage(
          lessonId: widget.lessonId,
          lessonTitle: widget.lessonTitle,
          lessonData: widget.lessonData,
          attemptNumber: widget.attemptNumber + 1,
        ),
      ),
    );
  }

  bool get _allQuestionsAnswered {
    _controllers.forEach((key, controller) => _answers[key] = controller.text);
    return _answers.values.every((answer) => answer.trim().isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    // **FIX:** The main build method now directs to the new results view when done
    return Scaffold(
      appBar: AppBar(
        title: Text(_showResults ? "Activity Results" : widget.lessonTitle),
        backgroundColor: const Color(0xFF32CD32),
      ),
      body: _isSubmitting
          ? _buildLoadingScreen()
          : _showResults
          ? _buildResultsView()
          : _buildActivityContent(),
    );
  }

  Widget _buildResultsView() {
    final maxScore = widget.lessonData['activity']['maxPossibleAIScore'] ?? 60;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Results summary is now at the top
          Card(
            margin: const EdgeInsets.only(bottom: 24),
            color: Colors.indigo[50],
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    'Activity Complete!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your Total AI Score:',
                    style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                  ),
                  Text(
                    '${_overallScore ?? 0} / $maxScore',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This score has been saved to your activity log.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: _tryAgain,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back to Lesson'),
              ),
            ],
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20.0),
            child: Divider(),
          ),

          const Text(
            'Review Your Answers',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Display the question sets with feedback
          ..._buildQuestionSets(),
        ],
      ),
    );
  }

  Widget _buildActivityContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildInstructions(),
          const SizedBox(height: 16),
          ..._buildQuestionSets(),
          const SizedBox(height: 24),
          _buildActionButtons(),
          if (_showResults) _buildResults(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.headphones, color: Color(0xFF32CD32), size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Listening Activity',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF32CD32),
                      ),
                    ),
                  ],
                ),
                if (!_isTimedOut && !_showResults)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _timerSeconds < 300
                          ? Colors.red.shade100
                          : Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.timer,
                          size: 18,
                          color: _timerSeconds < 300 ? Colors.red : Colors.blue,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_timerSeconds ~/ 60}:${(_timerSeconds % 60).toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: _timerSeconds < 300
                                ? Colors.red
                                : Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Attempt Number: ${widget.attemptNumber}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructions() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue.shade700),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Listen to each call script carefully, then answer the questions based on what you heard.',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildQuestionSets() {
    final questionSets = List<Map<String, dynamic>>.from(
      widget.lessonData['activity']?['questionSets'] ?? [],
    );
    return questionSets.map((set) => _buildQuestionSet(set)).toList();
  }

  Widget _buildQuestionSet(Map<String, dynamic> set) {
    final callId = set['callId'] as String;
    final questions = List<Map<String, dynamic>>.from(set['questions'] ?? []);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Call Transcript (${callId.replaceAll('call', 'Call ')})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed:
                      (_isSubmitting ||
                          _showResults ||
                          _isTimedOut ||
                          _loadingAudioId != null)
                      ? null
                      : () => _playScript(callId),
                  icon: _loadingAudioId == callId
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.volume_up, size: 20),
                  label: Text(
                    _loadingAudioId == callId ? 'Loading...' : 'Play Script',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            if (_showResults) _buildTranscriptSection(callId),
            const SizedBox(height: 16),
            ...questions.map((q) => _buildQuestion(q)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildTranscriptSection(String callId) {
    final isVisible = _transcriptVisibility[callId] ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: () =>
              setState(() => _transcriptVisibility[callId] = !isVisible),
          icon: Icon(isVisible ? Icons.visibility_off : Icons.visibility),
          label: Text(
            isVisible ? 'Hide Transcript' : 'Show Transcript to Review',
          ),
        ),
        if (isVisible) _buildTranscript(callId),
      ],
    );
  }

  Widget _buildTranscript(String callId) {
    final transcripts = widget.lessonData['activity']['transcripts'];
    final transcript = transcripts[callId] as List?;

    if (transcript == null) return const SizedBox();

    return Card(
      color: Colors.grey[100],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Call Transcript:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 12),
            ...transcript.map<Widget>((turn) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Colors.black87, fontSize: 14),
                    children: [
                      TextSpan(
                        text: '${turn['character']}: ',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: turn['text']),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestion(Map<String, dynamic> question) {
    final qId = question['id'] as String;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question['text'],
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controllers[qId],
            // **FIX:** Fields are disabled when showing results
            enabled: !_showResults,
            readOnly: _showResults,
            decoration: InputDecoration(
              hintText: _showResults
                  ? (_answers[qId] ?? '')
                  : 'Your answer here...',
              border: const OutlineInputBorder(),
              filled: _showResults,
              fillColor: Colors.grey[100],
            ),
            maxLines: 2,
          ),
          if (_showResults && _feedback[qId] != null)
            AiFeedbackDisplayCard(feedbackData: _feedback[qId]),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_isTimedOut && !_showResults) {
      return Card(
        color: Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.warning, color: Colors.red.shade700),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Time\'s Up!',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'This attempt was not submitted and will not be saved.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        if (!_showResults && !_isTimedOut)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: (_isSubmitting || !_allQuestionsAnswered)
                  ? null
                  : _handleSubmit,
              icon: const Icon(Icons.check_circle),
              label: const Text('Submit My Answers'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3066be),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        if (_showResults || _isTimedOut)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _tryAgain,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildResults() {
    final maxScore = widget.lessonData['activity']['maxPossibleAIScore'] ?? 60;
    final percentage = maxScore > 0
        ? ((_overallScore ?? 0) / maxScore * 100).round()
        : 0;

    return Card(
      margin: const EdgeInsets.only(top: 16),
      color: Colors.purple.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              percentage >= 70 ? Icons.celebration : Icons.info_outline,
              size: 48,
              color: percentage >= 70 ? Colors.green : Colors.orange,
            ),
            const SizedBox(height: 12),
            const Text(
              'Activity Complete!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your Total AI Score: ${_overallScore ?? 0} / $maxScore',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3066be),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$percentage%',
              style: TextStyle(
                fontSize: 16,
                color: percentage >= 70 ? Colors.green : Colors.orange,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This score and time spent have been saved.',
              style: TextStyle(fontSize: 12, color: Colors.purple),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Evaluating your responses...',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8),
          Text(
            'Please wait for your personalized feedback.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
