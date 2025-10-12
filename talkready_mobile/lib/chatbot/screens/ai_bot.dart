import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:showcaseview/showcaseview.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import '../models/prompt.dart';
import '../models/message.dart';
import '../services/audio_service.dart';
import '../services/transcription_service.dart';
import '../services/tts_service.dart';
import '../services/openai_service.dart';
import '../services/firebase_chat_service.dart';
import '../widgets/chat_message.dart';
import '../widgets/icon_row.dart';
import '../widgets/suggestion_chips.dart';
import '../utils/text_processing.dart';
import 'tutorial_service.dart';
import 'package:logger/logger.dart';

final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 2,
    errorMethodCount: 8,
    lineLength: 120,
    colors: true,
    printEmojis: true,
  ),
);

class AIBotScreen extends StatefulWidget {
  final VoidCallback? onBackPressed;

  const AIBotScreen({super.key, this.onBackPressed});

  @override
  State<AIBotScreen> createState() => _AIBotScreenState();
}

class _AIBotScreenState extends State<AIBotScreen> {
  // Services
  late AudioService _audioService;
  late TranscriptionService _transcriptionService;
  late TTSService _ttsService;
  late OpenAIService _openAIService;
  late FirebaseChatService _firebaseChatService;

  // State variables
  final List<Message> _messages = [];
  bool _isListening = false;
  bool _isProcessingTTS = false;
  bool _isTyping = false;
  bool _hasStartedListening = false;
  bool _hasSeenTutorial = false;
  bool _hasTriggeredTutorial = false;
  bool _isPlayingUserAudio = false;
  bool _showSuggestions = true;
  bool _isAwaitingPronunciationPractice = false;
  Timer? _rolePlayTimer;

  // User data
  String? _userName;
  ImageProvider? _userProfileImage;

  // Practice mode
  Prompt? _currentLearningPrompt;
  PromptCategory? _currentPracticeMode;
  String? _currentPracticePhrase;
  int? _rolePlayDurationMinutes;
  DateTime? _rolePlayStartTime;

