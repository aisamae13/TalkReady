// lesson5_1.dart (Revised for robust HTML display and previous fixes)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_html/flutter_html.dart'; // For OpenAI HTML feedback
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import '../lessons/common_widgets.dart'; // For buildSlide
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../firebase_service.dart';

// TurnDataL5 Class (same as before)
class TurnDataL5 {
  final String id;
  final String character;
  final String text;
  final String? voice;
  String? localAudioPath;
  String? audioStorageUrl;
  String? transcription;
  Map<String, dynamic>? azureAiFeedback;
  String? openAiDetailedFeedback; // Expected to be HTML
  bool isProcessed;
  bool isPlayingCustomerAudio;

  TurnDataL5({
    required this.id,
    required this.character,
    required this.text,
    this.voice,
    this.localAudioPath,
    this.audioStorageUrl,
    this.transcription,
    this.azureAiFeedback,
    this.openAiDetailedFeedback,
    this.isProcessed = false,
    this.isPlayingCustomerAudio = false,
  });

  TurnDataL5 copyWith({
    String? localAudioPath,
    String? audioStorageUrl,
    String? transcription,
    Map<String, dynamic>? azureAiFeedback,
    String? openAiDetailedFeedback,
    bool? isProcessed,
    bool? isPlayingCustomerAudio,
  }) {
    return TurnDataL5(
      id: id,
      character: character,
      text: text,
      voice: voice,
      localAudioPath: localAudioPath ?? this.localAudioPath,
      audioStorageUrl: audioStorageUrl ?? this.audioStorageUrl,
      transcription: transcription ?? this.transcription,
      azureAiFeedback: azureAiFeedback ?? this.azureAiFeedback,
      openAiDetailedFeedback:
          openAiDetailedFeedback ?? this.openAiDetailedFeedback,
      isProcessed: isProcessed ?? this.isProcessed,
      isPlayingCustomerAudio:
          isPlayingCustomerAudio ?? this.isPlayingCustomerAudio,
    );
  }
}

// Lesson5_1 StatefulWidget (same props as before)
class Lesson5_1 extends StatefulWidget {
  final int currentSlide;
  final CarouselSliderController carouselController;
  final Function(int) onSlideChanged;
  final int initialAttemptNumber;
  final bool showActivityInitially;
  final VoidCallback onShowActivitySection;
  final bool passToShowSummary;
  final Map<String, dynamic>? summaryData;
  final Future<Map<String, dynamic>?> Function({
    required String turnId,
    required String localAudioPath,
    required String originalText,
  }) onProcessAgentTurn;
  final Future<void> Function({
    required String lessonIdFirestoreKey,
    required int attemptNumber,
    required int timeSpent,
    required double overallLessonScore,
    required List<Map<String, dynamic>> turnDetails,
  }) onSaveLessonAttempt;

  const Lesson5_1({
    super.key,
    required this.currentSlide,
    required this.carouselController,
    required this.onSlideChanged,
    required this.initialAttemptNumber,
    required this.showActivityInitially,
    required this.onShowActivitySection,
    required this.passToShowSummary,
    this.summaryData,
    required this.onProcessAgentTurn,
    required this.onSaveLessonAttempt,
  });

  @override
  _Lesson5_1State createState() => _Lesson5_1State();
}

class _Lesson5_1State extends State<Lesson5_1> {
  final FirebaseService _firebaseService = FirebaseService();
  // Logger, TTS, AudioRecorder, AudioPlayer (same as before)
  final Logger _logger = Logger(
      printer: PrettyPrinter(
          methodCount: 1,
          errorMethodCount: 5,
          lineLength: 120,
          colors: true,
          printEmojis: true,
          printTime: false));
  FlutterTts flutterTts = FlutterTts();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // State variables (same as before)
  bool _isStudied = false;
  bool _isActivityVisible = false;
  bool _showFinalSummary = false;
  int _currentTurnIndex = 0;
  Map<String, TurnDataL5> _turnDataStateMap = {};
  bool _isRecording = false;
  bool _isProcessingTurn = false;
  bool _isLoadingAI = false;
  int? _completedAttemptNumberForSummary;
  Timer? _timer;
  int _secondsElapsed = 0;
  late int _currentAttemptNumberForUI;
  double? _overallLessonScore;

