// lesson3_2.dart
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:logger/logger.dart';
import 'dart:async';
import 'dart:io'; // Ensure dart:io is imported
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../lessons/common_widgets.dart'; // For buildSlide

// PromptAttemptData class (ensure this is defined as before)
class PromptAttemptData {
  String? audioStorageUrl;
  String? transcription;
  Map<String, dynamic>? azureAiFeedback;
  String? openAiDetailedFeedback;
  bool isProcessed;
  String? localAudioPath;
  bool
      isUploading; // This state will be managed by module3.dart via callback status if needed
  bool isProcessingAzure;
  bool isFetchingOpenAI;

  PromptAttemptData({
    this.audioStorageUrl,
    this.transcription,
    this.azureAiFeedback,
    this.openAiDetailedFeedback,
    this.isProcessed = false,
    this.localAudioPath,
    this.isUploading = false,
    this.isProcessingAzure = false,
    this.isFetchingOpenAI = false,
  });
}

class buildLesson3_2 extends StatefulWidget {
  // ... (Constructor remains the same as your last correct version)
  final BuildContext parentContext;
  final int currentSlide;
  final CarouselSliderController carouselController;
  final bool showActivitySectionInitially;
  final VoidCallback onShowActivitySection;
  final Function(int) onSlideChanged;
  final int initialAttemptNumber;
  final bool displayFeedback;

  final Future<Map<String, dynamic>?> Function(
    String audioPathOrUrl,
    String originalText,
    String promptId,
  ) onProcessAudioPrompt;
  final Future<String?> Function(
    Map<String, dynamic> azureFeedback,
    String originalText,
  ) onExplainAzureFeedback;
  final Function(
    List<Map<String, dynamic>> submittedPromptData,
    Map<String, String> reflections,
    double overallScore,
    int timeSpent,
    int attemptNumberForSubmission,
  ) onSubmitLesson;

  const buildLesson3_2({
    super.key,
    required this.parentContext,
    required this.currentSlide,
    required this.carouselController,
    required this.showActivitySectionInitially,
    required this.onShowActivitySection,
    required this.onSlideChanged,
    required this.initialAttemptNumber,
    required this.displayFeedback,
    required this.onProcessAudioPrompt,
    required this.onExplainAzureFeedback,
    required this.onSubmitLesson,
  });

  @override
  _Lesson3_2State createState() => _Lesson3_2State();
}

class _Lesson3_2State extends State<buildLesson3_2> {
  final Logger _logger = Logger();
  Timer? _timer;
  int _secondsElapsed = 0;
  late int _currentAttemptForDisplay;

  bool _isLoadingLessonContent = true;
  Map<String, dynamic>? _lessonData;
  List<dynamic> _speakingPrompts = [];
  int _currentPromptIndex = 0;

  late Map<String, PromptAttemptData> _promptAttemptDataMap;

  final AudioRecorder _audioRecorder =
      AudioRecorder(); // Instance of audio recorder
  final AudioPlayer _audioPlayer = AudioPlayer(); // Instance for playback
  bool _isRecording = false;
  // String? _currentRecordingPath; // This will be stored inside PromptAttemptData

  final TextEditingController _confidenceController = TextEditingController();
  final TextEditingController _hardestSentenceController =
      TextEditingController();
  final TextEditingController _improvementController = TextEditingController();

  bool _showOverallResultsView = false;
  double? _overallLessonScoreForDisplay;
  bool _isSubmittingLesson = false;
  bool _isProcessingCurrentPrompt =
      false; // To disable buttons during individual prompt processing

  @override
  void initState() {
    super.initState();
    _currentAttemptForDisplay = widget.initialAttemptNumber + 1;
    _promptAttemptDataMap = {};
    _fetchLessonContentAndInitialize();

    if (widget.showActivitySectionInitially && !widget.displayFeedback) {
      _startTimer();
    }
  }

