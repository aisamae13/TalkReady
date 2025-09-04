import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../firebase_service.dart';
import '../StudentAssessment/AiFeedbackData.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'common_widgets.dart';
import '../widgets/parsed_feedback_card.dart';

// PromptAttemptData class for managing individual prompt states
class PromptAttemptData {
  String? audioStorageUrl;
  String? transcription;
  Map<String, dynamic>? azureAiFeedback;
  String? openAiDetailedFeedback;
  bool isProcessed;
  String? localAudioPath;
  bool isUploading;
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
  // Simplified constructor with only essential parameters
  final BuildContext parentContext;
  final bool showActivitySectionInitially;
  final VoidCallback onShowActivitySection;
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
    this.showActivitySectionInitially = false,
    required this.onShowActivitySection,
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
  final FirebaseService _firebaseService = FirebaseService();
  Timer? _timer;
  int _secondsElapsed = 0;
  late int _currentAttemptForDisplay;

  // Content state
  bool _isLoadingLessonContent = true;
  Map<String, dynamic>? _lessonData;
  List<dynamic> _speakingPrompts = [];
  int _currentPromptIndex = 0;

  // Audio and recording state
  late Map<String, PromptAttemptData> _promptAttemptDataMap;
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  bool _isLoadingModelAudio = false;
  FlutterTts? _flutterTts;

  // UI state
  final TextEditingController _confidenceController = TextEditingController();
  final TextEditingController _hardestSentenceController = TextEditingController();
  final TextEditingController _improvementController = TextEditingController();
  bool _showOverallResultsView = false;
  double? _overallLessonScoreForDisplay;
  bool _isSubmittingLesson = false;
  bool _isProcessingCurrentPrompt = false;
  String _activeTab = 'coach'; // 'coach', 'metrics', or 'words'

  // Pre-assessment state
  bool _isPreAssessmentComplete = false;
  bool _hasStudied = false;
  bool _isRecordingPreAssessment = false;
  String? _preAssessmentAudioPath;
  bool _isProcessingPreAssessment = false;
  Map<String, dynamic>? _preAssessmentResult;

  @override
  void initState() {
    super.initState();
    _currentAttemptForDisplay = widget.initialAttemptNumber + 1;
    _promptAttemptDataMap = {};
    _initializeFlutterTts();
    _fetchLessonContentAndInitialize();
    _checkPreAssessmentStatus();

    if (widget.showActivitySectionInitially && !widget.displayFeedback) {
      _startTimer();
    }
  }

  Future<void> _initializeFlutterTts() async {
    _flutterTts = FlutterTts();
    await _flutterTts?.setLanguage("en-US");
    await _flutterTts?.setSpeechRate(0.8);
    await _flutterTts?.setVolume(1.0);
    await _flutterTts?.setPitch(1.0);
  }

  Future<void> _checkPreAssessmentStatus() async {
    try {
      final isComplete = await _firebaseService.checkPreAssessmentComplete('lesson_3_2');
      if (mounted) {
        setState(() {
          _isPreAssessmentComplete = isComplete;
          if (isComplete) _hasStudied = true;
        });
      }
    } catch (e) {
      _logger.e("Error checking pre-assessment status: $e");
    }
  }

