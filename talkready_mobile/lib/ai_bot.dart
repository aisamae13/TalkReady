import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
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
import 'scenarios/grammar_correction.dart';
import 'scenarios/vocabulary_building.dart';
import 'tutorial_service.dart';

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
  final AudioPlayer _audioPlayer = AudioPlayer();
  late FlutterSoundPlayer _player;
  late FlutterSoundRecorder _recorder;
  bool _isListening = false;
  bool _isProcessingTTS = false;
  String _lastRecognizedText = '';
  String? _audioFilePath;
  String? _userProfilePictureBase64;
  ImageProvider? _userProfileImage;
  final List<Map<String, dynamic>> _messages = [];
  String? _accentLocale;
  int _timeGoalSeconds = 300;
  Timer? _timer;
  int _remainingSeconds = 0;
  bool _hasStartedListening = false;
  bool _isTyping = false;
  bool _hasTriggeredTutorial = false;
  bool _hasSeenTutorial = false;
  static const String _ttsServerUrl = 'https://c360-175-176-32-217.ngrok-free.app/tts';
  bool _isRecorderInitialized = false;
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
  final GlobalKey _timerKey = GlobalKey();
  final GlobalKey _chatAreaKey = GlobalKey();
  final GlobalKey _micKey = GlobalKey();
  final GlobalKey _keyboardKey = GlobalKey();
  final GlobalKey _modeKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _scenarioOptions = [
    {'title': 'Pronunciation Practice', 'icon': Icons.mic, 'route': null},
    {'title': 'Fluency Enhancement', 'icon': Icons.chat_bubble, 'route': null},
    {
      'title': 'Grammar Correction Exercise',
      'icon': Icons.edit,
      'route': (BuildContext context, String accentLocale, String userName, int timeGoalSeconds) => GrammarCorrectionScreen(
        accentLocale: accentLocale,
        userName: userName,
        timeGoalSeconds: timeGoalSeconds,
      ),
    },
    {'title': 'Vocabulary Building Practice', 'icon': Icons.book, 'route':  (BuildContext context, String accentLocale, String userName, int timeGoalSeconds) => VocabularyBuildingPracticeScreen(
        accentLocale: accentLocale,
        userName: userName,
        timeGoalSeconds: timeGoalSeconds,
      ),},

    {'title': 'Listening Comprehension Drill', 'icon': Icons.headset, 'route': null},
  ];

  @override
