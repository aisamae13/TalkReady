import 'package:flutter/material.dart' hide CarouselController;
import 'package:carousel_slider/carousel_slider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:logger/logger.dart';
import 'dart:convert'; // For jsonEncode
import 'package:http/http.dart' as http; // For HTTP requests
import 'package:flutter_tts/flutter_tts.dart';
// import 'dart:io'; // Not explicitly used at top level, but File is used in Firebase/Cloudinary logic. FirebaseService handles File ops.
import '../firebase_service.dart';
import '../lessons/lesson3_1.dart'; // Ensure correct class name is buildLesson3_1
import '../lessons/lesson3_2.dart'; // Ensure correct class name is buildLesson3_2
// import 'package:cloudinary_public/cloudinary_public.dart'; // REMOVED - No longer using Cloudinary

class Module3Page extends StatefulWidget {
  final String? targetLessonKey;
  const Module3Page({super.key, this.targetLessonKey});

  @override
  State<Module3Page> createState() => _Module3PageState();
}

class _Module3PageState extends State<Module3Page> {
  int currentLesson = 1; // 1 for L3.1, 2 for L3.2
  bool showActivitySection = false; // Unified flag to show activity area
  YoutubePlayerController _youtubeController = YoutubePlayerController(
    initialVideoId: '', // Dummy, non-null initial value
    flags: const YoutubePlayerFlags(autoPlay: false),
  );
  int _currentSlide = 0;
  final CarouselSliderController _carouselController =
      CarouselSliderController();
  final Logger _logger = Logger();
  final FirebaseService _firebaseService = FirebaseService(); //
  late FlutterTts flutterTts;
  final Map<int, String?> _videoIds = {
    1: 'qY9iPdZfOic', // Lesson 3.1: Listening Comprehension video ID
    2: null, // Lesson 3.2: No YouTube video
  };

  // REMOVED Cloudinary specific variables
  // final String _cloudinaryCloudName = 'dchj7fhyn';
  // final String _cloudinaryUploadPreset = 'audio_upload';

  Map<String, dynamic>? _aiFeedbackDataCurrentLesson;
  int? _overallScoreCurrentLesson;
  int? _maxScoreCurrentLesson;
  bool _shouldDisplayFeedbackCurrentLesson = false;

  String? _youtubeError;
  Map<String, bool> _lessonCompletion = {'lesson1': false, 'lesson2': false};
  late Map<String, int> _lessonAttemptCounts;
  bool _isContentLoaded = false;
  bool _isLoadingNextLesson = false;
  bool _isSubmittingToServer = false;

  Map<String, dynamic>? _lessonData;
  List<dynamic> _speakingPrompts = [];
  Map<String, PromptAttemptData> _lesson3_2PromptDataMap =
      {}; // From lesson3_2.dart via state or props

  // Map to convert lesson number to Firestore key (used by FirebaseService)
  final Map<int, String> _lessonNumericToFirestoreKey = {
    1: "Lesson 3.1",
    2: "Lesson 3.2",
  };

  @override
  void initState() {
    super.initState();
    flutterTts = FlutterTts();
    _lessonAttemptCounts = {'lesson1': 0, 'lesson2': 0}; //
    _performAsyncInit();
  }

  Future<void> _initializeAndConfigureTts() async {
    await _configureTts();
  }

  Future<void> _configureTts() async {
    try {
      await flutterTts.stop();
      await flutterTts.setLanguage("en-US"); //
      await flutterTts.setSpeechRate(0.45); //
      await flutterTts.setVolume(1.0); //
      await flutterTts.setPitch(1.0); //
      _logger.i("L3.1: Flutter TTS configured."); //
    } catch (e) {
      _logger.e("L3.1: Error configuring TTS: $e"); //
    }
  }

  Future<void> _playScript(String scriptText) async {
    try {
      await flutterTts.stop();
      int result = await flutterTts.speak(scriptText); //
      if (result == 1) {
        _logger.i("L3.1: TTS speaking script..."); //
      } else {
        _logger.w("L3.1: TTS speak command failed."); //
      }
    } catch (e) {
      _logger.e("L3.1: Error during TTS speak: $e"); //
    }
  }