  // _callSimulationTurns and _studySlides (same as before)
  final List<TurnDataL5> _callSimulationTurns = [
    TurnDataL5(
        id: 'turn1_customer_complex',
        text:
            "Hi there, I was hoping to find out your opening hours today, and also, are you open this Saturday? I usually work weekdays, so Saturdays are better for me.",
        character: "Customer",
        voice: "US English Female"),
    TurnDataL5(
        id: 'turn2_agent_complex',
        text:
            "Good morning! Our standard hours are Monday to Friday, 9 a.m. to 5 p.m. Regarding Saturdays, we are unfortunately closed. However, our online support portal is available 24/7.",
        character: "Agent - Your Turn"),
    TurnDataL5(
        id: 'turn3_customer_complex',
        text:
            "Oh, closed on Saturdays? That's a bit inconvenient. Is there any way to reach support or get specific account help outside of those weekday hours?",
        character: "Customer",
        voice: "US English Female"),
    TurnDataL5(
        id: 'turn4_agent_complex',
        text:
            "I understand that can be inconvenient. While our live phone support is available during weekday hours, you can send us an email anytime, and we typically respond within 24 hours. Our website also has a comprehensive FAQ section. Would you like the email address for support?",
        character: "Agent - Your Turn"),
    TurnDataL5(
        id: 'turn5_customer_complex',
        text: "Okay, yes, the email address would be helpful. Thank you.",
        character: "Customer",
        voice: "US English Female"),
    TurnDataL5(
        id: 'turn6_agent_complex',
        text:
            "Certainly, our support email is support@talkready.ai. Is there anything else I can assist you with today?",
        character: "Agent - Your Turn"),
  ];

  final List<Map<String, String>> _studySlides = [
    {
      'title': 'Lesson Objective',
      'content':
          'To practice handling a simulated call where a customer asks for straightforward information, requiring a basic greeting, understanding the request, providing a simple answer, and concluding the call politely.'
    },
    {
      'title': 'Key Skills Integrated',
      'content':
          '• Module 1 (Grammar): Using basic sentence structures and correct present simple tense.\n• Module 2 (Vocabulary & Conversation): Applying standard greetings, using vocabulary for numbers/dates/times, and using basic closing phrases.\n• Module 3 (Listening & Speaking): Listening for a simple, clear request; speaking clearly and at a basic, understandable pace; maintaining basic fluency and pronunciation.\n• Module 4 (Basic Handling): Providing simple, direct information.'
    },
    {
      'title': 'Interactive Activity: Basic Call Simulation',
      'content':
          'Participate in a short, multi-turn simulated call. Listen to the customer, then speak your response using the recording feature.'
    },
    {
      'title': 'Scenario Example: Handling a Multi-Part Inquiry',
      'content':
          '<strong>Customer:</strong> "Hi there, I was hoping to find out your opening hours today, and also, are you open this Saturday? I usually work weekdays, so Saturdays are better for me."<br><strong>Your Goal (Agent):</strong> Clearly provide weekday hours, address the Saturday query, and offer an alternative if closed on Saturdays (e.g., "Good morning! Our standard hours are Monday to Friday, 9 a.m. to 5 p.m. Regarding Saturdays, we are unfortunately closed. However, our online support portal is available 24/7.").'
    },
    {
      'title': 'Evaluation Focus',
      'content':
          'Your performance will be evaluated on:\n• Listening accuracy (addressing the simple request).\n• Pronunciation and basic fluency.\n• Correct basic grammar and vocabulary.\n• Appropriateness of basic greeting and closing.\n• Overall successful completion of the simple call flow.'
    },
  ];

  // initState with logging (same as last full update)
  @override
  void initState() {
    super.initState();
    _logger.i("L5.1 initState: START");
    _logger.d(
        "L5.1 initState: widget.passToShowSummary=${widget.passToShowSummary}, widget.summaryData isNotNull=${widget.summaryData != null}, widget.initialAttemptNumber=${widget.initialAttemptNumber}, widget.showActivityInitially=${widget.showActivityInitially}");
    if (widget.summaryData != null) {
      _logger.d(
          "L5.1 initState: summaryData content: attemptNumber=${widget.summaryData!['attemptNumber']}, overallScore=${widget.summaryData!['overallLessonScore']}");
    }

    _currentAttemptNumberForUI = widget.initialAttemptNumber + 1;
    _initializeTts();

    if (widget.passToShowSummary && widget.summaryData != null) {
      _logger.i("L5.1 initState: Conditions met for WILL SHOW SUMMARY.");
      _isStudied = true;
      _isActivityVisible = true;
      _showFinalSummary = true;

      _overallLessonScore =
          widget.summaryData!['overallLessonScore'] as double?;
      _secondsElapsed = widget.summaryData!['timeSpent'] as int;
      _completedAttemptNumberForSummary =
          widget.summaryData!['attemptNumber'] as int;
      _logger.i(
          "L5.1 initState: Summary state set. Overall Score: $_overallLessonScore, Completed Attempt: $_completedAttemptNumberForSummary");
    } else {
      _logger.i(
          "L5.1 initState: Conditions for summary NOT met. Setting up for STUDY or ACTIVITY.");
      _isStudied = widget.showActivityInitially;
      _isActivityVisible = widget.showActivityInitially;
      _showFinalSummary = false;

      if (_isActivityVisible) {
        _logger.i(
            "L5.1 initState: Activity is visible, calling _startNewLessonAttempt for attempt #$_currentAttemptNumberForUI.");
        _startNewLessonAttempt();
      } else {
        _logger.i(
            "L5.1 initState: Activity not visible, will go to study phase. _isStudied=$_isStudied");
      }
    }
    _logger.i(
        "L5.1 initState: END. _showFinalSummary=$_showFinalSummary, _isActivityVisible=$_isActivityVisible, _isStudied=$_isStudied");
  }