  Future<void> _fetchLessonContentAndInitialize() async {
    setState(() => _isLoadingLessonContent = true);

    // Content from your "2_3 old.dart"
    final Map<String, dynamic> hardcodedLesson3_2Data = {
      'lessonTitle': 'Lesson 3.2: Speaking Practice – Dialogues',
      'slides': [
        {
          'title': 'Lesson Objective',
          'content':
              '• Improve pronunciation, rhythm, and intonation using real customer service phrases.\n• Practice repeating professional call center dialogues clearly and confidently.\n• Build fluency and confidence for real call interactions.',
        },
        {
          'title': 'Why Clear Speaking Matters',
          'content':
              'In customer service, how you say something is just as important as what you say. Good pronunciation helps customers understand you better, builds trust, and leads to more positive interactions.',
        },
        {
          'title': 'Focus Points for This Lesson',
          'content':
              '• <strong>Tone:</strong> Maintaining a professional, empathetic, and friendly tone.\n• <strong>Word Stress & Intonation:</strong> Emphasizing the right words and using natural pitch changes.\n• <strong>Clarity & Pacing:</strong> Speaking clearly and at an understandable speed.',
        },
      ],
      'activity': {
        'title': 'Speaking Practice Activity',
        'instructions':
            'For each prompt, record yourself saying the agent\'s line. Aim for clarity, natural intonation, and a professional tone. You will receive feedback on your pronunciation and fluency for each recording.',
        'speakingPrompts': [
          {
            'id': 'd1_agent1',
            'text':
                "Good morning! This is Anna from TechSupport. How can I assist you?",
            'character': "Agent",
          },
          {
            'id': 'd1_agent2',
            'text':
                "I’m sorry about that. Can I get your account number, please?",
            'character': "Agent",
          },
          {
            'id': 'd2_agent1',
            'text':
                "Hello! Thank you for calling. What can I help you with today?",
            'character': "Agent",
          },
          {
            'id': 'd2_agent2',
            'text': "Certainly. May I have your tracking number?",
            'character': "Agent",
          },
          {
            'id': 'd3_agent1',
            'text':
                "Thank you for waiting. I’ve confirmed your refund has been processed.",
            'character': "Agent",
          },
          {
            'id': 'd3_agent2',
            'text': "You're welcome! Have a great day.",
            'character': "Agent",
          },
        ],
      },
    };
    // ---- END HARDCODED LESSON 3.2 DATA ----

    _lessonData = hardcodedLesson3_2Data;
    _speakingPrompts =
        _lessonData!['activity']?['speakingPrompts'] as List<dynamic>? ?? [];
    _initializePromptAttemptData();

    _logger.i(
      "L3.2: Content from '2_3 old.dart' loaded. Prompts: ${_speakingPrompts.length}",
    );
    if (mounted) setState(() => _isLoadingLessonContent = false);
  }

  void _initializePromptAttemptData() {
    /* ... same ... */
    _promptAttemptDataMap.clear();
    for (var prompt in _speakingPrompts) {
      if (prompt is Map && prompt['id'] is String) {
        _promptAttemptDataMap[prompt['id']] = PromptAttemptData();
      }
    }
  }

