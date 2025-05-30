// ...existing code...
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart' as ap; // Added alias
import 'package:path_provider/path_provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
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

// Define PromptCategory and Prompt class
enum PromptCategory { vocabulary, pronunciation, grammar }

class Prompt {
  final String title;
  final String promptText; // This is the system message for OpenAI
  final PromptCategory category;
  final String? initialBotMessage; // Optional message for bot to say

  Prompt({
    required this.title,
    required this.promptText,
    required this.category,
    this.initialBotMessage,
  });
}

// Predefined learning prompts
final List<Prompt> _englishLearningPrompts = [
  // Vocabulary Prompts
  Prompt(
      title: "Expand My Vocabulary",
      promptText:
          "You are a vocabulary coach. The user wants to expand their vocabulary. When they provide a topic or a word, suggest related new words, explain them, and use them in example sentences. Encourage the user to try using the new words.",
      category: PromptCategory.vocabulary,
      initialBotMessage:
          "Okay, let's work on vocabulary! Tell me a topic you're interested in, or a word you'd like to explore."),
  Prompt(
      title: "Word Meanings & Usage",
      promptText:
          "You are an English language expert. The user will ask about specific words. Explain their meaning, provide synonyms/antonyms if relevant, and show examples of how to use them in sentences.",
      category: PromptCategory.vocabulary,
      initialBotMessage:
          "I can help with word meanings and usage. Which word are you curious about?"),

  // Pronunciation Prompts
  Prompt(
      title: "Pronunciation Practice",
      promptText:
          "You are a pronunciation coach. The user wants to practice their English pronunciation. Provide them with sentences, tongue twisters, or minimal pairs focusing on common difficult sounds for non-native speakers. Listen to their attempts (simulated, as you get text) and offer constructive feedback. Focus on clarity and intelligibility.",
      category: PromptCategory.pronunciation,
      initialBotMessage:
          "Let's practice pronunciation! Would you like to try some tricky sounds, a tongue twister, or minimal pairs?"),
  Prompt(
      title: "Phonetic Feedback (Simulated)",
      promptText:
          "You are a pronunciation expert. The user will provide text they have spoken. Analyze it for potential pronunciation challenges based on common English learner patterns (e.g., confusing 'l' and 'r', 'th' sounds, vowel sounds). Offer gentle, actionable advice. You cannot hear them, so base your feedback on the text provided and common issues.",
      category: PromptCategory.pronunciation,
      initialBotMessage:
          "I'll do my best to give feedback on your pronunciation based on the text you provide. What would you like to say?"),

  // Grammar Prompts
  Prompt(
      title: "Grammar Check & Correction",
      promptText:
          "You are a grammar expert. The user will provide sentences, and you should check them for grammatical errors. Explain any mistakes clearly and provide corrected versions. Be encouraging.",
      category: PromptCategory.grammar,
      initialBotMessage:
          "Let's work on grammar! Type a sentence, and I'll help you check it."),
  Prompt(
      title: "Explain Grammar Concepts",
      promptText:
          "You are an English grammar teacher. The user will ask questions about grammar rules or concepts (e.g., tenses, prepositions, articles). Explain these concepts in a simple and understandable way, providing examples.",
      category: PromptCategory.grammar,
      initialBotMessage:
          "Do you have any grammar questions? I can help explain concepts like tenses, prepositions, and more."),
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
  final FlutterTts _flutterTts = FlutterTts();
  final ap.AudioPlayer _audioPlayer = ap.AudioPlayer(); // Used alias for clarity
  late FlutterSoundPlayer _player;
  late FlutterSoundRecorder _recorder;
  bool _isListening = false;
  bool _isProcessingTTS = false;
  String _lastRecognizedText = '';
  String? _audioFilePath;
  String? _userProfilePictureBase64;
  ImageProvider? _userProfileImage;
  final List<Map<String, dynamic>> _messages = [];
  // String? _accentLocale; // Removed
  bool _hasStartedListening = false;
  bool _isTyping = false;
  final bool _hasTriggeredTutorial = false;
  bool _hasSeenTutorial = false;
  static const String _ttsServerUrl =
      'https://c360-175-176-32-217.ngrok-free.app/tts'; // Replace with your actual TTS server URL
  bool _isRecorderInitialized = false;
  bool _isPlayerInitialized = false;
  final TextEditingController _textController = TextEditingController();
  final Map<String, double> _sessionProgress = {
    'Fluency': 0.0,
    'Grammar': 0.0,
    'Pronunciation': 0.0,
    'Vocabulary': 0.0,
    'Interaction': 0.0,
  };
  int _responseCount = 0;
  final Random _random = Random();
  String? _userName;
  final GlobalKey _chatAreaKey = GlobalKey();
  final GlobalKey _micKey = GlobalKey();
  final GlobalKey _keyboardKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  Prompt? _currentLearningPrompt;

  String? _currentChatSessionId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _recorder = FlutterSoundRecorder();
    _player = FlutterSoundPlayer();
    _fetchOnboardingData().then((_) {
      _initRecorder();
      _initPlayer();
      _requestPermissions();
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
          
          logger.i(
              'Adding new session greeting to _messages: {"text": "$greetingMessage", "isUser": false, "timestamp": "${DateTime.now().toIso8601String()}"}');
          
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

      await _firestore.collection('chatSessions').doc(_currentChatSessionId).update({
        'messages': FieldValue.arrayUnion([firestoreMessage]),
        'lastActivity': FieldValue.serverTimestamp(),
      });
      logger.i('Message added to chat session: $_currentChatSessionId');
    } catch (e) {
      logger.e('Error adding message to chat session $_currentChatSessionId: $e');
      _showSnackBar('Error saving message: $e');
    }
  }

  Future<void> _triggerTutorial(BuildContext showcaseContext) async {
    if (!mounted) {
      logger.i('Tutorial not triggered: widget not mounted');
      return;
    }

    bool shouldShow =
        await TutorialService.shouldShowTutorial(Future.value(_hasSeenTutorial));
    if (!shouldShow) {
      logger.i('Tutorial skipped: user has already seen it');
      return;
    }

    logger.i('Showing welcome dialog for tutorial');
    bool? startTour = await TutorialService.showTutorialWithSkipOption(
      context: context,
      showcaseKeys: [_chatAreaKey, _micKey, _keyboardKey],
      skipText: 'Skip Tutorial',
      onComplete: () {
        setState(() {
          _hasSeenTutorial = true;
        });
        _saveTutorialStatus();
      },
      title: 'Welcome to TalkReady Bot!',
      content:
          'Get ready to explore the app with a quick tour! Would you like to start?',
      confirmText: 'Start Tour',
      showDontAskAgain: false,
    );

    if (!mounted || !showcaseContext.mounted) {
      logger.w('Cannot proceed with tutorial: widget or context not mounted');
      _showSnackBar('Cannot start tutorial at this time.');
      return;
    }

    if (startTour == false) { 
      logger.i('User chose to start tutorial walkthrough');
      try {
        await Future.delayed(const Duration(milliseconds: 600));
        logger.i('Dialog should be dismissed, starting showcase now');

        if (mounted && showcaseContext.mounted) {
          TutorialService.startShowCase(showcaseContext, [
            _chatAreaKey,
            _micKey,
            _keyboardKey,
          ]);
          logger.i('Showcase started successfully');
        } else {
          logger.w(
              'Cannot start showcase: widget not mounted or context unavailable');
          _showSnackBar('Cannot start tutorial at this time.');
        }
      } catch (e) {
        logger.e('Error starting tutorial: $e');
        _showSnackBar('Failed to start tutorial: $e');
      }
    } else { 
      logger.i('User skipped tutorial or dismissed dialog');
      setState(() {
        _hasSeenTutorial = true;
      });
      await _saveTutorialStatus();
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
      logger.e(
          'userName is null or empty for greeting generation, this should have been handled by _fetchOnboardingData.');
      throw Exception(
          'User name is missing. Please complete onboarding or contact support.');
    }
    final List<String> baseGreetings = [
        "$timePrefix, $_userName! How’s your day been? Spill something fun!",
        "$timePrefix, $_userName! What’s new with you today?",
        "$timePrefix, $_userName! Got any exciting plans?",
        "$timePrefix, $_userName! How’s your day going? Tell me a smashing story!",
        "$timePrefix, $_userName! What’s on your mind today?",
        "$timePrefix, $_userName! Fancy sharing a brilliant tale?",
        "$timePrefix, $_userName! How’s your day? Got any ripper tales?",
        "$timePrefix, $_userName! What’s cooking, mate?",
        "$timePrefix, $_userName! Got any yarns to spin?",
    ];
    String greeting = baseGreetings.isNotEmpty
        ? baseGreetings[_random.nextInt(baseGreetings.length)]
        : "$timePrefix, $_userName! Ready to practice your English?";
    logger.i('Generated greeting: "$greeting"');
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

  Future<void> _initializeTts() async {
    logger.i('Initializing TTS with locale: en_US');
    try {
      await _flutterTts.setLanguage('en_US'); // Default to en_US
      await _flutterTts.setPitch(0.7);
      await _flutterTts.setSpeechRate(0.6);
      logger.i('TTS initialized successfully');
    } catch (e) {
      logger.e('Error initializing TTS: $e');
      _showSnackBar('Failed to initialize text-to-speech');
    }
  }

  Future<void> _initRecorder() async {
    try {
      await _recorder.openRecorder();
      final tempDir = await getTemporaryDirectory();
      _audioFilePath = '${tempDir.path}/audio.wav';
      if (mounted) {
        setState(() {
          _isRecorderInitialized = true;
        });
      }
      logger.i('Recorder initialized successfully');
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRecorderInitialized = false;
        });
      }
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
      logger.w('Microphone permission denied');
      _showSnackBar('Microphone permission is required for voice input');
      if (statuses[Permission.microphone]!.isPermanentlyDenied && mounted) {
        _showPermissionDialog('Microphone', 'voice recording');
      }
    }
  }

  void _showPermissionDialog(String permissionName, String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$permissionName Permission Required'),
        content: Text(
          '$permissionName permission is permanently denied. Please enable it in your device settings to use $feature.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchOnboardingData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _userName = 'User';
      _userProfileImage = null;
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

        // Removed desiredAccent logic

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

        _sessionProgress.forEach((key, value) {
          _sessionProgress[key] = (userData['sessionProgress']?[key] as double?) ?? 0.0;
        });
        _responseCount = (userData['responseCount'] as int?) ?? 0;
        _hasSeenTutorial = (userData['hasSeenTutorial'] as bool?) ?? false;
        logger.i('Loaded progress: sessionProgress=$_sessionProgress, responseCount=$_responseCount, hasSeenTutorial=$_hasSeenTutorial');

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
      if (mounted) _showSnackBar('Error fetching preferences: $e. Using defaults.');
    } finally {
      if (mounted) {
        setState(() {}); 
      }
      _initializeTts(); 
    }
  }

  Future<void> _startListening() async {
// ...existing code...
    if (!_isRecorderInitialized) {
      _showSnackBar('Cannot record audio. Recorder initialization failed.');
      return;
    }

    if (!_isListening && !_isTyping) {
      if (!_hasStartedListening) {
        _hasStartedListening = true;
      }

      logger.d(
          'Starting to listen. IsListening: $_isListening, IsTyping: $_isTyping');

      try {
        if (_recorder.isRecording) {
          await _recorder.stopRecorder();
        }
        await _recorder.startRecorder(
          toFile: _audioFilePath!,
          codec: Codec.pcm16WAV,
        );
        if (mounted) {
          setState(() => _isListening = true);
        }
        logger.d('Recording started for AssemblyAI');
        _showSnackBar('Recording started. Speak now!');
      } catch (e) {
        logger.e('Error starting recording: $e');
        _showSnackBar('Error starting recording: $e');
        if (mounted) {
          setState(() => _isListening = false);
        }
      }
    } else {
      logger.w('Cannot start listening. Conditions not met.');
      _showSnackBar('Cannot start recording while typing.');
    }
  }

  Future<void> _stopListening() async {
// ...existing code...
    if (_isListening) {
      try {
        if (!_recorder.isRecording) {
          _showSnackBar('No active recording to stop.');
          if (mounted) {
            setState(() => _isListening = false);
          }
          return;
        }
        String? path = await _recorder.stopRecorder();
        if (mounted) {
          setState(() {
            _isListening = false;
            _audioFilePath = path;
          });
        }
        logger.d('Recording stopped, path: $_audioFilePath');
        _showSnackBar('Recording stopped.');

        if (_audioFilePath != null) {
          await _processAudioRecording();
        }
      } catch (e) {
        logger.e('Error stopping recording: $e');
        _showSnackBar('Error stopping recording: $e');
        if (mounted) {
          setState(() => _isListening = false);
        }
      }
    }
  }

  void _toggleTyping() {
// ...existing code...
    if (!_isListening) {
      if (mounted) {
        setState(() {
          logger.d('Toggling typing state to: $_isTyping');
          _isTyping = !_isTyping;
          if (!_isTyping) {
            _textController.clear();
            logger.d('Cleared text input');
          }
          if (!_hasStartedListening && _isTyping) {
            _hasStartedListening = true;
            logger.i('Started typing session');
          }
        });
      }
    } else {
      _showSnackBar('Please stop listening before typing.');
      logger.w('Attempted to toggle typing while listening');
    }
  }

  void _submitTypedText() {
// ...existing code...
    if (_textController.text.isNotEmpty) {
      String processedText = _processText(_textController.text);
      final userMessageData = {
        'text': processedText,
        'isUser': true,
        'timestamp': DateTime.now().toIso8601String(),
      };
      if (mounted) {
        setState(() {
          _messages.add(userMessageData);
          _pruneMessages(); 
        });
      }
      _addMessageToActiveChatSession(userMessageData); 
      _scrollToBottom();
      // _speakText(processedText, isUser: true); 
      _generateAIResponse(processedText);
      _evaluateUserInput(processedText);
      _textController.clear();
      if (mounted) {
        setState(() => _isTyping = false);
      }
    }
  }

  Future<void> _processAudioRecording() async {
// ...existing code...
    if (!_isPlayerInitialized) {
      _showSnackBar('Audio player is not ready. Please try again.');
      logger.w('Player not initialized, cannot process audio recording.');
      return;
    }

    if (_audioFilePath != null) {
      try {
        final file = File(_audioFilePath!);
        if (!await file.exists() || await file.length() == 0) {
          _showSnackBar('Audio file is missing or empty.');
          logger.w(
              'Audio file check failed: exists=${await file.exists()}, length=${await file.length()}');
          return;
        }

        _showSnackBar('Playing your voice...');
        logger.i('Playing recorded audio...');

        Completer<void> playbackCompleter = Completer<void>();

        if (_player.isPlaying) {
          await _player.stopPlayer();
          logger.i('Stopped previous playback before starting new one.');
        }

        await _player
            .startPlayer(
          fromURI: _audioFilePath!,
          codec: Codec.pcm16WAV,
          whenFinished: () {
            logger.i('Audio playback finished.');
            if (!playbackCompleter.isCompleted) {
              playbackCompleter.complete();
            }
          },
        )
            .catchError((error) {
          logger.e('Error playing audio: $error');
          _showSnackBar('Error playing your voice: $error');
          if (!playbackCompleter.isCompleted) {
            playbackCompleter.completeError(error);
          }
          return null;
        });

        await playbackCompleter.future;

        _showSnackBar('Uploading audio...');
        String audioUrl = await _uploadToCloudinary(_audioFilePath!);

        _showSnackBar('Transcribing audio...');
        String? transcript = await _transcribeWithAssemblyAI(audioUrl);
        if (transcript != null && transcript.isNotEmpty) {
          String processedText = _processText(transcript);
          final userMessageData = {
            'text': processedText,
            'isUser': true,
            'timestamp': DateTime.now().toIso8601String(),
          };
          if (mounted) {
            setState(() {
              _messages.add(userMessageData);
              _lastRecognizedText = processedText;
              _pruneMessages(); 
            });
          }
          _addMessageToActiveChatSession(userMessageData, audioUrl: audioUrl); 
          _scrollToBottom();
          logger.i('Transcribed text: $processedText');

          await _generateAIResponse(processedText);
          _evaluateUserInput(processedText);
        } else {
          _showSnackBar('Transcription returned empty. Did you speak clearly?');
          logger.w('AssemblyAI returned empty transcript');
        }
      } catch (e) {
        logger.e('Error processing audio: $e');
        _showSnackBar('Error processing audio: $e');
      }
    }
  }

  Future<String> _uploadToCloudinary(String filePath) async {
// ...existing code...
    final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
    final uploadPreset = dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '';
    if (cloudName.isEmpty || uploadPreset.isEmpty) {
      _showSnackBar('Cloudinary credentials missing. Please check .env file.');
      throw Exception('Cloudinary credentials not found in .env');
    }

    try {
      final url = 'https://api.cloudinary.com/v1_1/$cloudName/upload';
      final request = http.MultipartRequest('POST', Uri.parse(url));
      request.fields['upload_preset'] = uploadPreset;
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final data = jsonDecode(responseData);
        final secureUrl = data['secure_url'] as String?;
        if (secureUrl == null || secureUrl.isEmpty) {
          _showSnackBar(
              'Cloudinary upload returned an invalid URL. Please check settings.');
          throw Exception('Invalid Cloudinary response');
        }
        return secureUrl;
      }
      _showSnackBar('Cloudinary upload failed: Status ${response.statusCode}');
      throw Exception(
          'Failed to upload to Cloudinary: Status ${response.statusCode}');
    } catch (e) {
      _showSnackBar('Cloudinary upload error: $e');
      throw Exception('Cloudinary upload failed: $e');
    }
  }

  Future<String?> _transcribeWithAssemblyAI(String audioUrl) async {
// ...existing code...
    final apiKey = dotenv.env['ASSEMBLY_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      _showSnackBar('AssemblyAI API key missing.');
      return null;
    }

    try {
      final submitResponse = await http.post(
        Uri.parse('https://api.assemblyai.com/v2/transcript'),
        headers: {
          'Authorization': apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'audio_url': audioUrl}),
      );

      if (submitResponse.statusCode != 200) {
        _showSnackBar(
            'Failed to submit transcription: ${submitResponse.statusCode}');
        return null;
      }

      final submitData = jsonDecode(submitResponse.body);
      String transcriptId = submitData['id'];

      while (true) {
        final pollResponse = await http.get(
          Uri.parse('https://api.assemblyai.com/v2/transcript/$transcriptId'),
          headers: {'Authorization': apiKey},
        );
        final pollData = jsonDecode(pollResponse.body);
        String status = pollData['status'];

        if (status == 'completed') {
          return pollData['text'] ?? '';
        } else if (status == 'error') {
          _showSnackBar('Transcription error: ${pollData['error']}');
          return null;
        }
        await Future.delayed(const Duration(seconds: 2));
      }
    } catch (e) {
      _showSnackBar('AssemblyAI error: $e');
      return null;
    }
  }

  Future<String> _getOpenAIResponse(String prompt, {String? userInput}) async {
// ...existing code...
    if (!dotenv.isInitialized) {
      logger.e('DotEnv not initialized');
      _showSnackBar(
          'Environment variables not loaded. Please check app configuration.');
      return 'Sorry, I can’t respond right now. There’s a configuration issue.';
    }

    final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      logger.e('OpenAI API key missing');
      _showSnackBar('OpenAI API key missing. Please check .env file.');
      return 'Sorry, I can’t respond right now. Please try again later.';
    }

    try {
      logger.d(
          'Sending request to OpenAI with system prompt: $prompt, userInput: $userInput');
      final List<Map<String, String>> messages = [
        {
          'role': 'system',
          'content': prompt,
        },
        ..._messages.map((msg) => { 
              'role': msg['isUser'] ? 'user' : 'assistant',
              'content': msg['text'],
            }),
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

      logger.d(
          'OpenAI response status: ${response.statusCode}, body: ${response.body}');
      if (response.statusCode == 200) {
        final responseBody =
            utf8.decode(response.body.runes.toList(), allowMalformed: true);
        final data = jsonDecode(responseBody);
        final aiResponse = data['choices'][0]['message']['content'] ??
            'Interesting! How can I help you today?';
        final cleanedAiResponse = _cleanText(aiResponse);
        logger.i('OpenAI response: $cleanedAiResponse');
        return cleanedAiResponse;
      } else {
        logger.w(
            'OpenAI failed with status: ${response.statusCode}, body: ${response.body}');
        _showSnackBar(
            'OpenAI API request failed: Status ${response.statusCode}');
        return 'Oops, something went wrong. Let’s try that again!';
      }
    } catch (e) {
      logger.e('OpenAI error: $e');
      _showSnackBar('OpenAI API error: $e');
      return 'Sorry, I’m having trouble responding. Please try again!';
    }
  }

  String _processText(String text) {
// ...existing code...
    logger.d('Raw text before processing: "$text"');
    String processedText = _cleanText(text.trim());
    logger.d('After _cleanText: "$processedText"');

    if (!processedText.endsWith('.') &&
        !processedText.endsWith('?') &&
        !processedText.endsWith('!')) {
      processedText = processedText.replaceAll(RegExp(r'[.?!]$'), '');
      logger.d('After removing trailing punctuation: "$processedText"');

      List<String> questionStarters = [
        'how',
        'what',
        'where',
        'when',
        'why',
        'who',
        'are',
        'is',
        'can',
        'do',
        'will'
      ];
      bool isQuestion = questionStarters
              .any((starter) => processedText.toLowerCase().startsWith(starter)) ||
          processedText.toLowerCase().contains(' or ');
      if (isQuestion) {
        processedText += '?';
        logger.d('Added ? for question: "$processedText"');
      } else if (processedText.isNotEmpty) {
        processedText += '.';
        logger.d('Added . for statement: "$processedText"');
      }
    }
    return processedText;
  }

  String _cleanText(String text) {
// ...existing code...
    return text
        .replaceAll('â€™', "'")
        .replaceAll('â€', '"')
        .replaceAll('Ã©', 'e')
        .trim();
  }

  Future<void> _generateAIResponse(String userInput) async {
// ...existing code...
    if (mounted) {
      setState(() => _isProcessingTTS = true);
      logger.d(
          'Generating AI response for: $userInput with prompt: ${_currentLearningPrompt?.title ?? "General"}');

      String systemMessage;
      if (_currentLearningPrompt != null) {
        systemMessage = _currentLearningPrompt!.promptText;
      } else {
        final userName = _userName ?? "User"; 
        systemMessage =
            'You are an advanced English-speaking assistant named TalkReady. You are designed to help non-native speakers improve their spoken English skills. Based on user’s speaking level, You provide clear, friendly, and constructive feedback while encouraging natural and confident communication. The user\'s name is $userName.';
      }

      String aiResponse = await _getOpenAIResponse(
        systemMessage,
        userInput: userInput,
      );
      if (mounted) {
        final aiMessageData = {
          'text': aiResponse,
          'isUser': false,
          'timestamp': DateTime.now().toIso8601String(),
        };
        setState(() {
          _messages.add(aiMessageData);
          _isProcessingTTS = false;
          _isTyping = false;
          _pruneMessages(); 
        });
        _addMessageToActiveChatSession(aiMessageData); 
        _scrollToBottom();
        logger.i('AI message added: $aiResponse');
        _speakText(aiResponse, isUser: false);
        _evaluateUserInput(userInput); 
      }
    }
  }

  Future<void> _evaluateUserInput(String userInput) async {
// ...existing code...
    _responseCount++;
    try {
      double fluencyScore = await _analyzeFluency(userInput);
      double grammarScore = await _analyzeGrammar(userInput);
      double vocabScore = await _analyzeVocabulary(userInput);
      double pronunciationScore = 0.0; 
      double interactionScore = await _analyzeInteraction(userInput, _messages);

      if (mounted) {
        setState(() {
          _sessionProgress['Fluency'] =
              (_sessionProgress['Fluency']! + fluencyScore) / _responseCount;
          _sessionProgress['Grammar'] =
              (_sessionProgress['Grammar']! + grammarScore) / _responseCount;
          _sessionProgress['Pronunciation'] =
              (_sessionProgress['Pronunciation']! + pronunciationScore) /
                  _responseCount;
          _sessionProgress['Vocabulary'] =
              (_sessionProgress['Vocabulary']! + vocabScore) / _responseCount;
          _sessionProgress['Interaction'] =
              (_sessionProgress['Interaction']! + interactionScore) /
                  _responseCount;
        });
        logger.i('Updated session progress: $_sessionProgress');
      }
    } catch (e) {
      logger.e('Error evaluating user input: $e');
      _showSnackBar('Error analyzing your speech. Using default scores.');
    }
  }

  Future<double> _analyzeFluency(String text) async {
// ...existing code...
    try {
      final response = await _getOpenAIResponse(
        'Analyze the following text for fluency (smoothness, clarity, and flow) on a scale of 0.0 to 1.0. Return only the number, e.g., 0.8. Text: "$text"',
      );
      return double.tryParse(response.trim()) ?? 0.1;
    } catch (e) {
      logger.e('Error analyzing fluency: $e');
      return 0.1;
    }
  }

  Future<double> _analyzeGrammar(String text) async {
// ...existing code...
    try {
      final response = await _getOpenAIResponse(
        'Analyze the following text for grammatical correctness on a scale of 0.0 to 1.0. Return only the number, e.g., 0.7. Text: "$text"',
      );
      return double.tryParse(response.trim()) ?? 0.1;
    } catch (e) {
      logger.e('Error analyzing grammar: $e');
      return 0.1;
    }
  }

  Future<double> _analyzeVocabulary(String text) async {
// ...existing code...
    try {
      final response = await _getOpenAIResponse(
        'Analyze the following text for vocabulary richness (variety, complexity) on a scale of 0.0 to 1.0. Return only the number, e.g., 0.9. Text: "$text"',
      );
      return double.tryParse(response.trim()) ?? 0.1;
    } catch (e) {
      logger.e('Error analyzing vocabulary: $e');
      return 0.1;
    }
  }

  Future<double> _analyzeInteraction(
// ...existing code...
      String text, List<Map<String, dynamic>> history) async {
    try {
      final historyString = jsonEncode(history
          .map((msg) => {'text': msg['text'], 'isUser': msg['isUser']})
          .toList());
      final response = await _getOpenAIResponse(
        'Analyze the following text for interaction quality (relevance, coherence with history) on a scale of 0.0 to 1.0 based on the conversation history. Return only the number, e.g., 0.85. Text: "$text", History: $historyString',
      );
      return double.tryParse(response.trim()) ?? 0.1;
    } catch (e) {
      logger.e('Error analyzing interaction: $e');
      return 0.1;
    }
  }

  Future<void> _speakText(String text, {required bool isUser}) async {
// ...existing code...
    if (!mounted || isUser) return;
    if (mounted) {
      setState(() => _isProcessingTTS = true);
    }
    try {
      logger.i('Requesting TTS for text: "$text"');
      final response = await http.post(
        Uri.parse(_ttsServerUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': text,
          'locale': 'en_US', // Defaulting to en_US as _accentLocale is removed
        }),
      );
      logger.i('TTS server response: status=${response.statusCode}');
      if (response.statusCode == 200) {
        logger.i('Playing audio with default locale');
        await _audioPlayer.play(ap.BytesSource(response.bodyBytes));
      } else {
        logger.w(
            'TTS server failed with status ${response.statusCode}, falling back to FlutterTts');
        await _flutterTtsFallback(text);
      }
    } catch (e) {
      logger.e('F5-TTS error: $e, falling back to FlutterTts');
      await _flutterTtsFallback(text);
    } finally {
      if (mounted) {
        setState(() => _isProcessingTTS = false);
      }
    }
  }

  Future<void> _flutterTtsFallback(String text) async {
// ...existing code...
    try {
      if (text.contains('!')) {
        await _flutterTts.setPitch(0.9);
        await _flutterTts.setSpeechRate(0.6);
      } else if (text.contains('?')) {
        await _flutterTts.setPitch(1.1);
        await _flutterTts.setSpeechRate(0.85);
      } else {
        await _flutterTts.setPitch(0.9);
        await _flutterTts.setSpeechRate(0.9);
      }
      await _flutterTts.setLanguage('en_US'); // Defaulting to en_US
      await _flutterTts.speak(text);
      logger.d('Flutter TTS fallback played with locale: en_US');
    } catch (e) {
      logger.e('Error with Flutter TTS fallback: $e');
    }
  }

  Future<void> _saveProgress({bool showSnackBar = true}) async {
// ...existing code...
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'sessionProgress': _sessionProgress,
        'lastPracticeTime': FieldValue.serverTimestamp(),
        'responseCount': _responseCount,
        'lastRecognizedText': _lastRecognizedText,
      }).then((value) {
        logger.i(
            'Progress and lastRecognizedText saved to Firestore user document');
        if (showSnackBar && mounted) {
          _showSnackBar('Progress saved successfully.');
        }
      }).catchError((error) {
        logger.e('Error saving progress to Firestore: $error');
        if (showSnackBar && mounted) {
          _showSnackBar('Error saving progress. Please try again.');
        }
      });
    }
  }

  void _pruneMessages() {
// ...existing code...
    if (_messages.length > 20) { 
      _messages.removeRange(0, _messages.length - 20);
      logger.i('Pruned local _messages list to last 20');
    }
  }

  Future<void> _saveTutorialStatus() async {
// ...existing code...
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && mounted) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'hasSeenTutorial': _hasSeenTutorial,
        });
        logger.i(
            'Tutorial status saved to Firestore: hasSeenTutorial=$_hasSeenTutorial');
      } catch (e) {
        logger.e('Error saving tutorial status: $e');
        _showSnackBar('Error saving tutorial status.');
      }
    }
  }

  void _showSnackBar(String message) {
// ...existing code...
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  void _scrollToBottom() {
// ...existing code...
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
// ...existing code...
    logger.d("Attempting to stop audio. Current _audioPlayer state: ${_audioPlayer.state}");
    try {
      if (_audioPlayer.state != null) {
        logger.d("_audioPlayer.state is of type: ${_audioPlayer.state.runtimeType}");
      } else {
        logger.d("_audioPlayer.state is null, which is unexpected if player was used.");
      }

      if (_audioPlayer.state == ap.PlayerState.playing) {
        logger.d("AudioPlayer is in 'playing' state, calling stop().");
        await _audioPlayer.stop();
      } else {
        logger.d("AudioPlayer is not in 'playing' state or state is null. Current state: ${_audioPlayer.state}");
      }
      logger.d("Attempting to stop FlutterTts.");
      await _flutterTts.stop();

      if (mounted) {
        setState(() => _isProcessingTTS = false);
      }
      logger.i('Audio stopped successfully routine finished.');
    } catch (e, s) { 
      logger.e('Error stopping audio: $e', error: e, stackTrace: s);
      if (mounted) { 
        _showSnackBar('Failed to stop audio: $e');
      }
    }
  }

  String _categoryToString(PromptCategory category) {
// ...existing code...
    switch (category) {
      case PromptCategory.vocabulary:
        return "Vocabulary";
      case PromptCategory.pronunciation:
        return "Pronunciation";
      case PromptCategory.grammar:
        return "Grammar";
    }
  }

  void _addBotMessage(String text) {
// ...existing code...
    if (mounted) {
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
      _speakText(text, isUser: false);
      _scrollToBottom();
    }
  }

  Future<void> _showLearningFocusDialog() async {
// ...existing code...
    List<Widget> dialogOptions = [];

    for (var category in PromptCategory.values) {
      dialogOptions.add(SimpleDialogOption(
        onPressed: () {
          Navigator.pop(context, category);
        },
        child: Text(_categoryToString(category)),
      ));
    }

    dialogOptions.add(SimpleDialogOption(
      onPressed: () {
        Navigator.pop(context, null);
      },
      child: const Text("General Conversation"),
    ));

    var result = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: const Text('Choose a Learning Focus'),
          children: dialogOptions,
        );
      },
    );

    if (result is PromptCategory) {
      _showPromptsForCategoryDialog(result);
    } else if (result == null) {
      if (mounted) {
        setState(() {
          _currentLearningPrompt = null;
        });
      }
      _addBotMessage("Okay, let's have a general chat. How can I help you today?");
    }
  }

  Future<void> _showPromptsForCategoryDialog(PromptCategory category) async {
// ...existing code...
    final List<Prompt> categoryPrompts =
        _englishLearningPrompts.where((p) => p.category == category).toList();

    Prompt? selectedPrompt = await showDialog<Prompt>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: Text('Choose a ${_categoryToString(category)} Prompt'),
          children: categoryPrompts.map((prompt) {
            return SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context, prompt);
              },
              child: Text(prompt.title),
            );
          }).toList(),
        );
      },
    );

    if (selectedPrompt != null) {
      if (mounted) {
        setState(() {
          _currentLearningPrompt = selectedPrompt;
        });
      }
      if (selectedPrompt.initialBotMessage != null &&
          selectedPrompt.initialBotMessage!.isNotEmpty) {
        _addBotMessage(selectedPrompt.initialBotMessage!);
      } else {
        _addBotMessage(
            "Okay, we're focusing on: ${selectedPrompt.title}. What's your input?");
      }
    }
  }

  @override
  void dispose() {
// ...existing code...
    _flutterTts.stop();
    if (_isRecorderInitialized) {
      _recorder.closeRecorder();
    }
    if (_isPlayerInitialized) {
      _player.closePlayer();
    }
    _stopAudio(); 
    _textController.dispose();
    _audioPlayer.release(); 
    _audioPlayer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
// ...existing code...
    return ShowCaseWidget(
      onFinish: () {
        logger.i('ShowCaseWidget onFinish triggered');
        TutorialService.handleTutorialCompletion();
        if (mounted) {
          setState(() {
            _hasSeenTutorial = true;
          });
          _saveTutorialStatus();
        }
      },
      builder: (BuildContext showcaseContext) {
        if (!_hasSeenTutorial && !_hasTriggeredTutorial) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              logger.i('Automatic tutorial trigger for first-time user');
              _triggerTutorial(showcaseContext);
            }
          });
        }

        return WillPopScope(
          onWillPop: () async {
            _stopAudio();
            widget.onBackPressed?.call();
            _saveProgress(showSnackBar: false);
            return true;
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
              actions: [
                IconButton(
                  icon: const Icon(Icons.lightbulb_outline),
                  tooltip: 'Choose Learning Focus',
                  onPressed: _showLearningFocusDialog,
                  color: const Color.fromARGB(255, 41, 115, 178),
                ),
                if (_isProcessingTTS)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.0,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
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
                    description:
                        'Here, you’ll see your conversation with the TalkReady Bot. Your messages appear on the right, and the bot’s on the left.',
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
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
                          );
                        },
                      ),
                    ),
                  ),
                ),
                if (_isListening)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      _lastRecognizedText.isEmpty
                          ? 'Listening...'
                          : 'Listening: $_lastRecognizedText',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.blue,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                if (_isTyping)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            decoration: InputDecoration(
                              hintText: 'Type your message...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onSubmitted: (_) => _submitTypedText(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.send, color: Colors.blue),
                          onPressed: _submitTypedText,
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
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

class ChatMessage extends StatefulWidget {
  final String message;
  final bool isUser;
  final ImageProvider? userProfileImage;
  final String? timestamp;

  const ChatMessage({
    super.key,
    required this.message,
    required this.isUser,
    this.userProfileImage,
    this.timestamp,
  });

  @override
  State<ChatMessage> createState() => _ChatMessageState();
}

class _ChatMessageState extends State<ChatMessage> {
  bool _showTimestamp = false;

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return 'Unknown time';
    try {
      final dateTime = DateTime.parse(timestamp);
      return DateFormat('MMM d, yyyy, h:mm a').format(dateTime);
    } catch (e) {
      logger.e('Error parsing timestamp: $e');
      return 'Invalid time';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showTimestamp = !_showTimestamp;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Row(
          mainAxisAlignment:
              widget.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!widget.isUser) ...[
              CircleAvatar(
                radius: 20,
                backgroundImage: const AssetImage('images/talkready_bot.png'),
                backgroundColor: Colors.blue.shade100,
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: widget.isUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: widget.isUser
                          ? Colors.blue.shade100
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(widget.message),
                  ),
                  if (_showTimestamp && widget.timestamp != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        _formatTimestamp(widget.timestamp),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (widget.isUser) ...[
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey.shade300,
                backgroundImage: widget.userProfileImage,
                child: widget.userProfileImage == null
                    ? const Icon(Icons.person, color: Colors.white, size: 24)
                    : null,
              ),
            ],
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TutorialService.buildShowcase(
          context: context,
          key: keyboardKey,
          title: 'Keyboard Input',
          description: 'Tap here to type your message instead of speaking.',
          child: _buildIcon(Icons.keyboard, Colors.purple.shade200, onKeyboardTap,
              isActive: isTyping),
        ),
        const SizedBox(width: 20),
        TutorialService.buildShowcase(
          context: context,
          key: micKey,
          title: 'Microphone',
          description: 'Tap to start recording your voice. Tap again to stop.',
          child: _buildIcon(
            isListening ? Icons.stop : Icons.mic,
            Colors.blue.shade300,
            onMicTap,
            isActive: isListening,
          ),
        ),
      ],
    );
  }

  Widget _buildIcon(IconData icon, Color color, VoidCallback? onTap,
      {bool isActive = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: onTap != null && isActive ? color.withOpacity(0.7) : color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 30),
      ),
    );
  }
}
// ...existing code...