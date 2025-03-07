import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http; // For POST requests
import 'package:audioplayers/audioplayers.dart'; // For playing audio
import 'package:path_provider/path_provider.dart'; // For saving audio
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart'; // Added for microphone permissions
import 'dart:async';
import 'dart:convert'; // For JSON parsing
import 'dart:io'; // For File operations
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Ensure this is imported
import 'package:logger/logger.dart'; // Import logger
import 'dart:math'; // For Random

class AIBotScreen extends StatefulWidget {
  const AIBotScreen({super.key});

  @override
  State<AIBotScreen> createState() => _AIBotScreenState();
}

// Initialize logger at the top of the file
final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 2, // Number of method calls to show in stack trace
    errorMethodCount: 8, // Number of method calls if stack trace is an error
    lineLength: 120, // Width of the output
    colors: true, // Colorful log messages
    printEmojis: true, // Print an emoji for each log message
    dateTimeFormat:
        DateTimeFormat.onlyTimeAndSinceStart, // Include timestamp in logs
  ),
);

class _AIBotScreenState extends State<AIBotScreen> {
  final FlutterTts _flutterTts = FlutterTts();
  String? _initialGreeting; // Store the initial greeting
  final AudioPlayer _audioPlayer = AudioPlayer();
  late FlutterSoundPlayer _player;
  late FlutterSoundRecorder _recorder; // Use late initialization
  bool _isListening = false;
  bool _isProcessingTTS = false;
  String _lastRecognizedText = '';
  String? _audioFilePath; // Store local audio file path
  final List<Map<String, dynamic>> _nonSimulationMessages =
      []; // For non-simulation mode
  final List<Map<String, dynamic>> _simulationMessages =
      []; // For simulation mode
  List<Map<String, dynamic>> get _messages =>
      _isInSimulation ? _simulationMessages : _nonSimulationMessages;
  String? _accentLocale;
  int _timeGoalSeconds = 300;
  Timer? _timer;
  int _remainingSeconds = 0;
  bool _hasStartedListening = false;
  bool _isTyping = false;
  bool _isInSimulation = false; // Track simulation mode
<<<<<<< HEAD
  static const String _ttsServerUrl = 'https://bbc1-103-149-37-102.ngrok-free.app/tts';
=======
  static const String _ttsServerUrl =
      'https://0215-103-149-37-102.ngrok-free.app/tts';
>>>>>>> da22a3d1b8d7a54de5762df76b0921fca40e14a8
  bool _isRecorderInitialized = false;
  final TextEditingController _textController = TextEditingController();
  final Map<String, double> _sessionProgress = {
    'Fluency': 0.0,
    'Grammar': 0.0,
    'Pronunciation': 0.0, // Placeholder until Azure API is available
    'Vocabulary': 0.0,
    'Interaction': 0.0,
  };
  int _responseCount = 0;