  Future<void> _fetchLessonContentAndInitialize() async {
    setState(() => _isLoadingLessonContent = true);

    // Simplified lesson data - focus on core content
    final Map<String, dynamic> hardcodedLesson3_2Data = {
      'moduleTitle': 'Module 3: Speaking Skills',
      'lessonTitle': 'Lesson 3.2: Speaking Practice – Dialogues',
      'objective': {
        'heading': 'Learning Objectives',
        'points': [
          'Improve pronunciation and intonation in customer service contexts',
          'Practice professional call center dialogues',
          'Build confidence in spoken English communication'
        ]
      },
      'introduction': {
        'heading': 'Professional Speaking Skills',
        'paragraph': 'Clear communication is essential in customer service. This lesson focuses on practicing real-world dialogues to improve your speaking skills.',
        'focusPoints': {
          'heading': 'Key Focus Areas',
          'points': [
            'Clear pronunciation of technical terms',
            'Professional tone and courtesy',
            'Proper pacing and rhythm',
            'Active listening responses'
          ]
        }
      },
      'preAssessmentData': {
        'title': 'Speaking Assessment',
        'instruction': 'Record yourself reading this sentence to establish your baseline.',
        'promptText': 'Welcome to customer service. How may I assist you today?'
      },
      'activity': {
        'title': 'Speaking Practice',
        'instructions': 'Record yourself speaking each prompt clearly and professionally.',
        'speakingPrompts': [
          {
            'id': 'prompt1',
            'text': 'Thank you for calling. My name is Alex. How may I help you?',
            'context': 'Greeting a new customer'
          },
          {
            'id': 'prompt2',
            'text': 'I understand your concern. Let me look into this for you.',
            'context': 'Responding to a customer complaint'
          },
          {
            'id': 'prompt3',
            'text': 'Could you please verify your account number for security?',
            'context': 'Requesting customer verification'
          },
          {
            'id': 'prompt4',
            'text': 'Your issue has been resolved. Is there anything else I can help with?',
            'context': 'Concluding the service interaction'
          },
        ],
      },
    };

    _lessonData = hardcodedLesson3_2Data;
    _speakingPrompts = _lessonData!['activity']?['speakingPrompts'] as List<dynamic>? ?? [];
    _initializePromptAttemptData();

    _logger.i("L3.2: Enhanced lesson content loaded. Prompts: ${_speakingPrompts.length}");
    if (mounted) setState(() => _isLoadingLessonContent = false);
  }

  void _initializePromptAttemptData() {
    _promptAttemptDataMap.clear();
    for (var prompt in _speakingPrompts) {
      if (prompt is Map && prompt['id'] is String) {
        _promptAttemptDataMap[prompt['id']] = PromptAttemptData();
      }
    }
  }

  void _startTimer() {
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
    _timer?.cancel();
  }

  String _formatDuration(int totalSeconds) {
    final duration = Duration(seconds: totalSeconds);
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // Pre-assessment methods
  Future<void> _startPreAssessmentRecording() async {
    if (!await _audioRecorder.hasPermission()) {
      await Permission.microphone.request();
      if (!await _audioRecorder.hasPermission()) {
        ScaffoldMessenger.of(widget.parentContext).showSnackBar(
          const SnackBar(content: Text('Microphone permission is required')),
        );
        return;
      }
    }

    try {
      final Directory tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/pre_assessment_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );

      setState(() {
        _isRecordingPreAssessment = true;
        _preAssessmentAudioPath = path;
      });
    } catch (e) {
      _logger.e("Error starting pre-assessment recording: $e");
    }
  }

  Future<void> _stopPreAssessmentRecording() async {
    try {
      await _audioRecorder.stop();
      setState(() => _isRecordingPreAssessment = false);
    } catch (e) {
      _logger.e("Error stopping pre-assessment recording: $e");
    }
  }

  Future<void> _submitPreAssessment() async {
    if (_preAssessmentAudioPath == null) return;

    setState(() => _isProcessingPreAssessment = true);

    try {
      // Simulate processing - in real implementation, this would process the audio
      await Future.delayed(const Duration(seconds: 3));
      
      final mockResult = {
        'score': 85.0,
        'success': true,
      };

      setState(() {
        _preAssessmentResult = mockResult;
        _isProcessingPreAssessment = false;
      });

      // Mark as complete after a delay
      Future.delayed(const Duration(seconds: 2), () async {
        await _firebaseService.markPreAssessmentAsComplete('lesson_3_2');
        setState(() {
          _isPreAssessmentComplete = true;
          _hasStudied = true;
        });
      });
    } catch (e) {
      _logger.e("Error processing pre-assessment: $e");
      setState(() => _isProcessingPreAssessment = false);
    }
  }

