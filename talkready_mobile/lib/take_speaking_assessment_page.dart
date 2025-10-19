import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'firebase_service.dart';

class TakeSpeakingAssessmentPage extends StatefulWidget {
  final String assessmentId;
  final String? classId;

  const TakeSpeakingAssessmentPage({
    super.key,
    required this.assessmentId,
    this.classId,
  });

  @override
  State<TakeSpeakingAssessmentPage> createState() =>
      _TakeSpeakingAssessmentPageState();
}

class _TakeSpeakingAssessmentPageState extends State<TakeSpeakingAssessmentPage>
    with TickerProviderStateMixin {
  final Logger _logger = Logger();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseService _firebaseService = FirebaseService();

  // Audio recording
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();

  // State variables
  Map<String, dynamic>? assessment;
  bool loading = true;
  bool isSubmitting = false;
  bool hasAlreadySubmitted = false;
  bool isDeadlinePassed = false;
  String error = '';
  String? existingSubmissionId;

  // Recording states
  RecordingStatus recordingStatus = RecordingStatus.inactive;
  String? audioFilePath;
  String? audioUrl;
  bool isPlaying = false;
  Duration recordingDuration = Duration.zero;
  Duration playbackPosition = Duration.zero;

    // NEW: Enhanced recording features
    Timer? _durationTimer;
    Timer? _fileSizeTimer;
    int _fileSize = 0;
    double _audioLevel = 0.0;
    String _audioQuality = 'Good';
    StreamSubscription? _recorderSubscription;

 // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late AnimationController _waveController; // ADD THIS LINE
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeAudio();
    _fetchAssessmentAndCheckSubmission();
  }

void _initializeAnimations() {
  _fadeController = AnimationController(
    duration: const Duration(milliseconds: 600),
    vsync: this,
  );
  _pulseController = AnimationController(
    duration: const Duration(milliseconds: 1500),
    vsync: this,
  );
  // ADD THIS:
  _waveController = AnimationController(
    duration: const Duration(milliseconds: 800),
    vsync: this,
  );

  _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
    CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
  );
}

 Future<void> _initializeAudio() async {
  try {
    await _recorder.openRecorder();
    await _player.openPlayer();

    // ADD THIS: Subscribe to audio level updates
    _recorderSubscription = _recorder.onProgress?.listen((event) {
      if (mounted && recordingStatus == RecordingStatus.recording) {
        setState(() {
          _audioLevel = event.decibels ?? 0.0;
          _updateAudioQuality(event.decibels ?? 0.0);
        });
      }
    });
  } catch (e) {
    _logger.e("Error initializing audio: $e");
  }
}

void _updateAudioQuality(double decibels) {
  // Typical speaking range is -60 to -20 dB
  if (decibels > -30) {
    _audioQuality = 'Excellent';
  } else if (decibels > -45) {
    _audioQuality = 'Good';
  } else if (decibels > -60) {
    _audioQuality = 'Fair';
  } else {
    _audioQuality = 'Low';
  }
}

 @override
void dispose() {
  // ADD THESE:
  _durationTimer?.cancel();
  _fileSizeTimer?.cancel();
  _recorderSubscription?.cancel();

  _recorder.closeRecorder();
  _player.closePlayer();
  _fadeController.dispose();
  _pulseController.dispose();
  _waveController.dispose(); // ADD THIS
  super.dispose();
}
  Future<void> _fetchAssessmentAndCheckSubmission() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        loading = false;
        error = 'You must be logged in to take an assessment.';
      });
      return;
    }

    try {
      // Fetch assessment details
      final doc = await _firestore
          .collection('trainerAssessments')
          .doc(widget.assessmentId)
          .get();

      if (!doc.exists) {
        throw Exception('Assessment not found.');
      }

      final data = doc.data()!;
      final questions = (data['questions'] as List<dynamic>?)
              ?.map((q) => Map<String, dynamic>.from(q))
              .toList() ??
          [];

      // Safely handle the deadline field
      DateTime? deadline;
      final dynamic deadlineValue = data['deadline'];
      if (deadlineValue is Timestamp) {
        deadline = deadlineValue.toDate();
      } else if (deadlineValue is String) {
        try {
          deadline = DateTime.parse(deadlineValue);
        } catch (e) {
          _logger.w('Could not parse deadline string: $e');
        }
      }

      // Check if the deadline has passed
      if (deadline != null && DateTime.now().isAfter(deadline)) {
        setState(() {
          isDeadlinePassed = true;
          loading = false;
        });
        return; // Stop further processing if deadline is passed
      }

      // Check for existing submission
      final submissionQuery = await _firestore
          .collection('studentSubmissions')
          .where('assessmentId', isEqualTo: widget.assessmentId)
          .where('studentId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (submissionQuery.docs.isNotEmpty) {
        setState(() {
          hasAlreadySubmitted = true;
          loading = false;
        });
      } else {
        setState(() {
          this.assessment = {
            'id': doc.id,
            ...data,
            'questions': questions,
            'deadline': deadline, // Store the parsed deadline
          };
          loading = false;
        });
        // Start the animation only after the assessment data is set
        _fadeController.forward();
      }
    } catch (e, stackTrace) {
      _logger.e(
        'Error fetching assessment: $e',
        error: e,
        stackTrace: stackTrace,
      );
      setState(() {
        loading = false;
        error = 'Failed to load assessment. Please try again.';
      });
    }
  }

  Future<void> _requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      setState(() {
        error = "Microphone permission is required to record your assessment.";
      });
    }
  }