  // All other methods (_initializeTts, _startNewLessonAttempt, _playCurrentCustomerTurnAudio,
  // _startTimer, _stopTimer, _formatDuration, _handleStartRecording, _handleStopRecordingAndProcess,
  // _playLocalRecording, _processCurrentAgentTurn, _handleNextTurn, _calculateAndSaveLessonScore)
  // remain IDENTICAL to the "full update" I provided in the response before you sent the web files.
  // For brevity, I am not repeating them here but assume they are present and correct from that version.
  // Make sure the copyWith method in TurnDataL5 is used in those methods. I've put placeholders below.

  Future<void> _initializeTts() async {
    /* ...as before... */ await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.5);
    flutterTts.setCompletionHandler(() {
      if (_currentTurnIndex >= _callSimulationTurns.length) return;
      final currentTurnId = _callSimulationTurns[_currentTurnIndex].id;
      if (mounted &&
          _turnDataStateMap.containsKey(currentTurnId) &&
          _turnDataStateMap[currentTurnId]!.isPlayingCustomerAudio == true) {
        setState(() {
          _turnDataStateMap[currentTurnId] = _turnDataStateMap[currentTurnId]!
              .copyWith(isPlayingCustomerAudio: false);
        });
      }
    });
  }

  void _startNewLessonAttempt() {
    /* ...as before... */ _logger.i(
        "L5.1 _startNewLessonAttempt: Starting for attempt #$_currentAttemptNumberForUI");
    if (mounted) {
      setState(() {
        _currentTurnIndex = 0;
        _turnDataStateMap = {};
        for (var turn in _callSimulationTurns) {
          _turnDataStateMap[turn.id] = turn;
        }
        _isRecording = false;
        _isProcessingTurn = false;
        _showFinalSummary = false;
        _completedAttemptNumberForSummary = null;
        _overallLessonScore = null;
        _secondsElapsed = 0;
        _startTimer();
      });
      _playCurrentCustomerTurnAudio();
    }
  }

  void _playCurrentCustomerTurnAudio() async {
    /* ...as before... */ if (_currentTurnIndex < _callSimulationTurns.length) {
      final currentTurn = _callSimulationTurns[_currentTurnIndex];
      if (currentTurn.character == "Customer") {
        final turnId = currentTurn.id;
        if (!_turnDataStateMap.containsKey(turnId)) {
          _turnDataStateMap[turnId] = currentTurn;
        }
        setState(() {
          _turnDataStateMap[turnId] =
              _turnDataStateMap[turnId]!.copyWith(isPlayingCustomerAudio: true);
        });
        await flutterTts.speak(currentTurn.text);
      }
    }
  }

  void _startTimer() {
    /* ...as before... */ _stopTimer();
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
    /* ...as before... */ _timer?.cancel();
  }

  String _formatDuration(int totalSeconds) {
    /* ...as before... */ final d = Duration(seconds: totalSeconds);
    return "${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}";
  }

  Future<void> _handleStartRecording() async {
    /* ...as before... */ final hasPermission =
        await _audioRecorder.hasPermission();
    if (!hasPermission) {
      _logger.w("L5.1: Mic permission denied.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Mic permission required.')));
      }
      return;
    }
    final currentTurn = _callSimulationTurns[_currentTurnIndex];
    if (_turnDataStateMap[currentTurn.id]?.isProcessed == true ||
        _isProcessingTurn) {
      return;
    }
    final tempDir = await getTemporaryDirectory();
    final path =
        '${tempDir.path}/turn_${currentTurn.id}_${DateTime.now().millisecondsSinceEpoch}.m4a';
    try {
      await _audioRecorder
          .start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
      setState(() {
        _isRecording = true;
        _turnDataStateMap[currentTurn.id] =
            (_turnDataStateMap[currentTurn.id] ?? currentTurn).copyWith(
                localAudioPath: null,
                audioStorageUrl: null,
                transcription: null,
                azureAiFeedback: null,
                openAiDetailedFeedback: null,
                isProcessed: false);
      });
      _logger.i("L5.1: Recording started. Path: $path");
    } catch (e) {
      _logger.e("L5.1: Error starting recording: $e");
    }
  }

  Future<void> _handleStopRecordingAndProcess() async {
    /* ...as before... */ if (!_isRecording) return;
    final currentTurn = _callSimulationTurns[_currentTurnIndex];
    try {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);
      if (path != null) {
        _logger.i("L5.1: Recording stopped. File: $path");
        setState(() {
          _turnDataStateMap[currentTurn.id] =
              (_turnDataStateMap[currentTurn.id] ?? currentTurn)
                  .copyWith(localAudioPath: path);
        });
        _processCurrentAgentTurn(currentTurn.id, path, currentTurn.text);
      }
    } catch (e) {
      _logger.e("L5.1: Error stopping recording: $e");
    }
  }

  Future<void> _playLocalRecording(String? path) async {
    /* ...as before... */ if (path == null || path.isEmpty) return;
    try {
      await _audioPlayer.play(DeviceFileSource(path));
    } catch (e) {
      _logger.e("L5.1: Error playing local recording: $e");
    }
  }

  Future<void> _processCurrentAgentTurn(
      String turnId, String localAudioPath, String originalScriptText) async {
    /* ...as before... */ if (!mounted) return;
    setState(() => _isProcessingTurn = true);
    try {
      final result = await widget.onProcessAgentTurn(
          turnId: turnId,
          localAudioPath: localAudioPath,
          originalText: originalScriptText);
      if (!mounted) return;
      final currentTurnObject = _turnDataStateMap[turnId] ??
          _callSimulationTurns.firstWhere((t) => t.id == turnId);
      if (result != null && result['error'] == null) {
        setState(() {
          _turnDataStateMap[turnId] = currentTurnObject.copyWith(
              audioStorageUrl: result['audioStorageUrl'] as String?,
              transcription: result['transcription'] as String?,
              azureAiFeedback:
                  result['azureAiFeedback'] as Map<String, dynamic>?,
              openAiDetailedFeedback:
                  result['openAiDetailedFeedback'] as String?,
              isProcessed: true);
        });
      } else {
        setState(() {
          _turnDataStateMap[turnId] = currentTurnObject.copyWith(
              isProcessed: true,
              openAiDetailedFeedback:
                  "Error: ${result?['error'] ?? 'Unknown'}");
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _turnDataStateMap[turnId] = (_turnDataStateMap[turnId] ??
                  _callSimulationTurns.firstWhere((t) => t.id == turnId))
              .copyWith(
                  isProcessed: true, openAiDetailedFeedback: "Exception: $e");
        });
      }
    } finally {
      if (mounted) setState(() => _isProcessingTurn = false);
    }
  }

  Future<void> _handleNextTurn() async {
    /* ...as before... */ if (_isProcessingTurn || _isRecording) return;
    final currentTurnId = _callSimulationTurns[_currentTurnIndex].id;
    final currentTurnData = _turnDataStateMap[currentTurnId];
    if (_callSimulationTurns[_currentTurnIndex].character ==
            "Agent - Your Turn" &&
        (currentTurnData == null || currentTurnData.isProcessed != true)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Please record/submit your response.")));
      }
      return;
    }
    if (_currentTurnIndex < _callSimulationTurns.length - 1) {
      if (mounted) {
        setState(() => _currentTurnIndex++);
        _playCurrentCustomerTurnAudio();
      }
    } else {
      _logger.i("L5.1: Call simulation ended.");
      _stopTimer();
      _completedAttemptNumberForSummary = _currentAttemptNumberForUI;
      setState(() => _showFinalSummary = true);
      await _calculateAndSaveLessonScore();
    }
  }

  Future<void> _calculateAndSaveLessonScore() async {
    /* ...as before... */ if (!mounted) return;
    setState(() => _isLoadingAI = true);
    double totalAccuracyScore = 0;
    int agentTurnsProcessed = 0;
    _turnDataStateMap.forEach((turnId, data) {
      if (data.character == "Agent - Your Turn" &&
          data.isProcessed &&
          data.azureAiFeedback != null) {
        final accuracy = data.azureAiFeedback!['accuracyScore'] as num?;
        if (accuracy != null) {
          totalAccuracyScore += accuracy;
          agentTurnsProcessed++;
        }
      }
    });
    final double averageAccuracy = agentTurnsProcessed > 0
        ? (totalAccuracyScore / agentTurnsProcessed)
        : 0.0;
    if (mounted) {
      setState(() => _overallLessonScore =
          double.parse(averageAccuracy.toStringAsFixed(1)));
    }
    final List<Map<String, dynamic>> turnDetailsForFirebase =
        _callSimulationTurns.map((turn) {
      final data = _turnDataStateMap[turn.id];
      return {
        'id': turn.id,
        'text': turn.text,
        'character': turn.character,
        'audioUrl': data?.audioStorageUrl,
        'transcription': data?.transcription,
        'score': (data?.azureAiFeedback?['accuracyScore'] as num?)?.toDouble(),
        'azureAiFeedback': data?.azureAiFeedback,
        'openAiDetailedFeedback': data?.openAiDetailedFeedback
      };
    }).toList();

    // >>> START OF NEW LOGIC TO DETERMINE CORRECT ATTEMPT NUMBER <<<
    String? userId = _firebaseService.userId;
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User not authenticated.')));
        setState(() => _isLoadingAI = false);
      }
      return;
    }

    final String lessonIdFirestoreKey = "Lesson 5.1"; // Specific for this file
    List<Map<String, dynamic>> pastDetailedAttempts = [];
    try {
      pastDetailedAttempts = await _firebaseService
          .getDetailedLessonAttempts(lessonIdFirestoreKey);
    } catch (e) {
      _logger.e(
          "Error fetching past detailed attempts for $lessonIdFirestoreKey: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Could not verify past attempts. Please try again.')));
        setState(() => _isLoadingAI = false);
      }
      return;
    }

    final int actualNextAttemptNumber = pastDetailedAttempts.length + 1;
    // >>> END OF NEW LOGIC <<<

    // Determine the attempt number to save. Use the newly calculated one.
    final attemptNumberToSave = actualNextAttemptNumber;

    try {
      await widget.onSaveLessonAttempt(
          lessonIdFirestoreKey: lessonIdFirestoreKey, // e.g., "Lesson 5.1"
          attemptNumber: attemptNumberToSave, // <<< USE THE CORRECTED NUMBER
          timeSpent: _secondsElapsed,
          overallLessonScore: _overallLessonScore ?? 0.0,
          turnDetails: turnDetailsForFirebase);

      // Update UI state for the current attempt number display
      if (mounted) {
        setState(() {
          _currentAttemptNumberForUI = attemptNumberToSave;
          _completedAttemptNumberForSummary =
              attemptNumberToSave; // If you use this for summary display
        });
      }
      _logger.i("L5.1: Attempt #$attemptNumberToSave saved successfully.");
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error saving progress: $e")));
      }
      _logger.e("L5.1: Error in onSaveLessonAttempt: $e");
    } finally {
      if (mounted) setState(() => _isLoadingAI = false);
    }
  }

  Future<Map<String, dynamic>?> _fetchUserProgress() async {
    try {
      final userId = _firebaseService.userId;
      if (userId == null) {
        _logger.w("L5.1: User not authenticated");
        return null;
      }
      
      final prog = await FirebaseFirestore.instance
          .collection('userProgress')
          .doc(userId)
          .get();
          
      if (prog.exists) {
        _logger.i('L5.1: User progress data fetched');
        return prog.data();
      }
    } catch (e) {
      _logger.e('L5.1: Error fetching user progress: $e');
    }
    return null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _logger.i(
        "L5.1 build: Building UI. _showFinalSummary=$_showFinalSummary, widget.passToShowSummary=${widget.passToShowSummary}, _isActivityVisible=$_isActivityVisible, _isStudied=$_isStudied, widget.showActivityInitially=${widget.showActivityInitially}");

    Widget content;
    final currentSimulationTurn =
        (_currentTurnIndex < _callSimulationTurns.length &&
                _currentTurnIndex >= 0)
            ? _callSimulationTurns[_currentTurnIndex]
            : null;
    final currentTurnProcessedData = (currentSimulationTurn != null &&
            _turnDataStateMap.containsKey(currentSimulationTurn.id))
        ? _turnDataStateMap[currentSimulationTurn.id]
        : null;

    if (_showFinalSummary &&
        widget.passToShowSummary &&
        widget.summaryData != null) {
      _logger.i("L5.1 build: Rendering SUMMARY phase.");
      final List<dynamic>? turnDetailsList =
          widget.summaryData!['turnDetails'] as List<dynamic>?;
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Text('Call Simulation Complete!',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.green, fontWeight: FontWeight.bold))),
          if (_overallLessonScore != null &&
              _completedAttemptNumberForSummary != null)
            Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                    "Overall Score for Attempt #$_completedAttemptNumberForSummary: ${_overallLessonScore?.toStringAsFixed(1)}%",
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold))),
          const Divider(height: 20, thickness: 1),
          Text("Detailed Review:",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          (turnDetailsList == null || turnDetailsList.isEmpty)
              ? const Center(
                  child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child:
                          Text("No detailed turn data available for review.")))
              : ListView.builder(
                  shrinkWrap: true, // Fix for Expanded in SingleChildScrollView
                  physics:
                      const NeverScrollableScrollPhysics(), // Fix for Expanded in SingleChildScrollView
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  itemCount: turnDetailsList.length,
                  itemBuilder: (ctx, index) {
                    final turnData =
                        turnDetailsList[index] as Map<String, dynamic>;
                    final String character = turnData['character'] ?? 'Unknown';
                    final String text = turnData['text'] ?? 'No script.';
                    final String? transcription =
                        turnData['transcription'] as String?;
                    final Map<String, dynamic>? azureFeedback =
                        turnData['azureAiFeedback'] as Map<String, dynamic>?;
                    final String? openAiFeedbackHtml =
                        turnData['openAiDetailedFeedback'] as String?;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6.0),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("${index + 1}. $character:",
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: character == "Customer"
                                            ? Colors.blueGrey
                                            : Theme.of(context)
                                                .colorScheme
                                                .primary)),
                            const SizedBox(height: 6),
                            Text(text,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(fontStyle: FontStyle.italic)),
                            if (character == "Agent - Your Turn") ...[
                              if (transcription != null &&
                                  transcription.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                const Text("Your Transcription:",
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                Padding(
                                    padding: const EdgeInsets.only(
                                        top: 4.0, left: 8.0),
                                    child: Text(transcription,
                                        style: const TextStyle(
                                            color: Colors.black87))),
                              ],
                              if (azureFeedback != null) ...[
                                const SizedBox(height: 10),
                                _buildAzureFeedbackDisplay(
                                    azureFeedback, context)
                              ],
                              if (openAiFeedbackHtml != null &&
                                  openAiFeedbackHtml.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                _buildOpenAICoachFeedbackDisplay(
                                    openAiFeedbackHtml)
                              ], // Using corrected HTML display
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
          const SizedBox(height: 10),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: Text(
                  "Try Another Simulation (Attempt #$_currentAttemptNumberForUI)"),
              onPressed: _isLoadingAI ? null : _startNewLessonAttempt,
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
          ),
        ],
      );
    } else if (!_isStudied && !widget.showActivityInitially) {
      _logger.i("L5.1 build: Rendering STUDY phase.");
      content = Column(
        /* ... Study phase UI as before ... */
        children: [
          if (_studySlides.isNotEmpty)
            CarouselSlider(
                carouselController: widget.carouselController,
                items: _studySlides
                    .map((slide) => buildSlide(
                        title: slide['title']!,
                        content: slide['content']!,
                        slideIndex: _studySlides.indexOf(slide)))
                    .toList(),
                options: CarouselOptions(
                    height: 300.0,
                    enlargeCenterPage: false,
                    enableInfiniteScroll: false,
                    initialPage: widget.currentSlide,
                    onPageChanged: (index, reason) =>
                        widget.onSlideChanged(index),
                    viewportFraction: 0.95)),
          Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _studySlides
                  .asMap()
                  .entries
                  .map((entry) => GestureDetector(
                      onTap: () =>
                          widget.carouselController.animateToPage(entry.key),
                      child: Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 2),
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: widget.currentSlide == entry.key
                                  ? Theme.of(context).primaryColor
                                  : Colors.grey))))
                  .toList()),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.school),
            label: const Text("I've Reviewed Material – Start Simulation"),
            onPressed: () {
              setState(() {
                _isStudied = true;
                _isActivityVisible = true;
              });
              widget.onShowActivitySection();
              _startNewLessonAttempt();
            },
          ),
        ],
      );
    } else if (_isActivityVisible) {
      _logger.i(
          "L5.1 build: Rendering ACTIVITY phase for attempt #$_currentAttemptNumberForUI.");
      content = Column(
        /* ... Activity phase UI as before ... */
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
              'Basic Call Simulation: Scenario 1 - Attempt $_currentAttemptNumberForUI',
              style: Theme.of(context).textTheme.headlineSmall),
          Text('Time: ${_formatDuration(_secondsElapsed)}',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          if (currentSimulationTurn != null) ...[
            Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("${currentSimulationTurn.character}:",
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(currentSimulationTurn.text,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(fontStyle: FontStyle.italic)),
                          if (currentSimulationTurn.character == "Customer")
                            Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: ElevatedButton.icon(
                                    icon: FaIcon(
                                        currentTurnProcessedData
                                                    ?.isPlayingCustomerAudio ==
                                                true
                                            ? FontAwesomeIcons.volumeMute
                                            : FontAwesomeIcons.volumeUp,
                                        size: 16),
                                    label: Text(currentTurnProcessedData
                                                ?.isPlayingCustomerAudio ==
                                            true
                                        ? "Stop Audio"
                                        : "Listen to Customer"),
                                    onPressed: () {
                                      if (currentTurnProcessedData
                                              ?.isPlayingCustomerAudio ==
                                          true) {
                                        flutterTts.stop();
                                        setState(() {
                                          _turnDataStateMap[
                                                  currentSimulationTurn.id] =
                                              (_turnDataStateMap[
                                                          currentSimulationTurn
                                                              .id] ??
                                                      currentSimulationTurn)
                                                  .copyWith(
                                                      isPlayingCustomerAudio:
                                                          false);
                                        });
                                      } else {
                                        _playCurrentCustomerTurnAudio();
                                      }
                                    })),
                        ]))),
            if (currentSimulationTurn.character == "Agent - Your Turn") ...[
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                ElevatedButton.icon(
                    icon: FaIcon(_isRecording
                        ? FontAwesomeIcons.stopCircle
                        : FontAwesomeIcons.microphoneAlt),
                    label: Text(_isRecording ? "Stop" : "Record"),
                    onPressed: (_isProcessingTurn ||
                            (currentTurnProcessedData?.isProcessed ?? false))
                        ? null
                        : (_isRecording
                            ? _handleStopRecordingAndProcess
                            : _handleStartRecording),
                    style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _isRecording ? Colors.redAccent : Colors.green)),
                if (currentTurnProcessedData?.localAudioPath != null &&
                    !_isRecording)
                  IconButton(
                      icon: const FaIcon(FontAwesomeIcons.playCircle),
                      onPressed: () => _playLocalRecording(
                          currentTurnProcessedData?.localAudioPath),
                      tooltip: "Play My Recording"),
              ]),
              if (_isProcessingTurn)
                const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator())),
              if (currentTurnProcessedData?.isProcessed == true &&
                  !_isProcessingTurn) ...[
                if (currentTurnProcessedData?.transcription != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                          "Transcription: ${currentTurnProcessedData!.transcription}",
                          style: const TextStyle(fontWeight: FontWeight.w500))),
                if (currentTurnProcessedData?.azureAiFeedback != null)
                  _buildAzureFeedbackDisplay(
                      currentTurnProcessedData!.azureAiFeedback!, context),
                if (currentTurnProcessedData?.openAiDetailedFeedback != null)
                  _buildOpenAICoachFeedbackDisplay(currentTurnProcessedData!
                      .openAiDetailedFeedback!), // Using HTML renderer for activity phase too
              ],
            ],
            const SizedBox(height: 20),
            if ((currentSimulationTurn.character == "Customer" ||
                    (currentTurnProcessedData?.isProcessed == true)) &&
                !_isRecording &&
                !_isProcessingTurn)
              ElevatedButton.icon(
                  icon: const FaIcon(FontAwesomeIcons.arrowRight),
                  label: Text(
                      _currentTurnIndex < _callSimulationTurns.length - 1
                          ? "Next Turn"
                          : "End Call & View Summary"),
                  onPressed: _handleNextTurn),
          ] else
            const Text("Loading turn...")
        ],
      );
    } else {
      _logger.w(
          "L5.1 build: Reached FALLBACK content. State: _isStudied=$_isStudied, _isActivityVisible=$_isActivityVisible, _showFinalSummary=$_showFinalSummary");
      content = const Center(
          child: Text(
              "Loading lesson content or please start from study material."));
    }

    return SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: _isLoadingAI
            ? const Center(child: CircularProgressIndicator())
            : content);
  }

  // _buildAzureFeedbackDisplay (Detailed version - same as last full update)
  Widget _buildAzureFeedbackDisplay(
      Map<String, dynamic> azureFeedback, BuildContext context) {
    final accuracy = (azureFeedback['accuracyScore'] as num?)?.toDouble();
    final fluency = (azureFeedback['fluencyScore'] as num?)?.toDouble();
    final completeness =
        (azureFeedback['completenessScore'] as num?)?.toDouble();
    final prosody = (azureFeedback['prosodyScore'] as num?)?.toDouble();
    final words = (azureFeedback['words'] as List<dynamic>?)
        ?.map((w) => w as Map<String, dynamic>)
        .toList();

    Color getWordChipColor(Map<String, dynamic> wordData) {
      final errorType = wordData['errorType'] as String?;
      final wordAcc = (wordData['accuracyScore'] as num?)?.toDouble();
      if (errorType == "Mispronunciation") return Colors.orange.shade200;
      if (errorType == "Omission") return Colors.red.shade200;
      if (errorType == "Insertion") return Colors.purple.shade200;
      if (wordAcc == null) return Colors.grey.shade300;
      if (wordAcc >= 90) return Colors.green.shade100;
      if (wordAcc >= 70) return Colors.yellow.shade100;
      return Colors.red.shade100;
    }

    String getWordDisplayText(Map<String, dynamic> wordData) {
      final wordText = wordData['word'] as String? ?? '';
      final errorType = wordData['errorType'] as String?;
      if (errorType == "Omission" &&
          (wordText.isEmpty || wordText == "omitted")) {
        return "omitted";
      }
      return wordText;
    }

    return Card(
        /* ... same detailed card structure as before ... */
        elevation: 1,
        color: Colors.indigo[50],
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        child: Padding(
            padding: const EdgeInsets.all(12.0),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Azure AI Speech Analysis",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.indigo[700], fontWeight: FontWeight.bold)),
              const Divider(),
              if (accuracy != null)
                ListTile(
                    dense: true,
                    leading: const FaIcon(FontAwesomeIcons.percentage,
                        color: Colors.indigo, size: 18),
                    title: Text(
                        "Accuracy Score: ${accuracy.toStringAsFixed(1)}%")),
              if (fluency != null)
                ListTile(
                    dense: true,
                    leading: const FaIcon(FontAwesomeIcons.tachometerAlt,
                        color: Colors.indigo, size: 18),
                    title:
                        Text("Fluency Score: ${fluency.toStringAsFixed(1)}")),
              if (completeness != null)
                ListTile(
                    dense: true,
                    leading: const FaIcon(FontAwesomeIcons.clipboardCheck,
                        color: Colors.indigo, size: 18),
                    title: Text(
                        "Completeness Score: ${completeness.toStringAsFixed(1)}%")),
              if (prosody != null)
                ListTile(
                    dense: true,
                    leading: const FaIcon(FontAwesomeIcons.theaterMasks,
                        color: Colors.indigo, size: 18),
                    title:
                        Text("Prosody Score: ${prosody.toStringAsFixed(1)}")),
              if (words != null && words.isNotEmpty)
                ExpansionTile(
                    title: const Text("Word-by-Word Pronunciation Details",
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    tilePadding: EdgeInsets.zero,
                    childrenPadding:
                        const EdgeInsets.only(top: 8.0, bottom: 4.0),
                    children: [
                      Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Wrap(
                              spacing: 8.0,
                              runSpacing: 4.0,
                              alignment: WrapAlignment.center,
                              children: [
                                Chip(
                                    label: const Text('High (≥90%)'),
                                    backgroundColor: Colors.green.shade100,
                                    padding: EdgeInsets.zero),
                                Chip(
                                    label: const Text('Medium (70-89%)'),
                                    backgroundColor: Colors.yellow.shade100,
                                    padding: EdgeInsets.zero),
                                Chip(
                                    label: const Text('Low (<70%)'),
                                    backgroundColor: Colors.red.shade100,
                                    padding: EdgeInsets.zero),
                                Chip(
                                    label: const Text('Mispronounced'),
                                    backgroundColor: Colors.orange.shade200,
                                    padding: EdgeInsets.zero),
                                Chip(
                                    label: const Text('Insertion'),
                                    backgroundColor: Colors.purple.shade200,
                                    padding: EdgeInsets.zero)
                              ])),
                      Wrap(
                          spacing: 6.0,
                          runSpacing: 4.0,
                          children: words.map((wordData) {
                            final wordText = getWordDisplayText(wordData);
                            final wordAcc =
                                (wordData['accuracyScore'] as num?)?.toDouble();
                            final errorType = wordData['errorType'] as String?;
                            String displayLabel = wordText;
                            if (wordAcc != null && errorType != "Insertion") {
                              displayLabel +=
                                  " (${wordAcc.toStringAsFixed(0)}%)";
                            } else if (errorType == "Insertion") {
                              displayLabel = "+$wordText";
                            }
                            return Chip(
                                label: Text(displayLabel,
                                    style: const TextStyle(fontSize: 13)),
                                backgroundColor: getWordChipColor(wordData),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 0));
                          }).toList())
                    ]),
            ])));
  }

  // REVISED _buildOpenAICoachFeedbackDisplay to use Html widget with simpler styling first
  Widget _buildOpenAICoachFeedbackDisplay(String htmlFeedback) {
    return Card(
        elevation: 1,
        color: Colors.lightBlue[50],
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        child: Padding(
            padding: const EdgeInsets.all(12.0),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Coach's Playbook",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.lightBlue[800],
                      fontWeight: FontWeight.bold)),
              const Divider(),
              Html(
                data: htmlFeedback,
                style: {
                  // Start with a very simple style map, similar to lesson3_2.dart
                  "body": Style(
                    fontSize: FontSize.medium, // flutter_html FontSize
                    lineHeight: LineHeight.normal, // flutter_html LineHeight
                  ),
                  // You can cautiously add more specific styles for h4, ul, li, p, strong later
                  // if the basic rendering works. Example (KEEP THIS COMMENTED OUT INITIALLY):
                  /*
                  "h4": Style(
                    fontSize: FontSize.large,
                    fontWeight: FontWeight.w600,
                    color: Colors.lightBlue[700],
                    margin: Margins.only(top: Length(10.0), bottom: Length(5.0)),
                  ),
                  "ul": Style(
                    listStyleType: ListStyleType.none,
                    padding: Padding(),
                  ),
                  "li": Style(
                    margin: Margins.only(bottom: Length(6.0)),
                    padding: Padding.all(Length(6.0)),
                    backgroundColor: Colors.white,
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                  "p": Style(
                    margin: Margins.symmetric(vertical: Length(4.0)),
                  ),
                  "strong": Style(
                    fontWeight: FontWeight.w600,
                  ),
                  */
                },
              ),
            ])));
  }
}