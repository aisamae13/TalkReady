import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:logger/logger.dart';
import 'package:intl/intl.dart';

class ReviewSpeakingSubmissionPage extends StatefulWidget {
  final String submissionId;

  const ReviewSpeakingSubmissionPage({Key? key, required this.submissionId})
      : super(key: key);

  @override
  _ReviewSpeakingSubmissionPageState createState() =>
      _ReviewSpeakingSubmissionPageState();
}

class _ReviewSpeakingSubmissionPageState
    extends State<ReviewSpeakingSubmissionPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Logger _logger = Logger();

  bool _loading = true;
  String _error = '';
  Map<String, dynamic>? _submission;
  Map<String, dynamic>? _assessment;

  // Feedback State
  final TextEditingController _trainerFeedbackController =
      TextEditingController();
  final TextEditingController _trainerScoreController = TextEditingController();
  bool _isSaving = false;

  // Audio Player State
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupAudioPlayerListeners();
  }

  void _setupAudioPlayerListeners() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });
    _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) {
        setState(() {
          _duration = newDuration;
        });
      }
    });
    _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) {
        setState(() {
          _position = newPosition;
        });
      }
    });
  }

  Future<void> _loadData() async {
    if (_auth.currentUser == null) {
      setState(() {
        _error = 'You must be logged in.';
        _loading = false;
      });
      return;
    }

    try {
      final submissionDoc = await _firestore
          .collection('studentSubmissions')
          .doc(widget.submissionId)
          .get();

      if (!submissionDoc.exists) {
        throw Exception('Submission not found.');
      }

      final submissionData = submissionDoc.data() as Map<String, dynamic>;

      final assessmentDoc = await _firestore
          .collection('trainerAssessments')
          .doc(submissionData['assessmentId'])
          .get();

      if (!assessmentDoc.exists) {
        throw Exception('Associated assessment not found.');
      }
      final assessmentData = assessmentDoc.data() as Map<String, dynamic>;

      if (assessmentData['trainerId'] != _auth.currentUser!.uid) {
        throw Exception('You are not authorized to view this submission.');
      }

      if (mounted) {
        setState(() {
          _submission = submissionData;
          _assessment = assessmentData;
          _trainerFeedbackController.text = submissionData['trainerFeedback'] ?? '';
          _trainerScoreController.text = submissionData['score']?.toString() ?? '';
          _loading = false;
        });
      }
    } catch (e) {
      _logger.e('Error loading submission data: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load data: ${e.toString()}';
          _loading = false;
        });
      }
    }
  }

  Future<void> _publishFeedback() async {
    if (_submission == null) return;

    setState(() => _isSaving = true);

    try {
      final score = double.tryParse(_trainerScoreController.text);
      if (score == null) {
        throw Exception("Score must be a valid number.");
      }

      await _firestore
          .collection('studentSubmissions')
          .doc(widget.submissionId)
          .update({
        'trainerFeedback': _trainerFeedbackController.text,
        'score': score,
        'isReviewed': true,
        'reviewedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Feedback published successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      _logger.e("Failed to publish feedback: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to publish feedback: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _togglePlayAudio(String url) async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play(UrlSource(url));
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _trainerFeedbackController.dispose();
    _trainerScoreController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Speaking'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildPublishButton(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error.isNotEmpty) {
      return Center(child: Text(_error, style: const TextStyle(color: Colors.red)));
    }
    if (_submission == null || _assessment == null) {
      return const Center(child: Text("Submission data could not be loaded."));
    }

    final studentName = _submission!['studentName'] ?? 'Unknown Student';
    final speakingPrompt = (_assessment!['questions'] as List?)?.first;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reviewing submission from: $studentName',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 700) {
                // Two-column layout for wider screens
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildSubmissionCard(speakingPrompt)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildFeedbackCard()),
                  ],
                );
              } else {
                // Single-column layout for narrower screens
                return Column(
                  children: [
                    _buildSubmissionCard(speakingPrompt),
                    const SizedBox(height: 16),
                    _buildFeedbackCard(),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSubmissionCard(Map<String, dynamic>? prompt) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Student's Submission",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 24),
            Text(
              prompt?['title'] ?? 'Example',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                prompt?['promptText'] ?? prompt?['text'] ?? 'Testing',
                style: TextStyle(color: Colors.deepPurple.shade800),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Student's Recording:",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _buildAudioPlayer(),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioPlayer() {
    final audioUrl = _submission?['audioUrl'];
    if (audioUrl == null) {
      return const Text('No audio recording found.');
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
            onPressed: () => _togglePlayAudio(audioUrl),
          ),
          Text(_formatDuration(_position)),
          Expanded(
            child: Slider(
              value: _position.inSeconds.toDouble(),
              max: _duration.inSeconds.toDouble(),
              onChanged: (value) async {
                await _audioPlayer.seek(Duration(seconds: value.toInt()));
              },
            ),
          ),
          Text(_formatDuration(_duration)),
        ],
      ),
    );
  }

  Widget _buildFeedbackCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Feedback Hub",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Placeholder for AI Evaluation
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('AI Evaluation feature coming soon!')));
                },
                icon: const FaIcon(FontAwesomeIcons.robot, size: 18),
                label: const Text('Get AI Evaluation'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const FaIcon(FontAwesomeIcons.userEdit, size: 16),
                const SizedBox(width: 8),
                const Text(
                  'Your Manual Feedback',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _trainerFeedbackController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Provide constructive feedback here...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Overall Score (out of 10)',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _trainerScoreController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'e.g., 8.5',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPublishButton() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ElevatedButton.icon(
        onPressed: _isSaving ? null : _publishFeedback,
        icon: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ))
            : const FaIcon(FontAwesomeIcons.paperPlane),
        label: Text(_isSaving ? 'Publishing...' : 'Publish Feedback'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}