Future<void> _startRecording() async {
  try {
    final status = await Permission.microphone.status;
    if (!status.isGranted) {
      await _requestMicrophonePermission();
      return;
    }

    setState(() {
      audioFilePath = null;
      audioUrl = null;
      error = '';
      recordingDuration = Duration.zero;
      _fileSize = 0;
    });

    final directory = await getTemporaryDirectory();
    final filePath =
        '${directory.path}/speaking_assessment_${DateTime.now().millisecondsSinceEpoch}.aac';

    await _recorder.startRecorder(toFile: filePath, codec: Codec.aacADTS);

    setState(() {
      recordingStatus = RecordingStatus.recording;
      audioFilePath = filePath;
    });

    _waveController.repeat(reverse: true);
    _startDurationTracking();
    _startFileSizeTracking();
  } catch (e) {
    _logger.e("Error starting recording: $e");
    setState(() {
      error = "Could not start recording. Please check microphone permissions.";
    });
  }
}

void _startDurationTracking() {
  _durationTimer?.cancel();
  _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
    if (recordingStatus == RecordingStatus.recording) {
      setState(() {
        recordingDuration = Duration(seconds: recordingDuration.inSeconds + 1);
      });
    }
  });
}

void _startFileSizeTracking() {
  _fileSizeTimer?.cancel();
  _fileSizeTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
    if (audioFilePath != null &&
        recordingStatus == RecordingStatus.recording) {
      final file = File(audioFilePath!);
      if (file.existsSync()) {
        setState(() {
          _fileSize = file.lengthSync();
        });
      }
    }
  });
}

Future<void> _pauseRecording() async {
  try {
    await _recorder.pauseRecorder();
    _waveController.stop();
    _durationTimer?.cancel();
    _fileSizeTimer?.cancel();

    setState(() {
      recordingStatus = RecordingStatus.paused;
    });
  } catch (e) {
    _logger.e("Error pausing recording: $e");
  }
}