  // Audio recording methods
  Future<void> _startRecording() async {
    if (!await _audioRecorder.hasPermission()) {
      await Permission.microphone.request();
      if (!await _audioRecorder.hasPermission()) {
        ScaffoldMessenger.of(widget.parentContext).showSnackBar(
          const SnackBar(content: Text('Microphone permission is required')),
        );
        return;
      }
    }

    try {
      final Directory tempDir = await getTemporaryDirectory();
      String currentPromptId = _speakingPrompts[_currentPromptIndex]['id'];
      final path = '${tempDir.path}/audio_prompt_${currentPromptId}_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );

      if (mounted) {
        setState(() {
          _isRecording = true;
          _promptAttemptDataMap[currentPromptId]?.localAudioPath = path;
          _promptAttemptDataMap[currentPromptId]?.isProcessed = false;
        });
      }
    } catch (e) {
      _logger.e("Error starting recording: $e");
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _audioRecorder.stop();
      setState(() => _isRecording = false);
    } catch (e) {
      _logger.e("Error stopping recording: $e");
    }
  }

  Future<void> _playCurrentRecording() async {
    String currentPromptId = _speakingPrompts[_currentPromptIndex]['id'];
    final path = _promptAttemptDataMap[currentPromptId]?.localAudioPath;
    if (path != null) {
      try {
        await _audioPlayer.play(DeviceFileSource(path));
      } catch (e) {
        _logger.e("Error playing recording: $e");
      }
    }
  }