  Future<void> _performAsyncInit() async {
    setState(() => _isContentLoaded = false);
    try {
      await _loadLessonProgress(); //
      _initializeYoutubeController(); //
      _resetUIForCurrentLesson(); //
      await _loadLessonSpecificData(); // Added to ensure L3.2 prompts are ready
      if (mounted) {
        setState(() {
          showActivitySection =
              _lessonCompletion['lesson$currentLesson'] ?? false; //
          _isContentLoaded = true;
        });
      }
    } catch (error) {
      _logger.e("Error during initState loading for Module 3: $error"); //
      if (mounted) {
        setState(() {
          _youtubeError = "Failed to load lesson content. Please try again."; //
          _isContentLoaded = true;
        });
      }
    }
  }

  void _initializePromptAttemptDataL3_2() {
    _lesson3_2PromptDataMap.clear();
    if (_lessonData != null && currentLesson == 2) {
      final activityData =
          (_lessonData!['activity'] as Map<String, dynamic>?) ?? {}; //
      _speakingPrompts =
          activityData['speakingPrompts'] as List<dynamic>? ?? []; //
      for (var prompt in _speakingPrompts) {
        if (prompt is Map && prompt['id'] is String) {
          _lesson3_2PromptDataMap[prompt['id']] = PromptAttemptData(); //
        }
      }
      _logger.i(
          "L3.2: Initialized/Reset _lesson3_2PromptDataMap for ${_speakingPrompts.length} prompts."); //
    } else if (currentLesson == 2) {
      _logger.w(
          "L3.2: _lessonData is null or not for L3.2 during _initializePromptAttemptDataL3_2. Prompts might be empty."); //
      _speakingPrompts = [];
    }
  }

  void _resetUIForCurrentLesson() {
    _aiFeedbackDataCurrentLesson = null; //
    _overallScoreCurrentLesson = null; //
    _maxScoreCurrentLesson = null; //
    _shouldDisplayFeedbackCurrentLesson = false; //
    _logger.i("Resetting UI for Lesson $currentLesson"); //

    if (currentLesson == 2) {
      _initializePromptAttemptDataL3_2(); //
    }
  }

  Future<void> _loadLessonSpecificData() async {
    if (currentLesson == 2) {
      // Hardcoded data for Lesson 3.2 speaking prompts
      final Map<String, dynamic> hardcodedLesson3_2ActivityData = {
        'speakingPrompts': [
          //
          {
            'id': 'd1_agent1',
            'text':
                "Good morning! This is Anna from TechSupport. How can I assist you?",
            'character': "Agent"
          },
          {
            'id': 'd1_agent2',
            'text':
                "I’m sorry about that. Can I get your account number, please?",
            'character': "Agent"
          },
          {
            'id': 'd2_agent1',
            'text':
                "Hello! Thank you for calling. What can I help you with today?",
            'character': "Agent"
          },
          {
            'id': 'd2_agent2',
            'text': "Certainly. May I have your tracking number?",
            'character': "Agent"
          },
          {
            'id': 'd3_agent1',
            'text':
                "Thank you for waiting. I’ve confirmed your refund has been processed.",
            'character': "Agent"
          },
          {
            'id': 'd3_agent2',
            'text': "You're welcome! Have a great day.",
            'character': "Agent"
          },
        ],
      };
      // This is a simplified way to ensure _lessonData for L3.2 has the prompts
      // In a more dynamic system, this would come from a service.
      setState(() {
        _lessonData = {'activity': hardcodedLesson3_2ActivityData};
        _speakingPrompts = hardcodedLesson3_2ActivityData['speakingPrompts']
                as List<dynamic>? ??
            [];
        _initializePromptAttemptDataL3_2(); // Initialize after _speakingPrompts is set
      });
    } else {
      // For L3.1, content is mostly managed within lesson3_1.dart itself
      // _lessonData might not be strictly needed here if lesson3_1.dart handles its own content structure.
      setState(() {
        _lessonData = {}; // Reset or set minimal data for L3.1 if needed
      });
    }
  }