Future<void> _resumeRecording() async {
  try {
    await _recorder.resumeRecorder();
    _waveController.repeat(reverse: true);
    _startDurationTracking();
    _startFileSizeTracking();

    setState(() {
      recordingStatus = RecordingStatus.recording;
    });
  } catch (e) {
    _logger.e("Error resuming recording: $e");
  }
}

 Future<void> _stopRecording() async {
  try {
    await _recorder.stopRecorder();
    _waveController.stop();
    _durationTimer?.cancel();
    _fileSizeTimer?.cancel();

    setState(() {
      recordingStatus = RecordingStatus.stopped;
    });
  } catch (e) {
    _logger.e("Error stopping recording: $e");
    setState(() {
      error = "Error stopping recording.";
    });
  }
}



  Future<void> _playRecording() async {
    if (audioFilePath == null) return;

    try {
      setState(() {
        isPlaying = true;
      });

      await _player.startPlayer(
        fromURI: audioFilePath,
        whenFinished: () {
          setState(() {
            isPlaying = false;
            playbackPosition = Duration.zero;
          });
        },
      );
    } catch (e) {
      _logger.e("Error playing recording: $e");
      setState(() {
        isPlaying = false;
        error = "Error playing recording.";
      });
    }
  }

  Future<void> _stopPlayback() async {
    try {
      await _player.stopPlayer();
      setState(() {
        isPlaying = false;
        playbackPosition = Duration.zero;
      });
    } catch (e) {
      _logger.e("Error stopping playback: $e");
    }
  }

  Future<void> _submitAssessment() async {
    if (audioFilePath == null || !File(audioFilePath!).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please record your response first.')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || assessment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot submit. Please try again.')),
      );
      return;
    }

    setState(() {
      isSubmitting = true;
      error = '';
    });

    try {
      // Upload audio file
      final audioFile = File(audioFilePath!);
      final uploadResult = await _uploadAudioFile(audioFile, user.uid);
      final downloadURL = uploadResult['downloadURL']!;
      final filePath = uploadResult['filePath']!;
      // Get student details
      String studentName = "Unknown Student";
      try {
        final userDoc = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          studentName =
          '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim();
          if (studentName.isEmpty) {
        studentName = userData['displayName'] ?? "Unknown Student";
          }
        }
      } catch (e) {
        _logger.w("Could not fetch student name: $e");
      }

      // Prepare submission data
      final submissionData = {
        'studentId': user.uid,
        'studentName': studentName,
        'assessmentId': widget.assessmentId,
        'classId': assessment!['classId'],
        'trainerId': assessment!['trainerId'],
        'questions': assessment!['questions'],
        'assessmentType': 'speaking_assessment',
        'audioUrl': downloadURL,
        'audioPath': filePath,
        'aiFeedback': null,
        'trainerFeedback': null,
        'score': null,
        'isReviewed': false,
        'submittedAt': FieldValue.serverTimestamp(),
      };

      // Submit to Firestore
      await _firestore.collection('studentSubmissions').add(submissionData);

      // Navigate back with success message
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Speaking assessment submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _logger.e("Error submitting assessment: $e");
      setState(() {
        error = "Failed to submit assessment. Please try again.";
      });
    } finally {
      setState(() {
        isSubmitting = false;
      });
    }
  }

  Future<Map<String, String>> _uploadAudioFile(
    File audioFile,
    String studentId,
  ) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Call your Firebase service to upload the audio
      final result = await _firebaseService.uploadSpeakingAssessmentAudio(
        audioFile,
        studentId,
        widget.assessmentId,
        timestamp,
      );

      return result;
    } catch (e) {
      throw Exception('Failed to upload audio: $e');
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  String _formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
}

  @override
  Widget build(BuildContext context) {
    // Show already submitted screen
    if (hasAlreadySubmitted && !loading) {
      return _buildAlreadySubmittedScreen();
    }

    // Show deadline passed screen
    if (isDeadlinePassed && !loading) {
      return _buildDeadlinePassedScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(assessment?['title'] ?? 'Speaking Assessment'),
        backgroundColor: const Color(0xFF0077B3),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: loading
          ? _buildLoadingScreen()
          : error.isNotEmpty
          ? _buildErrorScreen()
          : _buildAssessmentContent(),
    );
  }

  Widget _buildLoadingScreen() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF0077B3)),
          SizedBox(height: 16),
          Text('Loading Speaking Assessment...'),
        ],
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const FaIcon(
              FontAwesomeIcons.exclamationTriangle,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 24),
            const Text(
              'Error Loading Assessment',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const FaIcon(FontAwesomeIcons.arrowLeft),
              label: const Text('Go Back'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaveformAnimation() {
  return AnimatedBuilder(
    animation: _waveController,
    builder: (context, child) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(5, (index) {
          final delay = index * 0.2;
          final animValue = (_waveController.value + delay) % 1.0;
          final height = 20 + (30 * (1 - (animValue - 0.5).abs() * 2)) *
                         (_audioLevel / 60).clamp(0.3, 1.0);

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 4,
            height: height,
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      );
    },
  );
}

  Widget _buildAlreadySubmittedScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assessment Completed'),
        backgroundColor: const Color(0xFF0077B3),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const FaIcon(
                FontAwesomeIcons.checkCircle,
                size: 80,
                color: Colors.green,
              ),
              const SizedBox(height: 24),
              const Text(
                'Already Submitted',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0077B3),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'You have already completed "${assessment?['title'] ?? 'this assessment'}". Your trainer will review it soon.',
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const FaIcon(FontAwesomeIcons.arrowLeft),
                label: const Text('Back to Class'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0077B3),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeadlinePassedScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assessment Closed'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const FaIcon(
                FontAwesomeIcons.lock,
                size: 80,
                color: Colors.orange,
              ),
              const SizedBox(height: 24),
              const Text(
                'Assessment Closed',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'The deadline for "${assessment?['title'] ?? 'this assessment'}" has passed.',
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const FaIcon(FontAwesomeIcons.arrowLeft),
                label: const Text('Back to Class'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssessmentContent() {
    if (assessment == null) return Container();

    // The new design doesn't seem to have a separate header.
    // The title is in the AppBar, and the subtitle can be added here.

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subtitle from the new design
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                assessment!['description'] ?? 'Speaking Test',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                ),
              ),
            ),

            // Questions/Prompts
            _buildQuestions(),

            const SizedBox(height: 32),

            // Submit Button
            _buildSubmitButton(),

            if (error.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  error,
                  style: TextStyle(color: Colors.red.shade700),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuestions() {
    final questions = assessment!['questions'] as List;

    return Column(
      children: questions.asMap().entries.map((entry) {
        final index = entry.key;
        final question = entry.value;
        return Container(
          margin: const EdgeInsets.only(bottom: 24),
          child: _buildQuestionCard(question, index + 1),
        );
      }).toList(),
    );
  }

  Widget _buildQuestionCard(Map<String, dynamic> question, int questionNumber) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Prompt $questionNumber: ${question['title'] ?? 'Speaking Prompt'}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              question['promptText'] ??
                  question['text'] ??
                  'No prompt text available',
              style: TextStyle(
                color: Colors.grey.shade800,
                fontSize: 16,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Recording controls are now inside the card
          _buildRecordingControls(),
        ],
      ),
    );
  }

