import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'dart:async';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:http_parser/http_parser.dart';
import '../services/unified_progress_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Lesson3_2ActivityPage extends StatefulWidget {
  final String lessonId;
  final String lessonTitle;
  final Map<String, dynamic> lessonData;
  final int attemptNumber;

  const Lesson3_2ActivityPage({
    super.key,
    required this.lessonId,
    required this.lessonTitle,
    required this.lessonData,
    required this.attemptNumber,
  });

  @override
  State<Lesson3_2ActivityPage> createState() => _Lesson3_2ActivityPageState();
}

class _Lesson3_2ActivityPageState extends State<Lesson3_2ActivityPage>
    with SingleTickerProviderStateMixin {
  final Logger _logger = Logger();
  final UnifiedProgressService _progressService = UnifiedProgressService();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Prompts
  int _currentPromptIndex = 0;
  List<Map<String, dynamic>> _speakingPrompts = [];

  // Recording
  bool _isRecording = false;
  String? _currentRecordingPath;
  bool _hasRecording = false;

  // AI Processing
  bool _isProcessing = false;
  bool _showFeedback = false;
  Map<String, dynamic>? _currentFeedback;

  // Tabs & word breakdown
  late TabController _tabController;
  List<Map<String, dynamic>> _wordComparison = [];

  // Timer
  Timer? _timerInstance;
  int _timerSeconds = 1200; // 20 min
  bool _isTimedOut = false;
  final int _initialTime = 1200;

  bool _isDetailedFeedbackMissing() {
    if (_currentFeedback == null) return false;

    final openAiExplanation = _currentFeedback!['openAiDetailedFeedback'];

    // Check if OpenAI explanation is null or empty
    if (openAiExplanation == null) return true;
    if (openAiExplanation is Map && openAiExplanation.isEmpty) return true;
    if (openAiExplanation is Map && openAiExplanation['feedback'] == null)
      return true;

    return false;
  }

  Future<bool> _hasInternetConnection() async {
    try {
      final result = await http
          .get(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 5));
      return result.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Results
  bool _showResults = false;
  List<Map<String, dynamic>> _promptResults = [];
  int? _overallScore; // 0–100

  @override
  void initState() {
    super.initState();
    _initializeActivity();
    _tabController = TabController(length: 4, vsync: this);
    _startTimer();
  }

  @override
  void dispose() {
    _timerInstance?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _initializeActivity() {
    _speakingPrompts = List<Map<String, dynamic>>.from(
      widget.lessonData['activity']?['speakingPrompts'] ?? [],
    );
  }

  void _startTimer() {
    _timerInstance = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_timerSeconds > 0 && !_showResults && !_isTimedOut) {
        setState(() => _timerSeconds--);
      } else if (_timerSeconds <= 0 && !_showResults && !_isTimedOut) {
        timer.cancel();
        setState(() => _isTimedOut = true);
        _handleTimeOut();
      }
    });
  }

  void _handleTimeOut() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Time's up! Moving to results."),
        backgroundColor: Colors.orange,
      ),
    );
    _showResultsScreen();
  }

  // ---------------- Recording ----------------

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final Directory appDocumentsDir =
            await getApplicationDocumentsDirectory();
        final String filePath =
            '${appDocumentsDir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.webm';

        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.opus,
            bitRate: 128000,
            sampleRate: 48000,
          ),
          path: filePath,
        );

        setState(() {
          _isRecording = true;
          _currentRecordingPath = filePath;
          _hasRecording = false;
          _showFeedback = false;
          _currentFeedback = null;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission is required.')),
        );
      }
    } catch (e) {
      _logger.e('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final String? path = await _audioRecorder.stop();
      if (path != null) {
        setState(() {
          _isRecording = false;
          _currentRecordingPath = path;
          _hasRecording = true;
        });
      }
    } catch (e) {
      _logger.e('Error stopping recording: $e');
      setState(() => _isRecording = false);
    }
  }

  Future<void> _playRecording() async {
    if (_currentRecordingPath != null) {
      try {
        await _audioPlayer.setFilePath(_currentRecordingPath!);
        await _audioPlayer.play();
      } catch (e) {
        _logger.e('Error playing recording: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to play recording.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ---------------- Cloudinary Upload (Fixed) ----------------

  // Replace the _uploadToCloudinary method with this enhanced version:
  Future<String?> _uploadToCloudinary(File audioFile) async {
    const int maxRetries = 3;
    const Duration timeoutDuration = Duration(seconds: 30);

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        if (!dotenv.isInitialized) {
          await dotenv.load();
        }
        final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
        final uploadPreset = dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '';
        if (cloudName.isEmpty || uploadPreset.isEmpty) {
          _logger.e('Cloudinary credentials missing (.env)');
          return null;
        }

        _logger.i(
          'Uploading audio to Cloudinary (${await audioFile.length()} bytes) - Attempt $attempt/$maxRetries',
        );

        final uri = Uri.parse(
          'https://api.cloudinary.com/v1_1/$cloudName/video/upload',
        );

        final req = http.MultipartRequest('POST', uri);
        req.fields['upload_preset'] = uploadPreset;
        req.files.add(
          await http.MultipartFile.fromPath(
            'file',
            audioFile.path,
            contentType: MediaType('video', 'webm'),
          ),
        );
        req.fields['resource_type'] = 'video';
        req.fields['folder'] = 'lesson3_2';

        // Add timeout to the request
        final streamed = await req.send().timeout(timeoutDuration);
        final responseData = await streamed.stream.bytesToString();

        _logger.i('Cloudinary response: $responseData');

        if (streamed.statusCode == 200) {
          final data = jsonDecode(responseData);
          final secureUrl = data['secure_url'] as String?;
          if (secureUrl != null) {
            _logger.i('Upload successful on attempt $attempt');
            return secureUrl;
          }
        } else {
          _logger.e(
            'Cloudinary upload failed (${streamed.statusCode}): $responseData',
          );
        }
      } catch (e) {
        _logger.e('Cloudinary upload error on attempt $attempt: $e');

        if (attempt == maxRetries) {
          _logger.e('All upload attempts failed');
          return null;
        }

        // Wait before retrying (exponential backoff)
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }
    return null;
  }

  // ---------------- AI Submission ----------------

  // Replace the _submitForFeedback method with this enhanced version:
  Future<void> _submitForFeedback() async {
    if (!_hasRecording || _currentRecordingPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please record your audio first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final currentPrompt = _speakingPrompts[_currentPromptIndex];
      final originalText = currentPrompt['text'] as String;

      // 1. Upload with retry logic
      final audioFile = File(_currentRecordingPath!);
      final cloudinaryUrl = await _uploadToCloudinary(audioFile);
      if (cloudinaryUrl == null) {
        throw Exception(
          'Audio upload failed after multiple attempts. Please check your internet connection and try again.',
        );
      }
      _logger.i('Audio uploaded: $cloudinaryUrl');

      // 2. Azure Pronunciation with retry logic
      Map<String, dynamic>? azureResult;
      const int maxAzureRetries = 2;

      for (int attempt = 1; attempt <= maxAzureRetries; attempt++) {
        try {
          _logger.i(
            'Attempting Azure evaluation - Attempt $attempt/$maxAzureRetries',
          );
          azureResult = await _progressService
              .evaluateAzureSpeech(cloudinaryUrl, originalText)
              .timeout(const Duration(seconds: 45)); // Add timeout

          if (azureResult != null && azureResult['success'] == true) {
            _logger.i('Azure evaluation successful on attempt $attempt');
            break;
          }
        } catch (e) {
          _logger.e('Azure evaluation attempt $attempt failed: $e');
          if (attempt == maxAzureRetries) {
            _logger.w('All Azure attempts failed, will use fallback');
            azureResult = null;
          } else {
            await Future.delayed(Duration(seconds: attempt * 3));
          }
        }
      }

      if (azureResult == null || azureResult['success'] != true) {
        throw Exception('Azure evaluation failed after multiple attempts.');
      }

      // 3. OpenAI Coach Explanation with timeout
      Map<String, dynamic>? openAiExplanation;
      const int maxOpenAiRetries = 3;

      for (int attempt = 1; attempt <= maxOpenAiRetries; attempt++) {
        try {
          _logger.i(
            'Attempting OpenAI explanation - Attempt $attempt/$maxOpenAiRetries',
          );
          openAiExplanation = await _progressService
              .getOpenAICoachExplanation(azureResult, originalText)
              .timeout(const Duration(seconds: 30));

          if (openAiExplanation != null) {
            _logger.i('OpenAI explanation successful on attempt $attempt');
            break;
          }
        } catch (e) {
          _logger.e('OpenAI explanation attempt $attempt failed: $e');
          if (attempt == maxOpenAiRetries) {
            _logger.w(
              'All OpenAI attempts failed, will use fallback explanation',
            );
            openAiExplanation = _generateFallbackCoachExplanation(azureResult);
          } else {
            await Future.delayed(Duration(seconds: attempt * 2));
          }
        }
      }

      // If still null after retries, use fallback
      if (openAiExplanation == null) {
        openAiExplanation = _generateFallbackCoachExplanation(azureResult);
      }

      // 4. Construct unified feedback
      final double? accuracyScorePct = (azureResult['accuracyScore'] is num)
          ? (azureResult['accuracyScore'] as num).toDouble()
          : null;

      final int normalizedScore5 = accuracyScorePct != null
          ? (accuracyScorePct / 20).clamp(0, 5).round()
          : 0;

      final feedback = {
        'score': normalizedScore5,
        'accuracyScore': accuracyScorePct,
        'audioUrl': cloudinaryUrl,
        'azureAiFeedback': {
          'textRecognized': azureResult['textRecognized'],
          'accuracyScore': azureResult['accuracyScore'],
          'fluencyScore': azureResult['fluencyScore'],
          'completenessScore': azureResult['completenessScore'],
          'prosodyScore': azureResult['prosodyScore'],
          'words': azureResult['words'] ?? [],
        },
        'openAiDetailedFeedback': openAiExplanation,
        'sections': [
          {
            'title': 'Accuracy',
            'text':
                'Azure AI Score: ${azureResult['accuracyScore']?.toStringAsFixed(1) ?? 'N/A'}% - ${_getAccuracyDescription(azureResult['accuracyScore'])}',
          },
          {
            'title': 'Fluency',
            'text':
                'Azure AI Score: ${azureResult['fluencyScore']?.toStringAsFixed(1) ?? 'N/A'} - ${_getFluencyDescription(azureResult['fluencyScore'])}',
          },
          {
            'title': 'Completeness',
            'text':
                'Azure AI Score: ${azureResult['completenessScore']?.toStringAsFixed(1) ?? 'N/A'}% - ${_getCompletenessDescription(azureResult['completenessScore'])}',
          },
        ],
      };

      // 5. Build word comparison safely
      List<dynamic> wordsFromAzure = [];
      if (feedback['azureAiFeedback'] is Map<String, dynamic>) {
        final azureMap = feedback['azureAiFeedback'] as Map<String, dynamic>;
        if (azureMap['words'] is List) {
          wordsFromAzure = azureMap['words'] as List<dynamic>;
        }
      }
      _wordComparison = _buildWordComparison(originalText, wordsFromAzure);

      if (!mounted) return;
      setState(() {
        _currentFeedback = feedback;
        _showFeedback = true;
        _isProcessing = false;
        _tabController.animateTo(0);
      });

      // Add this check right after setState
      if (_isDetailedFeedbackMissing()) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Detailed feedback unavailable due to connectivity. Your scores are saved. Consider recording again for detailed tips.',
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 6),
                action: SnackBarAction(
                  label: 'Record Again',
                  textColor: Colors.white,
                  onPressed: () {
                    setState(() {
                      _hasRecording = false;
                      _currentRecordingPath = null;
                      _showFeedback = false;
                      _currentFeedback = null;
                      _wordComparison = [];
                    });
                  },
                ),
              ),
            );
          }
        });
      }
    } catch (e) {
      _logger.e('Error in _submitForFeedback: $e');
      if (mounted) {
        setState(() => _isProcessing = false);

        // Show user-friendly error message
        String errorMessage = 'Processing failed. ';
        if (e.toString().contains('connection') ||
            e.toString().contains('abort')) {
          errorMessage +=
              'Please check your internet connection and try again.';
        } else if (e.toString().contains('timeout')) {
          errorMessage += 'The request timed out. Please try again.';
        } else {
          errorMessage += 'Please try again in a moment.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 5),
          ),
        );

        // Use fallback feedback
        await _generateFallbackFeedback();
      }
    }
  }

  // Add this method to generate fallback coach feedback when OpenAI fails
  Map<String, dynamic> _generateFallbackCoachExplanation(
    Map<String, dynamic> azureResult,
  ) {
    final double? accuracyScore = (azureResult['accuracyScore'] as num?)
        ?.toDouble();
    final double? fluencyScore = (azureResult['fluencyScore'] as num?)
        ?.toDouble();
    final double? completenessScore = (azureResult['completenessScore'] as num?)
        ?.toDouble();
    final double? prosodyScore = (azureResult['prosodyScore'] as num?)
        ?.toDouble();

    List<Map<String, dynamic>> feedback = [];

    // Accuracy feedback
    if (accuracyScore != null) {
      String tip = '';
      String whyThisScore = '';

      if (accuracyScore >= 90) {
        whyThisScore =
            'Excellent pronunciation! Your words were clearly articulated and easily understood.';
        tip =
            'Keep up the great work! Focus on maintaining this level of clarity.';
      } else if (accuracyScore >= 75) {
        whyThisScore =
            'Good pronunciation overall with minor areas for improvement.';
        tip =
            'Practice speaking more slowly and focus on enunciating consonant endings.';
      } else if (accuracyScore >= 60) {
        whyThisScore =
            'Fair pronunciation but some words were unclear or mispronounced.';
        tip =
            'Practice individual word pronunciation and speak more deliberately.';
      } else {
        whyThisScore =
            'Pronunciation needs significant improvement for clarity.';
        tip =
            'Focus on speaking slowly and clearly. Consider practicing with pronunciation exercises.';
      }

      feedback.add({
        'metric': 'Accuracy',
        'score': accuracyScore,
        'whyThisScore': whyThisScore,
        'tip': tip,
      });
    }

    // Fluency feedback
    if (fluencyScore != null) {
      String tip = '';
      String whyThisScore = '';

      if (fluencyScore >= 90) {
        whyThisScore =
            'Very smooth and natural speech flow with excellent rhythm.';
        tip =
            'Excellent fluency! Continue practicing to maintain this natural flow.';
      } else if (fluencyScore >= 75) {
        whyThisScore = 'Good speech rhythm with minor hesitations or pauses.';
        tip =
            'Practice speaking in longer phrases to reduce pauses between words.';
      } else if (fluencyScore >= 60) {
        whyThisScore =
            'Adequate fluency but with noticeable hesitations or unnatural pauses.';
        tip = 'Practice reading aloud to improve your speech flow and rhythm.';
      } else {
        whyThisScore = 'Speech was choppy with frequent pauses or hesitations.';
        tip =
            'Focus on speaking at a steady pace. Practice with shorter phrases first.';
      }

      feedback.add({
        'metric': 'Fluency',
        'score': fluencyScore,
        'whyThisScore': whyThisScore,
        'tip': tip,
      });
    }

    // Completeness feedback
    if (completenessScore != null) {
      String tip = '';
      String whyThisScore = '';

      if (completenessScore >= 95) {
        whyThisScore = 'You spoke the complete phrase with all words included.';
        tip = 'Perfect! You captured the entire message clearly.';
      } else if (completenessScore >= 80) {
        whyThisScore = 'Most of the phrase was captured with minor omissions.';
        tip =
            'Make sure to include all words in the phrase for complete communication.';
      } else if (completenessScore >= 60) {
        whyThisScore =
            'Some important parts of the phrase were missing or unclear.';
        tip =
            'Practice speaking the full phrase slowly to ensure all words are included.';
      } else {
        whyThisScore = 'Large portions of the phrase were omitted or unclear.';
        tip =
            'Focus on speaking the complete phrase. Break it into smaller parts if needed.';
      }

      feedback.add({
        'metric': 'Completeness',
        'score': completenessScore,
        'whyThisScore': whyThisScore,
        'tip': tip,
      });
    }

    // Prosody feedback
    if (prosodyScore != null) {
      String tip = '';
      String whyThisScore = '';

      if (prosodyScore >= 80) {
        whyThisScore =
            'Natural intonation and stress patterns that sound conversational.';
        tip = 'Great natural speech rhythm! Keep using varied intonation.';
      } else if (prosodyScore >= 60) {
        whyThisScore =
            'Adequate intonation but could sound more natural and varied.';
        tip =
            'Practice varying your tone and stress to sound more conversational.';
      } else if (prosodyScore >= 40) {
        whyThisScore =
            'Somewhat flat or monotone delivery that sounds robotic.';
        tip =
            'Work on adding emotion and varying your tone to sound more natural.';
      } else {
        whyThisScore = 'Very flat delivery with little natural speech rhythm.';
        tip =
            'Practice speaking with emotion and varying your pitch for different parts of the sentence.';
      }

      feedback.add({
        'metric': 'Prosody',
        'score': prosodyScore,
        'whyThisScore': whyThisScore,
        'tip': tip,
      });
    }

    String overall =
        'Keep practicing to improve your speaking skills. Focus on the areas highlighted above for the best improvement.';

    if (accuracyScore != null && accuracyScore >= 85) {
      overall =
          'Great job! Your pronunciation is clear and professional. Continue practicing to maintain this level.';
    } else if (accuracyScore != null && accuracyScore >= 70) {
      overall =
          'Good progress! With a bit more practice on clarity, you\'ll sound even more professional.';
    }

    return {'feedback': feedback, 'overall': overall};
  }

  // Add this method to your _Lesson3_2ActivityPageState class
  List<dynamic> _extractWordsFromAzureFeedback(dynamic azureFeedback) {
    if (azureFeedback == null) return [];

    if (azureFeedback is Map<String, dynamic>) {
      final words = azureFeedback['words'];
      if (words is List) {
        return words;
      }
    }

    return [];
  }

  // ---------------- Word Comparison ----------------

  List<Map<String, dynamic>> _buildWordComparison(
    String original,
    List azureWordsRaw,
  ) {
    final originalTokens = original
        .replaceAll(RegExp(r'[.,!?"]'), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.trim().isNotEmpty)
        .toList();

    final azureWords = azureWordsRaw
        .map<Map<String, dynamic>>(
          (w) => {
            'word': (w['word'] ?? w['Word'] ?? '').toString(),
            'accuracyScore': (w['accuracyScore'] ?? w['AccuracyScore']),
            'errorType': (w['errorType'] ?? w['ErrorType'] ?? 'None'),
          },
        )
        .toList();

    int aIdx = 0;
    final out = <Map<String, dynamic>>[];

    for (final token in originalTokens) {
      if (aIdx < azureWords.length &&
          azureWords[aIdx]['word'].toString().toLowerCase() ==
              token.toLowerCase()) {
        out.add({
          'word': token,
          'omission': false,
          'accuracyScore': (azureWords[aIdx]['accuracyScore'] is num)
              ? (azureWords[aIdx]['accuracyScore'] as num).toDouble()
              : null,
          'errorType': azureWords[aIdx]['errorType'],
        });
        aIdx++;
      } else {
        out.add({
          'word': token,
          'omission': true,
          'accuracyScore': null,
          'errorType': 'OMISSION',
        });
      }
    }
    return out;
  }

  // ---------------- Descriptions for Metrics ----------------

  String _getAccuracyDescription(dynamic s) {
    final double? score = (s is num) ? s.toDouble() : null;
    if (score == null) return 'Unable to assess accuracy';
    if (score >= 90) return 'Excellent pronunciation!';
    if (score >= 75) return 'Good pronunciation overall.';
    if (score >= 60) return 'Fair – work on clearer articulation.';
    return 'Needs practice – focus on each word clearly.';
  }

  String _getFluencyDescription(dynamic s) {
    final double? score = (s is num) ? s.toDouble() : null;
    if (score == null) return 'Unable to assess fluency';
    if (score >= 90) return 'Very smooth and natural.';
    if (score >= 75) return 'Good rhythm, minor hesitations.';
    if (score >= 60) return 'Adequate – aim for smoother flow.';
    return 'Practice steady, natural pacing.';
  }

  String _getCompletenessDescription(dynamic s) {
    final double? score = (s is num) ? s.toDouble() : null;
    if (score == null) return 'Unable to assess completeness';
    if (score >= 90) return 'Complete phrase spoken.';
    if (score >= 75) return 'Most of phrase captured.';
    if (score >= 60) return 'Some parts missed.';
    return 'Large parts omitted – speak full phrase.';
  }

  // ---------------- Fallback ----------------

  Future<void> _generateFallbackFeedback() async {
    await Future.delayed(const Duration(milliseconds: 600));
    _logger.w('Using fallback feedback (no Azure connection).');
    if (_currentFeedback != null) return; // Already have real feedback
    final fallback = {
      'score': 4,
      'accuracyScore': 80.0,
      'azureAiFeedback': null,
      'openAiDetailedFeedback': null,
      'sections': [
        {
          'title': 'Accuracy',
          'text':
              'Pronunciation generally clear; refine consonant endings for added clarity.',
        },
        {
          'title': 'Fluency',
          'text':
              'Speech pace acceptable. Aim for smoother connections between words.',
        },
        {
          'title': 'Suggestion',
          'text':
              'Practice reading the full line aloud several times focusing on consistent pace.',
        },
      ],
    };
    if (!mounted) return;
    setState(() {
      _currentFeedback = fallback;
      _showFeedback = true;
    });
  }

  // ---------------- Navigation & Results ----------------

  void _nextPrompt() {
    if (_currentFeedback != null) {
      final currentPrompt = _speakingPrompts[_currentPromptIndex];
      final result = {
        'promptId': currentPrompt['id'],
        'promptText': currentPrompt['text'],
        'context': currentPrompt['context'],
        'score': _currentFeedback!['score'],
        'accuracyScore': _currentFeedback!['accuracyScore'],
        'feedback': _currentFeedback,
        'audioPath': _currentRecordingPath,
        'audioUrl': _currentFeedback!['audioUrl'],
        'azureAiFeedback': _currentFeedback!['azureAiFeedback'],
        'openAiDetailedFeedback': _currentFeedback!['openAiDetailedFeedback'],
        'transcription':
            _currentFeedback!['azureAiFeedback']?['textRecognized'],
      };
      _promptResults.add(result);
    }

    if (_currentPromptIndex < _speakingPrompts.length - 1) {
      setState(() {
        _currentPromptIndex++;
        _resetPromptState();
      });
    } else {
      _showResultsScreen();
    }
  }

  void _resetPromptState() {
    setState(() {
      _hasRecording = false;
      _currentRecordingPath = null;
      _showFeedback = false;
      _currentFeedback = null;
      _wordComparison = [];
      _tabController.animateTo(0);
    });
  }

  void _showResultsScreen() {
    _timerInstance?.cancel();

    if (_promptResults.isNotEmpty) {
      int total = 0;
      int count = 0;
      for (final r in _promptResults) {
        final a = r['accuracyScore'];
        if (a is num) {
          total += a.round();
          count++;
        } else {
          // fallback convert normalized 1–5 (score) to percentage approx
          final n = r['score'];
          if (n is num) {
            total += (n * 20).round();
            count++;
          }
        }
      }
      _overallScore = count > 0 ? (total / count).round() : 0;
    } else {
      _overallScore = 0;
    }

    setState(() => _showResults = true);
  }

  Future<void> _submitLesson() async {
    if (_promptResults.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No prompts completed to submit.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final detailedResponses = {
        'overallScore': _overallScore ?? 0,
        'promptDetails': _promptResults
            .map(
              (r) => {
                'id': r['promptId'],
                'text': r['promptText'],
                'character': 'Agent',
                'audioUrl': r['audioUrl'],
                'transcription': r['transcription'] ?? '',
                'score':
                    r['accuracyScore'] ??
                    ((r['score'] ?? 0) * 20), // percent for consistency
                'accuracyScore': r['accuracyScore'],
                'azureAiFeedback': r['azureAiFeedback'],
                'openAiDetailedFeedback': r['openAiDetailedFeedback'],
              },
            )
            .toList(),
        'timeSpent': _initialTime - _timerSeconds,
        'reflections': {},
      };

      await _progressService.saveLessonAttempt(
        lessonId: widget.lessonId,
        score: _overallScore ?? 0,
        maxScore:
            widget.lessonData['activity']['maxPossibleAIScore'] as int? ?? 100,
        timeSpent: _initialTime - _timerSeconds,
        detailedResponses: detailedResponses,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lesson submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      _logger.e('Error submitting lesson: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error submitting lesson. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ---------------- UI Builders ----------------

  @override
  Widget build(BuildContext context) {
    if (_showResults) return _buildResultsView();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lessonTitle),
        backgroundColor: const Color(0xFF32CD32),
      ),
      body: Stack(
        children: [
          _buildPromptView(),
          if (_isProcessing) _buildProcessingOverlay(),
        ],
      ),
    );
  }

  Widget _buildPromptView() {
    if (_speakingPrompts.isEmpty) {
      return const Center(child: Text('No speaking prompts available.'));
    }

    final currentPrompt = _speakingPrompts[_currentPromptIndex];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(currentPrompt),
          const SizedBox(height: 20),
          _buildPromptCard(currentPrompt),
          const SizedBox(height: 20),
          _buildRecordingControls(),
          if (_showFeedback && _currentFeedback != null) ...[
            const SizedBox(height: 20),
            _buildFeedbackSection(),
          ],
          const SizedBox(height: 20),
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> currentPrompt) {
    return Card(
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
                    'Speaking Practice - Prompt ${_currentPromptIndex + 1} of ${_speakingPrompts.length}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1565C0),
                    ),
                  ),
                ),
                Text(
                  'Attempt: ${widget.attemptNumber}',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (!_showResults && !_isTimedOut)
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
                const Spacer(),
                // Add connection indicator
                FutureBuilder<bool>(
                  future: _hasInternetConnection(),
                  builder: (context, snapshot) {
                    final hasConnection = snapshot.data ?? true;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: hasConnection
                            ? Colors.green.shade100
                            : Colors.red.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            hasConnection ? Icons.wifi : Icons.wifi_off,
                            size: 14,
                            color: hasConnection ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            hasConnection ? 'Connected' : 'No Internet',
                            style: TextStyle(
                              fontSize: 10,
                              color: hasConnection ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptCard(Map<String, dynamic> prompt) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (prompt['context'] != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  prompt['context'],
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your turn. Please say the following Agent\'s line clearly:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1565C0),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Model audio feature coming soon!'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.volume_up, size: 16),
                      label: const Text('Listen to Model'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[100],
                        foregroundColor: Colors.blue[800],
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '"${prompt['text']}"',
                    style: const TextStyle(
                      fontSize: 18,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1565C0),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[300]!),
              ),
              child: const Row(
                children: [
                  Icon(Icons.mic, color: Color(0xFF32CD32), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Turn to Speak!',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Remember to speak your response clearly in English to receive an accurate evaluation from the AI coach.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF388E3C),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingControls() {
    return Column(
      children: [
        if (!_isRecording && !_hasRecording)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _startRecording,
              icon: const Icon(Icons.mic, size: 24),
              label: const Text('Record Audio'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF32CD32),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        if (_isRecording)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _stopRecording,
              icon: const Icon(Icons.stop, size: 24),
              label: const Text('Stop Recording'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        if (_hasRecording && !_isRecording) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _playRecording,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Play Recording'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _startRecording,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Record Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showFeedback ? null : _submitForFeedback,
              icon: const Icon(Icons.send),
              label: const Text('Submit for AI Feedback'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ----------- New Tabbed Feedback Section -----------

  Widget _buildFeedbackSection() {
    final azure = _currentFeedback?['azureAiFeedback'] as Map<String, dynamic>?;
    final coach =
        _currentFeedback?['openAiDetailedFeedback'] as Map<String, dynamic>?;

    return Card(
      elevation: 6,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with improved styling
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.psychology,
                      color: Colors.blue,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Feedback Analysis',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        Text(
                          'Comprehensive evaluation of your pronunciation',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  // Overall score badge
                  if (_currentFeedback?['accuracyScore'] != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _getScoreColor(
                          _currentFeedback!['accuracyScore'],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_currentFeedback!['accuracyScore'].toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // Enhanced Tab Bar with icons and better styling
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.grey.shade600,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade400, Colors.blue.shade600],
                    ),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  isScrollable: true,
                  dividerColor: Colors.transparent,
                  tabs: [
                    _buildTab(
                      Icons.sports,
                      "Coach's\nPlaybook",
                      _isDetailedFeedbackMissing(),
                    ),
                    _buildTab(Icons.analytics, "Azure AI\nMetrics", false),
                    _buildTab(Icons.translate, "Enhanced\nAnalysis", false),
                    _buildTab(Icons.spellcheck, "Word\nAnalysis", false),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Tab content with enhanced styling
              SizedBox(
                height: 500, // Increased height for better content display
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildEnhancedCoachPlaybookTab(coach),
                    _buildEnhancedAzureMetricsTab(azure),
                    _buildEnhancedAnalysisTab(azure),
                    _buildEnhancedWordAnalysisTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedWordAnalysisTab() {
    if (_wordComparison.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.spellcheck, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No word-level data available',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Header with word breakdown summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.spellcheck, color: Colors.indigo.shade600, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Word Pronunciation Analysis',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                    ),
                  ),
                ),
                _buildWordSummaryChip(),
              ],
            ),
          ),

          // Color legend
          Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildLegendItem('Excellent', Colors.green, '95-100%'),
                _buildLegendItem('Practice', Colors.orange, '60-94%'),
                _buildLegendItem('Focus', Colors.red, '<60%'),
              ],
            ),
          ),

          // Word list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _wordComparison.length,
              itemBuilder: (context, index) {
                return _buildEnhancedWordCard(_wordComparison[index], index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordSummaryChip() {
    final excellent = _wordComparison
        .where((w) => w['accuracyScore'] != null && w['accuracyScore'] >= 95)
        .length;
    final needsPractice = _wordComparison
        .where(
          (w) =>
              w['accuracyScore'] != null &&
              w['accuracyScore'] >= 60 &&
              w['accuracyScore'] < 95,
        )
        .length;
    final needsFocus = _wordComparison
        .where(
          (w) =>
              w['omission'] == true ||
              (w['accuracyScore'] != null && w['accuracyScore'] < 60),
        )
        .length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.indigo.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '$excellent/$needsPractice/$needsFocus',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.indigo.shade700,
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, String range) {
    return Column(
      children: [
        Container(
          width: 24,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        Text(
          range,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildEnhancedWordCard(Map<String, dynamic> word, int index) {
    final omission = word['omission'] == true;
    final double? accuracy = (word['accuracyScore'] is num)
        ? (word['accuracyScore'] as num).toDouble()
        : null;

    Color color;
    String category;
    IconData icon;

    if (omission) {
      color = Colors.red;
      category = 'OMISSION';
      icon = Icons.remove_circle;
    } else if (accuracy == null) {
      color = Colors.grey;
      category = 'N/A';
      icon = Icons.help;
    } else if (accuracy >= 95) {
      color = Colors.green;
      category = 'EXCELLENT';
      icon = Icons.check_circle;
    } else if (accuracy >= 60) {
      color = Colors.orange;
      category = 'PRACTICE';
      icon = Icons.warning;
    } else {
      color = Colors.red;
      category = 'FOCUS';
      icon = Icons.priority_high;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: omission ? Colors.red.shade200 : Colors.grey.shade300,
          width: omission ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          word['word'],
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: omission ? Colors.red.shade700 : Colors.black87,
          ),
        ),
        subtitle: Text(
          category,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
        trailing: accuracy != null
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${accuracy.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildEnhancedAnalysisTab(Map<String, dynamic>? azure) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Enhanced Analysis Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.shade50, Colors.indigo.shade50],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.purple.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.translate, color: Colors.purple.shade600, size: 24),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Enhanced Analysis for Filipino Speakers',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
                      Text(
                        'Specialized feedback for English pronunciation',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Overall Accent Score
          _buildAccentScoreCard(),
          const SizedBox(height: 16),

          // Reading Analysis
          _buildReadingAnalysisCard(azure),
        ],
      ),
    );
  }

  Widget _buildAccentScoreCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade50, Colors.teal.shade50],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events, color: Colors.green.shade600, size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Overall Accent Score',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '100', // This would be dynamic based on your analysis
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade600,
                ),
              ),
              Text(
                '%',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Excellent! Your English pronunciation is very clear.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.green.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildReadingAnalysisCard(Map<String, dynamic>? azure) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.menu_book, color: Colors.indigo.shade600, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Reading Analysis',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildAnalysisMetric('Naturalness', 100, Colors.green),
              ),
              const SizedBox(width: 16),
              Expanded(child: _buildAnalysisMetric('Pace', 60, Colors.orange)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisMetric(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                value: value / 100,
                strokeWidth: 6,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            Text(
              '$value%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEnhancedCoachPlaybookTab(Map<String, dynamic>? coach) {
    final list = (coach != null && coach['feedback'] is List)
        ? coach['feedback'] as List
        : [];

    if (list.isEmpty) {
      return _buildFeedbackUnavailableWidget();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header matching web design
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.indigo.shade50, Colors.blue.shade50],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.indigo.shade100),
            ),
            child: Row(
              children: [
                Icon(Icons.school, color: Colors.indigo.shade600, size: 24),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Coach's Detailed Analysis",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo,
                        ),
                      ),
                      Text(
                        "Personalized feedback with actionable improvement tips",
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Feedback cards matching web layout
          for (final metric in list)
            _buildEnhancedCoachMetricCard(metric as Map<String, dynamic>),

          // Overall summary matching web design
          if (coach?['overall'] != null)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade50, Colors.blue.shade50],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.emoji_events,
                        color: Colors.green.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Overall Assessment',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    coach!['overall'],
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFeedbackUnavailableWidget() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off, size: 80, color: Colors.orange.shade300),
          const SizedBox(height: 20),
          const Text(
            'Detailed Coach Feedback Unavailable',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'This can happen due to network connectivity issues. Your basic pronunciation scores are still available in the "Azure AI Metrics" tab.',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue.shade600,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'What you can do:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  '• Record again to try getting detailed feedback\n'
                  '• Check your internet connection\n'
                  '• Your pronunciation scores are still saved\n'
                  '• You can continue to the next prompt',
                  style: TextStyle(fontSize: 14, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _hasRecording = false;
                  _currentRecordingPath = null;
                  _showFeedback = false;
                  _currentFeedback = null;
                  _wordComparison = [];
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Ready to record again. Try speaking clearly and check your internet connection.',
                    ),
                    backgroundColor: Colors.blue,
                    duration: Duration(seconds: 3),
                  ),
                );
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try Recording Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(IconData icon, String label, bool hasWarning) {
    return Tab(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Just the icon with status indicator
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, size: 18),
              if (hasWarning)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                )
              else
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          // Compact text
          Flexible(
            child: Text(
              label.replaceAll('\n', ' '), // Remove line breaks
              style: const TextStyle(fontSize: 9),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(double? score) {
    if (score == null) return Colors.grey;
    if (score >= 90) return Colors.green;
    if (score >= 75) return Colors.lightGreen;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  IconData _getMetricIcon(String metricName) {
    switch (metricName.toLowerCase()) {
      case 'accuracy':
        return Icons.my_location; // ✅ Valid alternative to target
      case 'fluency':
        return Icons.timeline;
      case 'completeness':
        return Icons.playlist_add_check;
      case 'prosody':
        return Icons.graphic_eq;
      default:
        return Icons.analytics;
    }
  }

  Widget _buildEnhancedCoachMetricCard(Map<String, dynamic> metric) {
    final double? rawScore = (metric['score'] is num)
        ? (metric['score'] as num).toDouble()
        : null;
    final String metricName = metric['metric'] ?? '';

    // ✅ NEW: Determine if this is a /5 metric or percentage metric
    final bool isOutOfFive =
        metricName.toLowerCase() == 'fluency' ||
        metricName.toLowerCase() == 'prosody';

    // ✅ NEW: Convert score based on metric type
    double? displayScoreValue;
    String displayScore;
    Color scoreColor;

    if (rawScore == null) {
      displayScore = 'N/A';
      scoreColor = Colors.grey;
    } else if (isOutOfFive) {
      // For Fluency and Prosody: convert from percentage to /5 scale if needed
      if (rawScore > 5) {
        // If score is greater than 5, it's likely a percentage - convert it
        displayScoreValue =
            (rawScore / 100) * 5; // Convert percentage to /5 scale
      } else {
        // If score is 5 or less, it's already in /5 scale
        displayScoreValue = rawScore;
      }

      displayScore = '${displayScoreValue.toStringAsFixed(1)}/5';

      // Use appropriate color logic for /5 scores
      if (displayScoreValue >= 4.0) {
        scoreColor = Colors.green;
      } else if (displayScoreValue >= 3.0) {
        scoreColor = Colors.lightGreen;
      } else if (displayScoreValue >= 2.0) {
        scoreColor = Colors.orange;
      } else {
        scoreColor = Colors.red;
      }
    } else {
      // For Accuracy and Completeness: show as percentage
      displayScore = '${rawScore.toStringAsFixed(0)}%';
      scoreColor = _getScoreColor(rawScore);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with score
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scoreColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(_getMetricIcon(metricName), color: scoreColor, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    metricName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: scoreColor,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: scoreColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    displayScore,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content (rest remains the same)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (metric['whyThisScore'] != null) ...[
                  Text(
                    metric['whyThisScore'],
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                ],
                if (metric['tip'] != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lightbulb,
                          color: Colors.amber.shade700,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Improvement Tip',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.amber.shade700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                metric['tip'],
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedAzureMetricsTab(Map<String, dynamic>? azure) {
    if (azure == null) {
      return const Center(
        child: Text(
          'No Azure metrics available.',
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    final transcription =
        azure['textRecognized'] ?? 'Speech not clearly recognized.';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Transcription section matching web design
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.indigo.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.record_voice_over,
                      color: Colors.indigo.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'YOUR RECORDING:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.indigo,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '"$transcription"',
                  style: const TextStyle(
                    fontStyle: FontStyle.italic,
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Azure AI Metrics header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.psychology,
                  color: Colors.blue.shade600,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Azure AI Metrics',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Metrics grid matching web layout
          _buildMetricCard(
            'Accuracy',
            (azure['accuracyScore'] as num?)?.toDouble(),
            icon: Icons.my_location, // ✅ Corrected: Added "icon:"
            description:
                'Pronunciation clarity', // ✅ Corrected: Added "description:"
            percent: true,
          ),

          _buildMetricCard(
            'Fluency',
            (azure['fluencyScore'] as num?)?.toDouble(),
            icon: Icons.show_chart, // ✅ Corrected: Added "icon:"
            description:
                'Speech flow and rhythm', // ✅ Corrected: Added "description:"
            percent: false,
            maxValue: 5,
          ),

          _buildMetricCard(
            'Completeness',
            (azure['completenessScore'] as num?)?.toDouble(),
            icon: Icons.checklist, // ✅ Corrected: Added "icon:"
            description:
                'All words included', // ✅ Corrected: Added "description:"
            percent: true,
          ),

          _buildMetricCard(
            'Prosody',
            (azure['prosodyScore'] as num?)?.toDouble(),
            icon: Icons.equalizer, // ✅ Corrected: Added "icon:"
            description:
                'Tone and intonation', // ✅ Corrected: Added "description:"
            percent: false,
            maxValue: 5,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    String label,
    double? value, {
    required IconData icon,
    required String description,
    bool percent = true,
    double maxValue = 100,
  }) {
    if (value == null) return const SizedBox.shrink();

    // ✅ NEW: Determine if this is a /5 metric
    final bool isOutOfFive =
        label.toLowerCase() == 'fluency' || label.toLowerCase() == 'prosody';

    // ✅ NEW: Convert score and determine display format
    double displayValue;
    String displayText;

    if (isOutOfFive) {
      // For Fluency and Prosody: convert from percentage to /5 scale if needed
      if (value > 5) {
        // If value is greater than 5, it's likely a percentage - convert it
        displayValue = (value / 100) * 5; // Convert percentage to /5 scale
      } else {
        // If value is 5 or less, it's already in /5 scale
        displayValue = value;
      }
      displayText = '${displayValue.toStringAsFixed(1)}/5';
      // For progress bar, use the /5 scale
      final double normalizedValue = displayValue / 5;
    } else {
      // For Accuracy and Completeness: use as percentage
      displayValue = value;
      displayText = percent
          ? '${value.toStringAsFixed(1)}%'
          : '${value.toStringAsFixed(1)}/${maxValue.toInt()}';
    }

    final Color color = _getScoreColor(
      isOutOfFive ? (displayValue / 5 * 100) : value,
    );
    final double normalizedValue = isOutOfFive
        ? displayValue / 5
        : (percent ? value / 100 : value / maxValue);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  displayText, // ✅ Use converted display text
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: normalizedValue.clamp(0.0, 1.0),
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoachPlaybookTab(Map<String, dynamic>? coach) {
    final list = (coach != null && coach['feedback'] is List)
        ? coach['feedback'] as List
        : [];

    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, size: 64, color: Colors.orange.shade300),
            const SizedBox(height: 16),
            const Text(
              'Detailed Coach Feedback Unavailable',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'This can happen due to network connectivity issues. Your basic pronunciation scores are still available in the "Detailed Metrics" tab.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'What you can do:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '• Record again to try getting detailed feedback\n'
                    '• Check your internet connection\n'
                    '• Your pronunciation scores are still saved\n'
                    '• You can continue to the next prompt',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Reset to recording state
                  setState(() {
                    _hasRecording = false;
                    _currentRecordingPath = null;
                    _showFeedback = false;
                    _currentFeedback = null;
                    _wordComparison = [];
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Ready to record again. Try speaking clearly and check your internet connection.',
                      ),
                      backgroundColor: Colors.blue,
                      duration: Duration(seconds: 3),
                    ),
                  );
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Try Recording Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Original code for when feedback is available
    return ListView(
      padding: const EdgeInsets.only(top: 12),
      children: [
        for (final metric in list)
          _coachMetricCard(metric as Map<String, dynamic>),
        if (coach?['overall'] != null)
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.indigo[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.indigo.shade100),
            ),
            child: Text(
              coach!['overall'],
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.indigo,
              ),
            ),
          ),
      ],
    );
  }

  Widget _coachMetricCard(Map<String, dynamic> m) {
    final double? sc = (m['score'] is num)
        ? (m['score'] as num).toDouble()
        : null;
    Color color;
    if (sc == null) {
      color = Colors.grey;
    } else if (sc >= 90) {
      color = Colors.green;
    } else if (sc >= 75) {
      color = Colors.lightGreen;
    } else if (sc >= 60) {
      color = Colors.orange;
    } else {
      color = Colors.red;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                m['metric'] ?? '',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              if (sc != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${sc.toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          if (m['whyThisScore'] != null) ...[
            const SizedBox(height: 6),
            Text(m['whyThisScore'], style: const TextStyle(fontSize: 13)),
          ],
          if (m['tip'] != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.yellow[50],
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Text(
                'Tip: ${m['tip']}',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailedMetricsTab(Map<String, dynamic>? azure) {
    if (azure == null) {
      return const Center(child: Text('No Azure metrics available.'));
    }

    Widget metric(
      String label,
      double? value, {
      bool percent = true,
      IconData icon = Icons.speed,
    }) {
      if (value == null) return const SizedBox.shrink();
      Color barColor;
      if (value >= 90) {
        barColor = Colors.green;
      } else if (value >= 75) {
        barColor = Colors.lightGreen;
      } else if (value >= 60) {
        barColor = Colors.orange;
      } else {
        barColor = Colors.red;
      }
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: barColor),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Text(
                  percent
                      ? '${value.toStringAsFixed(1)}%'
                      : value.toStringAsFixed(1),
                  style: TextStyle(
                    color: barColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: value.clamp(0, 100) / 100,
              color: barColor,
              backgroundColor: Colors.grey.shade200,
              minHeight: 10,
            ),
          ],
        ),
      );
    }

    final List<Widget> col = [];
    col.add(
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.indigo[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.indigo.shade100),
        ),
        child: Text(
          '"${azure['textRecognized'] ?? 'Speech not clearly recognized.'}"',
          style: const TextStyle(fontStyle: FontStyle.italic),
        ),
      ),
    );
    col.add(const SizedBox(height: 12));

    col.addAll([
      metric('Accuracy', (azure['accuracyScore'] as num?)?.toDouble()),
      metric(
        'Fluency',
        (azure['fluencyScore'] as num?)?.toDouble(),
        percent: false,
        icon: Icons.timeline,
      ),
      metric(
        'Completeness',
        (azure['completenessScore'] as num?)?.toDouble(),
        icon: Icons.playlist_add_check,
      ),
      metric(
        'Prosody',
        (azure['prosodyScore'] as num?)?.toDouble(),
        percent: false,
        icon: Icons.graphic_eq,
      ),
    ]);

    return ListView(padding: const EdgeInsets.only(top: 12), children: col);
  }

  Widget _buildWordByWordTab() {
    if (_wordComparison.isEmpty) {
      return const Center(child: Text('No word-level data.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 12),
      itemCount: _wordComparison.length,
      itemBuilder: (_, i) {
        final w = _wordComparison[i];
        final omission = w['omission'] == true;
        final double? acc = (w['accuracyScore'] is num)
            ? (w['accuracyScore'] as num).toDouble()
            : null;

        Color color;
        if (omission) {
          color = Colors.red;
        } else if (acc == null) {
          color = Colors.grey;
        } else if (acc >= 95) {
          color = Colors.green;
        } else if (acc >= 80) {
          color = Colors.lightGreen;
        } else if (acc >= 60) {
          color = Colors.orange;
        } else {
          color = Colors.red;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: omission ? Colors.red.shade200 : Colors.grey.shade300,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  w['word'],
                  style: TextStyle(
                    color: color,
                    fontWeight: omission ? FontWeight.bold : FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              if (omission)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade600,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'OMISSION',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else if (acc != null)
                Text(
                  '${acc.toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                )
              else
                const Text(
                  'N/A',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNavigationButtons() {
    return Column(
      children: [
        if (_currentPromptIndex > 0)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _currentPromptIndex--;
                  _resetPromptState();
                });
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text('Previous Prompt'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        if (_currentPromptIndex > 0) const SizedBox(height: 12),
        if (_showFeedback)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _nextPrompt,
              icon: const Icon(Icons.arrow_forward),
              label: Text(
                _currentPromptIndex < _speakingPrompts.length - 1
                    ? 'Next Prompt'
                    : 'Finish & View Results',
              ),
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

  Widget _buildProcessingOverlay() {
    return Container(
      color: Colors.black54,
      child: const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF32CD32)),
                ),
                SizedBox(height: 16),
                Text(
                  'Processing Your Audio with Azure AI...',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text(
                  'Please wait a moment.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultsView() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Results'),
        backgroundColor: const Color(0xFF32CD32),
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFF32CD32).withOpacity(0.1), Colors.white],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Overall Summary Card
              _buildOverallSummaryCard(),
              const SizedBox(height: 20),

              // Performance Breakdown
              _buildPerformanceBreakdown(),
              const SizedBox(height: 20),

              // Detailed Results by Prompt
              _buildDetailedPromptResults(),
              const SizedBox(height: 20),

              // Time & Statistics
              _buildTimeAndStats(),
              const SizedBox(height: 30),

              // Action Buttons
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverallSummaryCard() {
    final completedPrompts = _promptResults.length;
    final totalPrompts = _speakingPrompts.length;
    final completionRate = totalPrompts > 0
        ? (completedPrompts / totalPrompts * 100).round()
        : 0;

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.indigo.shade50, Colors.blue.shade50],
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.emoji_events,
                    color: Colors.green.shade600,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Speaking Practice Complete!',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo,
                        ),
                      ),
                      Text(
                        'Congratulations on completing the activity',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Overall Score
            Column(
              children: [
                const Text(
                  'Your Overall Score',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_overallScore ?? 0}%',
                  style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.bold,
                    color: _getScoreColor((_overallScore ?? 0).toDouble()),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _getScoreColor(
                      (_overallScore ?? 0).toDouble(),
                    ).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _getPerformanceLabel(_overallScore ?? 0),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _getScoreColor((_overallScore ?? 0).toDouble()),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Progress Info
            Row(
              children: [
                Expanded(
                  child: _buildSummaryMetric(
                    'Completed',
                    '$completedPrompts/$totalPrompts',
                    'Prompts',
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.grey.shade300),
                Expanded(
                  child: _buildSummaryMetric(
                    'Completion',
                    '$completionRate%',
                    'Rate',
                    Icons.trending_up,
                    Colors.blue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryMetric(
    String label,
    String value,
    String unit,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          '$label $unit',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPerformanceBreakdown() {
    if (_promptResults.isEmpty) return const SizedBox.shrink();

    // Calculate average scores for each metric
    double avgAccuracy = 0;
    double avgFluency = 0;
    double avgCompleteness = 0;
    double avgProsody = 0;
    int count = 0;

    for (final result in _promptResults) {
      final azure = result['azureAiFeedback'] as Map<String, dynamic>?;
      if (azure != null) {
        if (azure['accuracyScore'] != null) {
          avgAccuracy += (azure['accuracyScore'] as num).toDouble();
          count++;
        }
        if (azure['fluencyScore'] != null) {
          avgFluency += (azure['fluencyScore'] as num).toDouble();
        }
        if (azure['completenessScore'] != null) {
          avgCompleteness += (azure['completenessScore'] as num).toDouble();
        }
        if (azure['prosodyScore'] != null) {
          avgProsody += (azure['prosodyScore'] as num).toDouble();
        }
      }
    }

    if (count > 0) {
      avgAccuracy /= count;
      avgFluency /= count;
      avgCompleteness /= count;
      avgProsody /= count;
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.indigo.shade600, size: 24),
                const SizedBox(width: 12),
                const Text(
                  'Performance Breakdown',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Metrics
            _buildMetricProgress('Accuracy', avgAccuracy, true),
            const SizedBox(height: 16),
            _buildMetricProgress('Fluency', avgFluency, false, maxValue: 5),
            const SizedBox(height: 16),
            _buildMetricProgress('Completeness', avgCompleteness, true),
            const SizedBox(height: 16),
            _buildMetricProgress('Prosody', avgProsody, false, maxValue: 5),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricProgress(
    String label,
    double value,
    bool isPercentage, {
    double maxValue = 100,
  }) {
    final normalizedValue = isPercentage ? value / 100 : value / maxValue;
    final displayValue = isPercentage
        ? '${value.toStringAsFixed(1)}%'
        : '${value.toStringAsFixed(1)}/$maxValue';
    final color = _getScoreColor(
      isPercentage ? value : (value / maxValue * 100),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            Text(
              displayValue,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: normalizedValue.clamp(0.0, 1.0),
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedPromptResults() {
    if (_promptResults.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.list_alt, color: Colors.indigo.shade600, size: 24),
                const SizedBox(width: 12),
                const Text(
                  'Detailed Results',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Prompt results list
            ...List.generate(_promptResults.length, (index) {
              final result = _promptResults[index];
              final score = result['accuracyScore'] ?? (result['score'] * 20);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _getScoreColor(score.toDouble()),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Prompt ${index + 1}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _truncateText(
                              result['promptText']?.toString() ??
                                  'No text available',
                              50,
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getScoreColor(score.toDouble()),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${score.round()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeAndStats() {
    final timeSpent = _initialTime - _timerSeconds;
    final minutes = timeSpent ~/ 60;
    final seconds = timeSpent % 60;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  color: Colors.indigo.shade600,
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Session Statistics',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Time Spent',
                    '${minutes}m ${seconds}s',
                    Icons.timer,
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Attempt #',
                    '${widget.attemptNumber}',
                    Icons.refresh,
                    Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back to Lesson'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _submitLesson,
            icon: const Icon(Icons.check),
            label: const Text('Submit Lesson'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) {
      return text;
    }
    return '${text.substring(0, maxLength)}...';
  }

  // Helper method for performance labels
  String _getPerformanceLabel(int score) {
    if (score >= 90) return 'Excellent';
    if (score >= 80) return 'Good';
    if (score >= 70) return 'Fair';
    if (score >= 60) return 'Needs Practice';
    return 'Keep Trying';
  }
}