  final Random _random = Random(); // For randomizing greetings
  String? _userName;

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
          String randomGreeting = _generateRandomGreeting();
          _initialGreeting = randomGreeting;
          logger.i(
              'Adding greeting to _messages: {"text": "$randomGreeting", "isUser": false}');
          setState(() {
            _messages.add({'text': randomGreeting, 'isUser': false});
          });
          _speakText(randomGreeting, isUser: false);
        }
      });
    });
  }

  String _generateRandomGreeting() {
    logger.i(
        'Generating greeting with _accentLocale: $_accentLocale, userName: $_userName');
    final now = DateTime.now();
    String timePrefix = now.hour < 12
        ? "Good morning"
        : now.hour < 17
            ? "Good afternoon"
            : "Good evening";

    // Use _userName or throw an error if null/empty
    if (_userName == null || _userName!.isEmpty) {
      logger.e(
          'userName is null or empty, cannot generate personalized greeting');
      throw Exception(
          'User name is missing. Please complete onboarding or contact support.');
    }
    // Base greetings with user's name
    final List<String> baseGreetings = [
      if (_accentLocale == 'en_US')
        "$timePrefix, $_userName! How’s your day been? Spill something fun!",
      if (_accentLocale == 'en_GB')
        "$timePrefix, $_userName! How’s your day going? Tell me a smashing story!",
      if (_accentLocale == 'en_AU')
        "$timePrefix, $_userName! How’s your day? Got any ripper tales?",
    ];
    String greeting = baseGreetings[_random.nextInt(baseGreetings.length)];
    logger.i('Generated greeting: "$greeting"');
    return greeting;
  }

  Future<void> _initPlayer() async {
    await _player.openPlayer();
  }

  Future<void> _initializeTts() async {
    logger.i('Initializing TTS with locale: ${_accentLocale ?? 'en_US'}');
    await _flutterTts.setLanguage(
        _accentLocale ?? 'en_US'); // Use fetched locale or fallback
    await _flutterTts.setPitch(0.7);
    await _flutterTts.setSpeechRate(0.6);
  }

  Future<void> _initRecorder() async {
    try {
      await _recorder.openRecorder();
      final tempDir = await getTemporaryDirectory();
      _audioFilePath = '${tempDir.path}/audio.wav';
      _isRecorderInitialized = true;
    } catch (e) {
      _isRecorderInitialized = false;
      _showSnackBar('Error initializing recorder: $e');
    }
  }

  Future<void> _requestPermissions() async {
    if (!await Permission.microphone.isGranted) {
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted && mounted) {
        _showSnackBar(
            'Microphone permission denied. Please enable it in settings.');
      }
    }
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

        // Handle dailyPracticeGoal to set _timeGoalSeconds
        String? dailyGoal = onboarding['dailyPracticeGoal']?.toString();
        if (dailyGoal != null) {
          String minutesStr = dailyGoal.replaceAll(
              RegExp(r'[^0-9]'), ''); // Extract only numbers
          int minutes = int.tryParse(minutesStr) ??
              5; // Default to 5 minutes if parsing fails
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
                logger
                    .w('Unknown accent: "$cleanedAccent", defaulting to en_US');
            }
            _userName = onboarding['userName']?.toString();
            if (_userName == null || _userName!.isEmpty) {
              _userName = user.displayName?.toString() ?? 'User';
              logger.w(
                  'userName not found in onboarding, using fallback: $_userName');
            }
            logger.i('Set userName to: $_userName');
            logger.i('Set accent locale to: $_accentLocale');

            // Load progress from Firestore (using only sessionProgress)
            _sessionProgress.forEach((key, value) {
              _sessionProgress[key] =
                  (userData['sessionProgress']?[key] as double?) ?? 0.0;
            });
            _responseCount = (userData['responseCount'] as int?) ?? 0;
            _remainingSeconds =
                (userData['remainingSeconds'] as int?) ?? _timeGoalSeconds;
            logger.i(
                'Loaded progress: sessionProgress=$_sessionProgress, responseCount=$_responseCount, remainingSeconds=$_remainingSeconds');

            // Load messages from Firestore, separating by mode
            _nonSimulationMessages.clear();
            _simulationMessages.clear();
            (userData['nonSimulationMessages'] as List<dynamic>?)
                ?.forEach((msg) {
              _nonSimulationMessages.add(Map<String, dynamic>.from(msg));
            });
            (userData['simulationMessages'] as List<dynamic>?)?.forEach((msg) {
              _simulationMessages.add(Map<String, dynamic>.from(msg));
            });
            logger.i('Loaded non-simulation messages: $_nonSimulationMessages');
            logger.i('Loaded simulation messages: $_simulationMessages');
            _initializeTts();
          });
        }
      } else {
        logger.e('No onboarding data found for user');
        if (mounted)
          _showSnackBar(
              'No onboarding data found. Please complete onboarding.');
      }
    } catch (e) {
      logger.e('Error fetching preferences: $e');
      if (mounted) _showSnackBar('Error fetching preferences: $e');
    }
  }

  void _startTimer() {
    _timer?.cancel(); // Cancel any existing timer
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel(); // Cancel the timer if the widget is no longer mounted
        return;
      }
      if (_remainingSeconds > 0) {
        setState(() =>
            _remainingSeconds--); // Safe setState with mounted check above
      } else {
        timer.cancel();
        _stopListening();
        if (mounted) {
          _showSnackBar(
              'Time’s up for today’s practice!'); // This SnackBar appears
          _saveProgress(); // Save progress when timer ends
          _showContinuePracticeDialog(); // This opens the dialog
        }
      }
    });
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
              Navigator.pop(context); // Close dialog
              _showSnackBar(
                  'Practice session ended for today.'); // This SnackBar appears
              _saveProgress(); // Save progress and potentially navigate away
            },
            child: const Text('No, Stop'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _resetTimerAndContinue(); // Reset timer and allow more practice
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
        _remainingSeconds =
            _timeGoalSeconds; // Reset to the daily goal or a custom value
        _hasStartedListening = false; // Reset to allow new timer start
      });
      _startTimer(); // Restart the timer
      _showSnackBar(
          'You can continue practicing for another ${_formatTime(_timeGoalSeconds)}!');
    }
  }

  Future<void> _startListening() async {
    if (!_isListening && !_isTyping && _remainingSeconds > 0) {
      if (!_hasStartedListening) {
        _startTimer();
        _hasStartedListening = true;
      }

      logger.d(
          'Starting to listen. IsListening: $_isListening, IsTyping: $_isTyping, RemainingSeconds: $_remainingSeconds');

      try {
        if (!_isRecorderInitialized) {
          await _initRecorder();
        }
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
          'isSimulation': _isInSimulation
        });
        _pruneMessages();
      });
      _speakText(processedText, isUser: true);
      if (_isInSimulation) {
        _evaluateSimulationResponse(processedText);
      } else {
        _generateAIResponse(processedText);
        _evaluateUserInput(processedText);
      }
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

        logger.i('Playing recorded audio...');
        await _player
            .startPlayer(
          fromURI: _audioFilePath!,
          codec: Codec.pcm16WAV,
          whenFinished: () {
            logger.i('Audio playback finished.');
          },
        )
            .catchError((error) {
          logger.e('Error playing audio: $error');
          _showSnackBar('Error playing your voice: $error');
          return null;
        });

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
              'isSimulation': _isInSimulation
            });
            _lastRecognizedText = processedText; // Keep for consistency
            _pruneMessages();
          });
          logger.i('Transcribed text: $processedText');
          await Future.delayed(const Duration(milliseconds: 500));
          if (_isInSimulation) {
            await _evaluateSimulationResponse(processedText);
          } else {
            await _generateAIResponse(processedText);
            _evaluateUserInput(processedText);
          }
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

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
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
        await Future.delayed(
            const Duration(seconds: 2)); // Poll every 2 seconds
      }
    } catch (e) {
      _showSnackBar('AssemblyAI error: $e');
      return null;
    }
  }

  Future<String> _getOpenAIResponse(String prompt,
      {bool isSimulation = false, String? userInput}) async {
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
          'Sending request to OpenAI with prompt: $prompt, userInput: $userInput, isSimulation: $isSimulation');
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

      // Add user input only in non-simulation mode or as the latest user response in simulation
      if (!isSimulation && userInput != null) {
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
      setState(() => _isProcessingTTS = true); // Start processing indicator
      logger.d('Generating AI response for: $userInput');
      String aiResponse = await _getOpenAIResponse(
        'You are an advanced English-speaking assistant named TalkReady. You are designed to help non-native speakers improve their spoken English skills. Based on user’s speaking level and $_accentLocale, You provide clear, friendly, and constructive feedback while encouraging natural and confident communication.',
        isSimulation: false,
        userInput: userInput,
      );
      setState(() {
        _messages.add({'text': aiResponse, 'isUser': false});
        _isProcessingTTS = false;
        _isTyping = false;
      });
      logger.i('AI message added: $aiResponse');
      _speakText(aiResponse, isUser: false);
      _evaluateUserInput(userInput);
    }
  }

  Future<void> _evaluateUserInput(String userInput) async {
    _responseCount++;
    try {
      double fluencyScore = await _analyzeFluency(userInput);
      double grammarScore = await _analyzeGrammar(userInput);
      double vocabScore = await _analyzeVocabulary(userInput);
      double pronunciationScore =
          0.0; // Still placeholder (requires speech analysis)
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
        isSimulation: false,
      );
      return double.tryParse(response.trim()) ??
          0.1; // Default to 0.1 if parsing fails
    } catch (e) {
      logger.e('Error analyzing fluency: $e');
      return 0.1; // Fallback
    }
  }

  Future<double> _analyzeGrammar(String text) async {
    try {
      final response = await _getOpenAIResponse(
        'Analyze the following text for grammatical correctness on a scale of 0.0 to 1.0. Return only the number, e.g., 0.7. Text: "$text"',
        isSimulation: false,
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
        isSimulation: false,
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
        isSimulation: false,
      );
      return double.tryParse(response.trim()) ?? 0.1;
    } catch (e) {
      logger.e('Error analyzing interaction: $e');
      return 0.1;
    }
  }

  Future<void> _speakText(String text, {required bool isUser}) async {
    if (!mounted || isUser) return; // Only process AI responses
    setState(
        () => _isProcessingTTS = true); // Start showing processing indicator
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
      setState(
          () => _isProcessingTTS = false); // Stop showing processing indicator
    }
  }

  Future<void> _flutterTtsFallback(String text) async {
    try {
      if (text.contains('!')) {
        await _flutterTts.setPitch(0.9); // Excited tone for exclamations
        await _flutterTts.setSpeechRate(0.6); // Normal speed
      } else if (text.contains('?')) {
        await _flutterTts.setPitch(1.1); // Questioning tone
        await _flutterTts.setSpeechRate(0.85); // Slightly slower for questions
      } else {
        await _flutterTts.setPitch(0.9); // Neutral tone
        await _flutterTts.setSpeechRate(0.9); // Slightly slower for statements
      }
      await _flutterTts.setLanguage(
          _accentLocale ?? 'en_US'); // Match user’s accent or default to US
      await _flutterTts.speak(text);
      logger.d('Flutter TTS fallback played with locale: $_accentLocale');
    } catch (e) {
      logger.e('Error with Flutter TTS fallback: $e');
      _showSnackBar('TTS fallback failed: $e');
    }
  }

  void _saveProgress(
      {bool isStartingSimulation = false, bool showSnackBar = true}) {
    if (mounted) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'sessionProgress': _sessionProgress,
          'lastPracticeTime': FieldValue.serverTimestamp(),
          'totalPracticeTime':
              FieldValue.increment(_timeGoalSeconds - _remainingSeconds),
          'responseCount': _responseCount,
          'remainingSeconds': _remainingSeconds,
          'messages':
              _isInSimulation ? _simulationMessages : _nonSimulationMessages,
        }).then((value) {
          logger.i('Progress and messages saved to Firestore');
          if (showSnackBar && !isStartingSimulation) {
            _showSnackBar('Progress and chat history saved successfully.');
          }
          if (!isStartingSimulation) {
            Navigator.pop(
                context, _sessionProgress); // This navigates back to homepage
          }
        }).catchError((error) {
          logger.e('Error saving progress to Firestore: $error');
          if (showSnackBar) {
            _showSnackBar('Error saving progress. Please try again.');
          }
        });
      }
    }
  }

  void _pruneMessages() {
    if (_messages.length > 50) {
      _messages.removeRange(0, _messages.length - 50); // Keep last 50 messages
      logger.i('Pruned messages to last 50');
    }
    _saveMessagesToFirestore(); // Save pruned messages
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

  void _endSimulation() {
    logger.i(
        'Before ending simulation, _simulationMessages: $_simulationMessages');
    setState(() {
      _isInSimulation = false;
      _simulationMessages.clear(); // Clear only simulation messages
      // Huwag idagdag ang _initialGreeting kung naroroon na ito dati
      if (_nonSimulationMessages.isEmpty && _initialGreeting != null) {
        _nonSimulationMessages
            .insert(0, {'text': _initialGreeting!, 'isUser': false});
      }
      _sessionProgress.forEach((key, value) => _sessionProgress[key] = 0.0);
      _responseCount = 0;
      _lastRecognizedText = '';
      _isListening = false;
      _isTyping = false;
    });
    logger.i(
        'After ending simulation, _simulationMessages: $_simulationMessages, _nonSimulationMessages: $_nonSimulationMessages');
    // Iwasan ang pag-speak ng greeting ulit kung hindi kailangan
    if (_nonSimulationMessages.length == 1 && _initialGreeting != null) {
      _speakText(_initialGreeting!,
          isUser: false); // Speak lamang kung ito lang ang mensahe
    }
    _saveProgress(isStartingSimulation: true); // Suppress navigation
    _showSnackBar('Simulation ended.');
  }

  void _showSimulationMode() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0), // Softer, rounded corners
        ),
        elevation: 8.0, // Subtle shadow for depth
        backgroundColor: Colors.white, // Clean white background
        child: Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue.shade50, // Light blue for a soothing gradient
                Colors.white, // White for contrast
              ],
            ),
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title with custom styling
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Text(
                  'Choose Your Simulation Mode',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade600, // Dark blue for title
                    letterSpacing: 1.0,
                    shadows: [
                      Shadow(
                        color: Colors.blue.shade100,
                        offset: const Offset(1, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
              // Simulation options with icons and dividers
              Expanded(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    _buildSimulationOption(
                      context: context,
                      title: 'Beginner - Customer Inquiry',
                      icon: Icons.person_outline,
                      onTap: () {
                        Navigator.pop(context);
                        _startSimulation('beginner_inquiry');
                      },
                    ),
                    Divider(
                        color: Colors.blue.shade200,
                        thickness: 1.0,
                        height: 1.0),
                    _buildSimulationOption(
                      context: context,
                      title: 'Intermediate - Customer Complaint',
                      icon: Icons.warning_amber_rounded,
                      onTap: () {
                        Navigator.pop(context);
                        _startSimulation('intermediate_complaint');
                      },
                    ),
                    Divider(
                        color: Colors.blue.shade200,
                        thickness: 1.0,
                        height: 1.0),
                    _buildSimulationOption(
                      context: context,
                      title: 'Advanced - Upselling',
                      icon: Icons.attach_money,
                      onTap: () {
                        Navigator.pop(context);
                        _startSimulation('advanced_upsell');
                      },
                    ),
                    Divider(
                        color: Colors.blue.shade200,
                        thickness: 1.0,
                        height: 1.0),
                    _buildSimulationOption(
                      context: context,
                      title: 'Technical Support - Troubleshooting',
                      icon: Icons.support_agent,
                      onTap: () {
                        Navigator.pop(context);
                        _startSimulation('technical_support');
                      },
                    ),
                  ],
                ),
              ),
              // Actions (Cancel button) with custom styling
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blue.shade900, // Text color
                        backgroundColor:
                            Colors.blue.shade100, // Light blue background
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(12.0), // Rounded corners
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

// Helper method to build each simulation option with a consistent aesthetic
  Widget _buildSimulationOption({
    required BuildContext context,
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      leading: Icon(
        icon,
        color: Colors.blue.shade500, // Consistent icon color
        size: 28.0,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: Colors.blue.shade900, // Dark blue for text
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(8.0), // Slight rounding for each item
      ),
      tileColor: Colors.blue.shade50, // Light blue background for each option
      hoverColor: Colors.blue.shade100, // Subtle hover effect
      focusColor: Colors.blue.shade100, // Subtle focus effect
    );
  }

  void _startSimulation(String scenario) {
    logger.i('Before starting simulation, _messages: $_messages');
    logger.i(
        'Starting simulation. _isInSimulation: $_isInSimulation, scenario: $scenario, remainingSeconds: $_remainingSeconds');
    setState(() {
      _isInSimulation = true;
      _messages.clear(); // Clear all messages to start fresh for simulation
      _sessionProgress.forEach(
          (key, value) => _sessionProgress[key] = 0.0); // Reset progress
      _responseCount = 0;
    });
    logger.i('After starting simulation, _messages: $_messages');
    _simulateCallCenterScenario(scenario);
    _saveProgress(isStartingSimulation: true); // Pass flag to skip navigation
  }

  Future<void> _simulateCallCenterScenario(String scenario) async {
    String aiPrompt;
    switch (scenario) {
      case 'beginner_inquiry':
        aiPrompt = "Hello, can you confirm my account balance?";
        break;
      case 'intermediate_complaint':
        aiPrompt = "I’m upset about a late delivery—can you help?";
        break;
      case 'advanced_upsell':
        aiPrompt =
            "I’m interested in your basic plan. Do you have anything better?";
        break;
      case 'technical_support':
        aiPrompt = "My internet isn’t working—can you assist?";
        break;
      default:
        aiPrompt = "Hello, how can I assist you today?";
    }

    setState(() {
      _messages.add({'text': aiPrompt, 'isUser': false, 'isSimulation': true});
    });
    await _speakText(aiPrompt, isUser: false);
    _showSnackBar('Tap the microphone to respond as a call center agent.');
  }

  Future<void> _evaluateSimulationResponse(String userResponse) async {
    if (!_isInSimulation) {
      logger.w('Not in simulation mode, skipping evaluation.');
      return;
    }

    // Get the last AI prompt (customer’s previous message) for context
    String lastPrompt = _messages.lastWhere((msg) => !msg['isUser'],
        orElse: () => {'text': ''})['text'] as String;
    String scenarioType = _messages
            .any((msg) => msg['isSimulation'] && !msg['isUser'])
        ? _messages
            .firstWhere((msg) => msg['isSimulation'] && !msg['isUser'])['text']
        : 'general';

    // Prepare the system prompt for OpenAI
    String systemPrompt = '''
You are a realistic call center customer speaking with an agent. Respond naturally and appropriately based on the scenario and the agent’s response. Use phrasing and vocabulary typical of ${_accentLocale ?? 'en_US'} (e.g., "mate" for Australian, "cheers" for British, "buddy" for American). Maintain a consistent tone: polite but potentially frustrated or inquisitive depending on the scenario.

Scenario: $scenarioType
Agent’s response: "$userResponse"
Last customer prompt: "$lastPrompt"
Provide a short, single response (1-2 sentences) as the customer, continuing the conversation or concluding if appropriate.
''';

    try {
      String aiResponse = await _getOpenAIResponse(
        systemPrompt,
        isSimulation: true,
      );
      setState(() {
        _messages
            .add({'text': aiResponse, 'isUser': false, 'isSimulation': true});
      });
      await _evaluateUserInput(userResponse);
      await _speakText(aiResponse, isUser: false);
      _showSnackBar('Tap the microphone to respond again.');
    } catch (e) {
      logger.e('Error generating AI response for simulation: $e');
      _showSnackBar('Error in simulation response. Please try again.');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _flutterTts.stop();
    _recorder.closeRecorder();
    _player.closePlayer();
    _textController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          Padding(
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
        ],
        leading: _isInSimulation
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.red),
                onPressed: _endSimulation,
                tooltip: 'End Simulation',
              )
            : null,
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: ListView.builder(
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  return ChatMessage(
                    message: message['text'],
                    isUser: message['isUser'],
                    isSimulation: message['isSimulation'] ?? false,
                  );
                },
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
          if (_isInSimulation)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'Simulation Mode: Respond as\na call center agent',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.amber,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: IconRow(
              onMicTap: () =>
                  _isListening ? _stopListening() : _startListening(),
              onKeyboardTap: _toggleTyping,
              onModeTap: _showSimulationMode,
              isListening: _isListening,
              isTyping: _isTyping,
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage extends StatelessWidget {
  final String message;
  final bool isUser;
  final bool isSimulation;

  const ChatMessage({
    super.key,
    required this.message,
    required this.isUser,
    this.isSimulation = false,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUser
              ? Colors.blue[100]
              : isSimulation
                  ? Colors
                      .amber[100] // Amber background for simulation AI messages
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
        child: Text(message),
      ),
    );
  }
}

class IconRow extends StatelessWidget {
  final VoidCallback onMicTap;
  final VoidCallback onKeyboardTap;
  final VoidCallback onModeTap;
  final bool isListening;
  final bool isTyping;

  const IconRow({
    super.key,
    required this.onMicTap,
    required this.onKeyboardTap,
    required this.onModeTap,
    required this.isListening,
    required this.isTyping,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildIcon(Icons.keyboard, Colors.purple.shade200, onKeyboardTap,
            isActive: isTyping),
        const SizedBox(width: 20),
        _buildIcon(
          isListening ? Icons.stop : Icons.mic,
          Colors.blue.shade300,
          onMicTap,
          isActive: isListening,
        ),
        const SizedBox(width: 20),
        _buildIcon(Icons.play_circle, Colors.amber.shade200, onModeTap,
            isActive: false), // Use play_circle for Mode
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
