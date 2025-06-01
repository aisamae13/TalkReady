import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logger/logger.dart';
import 'dart:math';
import 'package:showcaseview/showcaseview.dart';
import 'package:intl/intl.dart';
import 'tutorial_service.dart';

enum PromptCategory { vocabulary, pronunciation, grammar }

class Prompt {
  final String title;
  final String promptText;
  final PromptCategory category;
  final String? initialBotMessage;

  Prompt({
    required this.title,
    required this.promptText,
    required this.category,
    this.initialBotMessage,
  });
}

final List<Prompt> _englishLearningPrompts = [
  Prompt(
    title: "Expand My Vocabulary",
    promptText:
        "You are a vocabulary coach. The user wants to expand their vocabulary. When they provide a topic or a word, suggest related new words, explain them, and use them in example sentences. Encourage the user to try using the new words.",
    category: PromptCategory.vocabulary,
    initialBotMessage:
        "Okay, let's work on vocabulary! Tell me a topic you're interested in, or a word you'd like to explore.",
  ),
  Prompt(
    title: "Word Meanings & Usage",
    promptText:
        "You are an English language expert. The user will ask about specific words. Explain their meaning, provide synonyms/antonyms if relevant, and show examples of how to use them in sentences.",
    category: PromptCategory.vocabulary,
    initialBotMessage:
        "I can help with word meanings and usage. Which word are you curious about?",
  ),
  Prompt(
    title: "Call-Center Pronunciation Practice",
    promptText:
        "You are a pronunciation coach for call-center English. Generate a unique, professional call-center phrase (e.g., 'Thank you for calling, how may I assist you?') for the user to practice. Ask them to say it aloud and type it. The typed text and audio will be analyzed using Azure's pronunciation assessment for feedback on fluency and accuracy, provided in a conversational paragraph with percentage scores. Suggest a new call-center phrase after feedback.",
    category: PromptCategory.pronunciation,
    initialBotMessage:
        "Let’s practice call-center phrases! I’ll suggest one soon—please wait a sec!",
  ),
  Prompt(
    title: "Phonetic Feedback (Simulated)",
    promptText:
        "You are a pronunciation expert. The user will provide text they have spoken (or typed). Analyze it for potential pronunciation challenges based on common English learner patterns (e.g., confusing 'l' and 'r', 'th' sounds, vowel sounds). Offer gentle, actionable advice. If the input is text, you cannot hear them, so base your feedback on the text provided and common issues. If audio was provided, more specific feedback can be given.",
    category: PromptCategory.pronunciation,
    initialBotMessage:
        "I'll do my best to give feedback on your pronunciation. What would you like to say or type?",
  ),
  Prompt(
    title: "Grammar Check & Correction",
    promptText:
        "You are a grammar expert. The user will provide sentences, and you should check them for grammatical errors. Explain any mistakes clearly and provide corrected versions. Be encouraging.",
    category: PromptCategory.grammar,
    initialBotMessage:
        "Let's work on grammar! Type a sentence, and I'll help you check it.",
  ),
  Prompt(
    title: "Explain Grammar Concepts",
    promptText:
        "You are an English grammar teacher. The user will ask questions about grammar rules or concepts (e.g., tenses, prepositions, articles). Explain these concepts in a simple and understandable way, providing examples.",
    category: PromptCategory.grammar,
    initialBotMessage:
        "Do you have any grammar questions? I can help explain concepts like tenses, prepositions, and more.",
  ),
];

class AIBotScreen extends StatefulWidget {
  final VoidCallback? onBackPressed;

  const AIBotScreen({super.key, this.onBackPressed});

  @override
  State<AIBotScreen> createState() => _AIBotScreenState();
}

final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 2,
    errorMethodCount: 8,
    lineLength: 120,
    colors: true,
    printEmojis: true,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
);

class _AIBotScreenState extends State<AIBotScreen> {
  final ap.AudioPlayer _audioPlayer = ap.AudioPlayer();
  late FlutterSoundPlayer _player;
  late FlutterSoundRecorder _recorder;
  bool _isListening = false;
  bool _isProcessingTTS = false;
  String _lastRecognizedText = '';
  String? _audioFilePath;
  String? _userProfilePictureBase64;
  ImageProvider? _userProfileImage;
  final List<Map<String, dynamic>> _messages = [];
  bool _hasStartedListening = false;
  bool _isTyping = false;
  bool _hasSeenTutorial = false;
  bool _isRecorderInitialized = false;
  bool _isPlayerInitialized = false;
  final TextEditingController _textController = TextEditingController();
  final Random _random = Random();
  String? _userName;
  bool _hasTriggeredTutorial = false;
  final GlobalKey _promptIconKey = GlobalKey();
  final GlobalKey _chatAreaKey = GlobalKey();
  final GlobalKey _micKey = GlobalKey();
  final GlobalKey _keyboardKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  Prompt? _currentLearningPrompt;
  String? _currentChatSessionId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _currentPracticePhrase; // Tracks the current call-center phrase
  bool _isPlayingUserAudio = false; // Tracks if user audio is playing

  @override
  Widget build(BuildContext context) {
    return buildMainScreen(context); // This renders your actual UI
  }

