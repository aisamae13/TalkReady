import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:logger/logger.dart';

// A model for the AI feedback
class SpeechAIFeedback {
  final double? accuracyScore;
  final double? fluencyScore;
  final double? prosodyScore;
  final List<SpeechWordAnalysis>? words;

  SpeechAIFeedback({
    this.accuracyScore,
    this.fluencyScore,
    this.prosodyScore,
    this.words,
  });

  factory SpeechAIFeedback.fromJson(Map<String, dynamic> json) {
    return SpeechAIFeedback(
      accuracyScore: json['accuracyScore']?.toDouble(),
      fluencyScore: json['fluencyScore']?.toDouble(),
      prosodyScore: json['prosodyScore']?.toDouble(),
      words: json['words'] != null
          ? (json['words'] as List)
              .map((w) => SpeechWordAnalysis.fromJson(w))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accuracyScore': accuracyScore,
      'fluencyScore': fluencyScore,
      'prosodyScore': prosodyScore,
      'words': words?.map((w) => w.toJson()).toList(),
    };
  }
}

class SpeechWordAnalysis {
  final String word;
  final String errorType;

  SpeechWordAnalysis({
    required this.word,
    required this.errorType,
  });

  factory SpeechWordAnalysis.fromJson(Map<String, dynamic> json) {
    return SpeechWordAnalysis(
      word: json['word'] ?? '',
      errorType: json['errorType'] ?? 'None',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'word': word,
      'errorType': errorType,
    };
  }
}

class ReviewSpeakingSubmission extends StatefulWidget {
  final String submissionId;

  const ReviewSpeakingSubmission({Key? key, required this.submissionId}) : super(key: key);

  @override
  _ReviewSpeakingSubmissionState createState() => _ReviewSpeakingSubmissionState();
}