  Future<void> _loadLessonProgress() async {
    try {
      final progress = await _firebaseService.getModuleProgress('module3'); //
      final lessonsData = progress['lessons'] as Map<String, dynamic>? ?? {}; //
      final attemptData =
          progress['attempts'] as Map<String, dynamic>? ?? {}; //

      _lessonCompletion = {
        'lesson1': lessonsData['lesson1'] ?? false, //
        'lesson2': lessonsData['lesson2'] ?? false, //
      };

      _lessonAttemptCounts = {
        'lesson1': attemptData['lesson1'] as int? ?? 0, //
        'lesson2': attemptData['lesson2'] as int? ?? 0, //
      };

      if (widget.targetLessonKey != null) {
        //
        _logger.i(
            "Module 3: Target lesson key provided: ${widget.targetLessonKey}"); //
        switch (widget.targetLessonKey) {
          case 'lesson1':
            currentLesson = 1;
            break; //
          case 'lesson2':
            currentLesson = 2;
            break; //
          default:
            _logger.w(
                "Module 3: Unknown targetLessonKey: ${widget.targetLessonKey}. Defaulting."); //
            if (!(_lessonCompletion['lesson1'] ?? false))
              currentLesson = 1; //
            else if (!(_lessonCompletion['lesson2'] ?? false))
              currentLesson = 2; //
            else
              currentLesson = 2; //
        }
      } else {
        if (!(_lessonCompletion['lesson1'] ?? false))
          currentLesson = 1; //
        else if (!(_lessonCompletion['lesson2'] ?? false))
          currentLesson = 2; //
        else
          currentLesson = 2; //
      }
      _logger.i(
          'Module 3: Loaded lesson progress: currentLesson=$currentLesson, completion=$_lessonCompletion, attempts=$_lessonAttemptCounts'); //
    } catch (e) {
      _logger.e('Module 3: Error loading lesson progress: $e'); //
      currentLesson = 1; //
      _lessonCompletion = {'lesson1': false, 'lesson2': false}; //
      _lessonAttemptCounts = {'lesson1': 0, 'lesson2': 0}; //
      rethrow;
    }
  }

  void _initializeYoutubeController() {
    String? videoId = _videoIds[currentLesson]; //
    _logger.i(
        'Module 3: Initializing/Updating YouTube controller for Lesson $currentLesson: videoId=$videoId'); //
    if (_youtubeController.initialVideoId != (videoId ?? '')) {
      _youtubeController.load(videoId ?? ''); //
    } else if (videoId == null || videoId.isEmpty) {
      _youtubeController.load(''); //
    }

    if (videoId != null && videoId.isNotEmpty) {
      if (mounted &&
          _youtubeController.initialVideoId == videoId &&
          _youtubeController.value.isReady) {
        //
        _logger.i(
            'Module 3: YouTube controller already initialized for $videoId.'); //
        return;
      }
      _youtubeController = YoutubePlayerController(
        //
        initialVideoId: videoId, //
        flags: const YoutubePlayerFlags(
            autoPlay: false,
            mute: false,
            enableCaption: true,
            captionLanguage: 'en',
            hideControls: false), //
      );
      _youtubeController.addListener(() {
        //
        if (_youtubeController.value.errorCode != 0 && mounted) {
          setState(() => _youtubeError =
              'YT Error: ${_youtubeController.value.errorCode}'); //
        }
      });
      if (mounted) setState(() => _youtubeError = null); //
    } else {
      _logger.w(
          'Module 3: No video ID for Lesson $currentLesson. Creating controller with empty ID.'); //
      _youtubeController = YoutubePlayerController(
          initialVideoId: '',
          flags: const YoutubePlayerFlags(autoPlay: false)); //
      if (mounted) setState(() => _youtubeError = null); //
    }
  }