  // Timer methods (keep as they are)
  void _startTimer() {
    /* ... */
    _timer?.cancel();
    _secondsElapsed = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _secondsElapsed++);
    });
  }

  void _stopTimer() {
    /* ... */
    _timer?.cancel();
  }

  void _resetTimer() {
    /* ... */
    if (mounted) setState(() => _secondsElapsed = 0);
  }

  String _formatDuration(int totalSeconds) {
    /* ... */
    final duration = Duration(seconds: totalSeconds);
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _startRecording() async {
    bool hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      _logger.w("L3.2: Microphone permission not granted.");
      // You might want to request permission here using permission_handler package
      // For now, showing a snackbar
      ScaffoldMessenger.of(widget.parentContext).showSnackBar(
        const SnackBar(
          content: Text('Microphone permission is required to record audio.'),
        ),
      );
      return;
    }

    try {
      final Directory tempDir = await getTemporaryDirectory();
      String currentPromptId = _speakingPrompts[_currentPromptIndex]['id'];
      final path =
          '${tempDir.path}/audio_prompt_${currentPromptId}_${DateTime.now().millisecondsSinceEpoch}.m4a'; // m4a is generally good for mobile

      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      ); // Using AAC for m4a
      if (mounted) {
        setState(() {
          _isRecording = true;
          _promptAttemptDataMap[currentPromptId]?.localAudioPath =
              null; // Clear old path
          _promptAttemptDataMap[currentPromptId]?.isProcessed = false;
          _promptAttemptDataMap[currentPromptId]?.azureAiFeedback = null;
          _promptAttemptDataMap[currentPromptId]?.openAiDetailedFeedback = null;
        });
      }
      _logger.i("L3.2: Recording started. Path: $path");
    } catch (e) {
      _logger.e("L3.2: Error starting recording: $e");
      ScaffoldMessenger.of(
        widget.parentContext,
      ).showSnackBar(SnackBar(content: Text('Error starting recording: $e')));
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      if (path != null) {
        String currentPromptId = _speakingPrompts[_currentPromptIndex]['id'];
        if (mounted) {
          setState(() {
            _isRecording = false;
            _promptAttemptDataMap[currentPromptId]?.localAudioPath = path;
            _logger.i("L3.2: Recording stopped. File saved at: $path");
          });
        }
      } else {
        _logger.w("L3.2: Stop recording called but path is null.");
      }
    } catch (e) {
      _logger.e("L3.2: Error stopping recording: $e");
    }
    if (mounted) setState(() => _isRecording = false);
  }

  Future<void> _playCurrentRecording() async {
    String currentPromptId = _speakingPrompts[_currentPromptIndex]['id'];
    final path = _promptAttemptDataMap[currentPromptId]?.localAudioPath;
    if (path != null) {
      try {
        _logger.i("L3.2: Playing recording from $path");
        await _audioPlayer.play(DeviceFileSource(path));
      } catch (e) {
        _logger.e("L3.2: Error playing recording: $e");
        ScaffoldMessenger.of(
          widget.parentContext,
        ).showSnackBar(SnackBar(content: Text('Could not play recording: $e')));
      }
    } else {
      _logger.w(
        "L3.2: No recording available to play for prompt $currentPromptId.",
      );
    }
  }

  Future<void> _processCurrentAudioPrompt() async {
    String currentPromptId = _speakingPrompts[_currentPromptIndex]['id'];
    PromptAttemptData? currentData = _promptAttemptDataMap[currentPromptId];

    if (currentData == null || currentData.localAudioPath == null) {
      ScaffoldMessenger.of(widget.parentContext).showSnackBar(
        const SnackBar(content: Text('Please record your audio first.')),
      );
      return;
    }
    if (!mounted) return;

    setState(() {
      _isProcessingCurrentPrompt = true;
    }); // Disable buttons

    // This is where module3.dart will handle the Cloudinary upload with the localAudioPath
    // and then call the server. For now, we directly call onProcessAudioPrompt with localAudioPath
    // assuming module3.dart will handle it or simulate it.

    // **IMPORTANT:** The `onProcessAudioPrompt` in module3.dart should now expect a LOCAL FILE PATH
    // It will be responsible for uploading this path to Cloudinary to get a URL
    // THEN it calls your server with that Cloudinary URL.

    _logger.i(
      "L3.2: Calling onProcessAudioPrompt for '$currentPromptId' with local path: ${currentData.localAudioPath}",
    );

    final azureFeedbackResult = await widget.onProcessAudioPrompt(
      currentData.localAudioPath!, // Pass the LOCAL path
      _speakingPrompts[_currentPromptIndex]['text'],
      currentPromptId,
    );

    if (!mounted) return;

    setState(() {
      if (azureFeedbackResult != null &&
          azureFeedbackResult['success'] == true) {
        currentData.azureAiFeedback = azureFeedbackResult;
        currentData.transcription =
            azureFeedbackResult['textRecognized'] as String?;
        currentData.audioStorageUrl = // NEW
            azureFeedbackResult['audioStorageUrlFromModule']
                as String?; // NEW KEY
// Assuming module3 returns this
        _logger.i("L3.2: Azure feedback SUCCESS for $currentPromptId");
        _fetchOpenAIExplanation(
          azureFeedbackResult,
          _speakingPrompts[_currentPromptIndex]['text'],
          currentPromptId,
        );
      } else {
        currentData.azureAiFeedback = {
          'error':
              azureFeedbackResult?['error'] ?? 'Failed to get Azure feedback',
          'success': false,
        };
        currentData.isProcessed = true; // Processed, but with error
        _logger.e(
          "L3.2: Azure feedback FAILED for $currentPromptId: ${currentData.azureAiFeedback}",
        );
        _isProcessingCurrentPrompt = false; // Re-enable buttons on error
      }
    });
  }

  Future<void> _fetchOpenAIExplanation(
    Map<String, dynamic> azureResult,
    String originalText,
    String promptId,
  ) async {
    if (!mounted) return;
    // No need for a separate isFetchingOpenAI in PromptAttemptData if _isProcessingCurrentPrompt covers all async work for a prompt
    _logger.i("L3.2: Calling onExplainAzureFeedback for $promptId");

    final openAIExplanation = await widget.onExplainAzureFeedback(
      azureResult,
      originalText,
    );
    if (!mounted) return;

    setState(() {
      _promptAttemptDataMap[promptId]?.openAiDetailedFeedback =
          openAIExplanation ?? "Coach's explanation not available.";
      _promptAttemptDataMap[promptId]?.isProcessed = true;
      _isProcessingCurrentPrompt = false; // All processing for this prompt done
      _logger.i("L3.2: OpenAI explanation received for $promptId");
    });
  }

  // _handleNextPrompt, _calculateOverallScore, _handleSubmitLesson as before
  // Ensure _calculateOverallScore uses azureAiFeedback.accuracyScore
  void _handleNextPrompt() {
    /* ... same ... */
    if (_isProcessingCurrentPrompt) {
      ScaffoldMessenger.of(widget.parentContext).showSnackBar(
        const SnackBar(
          content: Text('Please wait for current processing to finish.'),
        ),
      );
      return;
    }
    if (_currentPromptIndex < _speakingPrompts.length - 1) {
      setState(() {
        _currentPromptIndex++; /*_currentRecordingPath = null;*/
      }); // localAudioPath is in map
    } else {
      _logger.i("L3.2: All prompts completed. Showing reflections/summary.");
      _calculateOverallScore();
      setState(() => _showOverallResultsView = true);
      _stopTimer();
    }
  }

  void _calculateOverallScore() {
    /* ... same, ensure uses azureAiFeedback.accuracyScore ... */
    double totalAccuracyScore = 0;
    int processedPromptsWithScore = 0;
    _promptAttemptDataMap.forEach((key, data) {
      if (data.isProcessed &&
          data.azureAiFeedback != null &&
          data.azureAiFeedback!['accuracyScore'] is num) {
        totalAccuracyScore += data.azureAiFeedback!['accuracyScore'];
        processedPromptsWithScore++;
      }
    });
    if (mounted) {
      setState(() {
        _overallLessonScoreForDisplay = processedPromptsWithScore > 0
            ? totalAccuracyScore / processedPromptsWithScore
            : 0.0;
      });
    }
  }

  void _handleSubmitLesson() async {
    /* ... same, pass widget.initialAttemptNumber + 1 ... */
    if (!mounted) return;
    _logger.i("L3.2: Attempting to submit lesson.");
    setState(() => _isSubmittingLesson = true);

    List<Map<String, dynamic>> submittedPromptData = [];
    _promptAttemptDataMap.forEach((promptId, data) {
      final promptMeta = _speakingPrompts.firstWhere(
        (p) => p['id'] == promptId,
        orElse: () => {'id': promptId, 'text': 'Unknown Prompt'},
      );
      submittedPromptData.add({
        'id': promptId,
        'text': promptMeta['text'],
        'audioUrl': data
            .audioStorageUrl, // This will be populated by module3.dart after successful upload
        'transcription': data.transcription,
        'azureAiFeedback': data.azureAiFeedback,
        'openAiDetailedFeedback': data.openAiDetailedFeedback,
        'score': data.azureAiFeedback?['accuracyScore'],
      });
    });
    Map<String, String> reflections = {/* ... */};
    _calculateOverallScore();
    try {
      await widget.onSubmitLesson(
        submittedPromptData,
        reflections,
        _overallLessonScoreForDisplay ?? 0.0,
        _secondsElapsed,
        widget.initialAttemptNumber + 1,
      );
    } catch (e) {
      /* ... */
    } finally {
      if (mounted) setState(() => _isSubmittingLesson = false);
    }
  }

  @override
  void didUpdateWidget(covariant buildLesson3_2 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showActivitySectionInitially &&
        !widget.displayFeedback &&
        (widget.initialAttemptNumber != oldWidget.initialAttemptNumber ||
            (widget.showActivitySectionInitially !=
                    oldWidget.showActivitySectionInitially &&
                !oldWidget.displayFeedback))) {
      _logger.i(
        "L3.2 didUpdateWidget: Resetting for new attempt. Initial attempt: ${widget.initialAttemptNumber + 1}",
      );
      _currentAttemptForDisplay = widget.initialAttemptNumber + 1;
      _currentPromptIndex = 0;
      _initializePromptAttemptData();
      _confidenceController.clear();
      _hardestSentenceController.clear();
      _improvementController.clear();
      _showOverallResultsView = false;
      _overallLessonScoreForDisplay = null;
      _isRecording = false;
      _resetTimer();
      _startTimer();
    }
    if (!widget.showActivitySectionInitially &&
        oldWidget.showActivitySectionInitially) _stopTimer();
    if (widget.displayFeedback &&
        !oldWidget.displayFeedback &&
        _timer?.isActive == true) _stopTimer();
  }

  @override
  void dispose() {
    _confidenceController.dispose();
    _hardestSentenceController.dispose();
    _improvementController.dispose();
    _stopTimer();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingLessonContent || _lessonData == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final String lessonTitle =
        _lessonData!['lessonTitle'] as String? ?? 'Lesson 3.2';
    List<dynamic> slides = _lessonData!['slides'] as List<dynamic>? ?? [];

    final String activityTitle =
        _lessonData!['activity']?['title'] as String? ?? 'Activity';
    final String activityInstructions =
        _lessonData!['activity']?['instructions'] as String? ?? '';

    Map<String, dynamic>? currentPromptMap = (_speakingPrompts.isNotEmpty &&
            _currentPromptIndex < _speakingPrompts.length)
        ? _speakingPrompts[_currentPromptIndex] as Map<String, dynamic>
        : null;
    String currentPromptText =
        currentPromptMap?['text'] as String? ?? "No prompt.";
    String currentPromptId = currentPromptMap?['id'] as String? ?? "unknown";
    PromptAttemptData? currentPromptData =
        _promptAttemptDataMap[currentPromptId];
    bool canSubmitAudioForProcessing =
        currentPromptData?.localAudioPath != null &&
            !(currentPromptData?.isProcessed ?? true) &&
            !_isRecording &&
            !_isProcessingCurrentPrompt;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lessonTitle,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF00568D),
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          if (slides.isNotEmpty &&
              (!widget.showActivitySectionInitially ||
                  widget.displayFeedback)) ...[
            CarouselSlider(
              key: ValueKey('carousel_l3_2_${slides.hashCode}'),
              carouselController: widget.carouselController,
              items: slides
                  .map(
                    (slide) => buildSlide(
                      title: slide['title'] as String? ?? 'Slide',
                      content: slide['content'] as String? ?? '',
                      slideIndex: slides.indexOf(slide),
                    ),
                  )
                  .toList(),
              options: CarouselOptions(
                height: 220.0,
                viewportFraction: 0.9,
                enlargeCenterPage: false,
                enableInfiniteScroll: false,
                initialPage: widget.currentSlide,
                onPageChanged: (index, reason) => widget.onSlideChanged(index),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: slides.asMap().entries.map((entry) {
                return GestureDetector(
                  onTap: () =>
                      widget.carouselController.animateToPage(entry.key),
                  child: Container(
                    width: 8.0,
                    height: 8.0,
                    margin: const EdgeInsets.symmetric(
                      vertical: 10.0,
                      horizontal: 2.0,
                    ),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.currentSlide == entry.key
                          ? const Color(0xFF00568D)
                          : Colors.grey,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
          if (!widget.showActivitySectionInitially)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.onShowActivitySection,
                child: const Text('Start Speaking Activity'),
              ),
            ),
          if (widget.showActivitySectionInitially &&
              !widget.displayFeedback) ...[
            const SizedBox(height: 16),
            if (!_showOverallResultsView) ...[
              Text(
                activityTitle,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: Colors.orange),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Time: ${_formatDuration(_secondsElapsed)}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'Attempt: $_currentAttemptForDisplay',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              HtmlFormattedText(htmlString: activityInstructions),
              const SizedBox(height: 20),
              Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 10),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Prompt ${_currentPromptIndex + 1} of ${_speakingPrompts.length}: Say the following line",
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        currentPromptText,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontStyle: FontStyle.italic,
                              fontSize: 18,
                              color: Colors.indigo.shade700,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ElevatedButton.icon(
                    icon: FaIcon(
                      _isRecording
                          ? FontAwesomeIcons.stopCircle
                          : FontAwesomeIcons.microphoneLines,
                    ),
                    label: Text(_isRecording ? 'Stop' : 'Record'),
                    onPressed: _isProcessingCurrentPrompt
                        ? null
                        : (_isRecording ? _stopRecording : _startRecording),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isRecording
                          ? Colors.red.shade400
                          : Colors.green.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  if (currentPromptData?.localAudioPath != null &&
                      !_isRecording)
                    IconButton(
                      icon: const FaIcon(FontAwesomeIcons.circlePlay),
                      onPressed: _isProcessingCurrentPrompt
                          ? null
                          : _playCurrentRecording,
                      tooltip: "Play my recording",
                      color: Theme.of(context).primaryColor,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (currentPromptData?.localAudioPath != null && !_isRecording)
                Center(
                  child: ElevatedButton.icon(
                    icon: const FaIcon(FontAwesomeIcons.cloudArrowUp),
                    label: const Text('Submit this Recording for Feedback'),
                    onPressed: canSubmitAudioForProcessing
                        ? _processCurrentAudioPrompt
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              if (_isProcessingCurrentPrompt)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(width: 10),
                        Text("Processing..."),
                      ],
                    ),
                  ),
                ),
              if (currentPromptData?.isProcessed ?? false) ...[
                const SizedBox(height: 15),
                Text(
                  "Feedback for Prompt ${_currentPromptIndex + 1}:",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).primaryColorDark,
                      ),
                ),
                if (currentPromptData?.transcription != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: RichText(
                      text: TextSpan(
                        style: DefaultTextStyle.of(context).style,
                        children: [
                          const TextSpan(
                            text: "Azure heard: ",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(
                            text: "\"${currentPromptData!.transcription}\"",
                            style: const TextStyle(fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (currentPromptData?.azureAiFeedback != null) ...[
                  _buildAzureMetricsDisplay(
                    currentPromptData!.azureAiFeedback!,
                  ),
                  _buildWordBreakdownDisplay(
                    currentPromptData.azureAiFeedback!['words']
                        as List<dynamic>?,
                  ),
                ],
                if (currentPromptData?.openAiDetailedFeedback != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0, bottom: 4.0),
                    child: Text(
                      "Coach's Playbook:",
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.teal.shade700,
                          ),
                    ),
                  ),
                  Card(
                    elevation: 0,
                    color: Colors.teal[50],
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: Colors.teal.shade100),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Html(
                        data: currentPromptData!.openAiDetailedFeedback!,
                        style: {
                          "body": Style(
                            fontSize: FontSize.medium,
                            lineHeight: LineHeight.normal,
                          ),
                        },
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed:
                      _isProcessingCurrentPrompt ? null : _handleNextPrompt,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                  ),
                  child: Text(
                    _currentPromptIndex < _speakingPrompts.length - 1
                        ? 'Next Prompt'
                        : 'Finish & View Summary',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ] else if (_showOverallResultsView) ...[
              Text(
                "Lesson Summary & Reflections",
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (_overallLessonScoreForDisplay != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Text(
                    "Your Overall Average Score: ${_overallLessonScoreForDisplay!.toStringAsFixed(1)}%",
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.purple.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              const SizedBox(height: 10),
              Text(
                "Your Reflections:",
                style: Theme.of(context).textTheme.titleLarge,
              ),
              TextField(
                controller: _confidenceController,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "How confident did you feel during this practice?",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _hardestSentenceController,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText:
                      "Which sentence or phrase was the most challenging and why?",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _improvementController,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText:
                      "What specific areas will you focus on to improve?",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmittingLesson ? null : _handleSubmitLesson,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00568D),
                  ),
                  child: _isSubmittingLesson
                      ? const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        )
                      : const Text(
                          'Submit Lesson Attempt',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  widget.onShowActivitySection();
                  setState(() {
                    _showOverallResultsView = false;
                  });
                },
                child: const Text("Retake Full Speaking Activity"),
              ),
            ],
          ] else if (widget.showActivitySectionInitially &&
              widget.displayFeedback) ...[
            Text(
              "Displaying overall feedback for a past attempt. (UI Placeholder - parent module handles this data)",
              style: TextStyle(color: Colors.purple),
            ),
            ElevatedButton(
              onPressed: widget.onShowActivitySection,
              child: const Text("Try Again"),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAzureMetricsDisplay(Map<String, dynamic> azureFeedback) {
    /* ... Same as before ... */
    Widget metricRow(String label, dynamic scoreValue, IconData icon) {
      double score = 0.0;
      if (scoreValue is num) score = scoreValue.toDouble();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5.0),
        child: Row(
          children: [
            FaIcon(icon, size: 18, color: Theme.of(context).primaryColorDark),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "$label: ",
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
            Text(
              "${score.toStringAsFixed(0)}${label.contains('Score') ? '%' : ''}",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color:
                    score > 70 ? Colors.green.shade700 : Colors.orange.shade800,
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Azure AI Speech Analysis:",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).primaryColorDark,
                  ),
            ),
            const Divider(height: 15),
            if (azureFeedback['accuracyScore'] != null)
              metricRow(
                "Accuracy Score",
                azureFeedback['accuracyScore'],
                FontAwesomeIcons.percentage,
              ),
            if (azureFeedback['fluencyScore'] != null)
              metricRow(
                "Fluency Score",
                azureFeedback['fluencyScore'],
                FontAwesomeIcons.personRunning,
              ),
            if (azureFeedback['completenessScore'] != null)
              metricRow(
                "Completeness Score",
                azureFeedback['completenessScore'],
                FontAwesomeIcons.clipboardCheck,
              ),
            if (azureFeedback['prosodyScore'] != null)
              metricRow(
                "Prosody Score",
                azureFeedback['prosodyScore'],
                FontAwesomeIcons.music,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWordBreakdownDisplay(List<dynamic>? words) {
    /* ... Same as before ... */
    if (words == null || words.isEmpty)
      return const Text(
        "No word-by-word breakdown.",
        style: TextStyle(fontStyle: FontStyle.italic),
      );
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Word-by-Word Breakdown:",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).primaryColorDark,
                  ),
            ),
            const Divider(height: 15),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: words.map((wordDataMap) {
                final wordData = wordDataMap as Map<String, dynamic>;
                final word = wordData['word'] as String? ?? '';
                final accuracy = wordData['accuracyScore'] as num?;
                final errorType = wordData['errorType'] as String?;
                Color wordColor = Colors.black87;
                String displaySuffix = "";
                if (accuracy != null) {
                  if (accuracy < 60) {
                    wordColor = Colors.red.shade700;
                    displaySuffix = " (${accuracy.toStringAsFixed(0)}%)";
                  } else if (accuracy < 85) {
                    wordColor = Colors.orange.shade800;
                    displaySuffix = " (${accuracy.toStringAsFixed(0)}%)";
                  } else {
                    wordColor = Colors.green.shade800;
                  }
                }
                if (errorType != null &&
                    errorType != "None" &&
                    errorType != "NoError") {
                  displaySuffix += " - $errorType";
                }
                return Chip(
                  label: Text(
                    word + displaySuffix,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  backgroundColor: wordColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