Widget _buildRecordingControls() {
  return Center(
    child: Column(
      children: [
        // Recording button
        if (recordingStatus == RecordingStatus.inactive)
          _buildStartRecordingButton()
        else if (recordingStatus == RecordingStatus.recording)
          _buildRecordingActiveUI()
        else if (recordingStatus == RecordingStatus.paused)
          _buildPausedUI()
        else
          _buildPlaybackControls(),

        const SizedBox(height: 16),

        // Status indicators
        if (recordingStatus == RecordingStatus.recording ||
            recordingStatus == RecordingStatus.paused) ...[
          _buildRecordingStats(),
        ] else if (recordingStatus == RecordingStatus.stopped) ...[
          Text(
            'Duration: ${_formatDuration(recordingDuration)} • ${_formatFileSize(_fileSize)}',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ],
    ),
  );
}
Widget _buildRecordingActiveUI() {
  return Column(
    children: [
      _buildWaveformAnimation(),
      const SizedBox(height: 16),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton.icon(
            onPressed: _pauseRecording,
            icon: const FaIcon(FontAwesomeIcons.pause, size: 16),
            label: const Text('Pause'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _stopRecording,
            icon: const FaIcon(FontAwesomeIcons.stopCircle, size: 16),
            label: const Text('Stop'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        'Tap pause to take a break',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
          fontStyle: FontStyle.italic,
        ),
      ),
    ],
  );
}

Widget _buildPausedUI() {
  return Column(
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pause_circle, color: Colors.orange[700], size: 20),
            const SizedBox(width: 8),
            Text(
              'Recording Paused',
              style: TextStyle(
                color: Colors.orange[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton.icon(
            onPressed: _resumeRecording,
            icon: const FaIcon(FontAwesomeIcons.play, size: 16),
            label: const Text('Resume'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _stopRecording,
            icon: const FaIcon(FontAwesomeIcons.stopCircle, size: 16),
            label: const Text('Stop'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    ],
  );
}

Widget _buildRecordingStats() {
  Color qualityColor;
  IconData qualityIcon;

  switch (_audioQuality) {
    case 'Excellent':
      qualityColor = Colors.green;
      qualityIcon = Icons.check_circle;
      break;
    case 'Good':
      qualityColor = Colors.blue;
      qualityIcon = Icons.check_circle;
      break;
    case 'Fair':
      qualityColor = Colors.orange;
      qualityIcon = Icons.warning;
      break;
    default:
      qualityColor = Colors.red;
      qualityIcon = Icons.error;
  }

  return Column(
    children: [
      Text(
        'Recording: ${_formatDuration(recordingDuration)}',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFF0077B3),
        ),
      ),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(qualityIcon, color: qualityColor, size: 16),
          const SizedBox(width: 4),
          Text(
            'Microphone level: $_audioQuality',
            style: TextStyle(
              fontSize: 14,
              color: qualityColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Text(
        'File size: ${_formatFileSize(_fileSize)}',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
        ),
      ),
    ],
  );
}

  Widget _buildStartRecordingButton() {
    return ElevatedButton.icon(
      onPressed: _startRecording,
      icon: const FaIcon(FontAwesomeIcons.microphone),
      label: const Text('Start Recording'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      ),
    );
  }


  Widget _buildPlaybackControls() {
    return Column(
      children: [
        const Text(
          'Listen to your recording before submitting:',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),

        const SizedBox(height: 16),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: isPlaying ? _stopPlayback : _playRecording,
              icon: FaIcon(
                isPlaying ? FontAwesomeIcons.stop : FontAwesomeIcons.play,
              ),
              label: Text(isPlaying ? 'Stop' : 'Play'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0077B3),
                foregroundColor: Colors.white,
              ),
            ),

            const SizedBox(width: 16),

            ElevatedButton.icon(
              onPressed: _startRecording,
              icon: const FaIcon(FontAwesomeIcons.redo),
              label: const Text('Record Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[600],
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    final canSubmit = audioFilePath != null &&
        File(audioFilePath!).existsSync() &&
        recordingStatus == RecordingStatus.stopped;

    return Container(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: (canSubmit && !isSubmitting) ? _submitAssessment : null,
        icon: isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const FaIcon(FontAwesomeIcons.paperPlane),
        label: Text(isSubmitting ? 'Submitting...' : 'Submit Assessment'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF28a745), // Green color from image
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

enum RecordingStatus { inactive, recording, paused, stopped }