  Future<void> _handleSubmitLesson3_1(
    Map<String, String> userTextAnswers,
    int timeSpent,
    int attemptNumber,
  ) async {
    setState(() => _isSubmittingToServer = true);
    _logger.i(
        "L3.1 Submission: Attempt $attemptNumber, Time $timeSpent, Answers: $userTextAnswers"); //

    try {
      final response = await http
          .post(
            //
            Uri.parse('http://192.168.254.103:5000/evaluate-scenario'), //
            headers: {'Content-Type': 'application/json'}, //
            body: jsonEncode(
                {'answers': userTextAnswers, 'lesson': 'Lesson 3.1'}), //
          )
          .timeout(const Duration(seconds: 60)); //

      if (!mounted) return;

      if (response.statusCode == 200) {
        //
        final result = jsonDecode(response.body); //
        final feedbackMap = result['feedback'] as Map<String, dynamic>?; //
        int calculatedScore = 0; //
        int maxScore = 0; //
        if (feedbackMap != null) {
          feedbackMap.forEach((key, value) {
            //
            if (value is Map && value['score'] is num) {
              calculatedScore += (value['score'] as num).toInt(); //
            }
            maxScore += 5; // Assuming each question is out of 5
          });
        }
        setState(() {
          _aiFeedbackDataCurrentLesson = feedbackMap; //
          _overallScoreCurrentLesson = calculatedScore; //
          _maxScoreCurrentLesson = maxScore; //
          _shouldDisplayFeedbackCurrentLesson = true; //
          showActivitySection = true; //
        });
        await _firebaseService.saveSpecificLessonAttempt(
          //
          lessonIdKey: "Lesson 3.1", //
          score: calculatedScore, //
          attemptNumberToSave: attemptNumber, //
          timeSpent: timeSpent, //
          detailedResponsesPayload: {
            'answers': userTextAnswers,
            'feedbackForAnswers': feedbackMap
          }, //
        );
        await _saveLessonProgressStatus(1); //
      } else {
        _logger.e(
            "L3.1 AI Server Error: ${response.statusCode} - ${response.body}"); //
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text("Error getting feedback: ${response.reasonPhrase}"))); //
      }
    } catch (e) {
      _logger.e("L3.1 Submission Exception: $e"); //
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Submission failed: $e"))); //
    } finally {
      if (mounted) setState(() => _isSubmittingToServer = false); //
    }
  }

  // REMOVED _uploadAudioToCloudinary method

  Future<Map<String, dynamic>?> _handleProcessAudioPromptL3_2(
      String localAudioPath, String originalText, String promptId) async {
    setState(() => _isSubmittingToServer = true);
    _logger.i(
        "L3.2 Module: Received local audio path for prompt '$promptId': $localAudioPath"); //

    // STEP 1: Upload the local audio file to FIREBASE STORAGE
    final String lessonKeyForFirebase =
        _lessonNumericToFirestoreKey[2] ?? "Lesson 3.2"; // Specific for L3.2

    String? firebaseStorageUrl = await _firebaseService.uploadLessonAudio(
        // Using existing method from FirebaseService
        localAudioPath,
        lessonKeyForFirebase,
        promptId); //

    if (firebaseStorageUrl == null || firebaseStorageUrl.isEmpty) {
      _logger.e(
          "L3.2 Module: Firebase Storage upload failed. Cannot proceed for prompt '$promptId'."); //
      if (mounted) setState(() => _isSubmittingToServer = false);
      return {
        'success': false, //
        'error': 'Audio upload to Firebase Storage failed.',
        'audioStorageUrlFromModule': null // Changed key
      };
    }

    _logger.i(
        "L3.2 Module: Uploaded to Firebase Storage: $firebaseStorageUrl. Now calling server for Azure eval."); //

    // STEP 2: Call your backend with the REAL FIREBASE STORAGE DOWNLOAD URL
    try {
      final response = await http
          .post(
            //
            Uri.parse(
                'http://192.168.254.103:5000/evaluate-speech-with-azure'), //
            headers: {'Content-Type': 'application/json'}, //
            body: jsonEncode({
              //
              'audioUrl':
                  firebaseStorageUrl, // SEND THE REAL FIREBASE STORAGE URL
              'originalText': originalText, //
              'language': 'en-US' //
            }),
          )
          .timeout(const Duration(seconds: 120)); //

      if (!mounted) return null;

      if (response.statusCode == 200) {
        //
        final result = jsonDecode(response.body) as Map<String, dynamic>; //
        _logger.i(
            "L3.2 Module: Azure Feedback for '$promptId' received from server: Success"); //
        return {
          ...result, //
          'audioStorageUrlFromModule':
              firebaseStorageUrl // Pass back the Firebase URL with new key
        };
      } else {
        final errorBody = jsonDecode(response.body); //
        _logger.e(
            "L3.2 Module: Server Error (Azure eval) for '$promptId': ${response.statusCode} - ${response.body}"); //
        return {
          'success': false, //
          'error':
              errorBody['error'] ?? response.reasonPhrase ?? 'Server error', //
          'audioStorageUrlFromModule': firebaseStorageUrl //
        };
      }
    } catch (e) {
      _logger.e(
          "L3.2 Module: HTTP Exception during Azure eval for '$promptId': $e"); //
      return {
        'success': false, //
        'error': e.toString(), //
        'audioStorageUrlFromModule': firebaseStorageUrl //
      };
    } finally {
      if (mounted) setState(() => _isSubmittingToServer = false); //
    }
  }

  Future<String?> _handleExplainAzureFeedbackL3_2(
      Map<String, dynamic> azureFeedback, String originalText) async {
    setState(() => _isSubmittingToServer = true);
    _logger.i("L3.2 Getting OpenAI explanation for Azure feedback."); //
    try {
      final response = await http
          .post(
            //
            Uri.parse(
                'http://192.168.254.103:5000/explain-azure-feedback-with-openai'), // Placeholder
            headers: {'Content-Type': 'application/json'}, //
            body: jsonEncode({
              'azureFeedback': azureFeedback,
              'originalText': originalText
            }), //
          )
          .timeout(const Duration(seconds: 60)); //

      if (!mounted) return null;
      if (response.statusCode == 200) {
        //
        final result = jsonDecode(response.body); //
        _logger.i(
            "L3.2 OpenAI Explanation: ${result['detailedFeedback'] != null}"); //
        return result['detailedFeedback'] as String?; //
      } else {
        _logger.e(
            "L3.2 OpenAI Server Error: ${response.statusCode} - ${response.body}"); //
        return "Error getting coach's explanation: ${response.reasonPhrase}"; //
      }
    } catch (e) {
      _logger.e("L3.2 OpenAI Exception: $e"); //
      return "Failed to get coach's explanation: $e"; //
    } finally {
      if (mounted && currentLesson == 2)
        setState(() => _isSubmittingToServer = false); //
    }
  }

  Future<void> _handleSubmitLessonL3_2(
    List<Map<String, dynamic>> submittedPromptData,
    Map<String, String> reflections,
    double overallScore,
    int timeSpent,
    int attemptNumber,
  ) async {
    setState(() => _isSubmittingToServer = true);
    _logger.i(
        "L3.2 Submitting Full Lesson: Attempt $attemptNumber, Overall Score $overallScore, Time $timeSpent"); //

    try {
      await _firebaseService.saveSpecificLessonAttempt(
        //
        lessonIdKey: "Lesson 3.2", //
        score: overallScore.round(), //
        attemptNumberToSave: attemptNumber, //
        timeSpent: timeSpent, //
        detailedResponsesPayload: {
          //
          'overallScore': overallScore, //
          'reflections': reflections, //
          'promptDetails': submittedPromptData, //
        },
      );
      if (!mounted) return;
      setState(() {
        showActivitySection = true; //
      });
      await _saveLessonProgressStatus(2); //
      _logger.i(
          "L3.2 Lesson submission successful for attempt $attemptNumber."); //
    } catch (e) {
      _logger.e("L3.2 Error submitting full lesson: $e"); //
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to submit lesson: $e"))); //
    } finally {
      if (mounted) setState(() => _isSubmittingToServer = false); //
    }
  }

  Future<void> _saveLessonProgressStatus(int lessonNumberInModule) async {
    final lessonFirebaseKey = 'lesson$lessonNumberInModule'; //
    final currentAttempts = Map<String, int>.from(_lessonAttemptCounts); //
    currentAttempts[lessonFirebaseKey] =
        (currentAttempts[lessonFirebaseKey] ?? 0) + 1; //

    await _firebaseService.updateLessonProgress(
        'module3', lessonFirebaseKey, true,
        attempts: currentAttempts); //
    if (mounted) {
      setState(() {
        _lessonCompletion[lessonFirebaseKey] = true; //
        _lessonAttemptCounts = currentAttempts; //
      });
    }
  }

  @override
  void dispose() {
    if (mounted) {
      _youtubeController.pause(); //
      _youtubeController.dispose(); //
    }
    flutterTts.stop(); // Added to ensure TTS is stopped
    super.dispose();
    _logger.i('Disposed Module3Page'); //
  }

  @override
  Widget build(BuildContext context) {
    if (!_isContentLoaded) {
      return Scaffold(
          appBar: AppBar(title: const Text('Module 3')),
          body: const Center(child: CircularProgressIndicator())); //
    }

    bool isModuleCompleted =
        _lessonCompletion.values.every((completed) => completed); //
    int initialAttemptForChild =
        _lessonAttemptCounts['lesson$currentLesson'] ?? 0; //

    return Scaffold(
      appBar: AppBar(
        title: Text(currentLesson == 1
            ? 'Module 3: Listening Comprehension'
            : 'Module 3: Speaking Practice'), //
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context)), //
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0), //
              child: Column(
                children: [
                  Text('Lesson $currentLesson of 2',
                      style:
                          const TextStyle(fontSize: 16, color: Colors.grey)), //
                  const SizedBox(height: 16), //
                  if (_youtubeError != null)
                    Center(
                        child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(_youtubeError!,
                                style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold)))), //

                  _buildLessonContentWidget(initialAttemptForChild), //

                  if (showActivitySection &&
                      _shouldDisplayFeedbackCurrentLesson &&
                      _youtubeError == null) ...[
                    //
                    const SizedBox(height: 24), //
                    if (currentLesson < 2)
                      ElevatedButton(
                        //
                        onPressed: _isLoadingNextLesson
                            ? null
                            : () async {
                                //
                                setState(() => _isLoadingNextLesson = true); //
                                await Future.delayed(
                                    const Duration(milliseconds: 300)); //
                                if (mounted) {
                                  setState(() {
                                    currentLesson++; //
                                    _initializeYoutubeController(); //
                                    _resetUIForCurrentLesson(); //
                                    _loadLessonSpecificData(); // Reload data for the new lesson
                                    showActivitySection = _lessonCompletion[
                                            'lesson$currentLesson'] ??
                                        false; //
                                    _currentSlide = 0; //
                                    if (_carouselController.ready)
                                      _carouselController.jumpToPage(0); //
                                    _isLoadingNextLesson = false; //
                                  });
                                }
                              },
                        child: _isLoadingNextLesson
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Next Lesson'), //
                      )
                    else if (currentLesson == 2)
                      ElevatedButton(
                        //
                        onPressed: () => Navigator.pop(context), //
                        style: ElevatedButton.styleFrom(
                            backgroundColor: isModuleCompleted
                                ? Colors.green
                                : Theme.of(context).primaryColor), //
                        child: Text(isModuleCompleted
                            ? 'Module Completed - Return'
                            : 'Finish Module & Return'), //
                      )
                  ],
                ],
              ),
            ),
            if (_isSubmittingToServer) //
              Container(
                //
                color: Colors.black.withOpacity(0.3), //
                child: const Center(child: CircularProgressIndicator()), //
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonContentWidget(int initialAttemptNumberForLesson) {
    VoidCallback onShowActivityCallback = () {
      //
      if (mounted) {
        setState(() {
          showActivitySection = true; //
          _shouldDisplayFeedbackCurrentLesson = false; //
          _aiFeedbackDataCurrentLesson = null; //
          _overallScoreCurrentLesson = null; //
          _maxScoreCurrentLesson = null; //
          _resetUIForCurrentLesson(); //
        });
      }
    };

    switch (currentLesson) {
      case 1:
        return buildLesson3_1(
          //
          parentContext: context, //
          currentSlide: _currentSlide, //
          carouselController: _carouselController, //
          youtubeController: _youtubeController, //
          youtubePlayerKey: ValueKey('yt_m3_l1_${_videoIds[1]}'), //
          showActivitySectionInitially: showActivitySection, //
          onShowActivitySection: onShowActivityCallback, //
          onSubmitAnswers: _handleSubmitLesson3_1, //
          onSlideChanged: (index) => setState(() => _currentSlide = index), //
          initialAttemptNumber: initialAttemptNumberForLesson, //
          displayFeedback: _shouldDisplayFeedbackCurrentLesson, //
          aiFeedbackData: _aiFeedbackDataCurrentLesson, //
          overallAIScoreForDisplay: _overallScoreCurrentLesson, //
          maxPossibleAIScoreForDisplay: _maxScoreCurrentLesson, //
        );
      case 2:
        return buildLesson3_2(
          //
          parentContext: context, //
          currentSlide: _currentSlide, //
          carouselController: _carouselController, //
          showActivitySectionInitially: showActivitySection, //
          onShowActivitySection: onShowActivityCallback, //
          onProcessAudioPrompt: _handleProcessAudioPromptL3_2, //
          onExplainAzureFeedback: _handleExplainAzureFeedbackL3_2, //
          onSubmitLesson: _handleSubmitLessonL3_2, //
          onSlideChanged: (index) => setState(() => _currentSlide = index), //
          initialAttemptNumber: initialAttemptNumberForLesson, //
          displayFeedback: _shouldDisplayFeedbackCurrentLesson, //
        );
      default:
        _logger.w(
            'Module 3: Invalid lesson number in _buildLessonContentWidget: $currentLesson'); //
        return Center(child: Text('Error: Invalid lesson $currentLesson')); //
    }
  }
}
