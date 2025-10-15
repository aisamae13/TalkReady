import 'dart:io';
import '../../config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:showcaseview/showcaseview.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import '../models/message.dart';
import '../services/audio_service.dart';
import '../services/transcription_service.dart';
import '../services/tts_service.dart';
import '../services/openai_service.dart';
import '../services/firebase_chat_service.dart';
import '../widgets/chat_message.dart';
import '../widgets/icon_row.dart';
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

  // User data
  String? _userName;
  ImageProvider? _userProfileImage;

  // Controllers and keys
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
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

        // Wake up backend (non-blocking)
        _ensureBackendAwake();
      }
    });
  }

  Future<void> _ensureBackendAwake() async {
    try {
      logger.i('Waking up backend...');
      final baseUrl = await ApiConfig.getApiBaseUrl();
      logger.i('Backend is ready at: $baseUrl');
    } catch (e) {
      logger.w('Backend wake-up check: $e (this is normal for cold starts)');
    }
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
        logger.e('Error processing audio: $e');

        String errorMessage = 'Error processing audio';

        if (e.toString().contains('not authenticated')) {
          errorMessage = 'Please log in to use voice recording.';
        } else if (e.toString().contains('too large')) {
          errorMessage =
              'Recording is too large. Please try a shorter message.';
        } else if (e.toString().contains('Failed to upload')) {
          errorMessage =
              'Upload failed. Please check your internet connection.';
        } else if (e.toString().contains('Transcription')) {
          errorMessage = 'Could not transcribe audio. Please try again.';
        }

        _showSnackBar(errorMessage);
      }
    }
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

      final audioUrl = await _transcriptionService.uploadToFirebaseStorage(
        audioPath,
      );

      // Use Azure Speech-to-Text for transcription
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
        await _generateAIResponse(transcript);
      } else {
        _showSnackBar('Transcription failed.');
      }
    } catch (e) {
      logger.e('Error processing audio: $e');

      String errorMessage = 'Error processing audio';

      if (e.toString().contains('not authenticated')) {
        errorMessage = 'Please log in to use voice recording.';
      } else if (e.toString().contains('too large')) {
        errorMessage = 'Recording is too large. Please try a shorter message.';
      } else if (e.toString().contains('Failed to upload')) {
        errorMessage = 'Upload failed. Please check your internet connection.';
      } else if (e.toString().contains('Audio download timed out')) {
        errorMessage = 'Audio download timed out. Please try again.';
      } else if (e.toString().contains('Transcription request timed out')) {
        errorMessage = 'Transcription timed out. Please try again.';
      } else if (e.toString().contains('Azure Speech API key')) {
        errorMessage = 'Speech service not configured. Please contact support.';
      } else if (e.toString().contains('Azure transcription failed')) {
        errorMessage =
            'Could not transcribe audio. Please speak clearly and try again.';
      }

      _showSnackBar(errorMessage);
    }
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

  Future<void> _generateAIResponse(String userInput) async {
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
      final systemPrompt = _openAIService.buildSystemPrompt(
        currentPrompt: null,
        userName: _userName,
        practiceMode: null,
        context: null,
        practiceTargetText: null,
      );

      final aiResult = await _openAIService.getOpenAIResponseWithFunctions(
        systemPrompt,
        _messages,
        userInput: userInput,
        enablePracticeFunctions: false,
      );

      setState(() {
        _messages.removeWhere((msg) => msg.id == typingMessage.id);
      });

      final aiResponse = aiResult['message'] as String;

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
      _speakText(aiResponse);
    } catch (e) {
      logger.e('Error generating AI response: $e');
      setState(() {
        _messages.removeWhere((msg) => msg.id == typingMessage.id);
      });

      // User-friendly error messages based on your API config
      String errorMessage = "Sorry, I'm having trouble responding.";

      if (e.toString().contains('starting up') ||
          e.toString().contains('cold start')) {
        errorMessage =
            "The server is waking up. Please wait 15-30 seconds and try again.";
      } else if (e.toString().contains('timed out')) {
        errorMessage = "The response took too long. Please try again.";
      } else if (e.toString().contains('Network connection failed')) {
        errorMessage = "Network issue. Please check your internet connection.";
      } else if (e.toString().contains('503') || e.toString().contains('502')) {
        errorMessage =
            "Server is starting. Please wait a moment and try again.";
      } else if (e.toString().contains('rate limit')) {
        errorMessage = "Too many requests. Please wait a moment.";
      } else if (e.toString().contains('Backend error:')) {
        // Extract the actual error message
        final match = RegExp(r'Backend error: (.+)').firstMatch(e.toString());
        errorMessage = match?.group(1) ?? "Server error. Please try again.";
      }

      _addBotMessage(errorMessage);
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

  Future<void> _triggerTutorial(BuildContext context) async {
    if (!mounted) return;

    bool shouldShow = await TutorialService.shouldShowTutorial(
      Future.value(_hasSeenTutorial),
    );
    if (!shouldShow || _hasTriggeredTutorial) return;

    setState(() => _hasTriggeredTutorial = true);

    bool? startTour = await TutorialService.showTutorialWithSkipOption(
      context: context,
      showcaseKeys: [_chatAreaKey, _micKey, _keyboardKey],
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

  @override
  void dispose() {
    _stopAudio();
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