class _ReviewSpeakingSubmissionState extends State<ReviewSpeakingSubmission> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Logger _logger = Logger();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _loading = true;
  String _error = '';
  Map<String, dynamic>? _submission;
  Map<String, dynamic>? _assessment;

  // AI Feedback State
  SpeechAIFeedback? _aiFeedback;
  bool _isLoadingAiFeedback = false;

  // Trainer Feedback State
  final TextEditingController _trainerFeedbackController = TextEditingController();
  final TextEditingController _trainerScoreController = TextEditingController();
  bool _isSaving = false;
  bool _saveSuccess = false;

  // Audio Player State
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _loadSubmissionData();
    _setupAudioPlayer();
  }

  void _setupAudioPlayer() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.completed) {
        setState(() {
          _isPlaying = false;
        });
      }
    });
  }

  Future<void> _loadSubmissionData() async {
    if (_auth.currentUser == null) {
      setState(() {
        _error = 'You must be logged in to view submissions.';
        _loading = false;
      });
      return;
    }

    try {
      // Get submission details
      final submissionDoc = await _firestore
          .collection('speakingSubmissions')
          .doc(widget.submissionId)
          .get();

      if (!submissionDoc.exists) {
        throw Exception('Submission not found.');
      }

      final submissionData = submissionDoc.data() as Map<String, dynamic>;
      
      // Get assessment details
      final assessmentDoc = await _firestore
          .collection('assessments')
          .doc(submissionData['assessmentId'])
          .get();

      if (!assessmentDoc.exists) {
        throw Exception('Assessment not found.');
      }

      final assessmentData = assessmentDoc.data() as Map<String, dynamic>;

      // Check if current user is the trainer for this assessment
      if (assessmentData['trainerId'] != _auth.currentUser!.uid) {
        throw Exception('You are not authorized to view this submission.');
      }

      setState(() {
        _submission = submissionData;
        _assessment = assessmentData;
        
        // Pre-fill feedback if exists
        if (submissionData.containsKey('trainerFeedback')) {
          _trainerFeedbackController.text = submissionData['trainerFeedback'] ?? '';
        }
        
        if (submissionData.containsKey('score')) {
          _trainerScoreController.text = submissionData['score'].toString();
        }
        
        if (submissionData.containsKey('aiFeedback') && submissionData['aiFeedback'] != null) {
          _aiFeedback = SpeechAIFeedback.fromJson(submissionData['aiFeedback']);
        }
        
        _loading = false;
      });

    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
      _logger.e('Error loading submission: $e');
    }
  }

  Future<void> _handleGetAiEvaluation() async {
    if (_submission == null || 
        _submission!['audioUrl'] == null || 
        _assessment == null || 
        _assessment!['questions'] == null || 
        _assessment!['questions'].isEmpty ||
        _assessment!['questions'][0]['referenceText'] == null) {
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Submission audio or reference text is missing for AI evaluation.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoadingAiFeedback = true;
      _error = '';
    });

    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:5000/evaluate-speech-with-azure'), // Use 10.0.2.2 for Android emulator
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'audioUrl': _submission!['audioUrl'],
          'originalText': _assessment!['questions'][0]['referenceText']
        }),
      );

      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'The AI evaluation failed.');
      }

      final feedbackResult = jsonDecode(response.body);
      setState(() {
        _aiFeedback = SpeechAIFeedback.fromJson(feedbackResult);
      });

    } catch (e) {
      setState(() {
        _error = 'AI Evaluation Error: ${e.toString()}';
      });
      _logger.e('AI evaluation error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoadingAiFeedback = false;
      });
    }
  }

  Future<void> _handlePublishFeedback() async {
    setState(() {
      _isSaving = true;
      _saveSuccess = false;
      _error = '';
    });

    try {
      final feedbackData = {
        'aiFeedback': _aiFeedback?.toJson(),
        'trainerFeedback': _trainerFeedbackController.text,
        'score': double.tryParse(_trainerScoreController.text) ?? 0,
        'updatedAt': FieldValue.serverTimestamp(),
        'reviewedBy': _auth.currentUser!.uid,
      };

      await _firestore
          .collection('speakingSubmissions')
          .doc(widget.submissionId)
          .update(feedbackData);

      setState(() {
        _saveSuccess = true;
      });

    } catch (e) {
      setState(() {
        _error = 'Failed to publish feedback: ${e.toString()}';
      });
      _logger.e('Error publishing feedback: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _togglePlayAudio(String audioUrl) async {
    if (_isPlaying) {
      await _audioPlayer.stop();
      setState(() {
        _isPlaying = false;
      });
    } else {
      setState(() {
        _isPlaying = true;
      });
      try {
        await _audioPlayer.play(UrlSource(audioUrl));
      } catch (e) {
        setState(() {
          _isPlaying = false;
          _error = 'Failed to play audio: ${e.toString()}';
        });
        _logger.e('Error playing audio: $e');
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _trainerFeedbackController.dispose();
    _trainerScoreController.dispose();
    super.dispose();
  }

  // AI Feedback Display Widget
  Widget _buildAiFeedbackDisplay() {
    if (_aiFeedback == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          'AI Evaluation Report',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.indigo[700],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.indigo[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Accuracy Score: ${_aiFeedback!.accuracyScore?.toStringAsFixed(1)}% (How closely speech matched reference text)',
            style: const TextStyle(fontSize: 12),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.indigo[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Fluency Score: ${_aiFeedback!.fluencyScore?.toStringAsFixed(1)}/100 (Rhythm and naturalness of speech)',
            style: const TextStyle(fontSize: 12),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.indigo[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Pronunciation Score: ${_aiFeedback!.prosodyScore?.toStringAsFixed(1)}/100 (Clarity and intonation)',
            style: const TextStyle(fontSize: 12),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.indigo[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Word-by-Word Analysis (Errors):',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              _aiFeedback!.words != null && 
              _aiFeedback!.words!.where((w) => w.errorType != 'None').isNotEmpty
                  ? Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _aiFeedback!.words!
                          .where((w) => w.errorType != 'None')
                          .map((word) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red[100],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Tooltip(
                                  message: 'Error: ${word.errorType}',
                                  child: Text(
                                    word.word,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.red[700],
                                    ),
                                  ),
                                ),
                              ))
                          .toList(),
                    )
                  : Text(
                      'No significant pronunciation errors detected.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Review Speaking Submission'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error.isNotEmpty && (_submission == null || _assessment == null)) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red[700],
                ),
                const SizedBox(height: 16),
                Text(
                  _error,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.red[700],
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Extract the speaking prompt
    final speakingPrompt = _assessment != null && 
                          _assessment!['questions'] != null && 
                          _assessment!['questions'].isNotEmpty
                          ? _assessment!['questions'][0]
                          : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Speaking Submission'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        color: Colors.grey[100],
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back Button
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Row(
                  children: [
                    Icon(
                      Icons.arrow_back,
                      color: Colors.blue[600],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Back to All Submissions',
                      style: TextStyle(
                        color: Colors.blue[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Main Content Card
              Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Assessment Title
                      Text(
                        _assessment?['title'] ?? 'Speaking Assessment',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1e40af), // Equivalent to sky-800
                        ),
                      ),
                      
                      // Student Name
                      Text(
                        'Reviewing submission from: ${_submission?['studentName'] ?? 'Student'}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Two columns layout (on larger screens)
                      LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth > 600) {
                            // Two columns for larger screens
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Left Column: Submission Details
                                Expanded(
                                  child: _buildSubmissionDetailsSection(speakingPrompt),
                                ),
                                const SizedBox(width: 16),
                                // Right Column: Feedback Hub
                                Expanded(
                                  child: _buildFeedbackHubSection(speakingPrompt),
                                ),
                              ],
                            );
                          } else {
                            // Single column for smaller screens
                            return Column(
                              children: [
                                _buildSubmissionDetailsSection(speakingPrompt),
                                const SizedBox(height: 16),
                                _buildFeedbackHubSection(speakingPrompt),
                              ],
                            );
                          }
                        },
                      ),
                      
                      // Save Button Section
                      Container(
                        margin: const EdgeInsets.only(top: 24),
                        padding: const EdgeInsets.only(top: 16),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: Colors.grey[300]!,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _saveSuccess
                                ? Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        color: Colors.green[600],
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Feedback Published Successfully!',
                                        style: TextStyle(
                                          color: Colors.green[600],
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  )
                                : ElevatedButton.icon(
                                    onPressed: _isSaving ? null : _handlePublishFeedback,
                                    icon: _isSaving
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.send),
                                    label: Text(_isSaving ? 'Publishing...' : 'Publish Feedback'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 12,
                                      ),
                                      backgroundColor: Colors.green[600],
                                      foregroundColor: Colors.white,
                                      textStyle: const TextStyle(
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubmissionDetailsSection(dynamic speakingPrompt) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Student's Submission",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          Divider(color: Colors.grey[300]),
          const SizedBox(height: 8),
          
          // Prompt Title
          Text(
            speakingPrompt?['title'] ?? 'Speaking Prompt',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
          
          // Prompt Text
          if (speakingPrompt?['promptText'] != null)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.indigo[50],
                border: Border(
                  left: BorderSide(
                    color: Colors.indigo[300]!,
                    width: 4,
                  ),
                ),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: Text(
                speakingPrompt?['promptText'],
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF4B5563), // text-gray-600
                ),
              ),
            ),
          
          const SizedBox(height: 16),
          
          // Audio Player
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Student's Recording:",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              _submission?['audioUrl'] != null
                  ? Column(
                      children: [
                        // Custom audio player UI
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              InkWell(
                                onTap: () => _togglePlayAudio(_submission!['audioUrl']),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[600],
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _isPlaying ? Icons.pause : Icons.play_arrow,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _isPlaying ? 'Playing...' : 'Play Recording',
                                  style: TextStyle(
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Text(
                      'Audio not available.',
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[500],
                      ),
                    ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackHubSection(dynamic speakingPrompt) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Feedback Hub",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          Divider(color: Colors.grey[300]),
          const SizedBox(height: 16),
          
          // AI Feedback Section
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ElevatedButton.icon(
                onPressed: (_isLoadingAiFeedback || _aiFeedback != null)
                    ? null
                    : _handleGetAiEvaluation,
                icon: _isLoadingAiFeedback
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const FaIcon(FontAwesomeIcons.robot),
                label: Text(
                  _aiFeedback != null
                      ? 'AI Evaluation Complete'
                      : 'Get AI Evaluation',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo[600],
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _aiFeedback != null
                      ? Colors.indigo[300]
                      : Colors.grey[400],
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
              
              if (_isLoadingAiFeedback)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'AI is analyzing the audio, this may take a moment...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                
              // AI Feedback Display
              _buildAiFeedbackDisplay(),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Trainer Feedback Section
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const FaIcon(
                    FontAwesomeIcons.userEdit,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Your Manual Feedback',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _trainerFeedbackController,
                decoration: InputDecoration(
                  hintText: 'Provide constructive feedback here...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
                minLines: 5,
                maxLines: 8,
                enabled: !_isSaving,
              ),
              const SizedBox(height: 16),
              Text(
                'Overall Score (out of ${speakingPrompt?['points'] ?? 10})',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 100,
                child: TextField(
                  controller: _trainerScoreController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  enabled: !_isSaving,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}