  Future<void> _playModelAudio() async {
    if (_flutterTts == null) return;
    
    setState(() => _isLoadingModelAudio = true);
    
    try {
      final currentPrompt = _speakingPrompts[_currentPromptIndex];
      final text = currentPrompt['text'];
      await _flutterTts!.speak(text);
    } catch (e) {
      _logger.e("Error playing model audio: $e");
    } finally {
      setState(() => _isLoadingModelAudio = false);
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

    setState(() => _isProcessingCurrentPrompt = true);

    try {
      final azureFeedbackResult = await widget.onProcessAudioPrompt(
        currentData.localAudioPath!,
        _speakingPrompts[_currentPromptIndex]['text'],
        currentPromptId,
      );

      if (!mounted) return;

      setState(() {
        if (azureFeedbackResult != null && azureFeedbackResult['success'] == true) {
          currentData.azureAiFeedback = azureFeedbackResult;
          currentData.transcription = azureFeedbackResult['textRecognized'] as String?;
          currentData.audioStorageUrl = azureFeedbackResult['audioStorageUrlFromModule'] as String?;
          
          _fetchOpenAIExplanation(
            azureFeedbackResult,
            _speakingPrompts[_currentPromptIndex]['text'],
            currentPromptId,
          );
        } else {
          currentData.azureAiFeedback = {
            'error': azureFeedbackResult?['error'] ?? 'Failed to get feedback',
            'success': false,
          };
          currentData.isProcessed = true;
          _isProcessingCurrentPrompt = false;
        }
      });
    } catch (e) {
      _logger.e("Exception during audio processing: $e");
      if (mounted) {
        setState(() {
          currentData.azureAiFeedback = {
            'error': 'Processing error: ${e.toString()}',
            'success': false,
          };
          currentData.isProcessed = true;
          _isProcessingCurrentPrompt = false;
        });
      }
    }
  }

  Future<void> _fetchOpenAIExplanation(
    Map<String, dynamic> azureResult,
    String originalText,
    String promptId,
  ) async {
    if (!mounted) return;

    final openAIExplanation = await widget.onExplainAzureFeedback(
      azureResult,
      originalText,
    );

    if (!mounted) return;

    setState(() {
      _promptAttemptDataMap[promptId]?.openAiDetailedFeedback =
          openAIExplanation ?? "Coach's explanation not available.";
      _promptAttemptDataMap[promptId]?.isProcessed = true;
      _isProcessingCurrentPrompt = false;
    });
  }

  void _handleNextPrompt() {
    if (_isProcessingCurrentPrompt) {
      ScaffoldMessenger.of(widget.parentContext).showSnackBar(
        const SnackBar(content: Text('Please wait for current processing to finish.')),
      );
      return;
    }
    
    setState(() => _activeTab = 'coach');
    
    if (_currentPromptIndex < _speakingPrompts.length - 1) {
      setState(() => _currentPromptIndex++);
    } else {
      _calculateOverallScore();
      setState(() => _showOverallResultsView = true);
      _stopTimer();
    }
  }

  void _calculateOverallScore() {
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
    if (!mounted) return;
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
        'audioUrl': data.audioStorageUrl,
        'transcription': data.transcription,
        'azureAiFeedback': data.azureAiFeedback,
        'openAiDetailedFeedback': data.openAiDetailedFeedback,
        'score': data.azureAiFeedback?['accuracyScore'],
      });
    });
    
    Map<String, String> reflections = {
      'confidence': _confidenceController.text,
      'hardestSentence': _hardestSentenceController.text,
      'improvement': _improvementController.text,
    };
    
    _calculateOverallScore();
    
    try {
      await widget.onSubmitLesson(
        submittedPromptData,
        reflections,
        _overallLessonScoreForDisplay ?? 0.0,
        _secondsElapsed,
        widget.initialAttemptNumber + 1,
      );
      
      ScaffoldMessenger.of(widget.parentContext).showSnackBar(
        const SnackBar(content: Text('Lesson submitted successfully!'))
      );
    } catch (e) {
      _logger.e("Error submitting lesson: $e");
      ScaffoldMessenger.of(widget.parentContext).showSnackBar(
        SnackBar(content: Text('Error submitting lesson: $e'))
      );
    } finally {
      if (mounted) setState(() => _isSubmittingLesson = false);
    }
  }

  // Helper method to determine score styling
  Map<String, dynamic> _getScoreStyling(double? score) {
    if (score == null) return {'color': Colors.grey.shade400, 'textColor': Colors.grey.shade700};
    if (score >= 90) return {'color': Colors.green.shade500, 'textColor': Colors.green.shade700};
    if (score >= 75) return {'color': Colors.lime.shade500, 'textColor': Colors.lime.shade700};
    if (score >= 60) return {'color': Colors.amber.shade400, 'textColor': Colors.amber.shade700};
    if (score >= 40) return {'color': Colors.orange.shade500, 'textColor': Colors.orange.shade700};
    return {'color': Colors.red.shade500, 'textColor': Colors.red.shade700};
  }

  @override
  void dispose() {
    _confidenceController.dispose();
    _hardestSentenceController.dispose();
    _improvementController.dispose();
    _stopTimer();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _flutterTts?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingLessonContent || _lessonData == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Pre-assessment section
    if (!_isPreAssessmentComplete && !_hasStudied) {
      return _buildPreAssessmentSection();
    }

    // Study material section
    if (!widget.showActivitySectionInitially) {
      return _buildStudyMaterialSection();
    }

    // Activity section
    if (!_showOverallResultsView) {
      return _buildActivitySection();
    }

    // Results section
    return _buildResultsSection();
  }

  Widget _buildPreAssessmentSection() {
    final preAssessmentData = _lessonData!['preAssessmentData'];
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            preAssessmentData['title'],
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF3949AB)),
          ),
          const SizedBox(height: 16),
          Text(
            preAssessmentData['instruction'],
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),
          
          // English-only notice
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.yellow.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.yellow.shade400),
            ),
            child: Row(
              children: [
                const FaIcon(FontAwesomeIcons.globe, color: Colors.orange),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Please Speak in English Only',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'This is an English proficiency assessment. Responses in other languages will be scored incorrectly.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Prompt text
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '"${preAssessmentData['promptText']}"',
              style: const TextStyle(fontSize: 18, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          
          // Recording controls
          Center(
            child: Column(
              children: [
                ElevatedButton.icon(
                  onPressed: _isProcessingPreAssessment || _preAssessmentResult != null
                      ? null
                      : (_isRecordingPreAssessment ? _stopPreAssessmentRecording : _startPreAssessmentRecording),
                  icon: FaIcon(_isRecordingPreAssessment ? FontAwesomeIcons.stop : FontAwesomeIcons.microphone),
                  label: Text(_isRecordingPreAssessment ? 'Stop Recording' : 'Start Recording'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isRecordingPreAssessment ? Colors.red : Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),
                
                if (_preAssessmentAudioPath != null && !_isRecordingPreAssessment && _preAssessmentResult == null)
                  ElevatedButton.icon(
                    onPressed: _isProcessingPreAssessment ? null : _submitPreAssessment,
                    icon: _isProcessingPreAssessment 
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const FaIcon(FontAwesomeIcons.paperPlane),
                    label: Text(_isProcessingPreAssessment ? 'Analyzing...' : 'Submit for Analysis'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
              ],
            ),
          ),
          
          // Results display
          if (_preAssessmentResult != null)
            Container(
              margin: const EdgeInsets.only(top: 24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text(
                    'Your baseline accuracy score is:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${(_preAssessmentResult!['score'] as double).toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Color(0xFF3949AB)),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'This lesson will help you improve. Preparing the lesson now...',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStudyMaterialSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _lessonData!['lessonTitle'],
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF3949AB)),
          ),
          const SizedBox(height: 24),
          
          // Learning objectives
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 5,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _lessonData!['objective']['heading'],
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF3949AB)),
                ),
                const SizedBox(height: 12),
                ...(_lessonData!['objective']['points'] as List).map((point) => 
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Expanded(child: Text(point, style: const TextStyle(fontSize: 16))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Introduction
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 5,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _lessonData!['introduction']['heading'],
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF3949AB)),
                ),
                const SizedBox(height: 12),
                Text(
                  _lessonData!['introduction']['paragraph'],
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                Text(
                  _lessonData!['introduction']['focusPoints']['heading'],
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF3949AB)),
                ),
                const SizedBox(height: 8),
                ...(_lessonData!['introduction']['focusPoints']['points'] as List).map((point) => 
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Expanded(child: Text(point, style: const TextStyle(fontSize: 16))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          
          // Proceed button
          Center(
            child: ElevatedButton.icon(
              onPressed: widget.onShowActivitySection,
              icon: const FaIcon(FontAwesomeIcons.microphone),
              label: const Text('Start Speaking Activity'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitySection() {
    if (_speakingPrompts.isEmpty || _currentPromptIndex >= _speakingPrompts.length) {
      return const Center(child: Text('No prompts available'));
    }

    final currentPrompt = _speakingPrompts[_currentPromptIndex];
    final currentPromptId = currentPrompt['id'];
    final currentPromptData = _promptAttemptDataMap[currentPromptId];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with timer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Speaking Prompt ${_currentPromptIndex + 1} / ${_speakingPrompts.length}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF3949AB)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const FaIcon(FontAwesomeIcons.clock, size: 16, color: Color(0xFF3949AB)),
                    const SizedBox(width: 8),
                    Text(
                      _formatDuration(_secondsElapsed),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Context
          if (currentPrompt['context'] != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Context:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(currentPrompt['context'], style: const TextStyle(fontSize: 16)),
                ],
              ),
            ),
          
          // Prompt text
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE8EAF6),
              borderRadius: BorderRadius.circular(8),
              border: const Border(left: BorderSide(color: Color(0xFF3949AB), width: 4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Your turn. Please say:',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF283593)),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isLoadingModelAudio ? null : _playModelAudio,
                      icon: _isLoadingModelAudio 
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const FaIcon(FontAwesomeIcons.volumeUp, size: 16),
                      label: const Text('Listen to Model'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE8EAF6),
                        foregroundColor: const Color(0xFF3949AB),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '"${currentPrompt['text']}"',
                  style: const TextStyle(fontSize: 18, fontStyle: FontStyle.italic, color: Color(0xFF3949AB)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Recording controls
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _isProcessingCurrentPrompt
                      ? null
                      : (_isRecording ? _stopRecording : _startRecording),
                  icon: FaIcon(_isRecording ? FontAwesomeIcons.stop : FontAwesomeIcons.microphone),
                  label: Text(_isRecording ? 'Stop' : 'Record'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isRecording ? Colors.red : Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
                const SizedBox(width: 16),
                
                if (currentPromptData?.localAudioPath != null && !_isRecording)
                  ElevatedButton.icon(
                    onPressed: _isProcessingCurrentPrompt ? null : _playCurrentRecording,
                    icon: const FaIcon(FontAwesomeIcons.play),
                    label: const Text('Play'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                      foregroundColor: Colors.black87,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Submit button
          if (currentPromptData?.localAudioPath != null && !currentPromptData!.isProcessed && !_isRecording)
            Center(
              child: ElevatedButton.icon(
                onPressed: _isProcessingCurrentPrompt ? null : _processCurrentAudioPrompt,
                icon: const FaIcon(FontAwesomeIcons.upload),
                label: const Text('Submit for Feedback'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            ),
          
          // Processing indicator
          if (_isProcessingCurrentPrompt)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Processing your audio...', style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ),
          
          // Feedback section
          if (currentPromptData?.isProcessed == true)
            _buildFeedbackSection(currentPromptData!),
          
          // Next button
          if (currentPromptData?.isProcessed == true)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: ElevatedButton.icon(
                  onPressed: _isProcessingCurrentPrompt ? null : _handleNextPrompt,
                  icon: const FaIcon(FontAwesomeIcons.arrowRight),
                  label: Text(
                    _currentPromptIndex < _speakingPrompts.length - 1
                        ? 'Next Prompt'
                        : 'View Results'
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF673AB7),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFeedbackSection(PromptAttemptData promptData) {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border(top: BorderSide(color: Colors.indigo.shade400, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FaIcon(FontAwesomeIcons.chalkboardTeacher, color: Colors.indigo.shade500, size: 28),
              const SizedBox(width: 12),
              const Text(
                'AI Feedback',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF3949AB)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Tab navigation
          Row(
            children: [
              _buildFeedbackTab('Coach', 'coach', FontAwesomeIcons.comment),
              _buildFeedbackTab('Metrics', 'metrics', FontAwesomeIcons.chartBar),
              _buildFeedbackTab('Words', 'words', FontAwesomeIcons.list),
            ],
          ),
          const SizedBox(height: 16),
          
          // Tab content
          if (_activeTab == 'coach')
            _buildCoachTab(promptData),
          if (_activeTab == 'metrics' && promptData.azureAiFeedback != null)
            _buildMetricsTab(promptData),
          if (_activeTab == 'words' && promptData.azureAiFeedback != null)
            _buildWordsTab(promptData),
        ],
      ),
    );
  }

  Widget _buildFeedbackTab(String label, String tabId, IconData icon) {
    final isActive = _activeTab == tabId;
    
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _activeTab = tabId),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? const Color(0xFF3949AB) : Colors.grey.shade300, 
                width: isActive ? 3 : 1,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FaIcon(
                icon, 
                color: isActive ? const Color(0xFF3949AB) : Colors.grey.shade600,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive ? const Color(0xFF3949AB) : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoachTab(PromptAttemptData promptData) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE1F5FE),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: promptData.openAiDetailedFeedback != null 
          ? Html(data: promptData.openAiDetailedFeedback!)
          : const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            ),
    );
  }

  Widget _buildMetricsTab(PromptAttemptData promptData) {
    final azureFeedback = promptData.azureAiFeedback!;
    
    return Column(
      children: [
        // Transcription
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFE8EAF6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'What Azure Heard:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF3949AB)),
              ),
              const SizedBox(height: 4),
              Text(
                '"${azureFeedback['textRecognized'] ?? "Speech not clearly recognized."}"',
                style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        
        // Metrics grid
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 1.5,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _buildMetricCard('Accuracy', azureFeedback['accuracyScore'], FontAwesomeIcons.percent, '%'),
            _buildMetricCard('Fluency', azureFeedback['fluencyScore'], FontAwesomeIcons.tachometerAlt, ''),
            _buildMetricCard('Completeness', azureFeedback['completenessScore'], FontAwesomeIcons.checkSquare, '%'),
            _buildMetricCard('Prosody', azureFeedback['prosodyScore'], FontAwesomeIcons.theaterMasks, ''),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(String label, dynamic score, IconData icon, String suffix) {
    if (score == null) return const SizedBox.shrink();
    
    final styling = _getScoreStyling(score.toDouble());
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  FaIcon(icon, size: 16, color: Colors.grey.shade700),
                  const SizedBox(width: 6),
                  Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              Text(
                '${score.toStringAsFixed(1)}$suffix',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: styling['textColor'],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: score / 100,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(styling['color']),
            minHeight: 8,
          ),
        ],
      ),
    );
  }

  Widget _buildWordsTab(PromptAttemptData promptData) {
    final words = promptData.azureAiFeedback?['words'] as List<dynamic>? ?? [];
    
    if (words.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No word-by-word analysis available.', style: TextStyle(fontStyle: FontStyle.italic)),
        ),
      );
    }
    
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: words.length,
      itemBuilder: (context, index) {
        final word = words[index] as Map<String, dynamic>;
        final wordText = word['word'] as String? ?? '';
        final score = word['accuracyScore'] as double? ?? 0;
        final errorType = word['errorType'] as String? ?? 'None';
        final styling = _getScoreStyling(score);
        
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    wordText,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: score < 80 ? FontWeight.bold : FontWeight.normal,
                      color: styling['textColor'],
                    ),
                  ),
                  if (errorType != 'None')
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        errorType,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              Text(
                '${score.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: styling['textColor'],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildResultsSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lesson Attempt Complete!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF388E3C)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          
          // Overall score
          if (_overallLessonScoreForDisplay != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  const Text(
                    'Your Overall Average Score:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_overallLessonScoreForDisplay!.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: _getScoreStyling(_overallLessonScoreForDisplay)['textColor'],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          
          // Reflections form
          const Text(
            'Your Reflections',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF3949AB)),
          ),
          const SizedBox(height: 12),
          
          TextField(
            controller: _confidenceController,
            decoration: const InputDecoration(
              labelText: 'How confident do you feel about your speaking?',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          
          TextField(
            controller: _hardestSentenceController,
            decoration: const InputDecoration(
              labelText: 'Which prompt was most challenging for you?',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          
          TextField(
            controller: _improvementController,
            decoration: const InputDecoration(
              labelText: 'What would you like to improve on?',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 24),
          
          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _currentPromptIndex = 0;
                    _showOverallResultsView = false;
                    _promptAttemptDataMap.clear();
                    _initializePromptAttemptData();
                    _startTimer();
                  });
                },
                icon: const FaIcon(FontAwesomeIcons.redo),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade600,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              const SizedBox(width: 16),
              
              ElevatedButton.icon(
                onPressed: _isSubmittingLesson ? null : _handleSubmitLesson,
                icon: _isSubmittingLesson
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const FaIcon(FontAwesomeIcons.paperPlane),
                label: Text(_isSubmittingLesson ? 'Submitting...' : 'Submit Lesson'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}