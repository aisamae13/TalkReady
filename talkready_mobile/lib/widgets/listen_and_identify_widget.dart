// lib/widgets/listen_and_identify_widget.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:just_audio/just_audio.dart';
import '../services/unified_progress_service.dart';
import 'dart:typed_data';

class ListenAndIdentifyWidget extends StatefulWidget {
  final Map<String, dynamic> assessmentData;
  final VoidCallback onComplete;

  const ListenAndIdentifyWidget({
    super.key,
    required this.assessmentData,
    required this.onComplete,
  });

  @override
  State<ListenAndIdentifyWidget> createState() =>
      _ListenAndServeIdentifyWidgetState();
}

class _ListenAndServeIdentifyWidgetState
    extends State<ListenAndIdentifyWidget> {
  final TextEditingController _answerController = TextEditingController();
  final UnifiedProgressService _progressService = UnifiedProgressService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isLoadingAudio = false;
  bool _showFeedback = false;
  String? _feedbackMessage;
  Color _feedbackColor = Colors.grey;

  @override
  void initState() {
    super.initState();
    // **FIX #1:** Add a listener to the controller.
    // This calls setState() on every keystroke, which rebuilds the widget
    // and allows the button's enabled/disabled state to be re-evaluated.
    _answerController.addListener(() {
      setState(() {
        // The empty call is enough to trigger a rebuild
      });
    });
  }

  @override
  void dispose() {
    _answerController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playAudio() async {
    if (_isLoadingAudio) return;
    setState(() => _isLoadingAudio = true);

    try {
      final textToSpeak = widget.assessmentData['textToSpeak'] as String?;
      if (textToSpeak == null || textToSpeak.isEmpty) {
        throw Exception("No text to speak provided in lesson data.");
      }

      final audioData = await _progressService.synthesizeSpeech(textToSpeak);

      if (audioData != null && mounted) {
        await _audioPlayer.setAudioSource(BytesAudioSource(audioData));
        await _audioPlayer.play();
        _audioPlayer.playerStateStream.firstWhere(
          (state) => state.processingState == ProcessingState.completed,
        );
      } else {
        throw Exception("Failed to get audio data from the server.");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing audio: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingAudio = false);
    }
  }

  void _checkAnswer() {
    final userAnswer = _answerController.text.trim();
    final correctAnswer = widget.assessmentData['correctAnswer'] as String;

    setState(() {
      _showFeedback = true;
      if (userAnswer.toLowerCase() == correctAnswer.toLowerCase()) {
        _feedbackMessage = 'Correct! Getting you ready for the lesson...';
        _feedbackColor = Colors.green;
      } else {
        _feedbackMessage =
            'Not quite. The correct answer was "$correctAnswer". Let\'s review the material.';
        _feedbackColor = Colors.red;
      }
    });

    Timer(const Duration(seconds: 4), widget.onComplete);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              widget.assessmentData['title'],
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00568D),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              widget.assessmentData['instruction'],
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Text(
              widget.assessmentData['question'],
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                IconButton(
                  icon: _isLoadingAudio
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        )
                      : const Icon(Icons.volume_up),
                  onPressed: _isLoadingAudio ? null : _playAudio,
                  iconSize: 32,
                  color: Theme.of(context).primaryColor,
                ),
                Expanded(
                  child: TextField(
                    controller: _answerController,
                    decoration: const InputDecoration(
                      hintText: 'Type your answer here...',
                      border: OutlineInputBorder(),
                    ),
                    enabled: !_showFeedback,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (!_showFeedback)
              ElevatedButton(
                // **FIX #2:** The onPressed property is now conditional.
                // It's 'null' (disabled) if the text is empty, and
                // points to the _checkAnswer function otherwise.
                onPressed: _answerController.text.trim().isEmpty
                    ? null
                    : _checkAnswer,
                child: const Text('Check Answer'),
              ),
            if (_showFeedback)
              AnimatedOpacity(
                opacity: 1.0,
                duration: const Duration(milliseconds: 500),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _feedbackColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _feedbackColor),
                  ),
                  child: Text(
                    _feedbackMessage ?? '',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _feedbackColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class BytesAudioSource extends StreamAudioSource {
  final Uint8List _buffer;
  BytesAudioSource(this._buffer) : super(tag: 'BytesAudioSource');
  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final startVal = start ?? 0;
    final endVal = end ?? _buffer.length;
    return StreamAudioResponse(
      sourceLength: _buffer.length,
      contentLength: endVal - startVal,
      offset: startVal,
      stream: Stream.fromIterable([_buffer.sublist(startVal, endVal)]),
      contentType: 'audio/mpeg',
    );
  }
}