  @override
  void initState() {
    super.initState();
    _recorder = FlutterSoundRecorder();
    _player = FlutterSoundPlayer();
    _fetchOnboardingData().then((_) {
      _initRecorder();
      _initPlayer();
      _requestPermissions();
      if (!dotenv.isInitialized) {
        logger.w('.env file not loaded. API keys might be missing.');
      } else {
        logger.i('.env file loaded. API keys should be available.');
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          String greetingMessage;
          try {
            greetingMessage = _generateRandomGreeting();
          } catch (e) {
            logger.e('Error generating personalized greeting: $e. Using fallback.');
            greetingMessage = "Hello${_userName != null && _userName!.isNotEmpty ? ", $_userName" : ""}! How can I help you practice today?";
            _showSnackBar('Could not display a personalized greeting at this time.');
          }
          final initialBotMessageData = {
            'text': greetingMessage,
            'isUser': false,
            'timestamp': DateTime.now().toIso8601String(),
          };
          setState(() {
            _messages.add(initialBotMessageData);
            _pruneMessages();
          });
          _speakText(greetingMessage, isUser: false);
          _scrollToBottom();
          _initializeNewChatSession(initialBotMessageData);
          if (_currentLearningPrompt?.title == "Call-Center Pronunciation Practice") {
            _generateCallCenterPhrase().then((phrase) {
              if (mounted) {
                setState(() => _currentPracticePhrase = phrase);
                _addBotMessage("Let’s practice call-center phrases! Try saying this clearly: '$phrase' Speak it, then type what you said.");
              }
            });
          }
        }
      });
    });
  }

  Future<void> _initializeNewChatSession(Map<String, dynamic> initialLocalMessage) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      logger.e("Cannot initialize chat session: user not logged in.");
      _showSnackBar("Error: You're not logged in. Cannot save chat session.");
      return;
    }
    try {
      Map<String, dynamic> firestoreInitialMessage = {
        'text': initialLocalMessage['text'],
        'sender': 'bot',
        'timestamp': Timestamp.fromDate(DateTime.parse(initialLocalMessage['timestamp'])),
        'audioUrl': null,
      };
      DocumentReference sessionRef = _firestore.collection('chatSessions').doc();
      _currentChatSessionId = sessionRef.id;
      await sessionRef.set({
        'userId': user.uid,
        'startTime': FieldValue.serverTimestamp(),
        'lastActivity': FieldValue.serverTimestamp(),
        'messages': [firestoreInitialMessage],
      });
      logger.i('New chat session created with ID: $_currentChatSessionId and initial message.');
    } catch (e) {
      logger.e('Error initializing new chat session: $e');
      _showSnackBar('Could not start a new chat session: $e');
    }
  }

  Future<void> _addMessageToActiveChatSession(Map<String, dynamic> localMessage, {String? audioUrl}) async {
    if (_currentChatSessionId == null) {
      logger.w('No active chat session ID. Cannot save message to Firestore.');
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      logger.e("Cannot add message to session: user not logged in.");
      return;
    }
    try {
      final firestoreMessage = {
        'text': localMessage['text'],
        'sender': localMessage['isUser'] ? 'user' : 'bot',
        'timestamp': Timestamp.fromDate(DateTime.parse(localMessage['timestamp'])),
        'audioUrl': localMessage['isUser'] ? audioUrl : null,
      };
      Map<String, dynamic> updateData = {
        'messages': FieldValue.arrayUnion([firestoreMessage]),
        'lastActivity': FieldValue.serverTimestamp(),
      };
      await _firestore.collection('chatSessions').doc(_currentChatSessionId).update(updateData);
      logger.i('Message added to chat session: $_currentChatSessionId');
    } catch (e) {
      logger.e('Error adding message to chat session $_currentChatSessionId: $e');
      _showSnackBar('Error saving message: $e');
    }
  }

  Future<void> _triggerTutorial(BuildContext context) async {
    if (!mounted) {
      logger.i('Tutorial not triggered: widget not mounted');
      return;
    }
    bool shouldShow = await TutorialService.shouldShowTutorial(Future.value(_hasSeenTutorial));
    if (!shouldShow) {
      logger.i('Tutorial skipped: user has already seen it');
      return;
    }
    if (_hasTriggeredTutorial) {
      logger.i('Tutorial already triggered in this session');
      return;
    }
    setState(() {
      _hasTriggeredTutorial = true;
    });
    logger.i('Showing welcome dialog for tutorial');
    bool? startTour = await TutorialService.showTutorialWithSkipOption(
      context: context,
      showcaseKeys: [_chatAreaKey, _micKey, _keyboardKey, _promptIconKey],
      skipText: 'Skip Tutorial',
      onComplete: () {
        if (mounted) {
          setState(() {
            _hasSeenTutorial = true;
          });
          _saveTutorialStatus();
        }
      },
      title: 'Welcome to TalkReady Bot!',
      content: 'Get ready to explore the app with a quick tour! Would you like to start?',
      confirmText: 'Start Tour',
      showDontAskAgain: false,
    );
    if (!mounted || !context.mounted) {
      logger.w('Cannot proceed with tutorial: widget or context not mounted');
      _showSnackBar('Cannot start tutorial at this time.');
      return;
    }
    if (startTour == true) {
      logger.i('User chose to start tutorial walkthrough');
      try {
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted && context.mounted) {
          TutorialService.startShowCase(context, [
            _chatAreaKey,
            _micKey,
            _keyboardKey,
            _promptIconKey,
          ]);
          logger.i('Showcase started successfully');
        } else {
          logger.w('Cannot start showcase: widget or context not mounted');
          _showSnackBar('Cannot start tutorial at this time.');
        }
      } catch (e) {
        logger.e('Error starting tutorial: $e');
        _showSnackBar('Failed to start tutorial: $e');
      }
    } else {
      logger.i('User skipped tutorial or dismissed dialog');
      if (mounted) {
        setState(() {
          _hasSeenTutorial = true;
        });
        _saveTutorialStatus();
        _showSnackBar('Tutorial skipped. You can access it later if needed.');
      }
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
      logger.e('userName is null or empty for greeting generation, this should have been handled by _fetchOnboardingData.');
      throw Exception('User name is missing. Please complete onboarding or contact support.');
    }
    final List<String> baseGreetings = [
      "$timePrefix, $_userName! How’s your day been? Spill something fun!",
      "$timePrefix, $_userName! What’s new with you today?",
      "$timePrefix, $_userName! Got any exciting plans?",
      "$timePrefix, $_userName! How’s your day going? Tell me a smashing story!",
      "$timePrefix, $_userName! What’s on your mind today?",
      "$timePrefix, $_userName! Fancy sharing a brilliant tale?",
      "$timePrefix, $_userName! What’s cooking, buddy?",
      "$timePrefix, $_userName! Got any yarns to spin?",
    ];
    String greeting = baseGreetings.isNotEmpty
        ? baseGreetings[_random.nextInt(baseGreetings.length)]
        : "$timePrefix, $_userName! Ready to practice your English?";
    logger.i('Generated greeting: $greeting');
    return greeting;
  }

  Future<void> _initPlayer() async {
    try {
      await _player.openPlayer();
      if (mounted) {
        setState(() {
          _isPlayerInitialized = true;
        });
      }
      logger.i('Player initialized successfully');
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPlayerInitialized = false;
        });
      }
      logger.e('Error initializing player: $e');
      _showSnackBar('Failed to initialize player');
    }
  }

  Future<void> _initRecorder() async {
    try {
      await _recorder.openRecorder();
      final tempDir = await getTemporaryDirectory();
      _audioFilePath = '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.wav';
      if (mounted) {
        setState(() => _isRecorderInitialized = true);
      }
      logger.i('Recorder initialized successfully');
    } catch (e) {
      if (mounted) setState(() => _isRecorderInitialized = false);
      logger.e('Error initializing recorder: $e');
      _showSnackBar('Error initializing recorder: $e');
    }
  }

  Future<void> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.microphone,
    ].request();
    if (statuses[Permission.microphone]!.isDenied ||
        statuses[Permission.microphone]!.isPermanentlyDenied) {
      logger.w('Microphone permission denied.');
      _showSnackBar('Microphone permission is required for voice input');
      if (statuses[Permission.microphone]!.isPermanentlyDenied && mounted) {
        _showPermissionDialog('Microphone', 'voice recording');
      }
    }
  }

  void _showPermissionDialog(String permissionName, String feature) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('$permissionName Permission Required'),
        content: Text(
          '$permissionName permission is permanently denied. Please enable it in your device settings to use $feature.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchOnboardingData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _userName = 'User';
      _userProfilePictureBase64 = null;
      _userProfileImage = null;
      _hasSeenTutorial = false;
      logger.w("User is null in _fetchOnboardingData, using defaults.");
      return;
    }
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      Map<String, dynamic>? userData = doc.data() as Map<String, dynamic>?;
      if (userData != null) {
        _userName = userData['firstName']?.toString();
        if ((_userName == null || _userName!.isEmpty) && userData.containsKey('onboarding')) {
          final onboardingMap = userData['onboarding'] as Map<String, dynamic>?;
          if (onboardingMap != null) {
            _userName = onboardingMap['firstName']?.toString() ?? onboardingMap['userName']?.toString();
          }
        }
        if (_userName == null || _userName!.isEmpty) {
          if (user.displayName != null && user.displayName!.isNotEmpty) {
            _userName = user.displayName!.split(' ').first;
            if (_userName!.isEmpty && user.displayName!.isNotEmpty) {
              _userName = user.displayName;
            }
          }
          if (_userName == null || _userName!.isEmpty) {
            _userName = 'User';
          }
          logger.w('Using fallback for userName: $_userName');
        }
        logger.i('Set userName to: $_userName');
        _userProfilePictureBase64 = userData['profilePicBase64']?.toString();
        if ((_userProfilePictureBase64 == null || _userProfilePictureBase64!.isEmpty) && userData.containsKey('onboarding')) {
          final onboardingMap = userData['onboarding'] as Map<String, dynamic>?;
          _userProfilePictureBase64 = onboardingMap?['profilePicBase64']?.toString();
        }
        if (_userProfilePictureBase64 != null && _userProfilePictureBase64!.isNotEmpty) {
          try {
            String tempBase64 = _userProfilePictureBase64!;
            if (tempBase64.startsWith('data:image')) {
              tempBase64 = tempBase64.split(',').last;
            }
            final bytes = base64Decode(tempBase64);
            _userProfileImage = MemoryImage(bytes);
            logger.i('Profile picture Base64 decoded, byte length: ${bytes.length}');
          } catch (e) {
            logger.e('Error decoding profilePicBase64: $e');
            _userProfileImage = null;
          }
        } else {
          logger.w('No profilePicBase64 found in user data');
          _userProfileImage = null;
        }
        _hasSeenTutorial = (userData['hasSeenTutorial'] as bool?) ?? false;
        logger.i('Loaded from Firestore: hasSeenTutorial=$_hasSeenTutorial');
      } else {
        logger.e('User data is null for user ${user.uid}. Using defaults.');
        if (user.displayName != null && user.displayName!.isNotEmpty) {
          _userName = user.displayName!.split(' ').first;
          if (_userName!.isEmpty && user.displayName!.isNotEmpty) {
            _userName = user.displayName;
          }
        }
        if (_userName == null || _userName!.isEmpty) {
          _userName = 'User';
        }
        _userProfileImage = null;
        _hasSeenTutorial = false;
        if (mounted) _showSnackBar('No user data found. Using defaults.');
      }
    } catch (e) {
      logger.e('Error fetching user data: $e. Using defaults.');
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        _userName = user.displayName!.split(' ').first;
        if (_userName!.isEmpty && user.displayName!.isNotEmpty) {
          _userName = user.displayName;
        }
      }
      if (_userName == null || _userName!.isEmpty) {
        _userName = 'User';
      }
      _userProfileImage = null;
      _hasSeenTutorial = false;
      if (mounted) _showSnackBar('Error fetching preferences: $e');
    } finally {
      if (mounted) setState(() {});
    }
  }

  Future<void> _startListening() async {
    if (!_isRecorderInitialized) {
      _showSnackBar('Cannot record audio. Recorder initialization failed.');
      return;
    }
    if (!_isListening && !_isTyping) {
      if (!_hasStartedListening) {
        setState(() {
          _hasStartedListening = true;
        });
      }
      try {
        if (_recorder.isRecording) {
          await _recorder.stopRecorder();
        }
        await _recorder.startRecorder(
          toFile: _audioFilePath!,
          codec: Codec.pcm16WAV,
          sampleRate: 16000,
        );
        setState(() => _isListening = true);
        logger.d('Recording started (path: $_audioFilePath, sampleRate: 16000 Hz)');
        _showSnackBar('Recording started. Speak now!');
      } catch (e) {
        logger.e('Error starting recording: $e');
        _showSnackBar('Error starting recording: $e');
        setState(() => _isListening = false);
      }
    } else {
      logger.w('Cannot start listening. Conditions not met (isListening: $_isListening, isTyping: $_isTyping).');
      if (_isTyping) _showSnackBar('Cannot start recording while typing.');
    }
  }

  Future<void> _stopListening() async {
    if (_isListening) {
      try {
        if (!_recorder.isRecording) {
          _showSnackBar('No active recording to stop.');
          setState(() => _isListening = false);
          return;
        }
        String? path = await _recorder.stopRecorder();
        setState(() {
          _isListening = false;
          _audioFilePath = path;
        });
        logger.d('Recording stopped, audio path: $path');
        _showSnackBar('Recording stopped.');
        if (_audioFilePath != null && await File(_audioFilePath!).exists()) {
          await _processAudioRecording();
        } else {
          logger.w('Audio file path is null or file does not exist after stopping recorder: $_audioFilePath');
          _showSnackBar('Could not find the recorded audio file.');
        }
      } catch (e) {
        logger.e('Error stopping recording: $e');
        _showSnackBar('Error stopping recording: $e');
        setState(() => _isListening = false);
      }
    }
  }

  Future<void> _playUserAudio() async {
    if (!_isPlayerInitialized || _audioFilePath == null) {
      _showSnackBar('Audio system not ready or no recording available.');
      return;
    }
    final file = File(_audioFilePath!);
    if (!await file.exists() || await file.length() == 0) {
      _showSnackBar('No valid recording to play.');
      return;
    }
    try {
      setState(() => _isPlayingUserAudio = true);
      await _audioPlayer.stop(); // Stop any ongoing playback
      await _audioPlayer.play(ap.DeviceFileSource(_audioFilePath!));
      _audioPlayer.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() => _isPlayingUserAudio = false);
        }
      });
      logger.i('Playing user recording: $_audioFilePath');
    } catch (e) {
      logger.e('Error playing user audio: $e');
      _showSnackBar('Error playing your recording: $e');
      setState(() => _isPlayingUserAudio = false);
    }
  }

  void _toggleTyping() {
    if (!_isListening) {
      setState(() {
        _isTyping = !_isTyping;
        logger.d('Toggled typing state to: $_isTyping');
        if (!_isTyping) {
          _textController.clear();
          logger.d('Cleared text input as typing was toggled off.');
        } else {
          if (!_hasStartedListening) {
            _hasStartedListening = true;
            logger.i('Session marked as started via typing.');
          }
        }
      });
    } else {
      _showSnackBar('Please stop listening before typing.');
      logger.w('Attempted to toggle typing while listening.');
    }
  }

  void _submitTypedText() {
    if (_textController.text.isNotEmpty) {
      String processedText = _processText(_textController.text);
      final userMessageData = {
        'text': processedText,
        'isUser': true,
        'timestamp': DateTime.now().toIso8601String(),
      };
      setState(() {
        _messages.add(userMessageData);
        _pruneMessages();
      });
      _addMessageToActiveChatSession(userMessageData);
      _scrollToBottom();
      _generateAIResponse(processedText);
      _textController.clear();
      setState(() => _isTyping = false);
    }
  }

 Future<String?> _transcribeWithAzure(String audioUrl) async {
  final apiKey = dotenv.env['AZURE_SPEECH_API_KEY'];
  final region = dotenv.env['AZURE_SPEECH_REGION'];
  if (apiKey == null || apiKey.isEmpty || region == null || region.isEmpty) {
    logger.e('Azure Speech API key or region missing.');
    _showSnackBar('Azure Speech API key or region missing. Cannot transcribe.');
    return null;
  }

  try {
    logger.i('Transcribing with Azure using audio URL: $audioUrl (Region: $region)');
    final audioResponse = await http.get(Uri.parse(audioUrl));
    if (audioResponse.statusCode != 200) {
      logger.e('Failed to download audio from Cloudinary: ${audioResponse.statusCode}');
      _showSnackBar('Failed to retrieve audio for transcription.');
      return null;
    }
    final audioBytes = audioResponse.bodyBytes;
    final endpoint = 'https://$region.stt.speech.microsoft.com/speech/recognition/conversation/cognitiveservices/v1';
    final queryParams = {
      'language': 'en-US',
      'format': 'detailed',
    };
    final uri = Uri.parse(endpoint).replace(queryParameters: queryParams);
    final headers = {
      'Ocp-Apim-Subscription-Key': apiKey,
      'Content-Type': 'audio/wav; codecs=audio/pcm; samplerate=16000',
      'Accept': 'application/json',
    };
    // Remove pronunciation assessment headers to get raw transcription
    final response = await http.post(
      uri,
      headers: headers,
      body: audioBytes,
    );
    logger.i('Azure STT response status: ${response.statusCode}, body: ${response.body}');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final transcript = data['DisplayText'] as String?;
      if (transcript == null || transcript.isEmpty) {
        logger.w('Azure STT returned empty or invalid transcript.');
        _showSnackBar('No transcription result from Azure.');
        return null;
      }
      logger.i('Azure STT successful: $transcript');
      return transcript;
    } else {
      logger.e('Azure STT failed: Status ${response.statusCode}, body: ${response.body}');
      _showSnackBar('Error transcribing with Azure: Status ${response.statusCode}');
      return null;
    }
  } catch (e) {
    logger.e('Error during Azure transcription: $e');
    _showSnackBar('Error transcribing with Azure: $e');
    return null;
  }
}

  Future<Map<String, String>> _generatePronunciationFeedback(String audioUrl, String recognizedText) async {
  final apiKey = dotenv.env['AZURE_SPEECH_API_KEY'] ?? '';
  final region = dotenv.env['AZURE_SPEECH_REGION'] ?? '';
  if (apiKey.isEmpty || region.isEmpty) {
    logger.e('Azure keys missing');
    return {
      'feedback': "Hi! I couldn't check your pronunciation due to a setup issue. Try again later!",
      'recognizedText': recognizedText,
    };
  }

  try {
    if (_currentPracticePhrase == null || _currentPracticePhrase!.isEmpty) {
      return {
        'feedback': "Oops! I don't have a phrase to check. Try saying 'Thank you for calling, how may I assist you?'",
        'recognizedText': recognizedText,
      };
    }

    final response = await http.post(
      Uri.parse('https://$region.stt.speech.microsoft.com/speech/recognition/conversation/cognitiveservices/v1?language=en-US'),
      headers: {
        'Ocp-Apim-Subscription-Key': apiKey,
        'Content-Type': 'audio/wav; codecs=audio/pcm; samplerate=16000',
        'Pronunciation-Assessment': base64Encode(utf8.encode(jsonEncode({
          'referenceText': _currentPracticePhrase,
          'gradingSystem': 'HundredMark',
          'granularity': 'Phoneme',
          'dimension': 'Comprehensive',
        }))),
      },
      body: (await http.get(Uri.parse(audioUrl))).bodyBytes,
    ).timeout(const Duration(seconds: 30));

    logger.i('Azure response: ${response.statusCode}, ${response.body}');

    if (response.statusCode != 200) {
      return {
        'feedback': "Oops! The pronunciation service is unavailable right now. Please try again later.",
        'recognizedText': recognizedText,
      };
    }

    final result = jsonDecode(response.body);
    if (result == null || result['RecognitionStatus'] != 'Success') {
      return {
        'feedback': "I couldn't understand that clearly. Please try saying it again!",
        'recognizedText': recognizedText,
      };
    }

    final nBest = result['NBest'] as List?;
    if (nBest == null || nBest.isEmpty) {
      logger.w('Azure NBest is null or empty: $result');
      return {
        'feedback': "Hmm, I couldn't analyze your pronunciation. Let's try again!",
        'recognizedText': recognizedText,
      };
    }

    final assessment = nBest.first;
    String feedback = "Here's your pronunciation analysis:\n\n";
    feedback += "🗣 You said: \"$recognizedText\"\n\n";
    feedback += "🎯 Target phrase: \"$_currentPracticePhrase\"\n\n";
    feedback += "📊 Scores:\n";
    feedback += "• Accuracy: ${assessment['AccuracyScore']?.toStringAsFixed(1) ?? 'N/A'}% (sounds correct)\n";
    feedback += "• Fluency: ${assessment['FluencyScore']?.toStringAsFixed(1) ?? 'N/A'}% (smoothness)\n";
    feedback += "• Completeness: ${assessment['CompletenessScore']?.toStringAsFixed(1) ?? 'N/A'}% (whole phrase)\n\n";

    final words = assessment['Words'] as List?;
    if (words != null && words.isNotEmpty) {
      feedback += "🔍 Detailed feedback:\n";
      for (var word in words.cast<Map>()) {
        final wordText = word['Word'] as String? ?? '';
        final errorType = word['ErrorType'] as String?;
        final score = (word['PronunciationAssessment']?['AccuracyScore'] as num?)?.toDouble() ?? 0.0;
        if (errorType != null && errorType != 'None') {
          feedback += "- \"$wordText\": ";
          if (errorType == 'Mispronunciation') {
            feedback += "Needs better pronunciation (${score.toStringAsFixed(1)}%)\n";
          } else if (errorType == 'Omission') {
            feedback += "Missing this word\n";
          } else if (errorType == 'Insertion') {
            feedback += "Extra word added\n";
          }
        }
      }
    }

    final accuracy = (assessment['AccuracyScore'] as num?)?.toDouble() ?? 0.0;
    final fluency = (assessment['FluencyScore'] as num?)?.toDouble() ?? 0.0;
    final completeness = (assessment['CompletenessScore'] as num?)?.toDouble() ?? 0.0;
    if (accuracy < 60 || fluency < 60 || completeness < 60) {
      feedback += "\nKeep practicing! Focus on each sound.\n";
    } else if (accuracy < 80 || fluency < 80 || completeness < 80) {
      feedback += "\nGood effort! A little more practice will help.\n";
    } else {
      feedback += "\nExcellent pronunciation!\n";
    }

    return {
      'feedback': feedback,
      'recognizedText': recognizedText,
    };
  } catch (e) {
    logger.e('Pronunciation analysis error: $e');
    return {
      'feedback': "Sorry, I couldn't analyze your pronunciation. Please try again!",
      'recognizedText': recognizedText,
    };
  }
}
  Future<void> _processAudioRecording() async {
  if (!_isPlayerInitialized || _audioFilePath == null) {
    _showSnackBar('Audio system not ready');
    return;
  }
  final file = File(_audioFilePath!);
  if (!await file.exists() || await file.length() == 0) {
    _showSnackBar('Invalid audio file');
    return;
  }

  try {
    _showSnackBar('Processing...');
    final audioUrl = await _uploadToCloudinary(_audioFilePath!);

    if (_currentLearningPrompt?.category == PromptCategory.pronunciation) {
      final transcript = await _transcribeWithAzure(audioUrl);
      if (transcript != null) {
        final userMessageData = {
          'text': transcript,
          'isUser': true,
          'timestamp': DateTime.now().toIso8601String(),
          'audioPath': _audioFilePath, // Store path for playback
        };
        setState(() {
          _messages.add(userMessageData);
          _pruneMessages();
        });
        _addMessageToActiveChatSession(userMessageData, audioUrl: audioUrl);
        _scrollToBottom();

        final feedback = await _generatePronunciationFeedback(audioUrl, transcript);
        _addBotMessage(feedback['feedback'] ?? '', skipTTS: true);

        final newPhrase = await _generateCallCenterPhrase();
        setState(() => _currentPracticePhrase = newPhrase);
        _addBotMessage("Would you like to practice another phrase? Try saying: '$newPhrase'");
      } else {
        _showSnackBar('Could not transcribe your speech.');
      }
    } else {
      final transcript = await _transcribeWithAssemblyAI(audioUrl);
      if (transcript != null) {
        final userMessageData = {
          'text': transcript,
          'isUser': true,
          'timestamp': DateTime.now().toIso8601String(),
          'audioPath': _audioFilePath, // Store path for playback
        };
        setState(() {
          _messages.add(userMessageData);
          _pruneMessages();
        });
        _addMessageToActiveChatSession(userMessageData, audioUrl: audioUrl);
        _scrollToBottom();
        await _generateAIResponse(transcript);
      } else {
        _showSnackBar('Transcription failed.');
      }
    }
  } catch (e) {
    _addBotMessage("Error processing audio: ${e.toString()}");
  }
}
  Future<String> _uploadToCloudinary(String filePath) async {
    final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
    final uploadPreset = dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '';
    if (cloudName.isEmpty || uploadPreset.isEmpty) {
      final errorMsg = 'Cloudinary credentials missing. Please check .env file.';
      logger.e(errorMsg);
      _showSnackBar(errorMsg);
      throw Exception('Cloudinary credentials not found in .env');
    }
    try {
      final url = 'https://api.cloudinary.com/v1_1/$cloudName/upload';
      final request = http.MultipartRequest('POST', Uri.parse(url));
      request.fields['upload_preset'] = uploadPreset;
      request.files.add(await http.MultipartFile.fromPath('file', filePath, filename: 'audio.wav'));
      logger.i('Uploading to Cloudinary: $filePath');
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      logger.i('Cloudinary response status: ${response.statusCode}, body: $responseBody');
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(responseBody);
        final secureUrl = data['secure_url'] as String?;
        if (secureUrl == null || secureUrl.isEmpty) {
          final errorMsg = 'Cloudinary upload returned invalid URL.';
          logger.e(errorMsg);
          _showSnackBar(errorMsg);
          throw Exception(errorMsg);
        }
        logger.i('Cloudinary upload successful: $secureUrl');
        return secureUrl;
      } else {
        final errorMsg = 'Cloudinary upload failed: Status ${response.statusCode}.';
        logger.e(errorMsg);
        _showSnackBar(errorMsg);
        throw Exception(errorMsg);
      }
    } catch (e) {
      final errorMsg = 'Cloudinary error: $e';
      logger.e(errorMsg);
      _showSnackBar(errorMsg);
      throw Exception(errorMsg);
    }
  }

  Future<String?> _transcribeWithAssemblyAI(String audioUrl) async {
    final apiKey = dotenv.env['ASSEMBLYAI_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      logger.e('AssemblyAI API key missing.');
      _showSnackBar('AssemblyAI API key missing.');
      return null;
    }
    logger.i('Attempting transcription with AssemblyAI for: $audioUrl');
    try {
      final submitResponse = await http.post(
        Uri.parse('https://api.assemblyai.com/v2/transcript'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'audio_url': audioUrl,
        }),
      );
      logger.i('status: ${submitResponse.statusCode}, body: ${submitResponse.body}');
      if (submitResponse.statusCode != 200) {
        logger.e('Submission error: ${submitResponse.body}');
        _showSnackBar('Failed to submit transcription: ${submitResponse.statusCode}');
        return null;
      }
      final submitData = jsonDecode(submitResponse.body);
      String transcriptId = submitData['id'];
      logger.i('Transcript ID: $transcriptId');
      int attempts = 0;
      const maxAttempts = 30;
      while (attempts < maxAttempts) {
        attempts++;
        await Future.delayed(Duration(seconds: 2));
        final pollResponse = await http.get(
          Uri.parse('https://api.assemblyai.com/v2/transcript/$transcriptId'),
          headers: {'Authorization': 'Bearer $apiKey'},
        );
        if (pollResponse.statusCode != 200) {
          logger.w('Poll error: ${pollResponse.statusCode}');
          if (attempts > 5 && pollResponse.statusCode >= 500) {
            _showSnackBar('AssemblyAI server error.');
            return null;
          }
          continue;
        }
        final pollData = jsonDecode(pollResponse.body);
        String status = pollData['status'];
        logger.i('Status: $status ($attempts/$maxAttempts)');
        if (status == 'completed') {
          logger.i('Transcription completed.');
          return pollData['text'] as String? ?? '';
        } else if (status == 'error') {
          logger.e('Error: ${pollData['error']}');
          _showSnackBar('Transcription error');
          return null;
        }
      }
      logger.w('Transcription timed out.');
      _showSnackBar('Transcription timed out.');
      return null;
    } catch (e) {
      logger.e('Error: $e');
      _showSnackBar('AssemblyAI error: $e');
      return null;
    }
  }

  Future<String> _generateCallCenterPhrase() async {
    final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    if (apiKey.isEmpty) throw Exception('OpenAI key missing');

    try {
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-4',
          'messages': [
            {
              'role': 'system',
              'content': '''
              Generate ONE concise call-center practice phrase (8-12 words) for English learners.
              Examples:
              - "How may I assist you today?"
              - "Could you hold for a moment please?"
              - "Let me transfer you to the right department."
              Return ONLY the phrase. No quotes or numbering.
            '''
            }
          ],
          'temperature': 0.7,
          'max_tokens': 30,
        }),
      );

      if (response.statusCode == 200) {
        final phrase = jsonDecode(response.body)['choices'][0]['message']['content']
            .trim()
            .replaceAll('"', '');
        logger.i('Generated phrase: $phrase');
        return phrase;
      } else {
        throw Exception('OpenAI error: ${response.statusCode}');
      }
    } catch (e) {
      logger.e('Phrase generation failed: $e');
      return "Could you please repeat that?";
    }
  }

  Future<String> _getOpenAIResponse(String prompt, {String? userInput}) async {
    final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      logger.e('OpenAI API key missing.');
      _showSnackBar('OpenAI API key missing.');
      return 'Sorry, I can’t respond right now.';
    }
    try {
      final messages = [
        {'role': 'system', 'content': prompt},
        ..._messages.reversed.take(5).map((msg) => ({
              'role': msg['isUser'] ? 'user' : 'assistant',
              'content': msg['text'].toString(),
            })).toList().reversed,
      ];
      if (userInput != null) {
        messages.add({'role': 'user', 'content': userInput});
      }
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': messages,
          'max_tokens': 200,
          'temperature': 0.7,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiResponse = data['choices'][0]['message']['content'] ?? 'How can I help you?';
        logger.i('OpenAI response: $aiResponse');
        return _cleanText(aiResponse);
      } else {
        logger.e('OpenAI failed: ${response.statusCode}, ${response.body}');
        return 'Oops, something went wrong!';
      }
    } catch (e) {
      logger.e('Error: $e');
      return 'Sorry, I’m having trouble connecting.';
    }
  }

  String _processText(String text) {
    String processedText = _cleanText(text.trim());
    if (processedText.isNotEmpty &&
        !processedText.endsWith('.') &&
        !processedText.endsWith('?') &&
        !processedText.endsWith('!')) {
      List<String> questionStarters = [
        'how', 'what', 'where', 'when', 'why', 'who', 'which',
        'are', 'is', 'can', 'do', 'does', 'did', 'will', 'would', 'should', 'could',
        'am', 'have', 'has', 'was', 'were',
      ];
      bool isQuestion = questionStarters.any((starter) => processedText.toLowerCase().startsWith('$starter ')) ||
          processedText.toLowerCase().contains(' or ');
      processedText += isQuestion ? '?' : '.';
    }
    return processedText;
  }

  String _cleanText(String text) {
    return text
        .replaceAll('â€™', "'")
        .replaceAll('â€œ', '"')
        .replaceAll('â€ ', '"')
        .replaceAll('â€“', '–')
        .replaceAll('â€”', '—')
        .trim();
  }

  Future<void> _generateAIResponse(String userInput) async {
    if (!mounted) return;
    setState(() => _isProcessingTTS = true);
    String prompt;
    if (_currentLearningPrompt != null) {
      prompt = _currentLearningPrompt!.promptText;
      logger.i("Using prompt: ${_currentLearningPrompt!.title}");
    } else {
      prompt = 'You are TalkReady, a friendly English-speaking assistant for call-center practice. Be encouraging. User: $_userName.';
      logger.i("Using general conversation prompt.");
    }
    String aiResponse = await _getOpenAIResponse(prompt, userInput: userInput);
    final aiMessageData = {
      'text': aiResponse,
      'isUser': false,
      'timestamp': DateTime.now().toIso8601String(),
    };
    setState(() {
      _messages.add(aiMessageData);
      _isTyping = false;
      _pruneMessages();
    });
    _addMessageToActiveChatSession(aiMessageData);
    _scrollToBottom();
    logger.i('AI message: $aiResponse');
    _speakText(aiResponse, isUser: false);
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

  Future<void> _speakText(String text, {required bool isUser, bool skipTTS = false}) async {
    if (!mounted || isUser || text.trim().isEmpty || skipTTS) {
      logger.w("Skip TTS: isUser=$isUser, emptyText=${text.trim().isEmpty}, skipTTS=$skipTTS, mounted=$mounted");
      setState(() => _isProcessingTTS = false);
      return;
    }
    final apiKey = dotenv.env['AZURE_SPEECH_API_KEY'];
    final region = dotenv.env['AZURE_SPEECH_REGION'];
    if (apiKey == null || region == null) {
      logger.e('Azure TTS missing: API Key: $apiKey, Region: $region');
      _showSnackBar('TTS config error.');
      setState(() => _isProcessingTTS = false);
      return;
    }
    setState(() => _isProcessingTTS = true);
    try {
      final endpoint = 'https://$region.tts.speech.microsoft.com/cognitiveservices/v1';
      final cleanText = text
          .replaceAll('&', '&amp;')
          .replaceAll('<', '&lt;')
          .replaceAll('>', '&gt;')
          .replaceAll('"', '&quot;')
          .replaceAll("'", '&apos;');
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Ocp-Apim-Subscription-Key': apiKey,
          'Content-Type': 'application/ssml+xml',
          'X-Microsoft-OutputFormat': 'audio-16khz-128kbitrate-mono-mp3',
          'User-Agent': 'TalkReady',
        },
        body: '''
<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="en-US">
  <voice name="en-US-JennyNeural">
    <prosody rate="0.9" pitch="+0%">
      <break time="100ms" />$cleanText<break time="100ms" />
    </prosody>
  </voice>
</speak>''',
      ).timeout(Duration(seconds: 30), onTimeout: () {
        logger.e('Azure TTS request timed out');
        throw Exception('TTS request timed out');
      });
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final audioPath = '${tempDir.path}/tts_output_${DateTime.now().millisecondsSinceEpoch}.mp3';
        final file = File(audioPath);
        await file.writeAsBytes(response.bodyBytes);
        await _audioPlayer.stop();
        await _audioPlayer.play(ap.DeviceFileSource(audioPath));
        _audioPlayer.onPlayerComplete.listen((_) {
          if (mounted) setState(() => _isProcessingTTS = false);
        });
        logger.i('Azure TTS played: $text');
      } else {
        logger.e('Azure TTS failed: ${response.statusCode}, Response: ${response.body}');
        _showSnackBar('Failed to play response audio.');
        setState(() => _isProcessingTTS = false);
      }
    } catch (e) {
      logger.e('TTS error: $e');
      _showSnackBar('Error playing response: $e');
      setState(() => _isProcessingTTS = false);
    }
  }

  Future<void> _saveProgress({bool showSnackBar = true}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        logger.i('No aggregated progress data to save.');
      } catch (e) {
        logger.e('Error in _saveProgress: $e');
        if (showSnackBar && mounted) {
          _showSnackBar('Error during cleanup: $e');
        }
      }
    }
  }

  Future<void> _saveTutorialStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      logger.w('Cannot save tutorial status: user not logged in.');
      return;
    }
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
            'hasSeenTutorial': _hasSeenTutorial,
          });
      logger.i('Tutorial status saved: hasSeenTutorial=$_hasSeenTutorial for user ${user.uid}');
    } catch (e) {
      logger.e('Error saving tutorial status: $e');
    }
  }

  void _showSnackBar(String message) {
    if (mounted && ScaffoldMessenger.maybeOf(context) != null) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: Duration(seconds: 3),
        ),
      );
    }
    logger.w("SnackBar not shown: $message");
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

  void _stopAudio() async {
    try {
      if (_audioPlayer.state == ap.PlayerState.playing) {
        await _audioPlayer.stop();
        logger.i('AudioPlayer stopped.');
      }
      if (_player.isPlaying) {
        await _player.stopPlayer();
        logger.i('FlutterSoundPlayer stopped.');
      }
      setState(() {
        _isProcessingTTS = false;
        _isPlayingUserAudio = false;
      });
    } catch (e) {
      logger.e('Error stopping audio: $e');
      _showSnackBar('Failed to stop audio: $e');
    }
  }

  String _categoryToString(PromptCategory category) {
    switch (category) {
      case PromptCategory.vocabulary:
        return "Vocabulary";
      case PromptCategory.pronunciation:
        return "Pronunciation";
      case PromptCategory.grammar:
        return "Grammar";
    }
  }

  void _addBotMessage(String text, {bool skipTTS = false}) {
    final botMessageData = {
      'text': text,
      'isUser': false,
      'timestamp': DateTime.now().toIso8601String(),
    };
    setState(() {
      _messages.add(botMessageData);
      _pruneMessages();
    });
    _addMessageToActiveChatSession(botMessageData);
    _scrollToBottom();
    logger.i('Bot message: $text');
    _speakText(text, isUser: false, skipTTS: skipTTS);
  }

  Future<void> _showLearningFocusDialog() async {
    List<Widget> dialogOptions = [];
    dialogOptions.add(
      SimpleDialogOption(
        onPressed: () {
          Navigator.pop(context, 'General');
        },
        child: Text("General Dialog Conversation"),
      ),
    );
    for (var category in PromptCategory.values) {
      dialogOptions.add(
        SimpleDialogOption(
          onPressed: () {
            Navigator.pop(context, category);
          },
          child: Text(_categoryToString(category)),
        ),
      );
    }
    var result = await showDialog(
      context: context,
      builder: (BuildContext context) => SimpleDialog(
        title: const Text('Choose a Learning Focus'),
        children: dialogOptions,
      ),
    );
    if (result is PromptCategory) {
      _showPromptsForCategoryDialog(result);
    } else if (result == "General" || result == null) {
      setState(() {
        _currentLearningPrompt = null;
      });
      _addBotMessage("Okay, let's have a general chat. How can I help you today?");
      logger.i('Switched to General Conversation.');
    }
  }

  Future<void> _showPromptsForCategoryDialog(PromptCategory category) async {
    final categoryPrompts = _englishLearningPrompts.where((p) => p.category == category).toList();
    if (categoryPrompts.isEmpty) {
      logger.w("No prompts for category: $category");
      _addBotMessage("Sorry, no exercises for ${_categoryToString(category)}.");
      setState(() => _currentLearningPrompt = null);
      return;
    }

    Prompt? selectedPrompt = await showDialog<Prompt>(
      context: context,
      builder: (BuildContext context) => SimpleDialog(
        title: Text('Choose a ${_categoryToString(category)} Prompt'),
        children: categoryPrompts
            .map((prompt) => SimpleDialogOption(
                  onPressed: () {
                    Navigator.pop(context, prompt);
                  },
                  child: Text(prompt.title),
                ))
            .toList(),
      ),
    );

    if (!mounted) return;

    setState(() {
      _currentLearningPrompt = selectedPrompt;
    });

    if (selectedPrompt != null) {
      if (selectedPrompt.category == PromptCategory.pronunciation) {
        _addBotMessage("Let's practice your pronunciation! First, I'll suggest a phrase...");
        final phrase = await _generateCallCenterPhrase();
        setState(() => _currentPracticePhrase = phrase);
        _addBotMessage("Try saying: '$phrase'");
      } else if (selectedPrompt.initialBotMessage != null) {
        _addBotMessage(selectedPrompt.initialBotMessage!);
      }
    }
  }

  @override
  void dispose() {
    _stopAudio();
    if (_recorder.isRecording) {
      _recorder.stopRecorder().catchError((e) {
        logger.e(e);
        return null;
      });
    }
    _recorder.closeRecorder();
    if (_player.isPlaying) {
      _player.stopPlayer();
    }
    _player.closePlayer();
    _textController.dispose();
    _audioPlayer.release();
    _audioPlayer.dispose();
    _scrollController.dispose();
    logger.i('AIBotScreen disposed.');
    super.dispose();
  }

  Widget buildMainScreen(BuildContext context) {
    return ShowCaseWidget(
      onFinish: () {
        TutorialService.handleTutorialCompletion();
        setState(() => _hasSeenTutorial = true);
        _saveTutorialStatus();
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
              _saveProgress(showSnackBar: false);
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
                  description: 'Choose a focus like vocabulary or pronunciation.',
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
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Color.fromARGB(255, 41, 115, 178)),
                      ),
                    ),
                  ),
              ],
            ),
            body: Column(
              children: [
                Expanded(
                  child: TutorialService.buildShowcase(
                    context: showcaseContext,
                    key: _chatAreaKey,
                    title: 'Chat Area',
                    description: 'Your conversation with TalkReady Bot happens here.',
                    child: Container(
                      padding: EdgeInsets.all(16),
                      color: Colors.grey[50],
                      child: ListView.builder(
                        controller: _scrollController,
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          return ChatMessage(
                            message: message['text'],
                            isUser: message['isUser'],
                            userProfileImage: _userProfileImage,
                            timestamp: message['timestamp'],
                            audioPath: message['audioPath'],
                            onPlayAudio: _playUserAudio,
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
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          _lastRecognizedText.isEmpty
                              ? 'Listening...'
                              : 'Heard "${_lastRecognizedText.substring(0, min(25, _lastRecognizedText.length))}${_lastRecognizedText.length > 25 ? '...' : ''}"',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.blue.shade700,
                            fontStyle: FontStyle.italic,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                if (_isTyping)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            decoration: InputDecoration(
                              hintText: 'Type your message...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(25),
                                borderSide: BorderSide(color: Colors.grey.shade400),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(25),
                                borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                              ),
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onSubmitted: (_) => _submitTypedText(),
                            textInputAction: TextInputAction.send,
                          ),
                        ),
                        SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.send, color: Theme.of(context).primaryColor),
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
                    onMicTap: () => _isListening ? _stopListening() : _startListening(),
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

class ChatMessage extends StatefulWidget {
  final String message;
  final bool isUser;
  final ImageProvider? userProfileImage;
  final String? timestamp;
  final String? audioPath;
  final VoidCallback onPlayAudio;
  final bool isPlaying;

  const ChatMessage({
    super.key,
    required this.message,
    required this.isUser,
    this.userProfileImage,
    this.timestamp,
    this.audioPath,
    required this.onPlayAudio,
    required this.isPlaying,
  });

  @override
  State<ChatMessage> createState() => _ChatMessageState();
}

class _ChatMessageState extends State<ChatMessage> {
  bool _showTimestamp = false;

  String _formatTimestamp(String? isoTimestamp) {
    if (isoTimestamp == null) return 'Unknown time';
    try {
      final dateTime = DateTime.parse(isoTimestamp).toLocal();
      if (DateTime.now().difference(dateTime).inDays == 0) {
        return DateFormat('h:mm a').format(dateTime);
      } else if (DateTime.now().difference(dateTime).inDays == 1) {
        return 'Yesterday, ${DateFormat('h:mm a').format(dateTime)}';
      } else {
        return DateFormat('MMM d, h:mm a').format(dateTime);
      }
    } catch (e) {
      logger.e('Error parsing timestamp: $e');
      return 'Invalid time';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () {
        if (widget.timestamp != null) {
          setState(() => _showTimestamp = !_showTimestamp);
        }
      },
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        child: Column(
          crossAxisAlignment: widget.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: widget.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!widget.isUser) ...[
                  CircleAvatar(
                    radius: 18,
                    backgroundImage: AssetImage('images/talkready_bot.png'),
                    backgroundColor: Colors.blueGrey[50],
                  ),
                  SizedBox(width: 10),
                ],
                Flexible(
                  child: Container(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    margin: EdgeInsets.only(
                      top: widget.isUser ? 2 : 4,
                      bottom: 2,
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: widget.isUser
                          ? theme.primaryColor.withOpacity(0.15)
                          : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                        bottomLeft: widget.isUser ? Radius.circular(16) : Radius.circular(4),
                        bottomRight: widget.isUser ? Radius.circular(4) : Radius.circular(16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 3,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.message,
                          style: TextStyle(fontSize: 15, color: Colors.black87),
                        ),
                        if (widget.isUser && widget.audioPath != null) ...[
                          SizedBox(height: 8),
                          IconButton(
                            icon: Icon(
                              widget.isPlaying ? Icons.stop : Icons.play_arrow,
                              color: theme.primaryColor,
                            ),
                            onPressed: widget.onPlayAudio,
                            tooltip: widget.isPlaying ? 'Stop playback' : 'Play your recording',
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (widget.isUser) ...[
                  SizedBox(width: 10),
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.grey.shade300,
                    backgroundImage: widget.userProfileImage,
                    child: widget.userProfileImage == null
                        ? Text(
                            widget.message.isNotEmpty ? widget.message[0].toUpperCase() : 'U',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                ],
              ],
            ),
            if (_showTimestamp && widget.timestamp != null)
              Padding(
                padding: EdgeInsets.only(
                  top: 4,
                  left: widget.isUser ? 0 : 58,
                  right: widget.isUser ? 58 : 0,
                ),
                child: Text(
                  _formatTimestamp(widget.timestamp),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class IconRow extends StatelessWidget {
  final VoidCallback onMicTap;
  final VoidCallback onKeyboardTap;
  final bool isListening;
  final bool isTyping;
  final GlobalKey micKey;
  final GlobalKey keyboardKey;

  const IconRow({
    super.key,
    required this.onMicTap,
    required this.onKeyboardTap,
    required this.isListening,
    required this.isTyping,
    required this.micKey,
    required this.keyboardKey,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        TutorialService.buildShowcase(
          context: context,
          key: keyboardKey,
          title: 'Keyboard Input',
          description: 'Type your message here.',
          targetShapeBorder: CircleBorder(),
          child: _buildIcon(
            Icons.keyboard_alt_outlined,
            isTyping ? theme.colorScheme.primary.withOpacity(0.5) : theme.colorScheme.secondary,
            onKeyboardTap,
            isActive: isTyping,
            tooltip: 'Type message',
          ),
        ),
        TutorialService.buildShowcase(
          context: context,
          key: micKey,
          title: 'Microphone',
          description: 'Record your voice here.',
          targetShapeBorder: CircleBorder(),
          child: _buildIcon(
            isListening ? Icons.stop_circle_outlined : Icons.mic_none_outlined,
            isListening ? Colors.red.shade400 : theme.primaryColor,
            onMicTap,
            isActive: isListening,
            tooltip: isListening ? 'Stop recording' : 'Start recording',
          ),
        ),
      ],
    );
  }

  Widget _buildIcon(IconData icon, Color color, VoidCallback onTap, {bool isActive = false, String? tooltip}) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: isActive ? color.withOpacity(0.8) : color.withOpacity(0.7),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isActive ? 0.2 : 0.1),
                spreadRadius: isActive ? 2 : 1,
                blurRadius: isActive ? 4 : 2,
                offset: Offset(0, isActive ? 2 : 1),
              ),
            ],
            border: isActive ? Border.all(color: Colors.white.withOpacity(0.7), width: 2) : null,
          ),
          child: Icon(icon, color: Colors.white, size: 30),
        ),
      ),
    );
  }
}