  // Controllers and keys
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _promptIconKey = GlobalKey();
  final GlobalKey _chatAreaKey = GlobalKey();
  final GlobalKey _micKey = GlobalKey();
  final GlobalKey _keyboardKey = GlobalKey();
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _fetchOnboardingData().then((_) {
      _initializeScreen();
    });
  }

  void _initializeServices() {
    _audioService = AudioService(logger: logger);
    _transcriptionService = TranscriptionService(logger: logger);
    _openAIService = OpenAIService(logger: logger);
    _firebaseChatService = FirebaseChatService(logger: logger);

    _audioService.initialize().then((_) {
      _ttsService = TTSService(logger: logger, audioService: _audioService);
    });
  }

  void _initializeScreen() {
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        String greetingMessage;
        try {
          greetingMessage = _generateRandomGreeting();
        } catch (e) {
          logger.e('Error generating greeting: $e');
          greetingMessage =
              "Hello${_userName != null && _userName!.isNotEmpty ? ", $_userName" : ""}! How can I help you practice today?";
          _showSnackBar('Could not display a personalized greeting.');
        }

        final initialMessage = Message(
          id: 'bot-${DateTime.now().millisecondsSinceEpoch}',
          text: greetingMessage,
          isUser: false,
          timestamp: DateTime.now().toIso8601String(),
        );

        setState(() {
          _messages.add(initialMessage);
          _pruneMessages();
        });

        _speakText(greetingMessage);
        _scrollToBottom();
        _firebaseChatService.initializeNewChatSession(initialMessage);
      }
    });
  }

  String _generateRandomGreeting() {
    logger.i('Generating greeting, userName: $_userName');
    final now = DateTime.now();
    String timePrefix = now.hour < 12
        ? "Good morning"
        : now.hour < 17
        ? "Good afternoon"
        : "Good evening";

    if (_userName == null || _userName!.isEmpty) {
      logger.e('userName is null or empty');
      throw Exception('User name is missing');
    }

    final List<String> baseGreetings = [
      "$timePrefix, $_userName! How's your day been? Spill something fun!",
      "$timePrefix, $_userName! What's new with you today?",
      "$timePrefix, $_userName! Got any exciting plans?",
      "$timePrefix, $_userName! How's your day going? Tell me a smashing story!",
      "$timePrefix, $_userName! What's on your mind today?",
      "$timePrefix, $_userName! Fancy sharing a brilliant tale?",
      "$timePrefix, $_userName! What's cooking, buddy?",
      "$timePrefix, $_userName! Got any yarns to spin?",
    ];

    String greeting = baseGreetings.isNotEmpty
        ? baseGreetings[_random.nextInt(baseGreetings.length)]
        : "$timePrefix, $_userName! Ready to practice your English?";

    logger.i('Generated greeting: $greeting');
    return greeting;
  }

  Future<void> _fetchOnboardingData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _userName = 'User';
      _userProfileImage = null;
      _hasSeenTutorial = false;
      logger.w("User is null, using defaults.");
      return;
    }

    try {
      final userData = await _firebaseChatService.fetchUserData();

      if (userData != null) {
        _userName = userData['firstName']?.toString();

        if (_userName == null || _userName!.isEmpty) {
          if (userData.containsKey('onboarding')) {
            final onboardingMap =
                userData['onboarding'] as Map<String, dynamic>?;
            _userName =
                onboardingMap?['firstName']?.toString() ??
                onboardingMap?['userName']?.toString();
          }
        }

        if (_userName == null || _userName!.isEmpty) {
          _userName = user.displayName?.split(' ').first ?? 'User';
        }

        String? profilePicBase64 = userData['profilePicBase64']?.toString();
        if ((profilePicBase64 == null || profilePicBase64.isEmpty) &&
            userData.containsKey('onboarding')) {
          final onboardingMap = userData['onboarding'] as Map<String, dynamic>?;
          profilePicBase64 = onboardingMap?['profilePicBase64']?.toString();
        }

        if (profilePicBase64 != null && profilePicBase64.isNotEmpty) {
          try {
            String tempBase64 = profilePicBase64;
            if (tempBase64.startsWith('data:image')) {
              tempBase64 = tempBase64.split(',').last;
            }
            final bytes = base64Decode(tempBase64);
            _userProfileImage = MemoryImage(bytes);
            logger.i('Profile picture decoded, byte length: ${bytes.length}');
          } catch (e) {
            logger.e('Error decoding profilePicBase64: $e');
            _userProfileImage = null;
          }
        }

        _hasSeenTutorial = (userData['hasSeenTutorial'] as bool?) ?? false;
        logger.i('Loaded: hasSeenTutorial=$_hasSeenTutorial');
      } else {
        _userName = user.displayName?.split(' ').first ?? 'User';
        _userProfileImage = null;
        _hasSeenTutorial = false;
      }
    } catch (e) {
      logger.e('Error fetching user data: $e');
      _userName =
          FirebaseAuth.instance.currentUser?.displayName?.split(' ').first ??
          'User';
      _userProfileImage = null;
      _hasSeenTutorial = false;
    } finally {
      if (mounted) setState(() {});
    }
  }

  Future<void> _startListening() async {
    if (!_audioService.isRecorderInitialized) {
      _showSnackBar('Cannot record audio. Recorder initialization failed.');
      return;
    }

    if (!_isListening && !_isTyping) {
      if (!_hasStartedListening) {
        setState(() => _hasStartedListening = true);
      }

      try {
        await _audioService.startRecording();
        setState(() => _isListening = true);
        _showSnackBar('Recording started. Speak now!');
      } catch (e) {
        logger.e('Error starting recording: $e');
        _showSnackBar('Error starting recording: $e');
        setState(() => _isListening = false);
      }
    } else if (_isTyping) {
      _showSnackBar('Cannot start recording while typing.');
    }
  }

  Future<void> _stopListening() async {
    if (_isListening) {
      try {
        String? path = await _audioService.stopRecording();
        setState(() => _isListening = false);
        _showSnackBar('Recording stopped.');

        if (path != null) {
          await _processAudioRecording(path);
        } else {
          _showSnackBar('Could not find the recorded audio file.');
        }
      } catch (e) {
        logger.e('Error stopping recording: $e');
        _showSnackBar('Error stopping recording: $e');
        setState(() => _isListening = false);
      }
    }
  }

  Future<void> _startRolePlaySession(int durationMinutes) async {
    final rolePlayPrompt = englishLearningPrompts.firstWhere(
      (p) => p.category == PromptCategory.rolePlay,
      orElse: () => englishLearningPrompts.first,
    );

    setState(() {
      _currentLearningPrompt = rolePlayPrompt;
      _currentPracticeMode = PromptCategory.rolePlay;
      _rolePlayDurationMinutes = durationMinutes;
      _rolePlayStartTime = DateTime.now();
      _showSuggestions = false;
    });

    _addBotMessage(
      "Awesome! We'll practice for $durationMinutes minutes. Let's start your role-play session. Would you like to be the customer or the agent?",
    );

    // Start timer that updates the UI every second
    _rolePlayTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final elapsed = DateTime.now().difference(_rolePlayStartTime!);
      final remaining = Duration(minutes: _rolePlayDurationMinutes!) - elapsed;

      if (remaining.isNegative) {
        timer.cancel();
        _endRolePlaySession();
      } else {
        setState(() {}); // Trigger rebuild to update timer display
      }
    });
  }

  void _endRolePlaySession() {
    if (!mounted) return;

    _rolePlayTimer?.cancel();
    _rolePlayTimer = null;

    _addBotMessage(
      "Great job! That's our $_rolePlayDurationMinutes-minute session done. You did well practicing those scenarios. Want to continue or try something else?",
    );

    setState(() {
      _rolePlayDurationMinutes = null;
      _rolePlayStartTime = null;
      _currentLearningPrompt = null;
      _currentPracticeMode = null;
      _showSuggestions = true;
    });
  }

  void _endRolePlaySessionEarly() {
    if (!mounted) return;

    // Cancel the timer
    _rolePlayTimer?.cancel();
    _rolePlayTimer = null;

    // Calculate how long they practiced
    if (_rolePlayStartTime != null) {
      final elapsed = DateTime.now().difference(_rolePlayStartTime!);
      final minutes = elapsed.inMinutes;

      _addBotMessage(
        "No problem! You practiced for $minutes minute${minutes != 1 ? 's' : ''}. Nice work! Want to continue chatting or try something else?",
      );
    }

    // Reset role-play state
    setState(() {
      _rolePlayDurationMinutes = null;
      _rolePlayStartTime = null;
      _currentLearningPrompt = null;
      _currentPracticeMode = null;
      _showSuggestions = true;
    });
  }

  Future<void> _processAudioRecording(String audioPath) async {
    try {
      _showSnackBar('Processing...');

      final audioFile = File(audioPath);
      if (!await audioFile.exists()) {
        logger.e('Audio file does not exist at path: $audioPath');
        _showSnackBar('Recording file not found. Please try again.');
        return;
      }

      final audioUrl = await _transcriptionService.uploadToCloudinary(
        audioPath,
      );

      // CHECK: Pronunciation or Fluency assessment
      if (_isAwaitingPronunciationPractice &&
          (_currentPracticeMode == PromptCategory.pronunciation ||
              _currentPracticeMode == PromptCategory.fluency)) {
        setState(() => _isAwaitingPronunciationPractice = false);

        final transcript = await _transcriptionService.transcribeWithAzure(
          audioUrl,
        );

        if (transcript != null) {
          final userMessage = Message(
            id: 'user-${DateTime.now().millisecondsSinceEpoch}',
            text: transcript,
            isUser: true,
            timestamp: DateTime.now().toIso8601String(),
            audioPath: audioPath,
          );

          setState(() {
            _messages.add(userMessage);
            _pruneMessages();
          });

          await _firebaseChatService.addMessageToSession(
            userMessage,
            audioUrl: audioUrl,
          );
          _scrollToBottom();

          // Generate feedback using Azure
          final feedback = await _transcriptionService
              .generatePronunciationFeedback(
                audioUrl,
                transcript,
                _currentPracticePhrase,
              );

          // Determine which feedback display to use
          final isFluencyMode = _currentPracticeMode == PromptCategory.fluency;

          if (isFluencyMode) {
            _addAzureFluencyMessage(feedback);
          } else {
            _addAzureFeedbackMessage(feedback);
          }

          // Generate AI response with context
          await _generateAIResponse(
            transcript,
            context: {
              'azureScoresSummary':
                  'Accuracy: ${feedback['accuracyScore']?.toStringAsFixed(0)}%, Fluency: ${feedback['fluencyScore']?.toStringAsFixed(0)}',
              'accuracyScore': feedback['accuracyScore'],
              'fluencyScore': feedback['fluencyScore'],
              'recognizedText': transcript,
              'isFluencyMode': isFluencyMode,
            },
          );
        } else {
          _showSnackBar('Could not transcribe your speech.');
        }
      } else {
        // General conversation - use AssemblyAI
        final transcript = await _transcriptionService.transcribeWithAssemblyAI(
          audioUrl,
        );

        if (transcript != null) {
          final userMessage = Message(
            id: 'user-${DateTime.now().millisecondsSinceEpoch}',
            text: transcript,
            isUser: true,
            timestamp: DateTime.now().toIso8601String(),
            audioPath: audioPath,
          );

          setState(() {
            _messages.add(userMessage);
            _pruneMessages();
          });

          await _firebaseChatService.addMessageToSession(
            userMessage,
            audioUrl: audioUrl,
          );
          _scrollToBottom();
          await _generateAIResponse(transcript);
        } else {
          _showSnackBar('Transcription failed.');
        }
      }
    } catch (e) {
      logger.e('Error processing audio: $e');
      _addBotMessage("Error processing audio: ${e.toString()}");
    }
  }

  void _addAzureFluencyMessage(Map<String, dynamic> feedback) {
    final azureMessage = Message(
      id: 'azure-fluency-${DateTime.now().millisecondsSinceEpoch}',
      text: feedback['feedback'] ?? '',
      isUser: false,
      timestamp: DateTime.now().toIso8601String(),
      type: MessageType.azureFluency, // NEW type
      metadata: {...feedback, 'originalText': _currentPracticePhrase},
    );

    setState(() {
      _messages.add(azureMessage);
      _pruneMessages();
    });
    _scrollToBottom();
  }

  void _addAzureFeedbackMessage(Map<String, dynamic> feedback) {
    final azureMessage = Message(
      id: 'azure-${DateTime.now().millisecondsSinceEpoch}',
      text: feedback['feedback'] ?? '',
      isUser: false,
      timestamp: DateTime.now().toIso8601String(),
      type: MessageType.azureFeedback,
      metadata: {...feedback, 'originalText': _currentPracticePhrase},
    );

    setState(() {
      _messages.add(azureMessage);
      _pruneMessages();
    });
    _scrollToBottom();
  }

  Future<void> _playUserAudio(String? audioPath) async {
    if (audioPath == null || audioPath.isEmpty) {
      _showSnackBar('No recording available.');
      return;
    }

    // Verify file exists before attempting to play
    final audioFile = File(audioPath);
    if (!await audioFile.exists()) {
      logger.e('Audio file not found at path: $audioPath');
      _showSnackBar('Recording file not found. It may have been deleted.');
      return;
    }

    // Check file size
    final fileSize = await audioFile.length();
    if (fileSize == 0) {
      logger.e('Audio file is empty: $audioPath');
      _showSnackBar('Recording file is empty.');
      return;
    }

    try {
      setState(() => _isPlayingUserAudio = true);
      logger.i('Playing user audio from: $audioPath (size: $fileSize bytes)');

      await _audioService.playUserAudio(audioPath);

      // Listen to audio completion
      _audioService.audioPlayer.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() => _isPlayingUserAudio = false);
          logger.i('Audio playback completed');
        }
      });

      // Fallback timeout (adjust based on expected audio length)
      Future.delayed(Duration(seconds: 30), () {
        if (mounted && _isPlayingUserAudio) {
          logger.w('Audio playback timeout - forcing stop');
          setState(() => _isPlayingUserAudio = false);
        }
      });
    } catch (e) {
      logger.e('Error playing user audio: $e');
      _showSnackBar('Error playing recording: ${e.toString()}');
      setState(() => _isPlayingUserAudio = false);
    }
  }

  void _toggleTyping() {
    if (!_isListening) {
      setState(() {
        _isTyping = !_isTyping;
        if (!_isTyping) {
          _textController.clear();
        } else {
          if (!_hasStartedListening) {
            _hasStartedListening = true;
          }
        }
      });
    } else {
      _showSnackBar('Please stop listening before typing.');
    }
  }

  void _submitTypedText() {
    if (_textController.text.isNotEmpty) {
      String processedText = TextProcessing.processText(_textController.text);

      final userMessage = Message(
        id: 'user-${DateTime.now().millisecondsSinceEpoch}',
        text: processedText,
        isUser: true,
        timestamp: DateTime.now().toIso8601String(),
      );

      setState(() {
        _messages.add(userMessage);
        _pruneMessages();
        _isTyping = false;
      });

      _firebaseChatService.addMessageToSession(userMessage);
      _scrollToBottom();
      _generateAIResponse(processedText);
      _textController.clear();
    }
  }

  Future<void> _generateAIResponse(
    String userInput, {
    Map<String, dynamic>? context,
  }) async {
    if (!mounted) return;

    setState(() => _isProcessingTTS = true);

    final typingMessage = Message(
      id: 'typing-${DateTime.now().millisecondsSinceEpoch}',
      text: 'TalkReady Bot is typing...',
      isUser: false,
      timestamp: DateTime.now().toIso8601String(),
      typing: true,
    );

    setState(() {
      _messages.add(typingMessage);
    });

    try {
      // LAYER 1: Hardcoded keyword detection (fast fallback)
      final exitKeywords = [
        'stop',
        'enough',
        'done',
        'finished',
        'quit',
        'exit',
        'change topic',
        'something else',
        'different',
        'switch',
        'no more',
        'that\'s enough',
        'i\'m done',
        'let\'s stop',
      ];

      final userInputLower = userInput.toLowerCase();
      final hardcodedExit = exitKeywords.any(
        (keyword) => userInputLower.contains(keyword),
      );

      if (hardcodedExit && _currentPracticeMode != null) {
        logger.i('Layer 1: Hardcoded keyword detected exit - $userInput');
      }

      if (_rolePlayDurationMinutes != null && _rolePlayStartTime != null) {
        context = context ?? {};
        context['rolePlayDuration'] = _rolePlayDurationMinutes;
        final elapsed = DateTime.now()
            .difference(_rolePlayStartTime!)
            .inMinutes;
        context['rolePlayElapsed'] = elapsed;
      }

      final systemPrompt = _openAIService.buildSystemPrompt(
        currentPrompt: _currentLearningPrompt,
        userName: _userName,
        practiceMode: _currentPracticeMode,
        context: context,
        practiceTargetText: _currentPracticePhrase,
      );

      // LAYER 2 & 3: OpenAI function calling + response detection
      // Enable functions for ALL practice modes
      final enableFunctions = _currentPracticeMode != null;

      final aiResult = await _openAIService.getOpenAIResponseWithFunctions(
        systemPrompt,
        _messages,
        userInput: userInput,
        enablePracticeFunctions: enableFunctions,
      );

      setState(() {
        _messages.removeWhere((msg) => msg.id == typingMessage.id);
      });

      // Check if AI called exit_practice_mode function
      bool aiDetectedExit = false;
      String aiResponse = '';

      if (aiResult['type'] == 'function_call' &&
          aiResult['function_name'] == 'exit_practice_mode') {
        logger.i(
          'Layer 2: AI function calling detected exit - ${aiResult['arguments']}',
        );
        aiDetectedExit = true;

        // Generate a response acknowledging the exit
        aiResponse = "Sure thing! What would you like to do now?";
      } else if (aiResult['type'] == 'message') {
        aiResponse = aiResult['message'] as String;
      }

      final botMessage = Message(
        id: 'bot-${DateTime.now().millisecondsSinceEpoch}',
        text: aiResponse,
        isUser: false,
        timestamp: DateTime.now().toIso8601String(),
      );

      setState(() {
        _messages.add(botMessage);
        _pruneMessages();
      });

      await _firebaseChatService.addMessageToSession(botMessage);
      _scrollToBottom();

      // Decide whether to exit practice mode
      bool shouldExit = hardcodedExit || aiDetectedExit;

      if (shouldExit) {
        // Exit ANY practice mode (not just pronunciation/fluency)
        setState(() {
          _currentPracticeMode = null;
          _currentLearningPrompt = null;
          _currentPracticePhrase = null;
          _isAwaitingPronunciationPractice = false;
          _showSuggestions = true;
        });
        logger.i('Exited practice mode');
      } else {
        // Continue practice mode - extract phrase and manage flags (for pronunciation/fluency)
        if (_currentPracticeMode == PromptCategory.pronunciation ||
            _currentPracticeMode == PromptCategory.fluency) {
          final extractedPhrase = _openAIService.extractPracticePhrase(
            aiResponse,
            _currentPracticeMode,
          );

          if (extractedPhrase != null) {
            // New phrase found
            setState(() {
              _currentPracticePhrase = extractedPhrase;
              _isAwaitingPronunciationPractice = true;
            });
            logger.i('New practice phrase extracted: $extractedPhrase');
          } else if (_currentPracticePhrase != null) {
            // LAYER 3: No new phrase extracted - check if AI is asking something
            final askingPatterns = [
              'what would you like',
              'would you like to',
              'want to try',
              'prefer to',
              'which one',
              'what else',
            ];

            final isAsking = askingPatterns.any(
              (pattern) => aiResponse.toLowerCase().contains(pattern),
            );

            if (isAsking) {
              logger.i(
                'Layer 3: AI asking question, likely wants to change - no new phrase',
              );
              setState(() {
                _isAwaitingPronunciationPractice = false;
              });
            } else {
              // Continue with existing phrase
              setState(() {
                _isAwaitingPronunciationPractice = true;
              });
              logger.i(
                'Continuing with existing phrase: $_currentPracticePhrase',
              );
            }
          } else {
            // No phrase at all
            setState(() {
              _isAwaitingPronunciationPractice = false;
            });
            logger.w('No practice phrase available');
          }
        }
        // For other practice modes (grammar, vocabulary, roleplay), just continue normally
        // They don't need special phrase extraction logic
      }

      _speakText(aiResponse);
    } catch (e) {
      logger.e('Error generating AI response: $e');
      setState(() {
        _messages.removeWhere((msg) => msg.id == typingMessage.id);
      });
      _addBotMessage("Sorry, I'm having trouble connecting. Please try again.");
    } finally {
      setState(() => _isProcessingTTS = false);
    }
  }

  void _addBotMessage(String text, {bool skipTTS = false}) {
    final botMessage = Message(
      id: 'bot-${DateTime.now().millisecondsSinceEpoch}',
      text: text,
      isUser: false,
      timestamp: DateTime.now().toIso8601String(),
    );

    setState(() {
      _messages.add(botMessage);
      _pruneMessages();
    });

    _firebaseChatService.addMessageToSession(botMessage);
    _scrollToBottom();
    _speakText(text, skipTTS: skipTTS);
  }

  Future<void> _speakText(String text, {bool skipTTS = false}) async {
    if (!mounted || text.trim().isEmpty || skipTTS) return;

    logger.i(
      '🔊 Starting TTS for text: "${text.substring(0, text.length > 50 ? 50 : text.length)}..."',
    );

    try {
      final cleanText = TextProcessing.cleanTextForTTS(text);
      if (cleanText.isNotEmpty) {
        logger.i('🎯 Calling TTS service with clean text: "$cleanText"');
        await _ttsService.speakText(cleanText);
        logger.i('✅ TTS completed successfully');
      }
    } catch (e) {
      logger.e('❌ TTS error details: ${e.toString()}');
      logger.e('❌ TTS error type: ${e.runtimeType}');

      // Show specific error based on the actual error message
      String userMessage = 'Error playing response audio';
      if (e.toString().contains('timeout')) {
        userMessage = 'Audio timeout - continuing without sound';
      } else if (e.toString().contains('authentication') ||
          e.toString().contains('401')) {
        userMessage = 'Audio service authentication issue';
      } else if (e.toString().contains('network') ||
          e.toString().contains('connection')) {
        userMessage = 'Network issue - audio unavailable';
      }

      _showSnackBar(userMessage);
    }
  }

  void _pruneMessages() {
    const maxMessages = 50;
    if (_messages.length > maxMessages) {
      setState(() {
        _messages.removeRange(0, _messages.length - maxMessages);
      });
      logger.i('Kept last $maxMessages messages.');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _showLearningFocusDialog() async {
    // Cancel role-play timer if active
    if (_rolePlayDurationMinutes != null) {
      _rolePlayTimer?.cancel();
      _rolePlayTimer = null;
    }

    setState(() {
      _showSuggestions = false;
      _rolePlayDurationMinutes = null;
      _rolePlayStartTime = null;
    });

    var result = await showDialog(
      context: context,
      builder: (BuildContext context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title with blue styling
              Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: Colors.blue.shade700,
                    size: 28,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Choose a Learning Focus',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),

              // General Dialog option with blue styling
              _buildFocusOption(
                context: context,
                title: "General Dialog Conversation",
                icon: Icons.chat_bubble_outline,
                onTap: () => Navigator.pop(context, 'General'),
              ),

              SizedBox(height: 12),
              Divider(color: Colors.blue.shade100),
              SizedBox(height: 12),

              // Category options with blue styling
              ...PromptCategory.values.map((category) {
                IconData icon;
                switch (category) {
                  case PromptCategory.vocabulary:
                    icon = Icons.book_outlined;
                    break;
                  case PromptCategory.pronunciation:
                    icon = Icons.mic_outlined;
                    break;
                  case PromptCategory.grammar:
                    icon = Icons.spellcheck;
                    break;
                  case PromptCategory.fluency:
                    icon = Icons.speed;
                    break;
                  case PromptCategory.rolePlay:
                    icon = Icons.people_outline;
                    break;
                }

                return Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: _buildFocusOption(
                    context: context,
                    title: Prompt.categoryToString(category),
                    icon: icon,
                    onTap: () => Navigator.pop(context, category),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );

    if (result is PromptCategory) {
      _showPromptsForCategoryDialog(result);
    } else if (result == "General") {
      // Add user message for General selection
      final userMessage = Message(
        id: 'user-${DateTime.now().millisecondsSinceEpoch}',
        text: "Let's have a general conversation.",
        isUser: true,
        timestamp: DateTime.now().toIso8601String(),
      );

      setState(() {
        _messages.add(userMessage);
        _pruneMessages();
        _currentLearningPrompt = null;
        _currentPracticeMode = null;
        _currentPracticePhrase = null;
        _showSuggestions = true;
      });

      await _firebaseChatService.addMessageToSession(userMessage);
      _scrollToBottom();

      _addBotMessage(
        "Okay, let's have a general chat. How can I help you today?",
      );
    } else if (result == null) {
      // User cancelled dialog
      setState(() {
        _currentLearningPrompt = null;
        _currentPracticeMode = null;
        _currentPracticePhrase = null;
        _showSuggestions = true;
      });
    }
  }

  Widget _buildFocusOption({
    required BuildContext context,
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade200, width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.blue.shade700, size: 22),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.blue.shade900,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.blue.shade400,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPromptsForCategoryDialog(PromptCategory category) async {
    if (category == PromptCategory.rolePlay) {
      final userMessage = Message(
        id: 'user-${DateTime.now().millisecondsSinceEpoch}',
        text: "Let's do a customer service role-play.",
        isUser: true,
        timestamp: DateTime.now().toIso8601String(),
      );

      setState(() {
        _messages.add(userMessage);
        _pruneMessages();
      });

      await _firebaseChatService.addMessageToSession(userMessage);
      _scrollToBottom();

      await _showRolePlaySetupDialog();
      return;
    }

    final categoryPrompts = englishLearningPrompts
        .where((p) => p.category == category)
        .toList();

    if (categoryPrompts.isEmpty) {
      _addBotMessage(
        "Sorry, no exercises for ${Prompt.categoryToString(category)}.",
      );
      setState(() {
        _currentLearningPrompt = null;
        _currentPracticeMode = null;
        _showSuggestions = true;
      });
      return;
    }

    Prompt? selectedPrompt = await showDialog<Prompt>(
      context: context,
      builder: (BuildContext context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Choose a ${Prompt.categoryToString(category)} Prompt',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
              SizedBox(height: 16),
              ...categoryPrompts.map((prompt) {
                return Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => Navigator.pop(context, prompt),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.blue.shade200,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        prompt.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );

    if (!mounted) return;

    if (selectedPrompt != null) {
      final userMessage = Message(
        id: 'user-${DateTime.now().millisecondsSinceEpoch}',
        text: selectedPrompt.title,
        isUser: true,
        timestamp: DateTime.now().toIso8601String(),
      );

      setState(() {
        _messages.add(userMessage);
        _pruneMessages();
      });

      await _firebaseChatService.addMessageToSession(userMessage);
      _scrollToBottom();
    }

    setState(() {
      _currentLearningPrompt = selectedPrompt;
      _currentPracticeMode = category;
      _showSuggestions = false;
    });

    if (selectedPrompt != null) {
      if (selectedPrompt.category == PromptCategory.pronunciation) {
        _addBotMessage(
          "Let's practice your pronunciation! First, I'll suggest a phrase...",
        );
        final phrase = await _openAIService.generateCallCenterPhrase();
        setState(() => _currentPracticePhrase = phrase);
        _addBotMessage("Try saying: '$phrase'");
        setState(() => _isAwaitingPronunciationPractice = true);
      } else if (selectedPrompt.category == PromptCategory.fluency) {
        _addBotMessage(
          "Let's work on reading fluency! I'll give you a passage...",
        );
        final passage = await _openAIService.generateFluencyPassage();
        setState(() => _currentPracticePhrase = passage);
        _addBotMessage("Read this smoothly: '$passage'");
        setState(() => _isAwaitingPronunciationPractice = true);
      } else if (selectedPrompt.initialBotMessage != null) {
        _addBotMessage(selectedPrompt.initialBotMessage!);
      }
    }
  }

  Future<void> _showRolePlaySetupDialog() async {
    int? selectedDuration = await showDialog<int>(
      context: context,
      builder: (BuildContext context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    color: Colors.blue.shade700,
                    size: 28,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Role-Play Session',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Text(
                'How long would you like to practice?',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              SizedBox(height: 20),
              _buildDurationOption(context, '5 minutes', 5),
              SizedBox(height: 10),
              _buildDurationOption(context, '10 minutes', 10),
              SizedBox(height: 10),
              _buildDurationOption(context, '15 minutes', 15),
              SizedBox(height: 10),
              _buildDurationOption(context, '20 minutes', 20),
              SizedBox(height: 10),
              _buildDurationOption(context, '30 minutes', 30),
            ],
          ),
        ),
      ),
    );

    if (selectedDuration != null && mounted) {
      await _startRolePlaySession(selectedDuration);
    } else {
      setState(() => _showSuggestions = true);
    }
  }

  void _handleSuggestionClick(SuggestionChip suggestion) async {
    // Add user message to chat showing what they clicked
    final userMessage = Message(
      id: 'user-${DateTime.now().millisecondsSinceEpoch}',
      text: suggestion.prompt,
      isUser: true,
      timestamp: DateTime.now().toIso8601String(),
    );

    setState(() {
      _messages.add(userMessage);
      _pruneMessages();
    });

    await _firebaseChatService.addMessageToSession(userMessage);
    _scrollToBottom();

    // Special handling for Role-Play suggestions
    if (suggestion.mode == PromptCategory.rolePlay) {
      await _showRolePlaySetupDialog();
      return;
    }

    // Original logic for other suggestions
    setState(() {
      _currentPracticeMode = suggestion.mode;
      _currentPracticePhrase = null;
      _showSuggestions = false;
    });

    // Find matching prompt
    final matchingPrompt = englishLearningPrompts.firstWhere(
      (p) => p.category == suggestion.mode,
      orElse: () => englishLearningPrompts.first,
    );

    setState(() => _currentLearningPrompt = matchingPrompt);

    // Generate AI response for the suggestion
    _generateAIResponse(
      suggestion.prompt,
      context: {'practiceModeChange': suggestion.mode},
    );
  }

  Future<void> _triggerTutorial(BuildContext context) async {
    if (!mounted) return;

    bool shouldShow = await TutorialService.shouldShowTutorial(
      Future.value(_hasSeenTutorial),
    );
    if (!shouldShow || _hasTriggeredTutorial) return;

    setState(() => _hasTriggeredTutorial = true);

    bool? startTour = await TutorialService.showTutorialWithSkipOption(
      context: context,
      showcaseKeys: [_chatAreaKey, _micKey, _keyboardKey, _promptIconKey],
      skipText: 'Skip Tutorial',
      onComplete: () {
        if (mounted) {
          setState(() => _hasSeenTutorial = true);
          _firebaseChatService.saveTutorialStatus(true);
        }
      },
      title: 'Welcome to TalkReady Bot!',
      content:
          'Get ready to explore the app with a quick tour! Would you like to start?',
      confirmText: 'Start Tour',
      showDontAskAgain: false,
    );

    if (!mounted || !context.mounted) return;

    if (startTour == true) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted && context.mounted) {
        TutorialService.startShowCase(context, [
          _chatAreaKey,
          _micKey,
          _keyboardKey,
          _promptIconKey,
        ]);
      }
    } else {
      if (mounted) {
        setState(() => _hasSeenTutorial = true);
        _firebaseChatService.saveTutorialStatus(true);
      }
    }
  }

  void _stopAudio() async {
    try {
      await _audioService.stopAllAudio();
      if (mounted) {
        // Add this check
        setState(() {
          _isProcessingTTS = false;
          _isPlayingUserAudio = false;
        });
      }
    } catch (e) {
      logger.e('Error stopping audio: $e');
    }
  }

  void _showSnackBar(String message) {
    if (mounted && ScaffoldMessenger.maybeOf(context) != null) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: Duration(seconds: 3)),
      );
    }
  }

  Widget _buildRolePlayTimer() {
    if (_rolePlayStartTime == null || _rolePlayDurationMinutes == null) {
      return SizedBox.shrink();
    }

    final elapsed = DateTime.now().difference(_rolePlayStartTime!);
    final remaining = Duration(minutes: _rolePlayDurationMinutes!) - elapsed;

    if (remaining.isNegative) {
      return SizedBox.shrink();
    }

    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      margin: EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 4),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer, size: 16, color: Colors.blue.shade700),
          SizedBox(width: 6),
          Text(
            'Time left: ${minutes}m ${seconds.toString().padLeft(2, '0')}s',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.blue.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationOption(BuildContext context, String label, int minutes) {
    return InkWell(
      onTap: () => Navigator.pop(context, minutes),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade200, width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.timer_outlined,
                color: Colors.blue.shade700,
                size: 22,
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.blue.shade900,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.blue.shade400,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _stopAudio();
    _rolePlayTimer?.cancel(); // Add this line
    _audioService.dispose();
    _textController.dispose();
    _scrollController.dispose();
    logger.i('AIBotScreen disposed.');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShowCaseWidget(
      onFinish: () {
        TutorialService.handleTutorialCompletion();
        setState(() => _hasSeenTutorial = true);
        _firebaseChatService.saveTutorialStatus(true);
      },
      autoPlay: false,
      builder: (BuildContext showcaseContext) {
        if (!_hasSeenTutorial && !_hasTriggeredTutorial) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _triggerTutorial(showcaseContext);
          });
        }

        return PopScope(
          canPop: true,
          onPopInvoked: (didPop) async {
            if (!didPop) {
              _stopAudio();
              widget.onBackPressed?.call();
            }
          },
          child: Scaffold(
            appBar: AppBar(
              title: const Text(
                'TalkReady Bot',
                style: TextStyle(
                  color: Color.fromARGB(255, 41, 115, 178),
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              backgroundColor: Colors.white,
              elevation: 1.0,
              actions: [
                TutorialService.buildShowcase(
                  context: showcaseContext,
                  key: _promptIconKey,
                  title: 'Learning Focus',
                  description:
                      'Choose a focus like vocabulary or pronunciation.',
                  targetShapeBorder: CircleBorder(),
                  child: IconButton(
                    icon: Icon(Icons.lightbulb_outline),
                    onPressed: _showLearningFocusDialog,
                    tooltip: 'Choose Learning Focus',
                    color: Color.fromARGB(255, 41, 115, 178),
                  ),
                ),
                if (_isProcessingTTS)
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color.fromARGB(255, 41, 115, 178),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            body: Column(
              children: [
                // Disclaimer notice
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.grey[100],
                  child: Text(
                    'Note: The chatbot isn\'t always accurate and may sometimes reply incorrectly.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                _buildRolePlayTimer(),
                if (_rolePlayDurationMinutes != null &&
                    _rolePlayStartTime != null)
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: TextButton.icon(
                      onPressed: _endRolePlaySessionEarly,
                      icon: Icon(Icons.exit_to_app, size: 18),
                      label: Text('End Role-Play Session'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        backgroundColor: Colors.red.shade50,
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: Colors.red.shade200),
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: TutorialService.buildShowcase(
                    context: showcaseContext,
                    key: _chatAreaKey,
                    title: 'Chat Area',
                    description:
                        'Your conversation with TalkReady Bot happens here.',
                    child: Container(
                      padding: EdgeInsets.all(16),
                      color: Colors.grey[50],
                      child: ListView.builder(
                        controller: _scrollController,
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          return ChatMessage(
                            message: message,
                            userProfileImage: _userProfileImage,
                            onPlayAudio: message.audioPath != null
                                ? () => _playUserAudio(message.audioPath)
                                : null,
                            isPlaying: _isPlayingUserAudio,
                          );
                        },
                      ),
                    ),
                  ),
                ),
                if (_showSuggestions &&
                    !_isTyping &&
                    _messages.length >= 1 &&
                    _currentPracticeMode == null)
                  SuggestionChipsDisplay(onChipClick: _handleSuggestionClick),
                if (_isListening)
                  Padding(
                    padding: EdgeInsets.only(top: 8.0, bottom: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.0,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.blue,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Listening...',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.blue.shade700,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_isTyping)
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            decoration: InputDecoration(
                              hintText: 'Type your message...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(25),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade400,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(25),
                                borderSide: BorderSide(
                                  color: Theme.of(context).primaryColor,
                                  width: 2,
                                ),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            onSubmitted: (_) => _submitTypedText(),
                            textInputAction: TextInputAction.send,
                          ),
                        ),
                        SizedBox(width: 8),
                        IconButton(
                          icon: Icon(
                            Icons.send,
                            color: Theme.of(context).primaryColor,
                          ),
                          onPressed: _submitTypedText,
                          tooltip: 'Send Message',
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom + 20,
                    top: 10,
                    left: 20,
                    right: 20,
                  ),
                  child: IconRow(
                    onMicTap: () =>
                        _isListening ? _stopListening() : _startListening(),
                    onKeyboardTap: _toggleTyping,
                    isListening: _isListening,
                    isTyping: _isTyping,
                    micKey: _micKey,
                    keyboardKey: _keyboardKey,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