void initState() {
  super.initState();
  _recorder = FlutterSoundRecorder();
  _player = FlutterSoundPlayer();
  _fetchOnboardingData().then((_) {
    _initializeTts();
    _remainingSeconds = _timeGoalSeconds;
    _initRecorder();
    _initPlayer();
    _requestPermissions();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Check if there’s already a bot message (likely a greeting)
        bool hasBotMessage = _messages.any((msg) => !msg['isUser']);
        if (!hasBotMessage) {
          String randomGreeting = _generateRandomGreeting();
          logger.i(
              'Adding greeting to _messages: {"text": "$randomGreeting", "isUser": false, "timestamp": "${DateTime.now().toIso8601String()}"}');
          setState(() {
            _messages.add({
              'text': randomGreeting,
              'isUser': false,
              'timestamp': DateTime.now().toIso8601String(),
            });
            _pruneMessages();
          });
          _speakText(randomGreeting, isUser: false);
          _scrollToBottom();
        } else {
          logger.i('Greeting already exists in messages, skipping new greeting');
          // Optionally, speak the last bot message if desired
          String lastBotMessage = _messages.lastWhere((msg) => !msg['isUser'])['text'];
          _speakText(lastBotMessage, isUser: false);
          _scrollToBottom();
        }
      }
    });
  });
}

 Future<void> _triggerTutorial(BuildContext showcaseContext) async {
    if (!mounted) {
      logger.i('Tutorial not triggered: widget not mounted');
      return;
    }

    bool shouldShow = await TutorialService.shouldShowTutorial(Future.value(_hasSeenTutorial));
    if (!shouldShow) {
      logger.i('Tutorial skipped: user has already seen it');
      return;
    }

    logger.i('Showing welcome dialog for tutorial');
    bool? startTour = await TutorialService.showTutorialWithSkipOption(
      context: context,
      showcaseKeys: [_timerKey, _chatAreaKey, _micKey, _keyboardKey, _modeKey],
      skipText: 'Skip Tutorial',
      onComplete: () {
        setState(() {
          _hasSeenTutorial = true;
        });
        _saveTutorialStatus();
      },
      title: 'Welcome to TalkReady Bot!',
      content: 'Get ready to explore the app with a quick tour! Would you like to start?',
      confirmText: 'Start Tour',
      showDontAskAgain: false,
    );

    if (!mounted || !showcaseContext.mounted) {
      logger.w('Cannot proceed with tutorial: widget or context not mounted');
      _showSnackBar('Cannot start tutorial at this time.');
      return;
    }

    if (startTour == false) { // confirmText ("Start Tour") returns false
      logger.i('User chose to start tutorial walkthrough');
      try {
        if (mounted && showcaseContext.mounted) {
          TutorialService.startShowCase(showcaseContext, [
            _timerKey,
            _chatAreaKey,
            _micKey,
            _keyboardKey,
            _modeKey,
          ]);
          logger.i('Showcase started successfully');
        } else {
          logger.w('Cannot start showcase: widget not mounted or context unavailable');
          _showSnackBar('Cannot start tutorial at this time.');
        }
      } catch (e) {
        logger.e('Error starting tutorial: $e');
        _showSnackBar('Failed to start tutorial: $e');
      }
    } else {
      logger.i('User skipped tutorial');
      setState(() {
        _hasSeenTutorial = true;
      });
      await _saveTutorialStatus();
    }
  }

  void _restartTutorial(BuildContext showcaseContext) {
    logger.i('Manual tutorial trigger via help icon, resetting and starting walkthrough');
    if (mounted) {
      setState(() {
        _hasSeenTutorial = false;
      });
      _triggerTutorial(showcaseContext);
    } else {
      logger.w('Cannot restart tutorial: widget is not mounted');
      _showSnackBar('Cannot restart tutorial at this time.');
    }
  }

 String _generateRandomGreeting() {
  logger.i('Generating greeting with _accentLocale: $_accentLocale, userName: $_userName');
  final now = DateTime.now();
  String timePrefix = now.hour < 12
      ? "Good morning"
      : now.hour < 17
          ? "Good afternoon"
          : "Good evening";

  if (_userName == null || _userName!.isEmpty) {
    logger.e('userName is null or empty, cannot generate personalized greeting');
    throw Exception('User name is missing. Please complete onboarding or contact support.');
  }
  final List<String> baseGreetings = [
    if (_accentLocale == 'en_US') ...[
      "$timePrefix, $_userName! How’s your day been? Spill something fun!",
      "$timePrefix, $_userName! What’s new with you today?",
      "$timePrefix, $_userName! Got any exciting plans?",
    ],
    if (_accentLocale == 'en_GB') ...[
      "$timePrefix, $_userName! How’s your day going? Tell me a smashing story!",
      "$timePrefix, $_userName! What’s on your mind today?",
      "$timePrefix, $_userName! Fancy sharing a brilliant tale?",
    ],
    if (_accentLocale == 'en_AU') ...[
      "$timePrefix, $_userName! How’s your day? Got any ripper tales?",
      "$timePrefix, $_userName! What’s cooking, mate?",
      "$timePrefix, $_userName! Got any yarns to spin?",
    ],
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
      logger.i('Player initialized successfully');
    } catch (e) {
      logger.e('Error initializing player: $e');
      _showSnackBar('Failed to initialize player');
    }
  }

  Future<void> _initializeTts() async {
    logger.i('Initializing TTS with locale: ${_accentLocale ?? 'en_US'}');
    try {
      await _flutterTts.setLanguage(_accentLocale ?? 'en_US');
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
    _isRecorderInitialized = true;
    logger.i('Recorder initialized successfully');
  } catch (e) {
    logger.e('Error initializing recorder: $e');
    _isRecorderInitialized = false;
    _showSnackBar('Error initializing recorder: $e');
  }
}

 Future<void> _requestPermissions() async {
  Map<Permission, PermissionStatus> statuses = await [
    Permission.microphone,
  ].request();

  if (statuses[Permission.microphone]!.isDenied || statuses[Permission.microphone]!.isPermanentlyDenied) {
    logger.w('Microphone permission denied');
    _showSnackBar('Microphone permission is required for voice input');
    if (statuses[Permission.microphone]!.isPermanentlyDenied && mounted) {
      _showPermissionDialog('Microphone', 'voice recording');
    }
  }


    if (statuses[Permission.storage]!.isDenied || statuses[Permission.storage]!.isPermanentlyDenied) {
      logger.w('Storage permission denied');
      _isRecorderInitialized = false;
      _showSnackBar('Storage permission is required for saving audio');
      if (statuses[Permission.storage]!.isPermanentlyDenied && mounted) {
        _showPermissionDialog('Storage', 'audio file saving');
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
  if (user == null) return;

  try {
    DocumentSnapshot doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    Map<String, dynamic>? userData = doc.data() as Map<String, dynamic>?;
    if (userData != null && userData.containsKey('onboarding')) {
      Map<String, dynamic> onboarding = userData['onboarding'];
      logger.i('Raw onboarding data: $onboarding');
      String rawAccent = onboarding['desiredAccent']?.toString() ?? 'Unknown';
      String cleanedAccent = rawAccent
          .replaceAll(RegExp(r'[^a-zA-Z ]'), '')
          .trim()
          .toLowerCase();
      logger.i('Raw desiredAccent: "$rawAccent", Cleaned: "$cleanedAccent"');

      String? dailyGoal = onboarding['dailyPracticeGoal']?.toString();
      if (dailyGoal != null) {
        String minutesStr = dailyGoal.replaceAll(RegExp(r'[^0-9]'), '');
        int minutes = int.tryParse(minutesStr) ?? 5;
        _timeGoalSeconds = minutes * 60;
        logger.i(
            'Set timeGoalSeconds to: $_timeGoalSeconds seconds ($minutes minutes)');
      } else {
        logger.i(
            'No dailyPracticeGoal found, using default timeGoalSeconds: $_timeGoalSeconds');
      }

      if (mounted) {
        setState(() {
          switch (cleanedAccent) {
            case 'australian':
              _accentLocale = 'en_AU';
              break;
            case 'american':
              _accentLocale = 'en_US';
              break;
            case 'british':
              _accentLocale = 'en_GB';
              break;
            case 'neutral':
              _accentLocale = 'en_US';
              break;
            default:
              _accentLocale = 'en_US';
              logger.w('Unknown accent: "$cleanedAccent", defaulting to en_US');
          }
          _userName = onboarding['userName']?.toString();
          if (_userName == null || _userName!.isEmpty) {
            _userName = user.displayName?.toString() ?? 'User';
            logger.w(
                'userName not found in onboarding, using fallback: $_userName');
          }
          _userProfilePictureBase64 = onboarding['profilePicBase64']?.toString();
          if (_userProfilePictureBase64 == null || _userProfilePictureBase64!.isEmpty) {
            logger.w('No profilePicBase64 found in onboarding data');
            _userProfileImage = null;
          } else {
            try {
              if (_userProfilePictureBase64!.startsWith('data:image')) {
                logger.i('Stripping Base64 prefix from profilePicBase64');
                _userProfilePictureBase64 = _userProfilePictureBase64!.split(',').last;
              }
              final bytes = base64Decode(_userProfilePictureBase64!);
              logger.i('Profile picture Base64 decoded, byte length: ${bytes.length}');
              _userProfileImage = MemoryImage(bytes);
            } catch (e) {
              logger.e('Error decoding profilePicBase64: $e');
              _userProfileImage = null;
            }
          }
          logger.i('Set userName to: $_userName');
          logger.i('Set accent locale to: $_accentLocale');

          _sessionProgress.forEach((key, value) {
            _sessionProgress[key] =
                (userData['sessionProgress']?[key] as double?) ?? 0.0;
          });
          _responseCount = (userData['responseCount'] as int?) ?? 0;
          _remainingSeconds =
              (userData['remainingSeconds'] as int?) ?? _timeGoalSeconds;
          _hasSeenTutorial = (userData['hasSeenTutorial'] as bool?) ?? false;
          logger.i(
              'Loaded progress: sessionProgress=$_sessionProgress, responseCount=$_responseCount, remainingSeconds=$_remainingSeconds, hasSeenTutorial=$_hasSeenTutorial');

          _messages.clear();
          (userData['messages'] as List<dynamic>?)?.forEach((msg) {
            var message = Map<String, dynamic>.from(msg);
            // Ensure older messages without timestamps are given a default
            if (!message.containsKey('timestamp')) {
              message['timestamp'] = DateTime.now().toIso8601String();
            }
            _messages.add(message);
          });
          logger.i('Loaded messages: $_messages');
          _initializeTts();
        });
      }
    } else {
      logger.e('No onboarding data found for user');
      if (mounted) {
        _showSnackBar(
            'No onboarding data found. Please complete onboarding.');
      }
    }
  } catch (e) {
    logger.e('Error fetching preferences: $e');
    if (mounted) _showSnackBar('Error fetching preferences: $e');
  }
}

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        timer.cancel();
        _stopListening();
        if (mounted) {
          _showSnackBar('Time’s up for today’s practice!');
          _saveProgress();
          _showContinuePracticeDialog();
        }
      }
    });
    logger.i('Timer started with $_remainingSeconds seconds remaining');
  }

  void _showContinuePracticeDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Practice Time Goal Reached'),
        content: const Text(
            'You’ve reached today’s practice goal. Would you like to continue practicing?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showSnackBar('Practice session ended for today.');
              _saveProgress();
            },
            child: const Text('No, Stop'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetTimerAndContinue();
            },
            child: const Text('Yes, Continue'),
          ),
        ],
      ),
    );
  }

  void _resetTimerAndContinue() {
    if (mounted) {
      setState(() {
        _remainingSeconds = _timeGoalSeconds;
        _hasStartedListening = false;
      });
      _startTimer();
      _showSnackBar(
          'You can continue practicing for another ${_formatTime(_timeGoalSeconds)}!');
    }
  }

  Future<void> _startListening() async {
  if (!_isRecorderInitialized) {
    _showSnackBar('Cannot record audio. Recorder initialization failed.');
    return;
  }

  if (!_isListening && !_isTyping && _remainingSeconds > 0) {
    if (!_hasStartedListening) {
      _startTimer();
      _hasStartedListening = true;
    }

    logger.d(
        'Starting to listen. IsListening: $_isListening, IsTyping: $_isTyping, RemainingSeconds: $_remainingSeconds');

    try {
      if (_recorder.isRecording) {
        await _recorder.stopRecorder();
      }
      await _recorder.startRecorder(
        toFile: _audioFilePath!,
        codec: Codec.pcm16WAV,
      );
      setState(() => _isListening = true);
      logger.d('Recording started for AssemblyAI');
      _showSnackBar('Recording started. Speak now!');
    } catch (e) {
      logger.e('Error starting recording: $e');
      _showSnackBar('Error starting recording: $e');
      setState(() => _isListening = false);
    }
  } else {
    logger.w('Cannot start listening. Conditions not met.');
    _showSnackBar('Time’s up! You can’t practice anymore.');
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
        logger.d('Recording stopped, path: $_audioFilePath');
        _showSnackBar('Recording stopped.');

        if (_audioFilePath != null) {
          await _processAudioRecording();
        }
      } catch (e) {
        logger.e('Error stopping recording: $e');
        _showSnackBar('Error stopping recording: $e');
        setState(() => _isListening = false);
      }
    }
  }

  void _toggleTyping() {
    if (!_isListening) {
      setState(() {
        logger.d('Toggling typing state to: $_isTyping');
        _isTyping = !_isTyping;
        if (!_isTyping) {
          _textController.clear();
          logger.d('Cleared text input');
        }
        if (!_hasStartedListening && _isTyping) {
          _startTimer();
          _hasStartedListening = true;
          logger.i('Started timer for typing session');
        }
      });
    } else {
      _showSnackBar('Please stop listening before typing.');
      logger.w('Attempted to toggle typing while listening');
    }
  }

  void _submitTypedText() {
  if (_textController.text.isNotEmpty && _remainingSeconds > 0) {
    String processedText = _processText(_textController.text);
    setState(() {
      _messages.add({
        'text': processedText,
        'isUser': true,
        'timestamp': DateTime.now().toIso8601String(),
      });
      _pruneMessages();
    });
    _scrollToBottom();
    _speakText(processedText, isUser: true);
    _generateAIResponse(processedText);
    _evaluateUserInput(processedText);
    _textController.clear();
    setState(() => _isTyping = false);
  }
}

 Future<void> _processAudioRecording() async {
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

      // Create a Completer to wait for playback completion
      Completer<void> playbackCompleter = Completer<void>();

      await _player.startPlayer(
        fromURI: _audioFilePath!,
        codec: Codec.pcm16WAV,
        whenFinished: () {
          logger.i('Audio playback finished.');
          playbackCompleter.complete(); // Resolve the completer when playback finishes
        },
      ).catchError((error) {
        logger.e('Error playing audio: $error');
        _showSnackBar('Error playing your voice: $error');
        playbackCompleter.completeError(error); // Resolve with error if playback fails
        return null;
      });

      // Wait for the playback to finish
      await playbackCompleter.future;

      _showSnackBar('Uploading audio...');
      String audioUrl = await _uploadToCloudinary(_audioFilePath!);

      _showSnackBar('Transcribing audio...');
      String? transcript = await _transcribeWithAssemblyAI(audioUrl);
      if (transcript != null && transcript.isNotEmpty) {
        String processedText = _processText(transcript);
        setState(() {
          _messages.add({
            'text': processedText,
            'isUser': true,
            'timestamp': DateTime.now().toIso8601String(),
          });
          _lastRecognizedText = processedText;
          _pruneMessages();
        });
        _scrollToBottom();
        logger.i('Transcribed text: $processedText');

        // Now that playback is complete, generate and speak the AI response
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
    final apiKey = dotenv.env['ASSEMBLYAI_API_KEY'] ?? '';
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
      logger.d('Sending request to OpenAI with prompt: $prompt, userInput: $userInput');
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
      bool isQuestion = questionStarters.any(
              (starter) => processedText.toLowerCase().startsWith(starter)) ||
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
    return text
        .replaceAll('â€™', "'")
        .replaceAll('â€', '"')
        .replaceAll('Ã©', 'e')
        .trim();
  }

 Future<void> _generateAIResponse(String userInput) async {
  if (mounted) {
    setState(() => _isProcessingTTS = true);
    logger.d('Generating AI response for: $userInput');
    String aiResponse = await _getOpenAIResponse(
      'You are an advanced English-speaking assistant named TalkReady. You are designed to help non-native speakers improve their spoken English skills. Based on user’s speaking level and $_accentLocale, You provide clear, friendly, and constructive feedback while encouraging natural and confident communication.',
      userInput: userInput,
    );
    if (mounted) {
      setState(() {
        _messages.add({
          'text': aiResponse,
          'isUser': false,
          'timestamp': DateTime.now().toIso8601String(),
        });
        _isProcessingTTS = false;
        _isTyping = false;
      });
      _scrollToBottom();
      logger.i('AI message added: $aiResponse');
      _speakText(aiResponse, isUser: false);
      _evaluateUserInput(userInput);
    }
  }
}

  Future<void> _evaluateUserInput(String userInput) async {
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
    if (!mounted || isUser) return;
    setState(() => _isProcessingTTS = true);
    try {
      logger.i('Requesting TTS for text: "$text", locale: $_accentLocale');
      final response = await http.post(
        Uri.parse(_ttsServerUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': text,
          'locale': _accentLocale ?? 'en_US',
        }),
      );
      logger.i('TTS server response: status=${response.statusCode}');
      if (response.statusCode == 200) {
        logger.i('Playing audio for locale: $_accentLocale');
        await _audioPlayer.play(BytesSource(response.bodyBytes));
      } else {
        logger.w('TTS server failed, falling back to FlutterTts');
        _showSnackBar(
            'F5-TTS server error (status ${response.statusCode}), using default TTS.');
        await _flutterTtsFallback(text);
      }
    } catch (e) {
      logger.e('Error with F5-TTS request: $e, falling back to FlutterTts');
      _showSnackBar('F5-TTS error: $e, using default TTS.');
      await _flutterTtsFallback(text);
    } finally {
      if (mounted) {
        setState(() => _isProcessingTTS = false);
      }
    }
  }

  Future<void> _flutterTtsFallback(String text) async {
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
      await _flutterTts.setLanguage(_accentLocale ?? 'en_US');
      await _flutterTts.speak(text);
      logger.d('Flutter TTS fallback played with locale: $_accentLocale');
    } catch (e) {
      logger.e('Error with Flutter TTS fallback: $e');
      _showSnackBar('TTS fallback failed: $e');
    }
  }

  void _saveProgress({bool showSnackBar = true}) {
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'sessionProgress': _sessionProgress,
      'lastPracticeTime': FieldValue.serverTimestamp(),
      'totalPracticeTime': FieldValue.increment(_timeGoalSeconds - _remainingSeconds),
      'responseCount': _responseCount,
      'remainingSeconds': _remainingSeconds,
      'messages': _messages,
      'lastRecognizedText': _lastRecognizedText,
    }).then((value) {
      logger.i('Progress, messages, and lastRecognizedText saved to Firestore');
      if (showSnackBar && mounted) {
        _showSnackBar('Progress and chat history saved successfully.');
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
    if (_messages.length > 20) {
      _messages.removeRange(0, _messages.length - 20);
      logger.i('Pruned messages to last 20');
    }
    _saveMessagesToFirestore();
  }

  void _saveMessagesToFirestore() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && mounted) {
      FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'messages': _messages,
      }).then((value) {
        logger.i('Messages saved to Firestore');
      }).catchError((error) {
        logger.e('Error saving messages to Firestore: $error');
        _showSnackBar('Error saving chat history. Try again later.');
      });
    }
  }

  Future<void> _saveTutorialStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && mounted) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'hasSeenTutorial': _hasSeenTutorial,
        });
        logger.i('Tutorial status saved to Firestore: hasSeenTutorial=$_hasSeenTutorial');
      } catch (e) {
        logger.e('Error saving tutorial status: $e');
        _showSnackBar('Error saving tutorial status.');
      }
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
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
  @override
  void dispose() {
    _timer?.cancel();
    _flutterTts.stop();
    _recorder.closeRecorder();
    _player.closePlayer();
    _textController.dispose();
    _audioPlayer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
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
            // Call the callback to update the tab index in HomePage
            widget.onBackPressed?.call();
            // Save progress before popping
            _saveProgress(showSnackBar: false);
            return true; // Allow the pop to proceed
          },
          child: Scaffold(
            appBar: AppBar(
              title: const Text(
                'TR Bot',
                style: TextStyle(
                  color: Color.fromARGB(255, 41, 115, 178),
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              backgroundColor: Colors.white,
              actions: [
                IconButton(
                  icon: const Icon(Icons.help, color: Colors.blue),
                  tooltip: 'View Tutorial',
                  onPressed: () => _restartTutorial(showcaseContext),
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
                TutorialService.buildShowcase(
                  context: showcaseContext,
                  key: _timerKey,
                  title: 'Practice Timer',
                  description: 'This shows your remaining practice time for today. Keep an eye on it!',
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.timer, size: 18, color: Colors.blue),
                          const SizedBox(width: 4),
                          Text(
                            _formatTime(_remainingSeconds),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
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
                    description: 'Here, you’ll see your conversation with the TalkReady Bot. Your messages appear on the right, and the bot’s on the left.',
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
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
                    onMicTap: () => _isListening ? _stopListening() : _startListening(),
                    onKeyboardTap: _toggleTyping,
                    onModeSelected: (String title) {
                      final selectedScenario = _scenarioOptions.firstWhere(
                          (scenario) => scenario['title'] == title);
                      final route = selectedScenario['route'];
                      if (route != null && mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => route(
                              context,
                              _accentLocale ?? 'en_US',
                              _userName ?? 'User',
                              _timeGoalSeconds,
                            ),
                          ),
                        );
                      }
                    },
                    isListening: _isListening,
                    isTyping: _isTyping,
                    scenarioOptions: _scenarioOptions,
                    micKey: _micKey,
                    keyboardKey: _keyboardKey,
                    modeKey: _modeKey,
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
          mainAxisAlignment: widget.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
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
                crossAxisAlignment: widget.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: widget.isUser ? Colors.blue.shade100 : Colors.white,
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
  final ValueChanged<String> onModeSelected;
  final bool isListening;
  final bool isTyping;
  final List<Map<String, dynamic>> scenarioOptions;
  final GlobalKey micKey;
  final GlobalKey keyboardKey;
  final GlobalKey modeKey;

  const IconRow({
    super.key,
    required this.onMicTap,
    required this.onKeyboardTap,
    required this.onModeSelected,
    required this.isListening,
    required this.isTyping,
    required this.scenarioOptions,
    required this.micKey,
    required this.keyboardKey,
    required this.modeKey,
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
        const SizedBox(width: 20),
        TutorialService.buildShowcase(
          context: context,
          key: modeKey,
          title: 'Practice Modes',
          description: 'Tap here to choose different practice scenarios, like grammar or vocabulary exercises.',
          child: PopupMenuButton<String>(
            onSelected: onModeSelected,
            itemBuilder: (BuildContext context) {
              return scenarioOptions.map((scenario) {
                return PopupMenuItem<String>(
                  value: scenario['title'],
                  child: Row(
                    children: [
                      Icon(
                        scenario['icon'],
                        color: Colors.blue.shade500,
                        size: 20.0,
                      ),
                      const SizedBox(width: 8.0),
                      Text(
                        scenario['title'],
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList();
            },
            child: _buildIcon(
              Icons.play_circle,
              Colors.amber.shade200,
              null,
              isActive: false,
            ),
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
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}