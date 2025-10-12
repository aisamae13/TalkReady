// lib/widgets/audio_player_widget.dart
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:typed_data';
import 'package:logger/logger.dart';
import '../services/unified_progress_service.dart'; // ✅ ADD: Import the service

class AudioPlayerWidget extends StatefulWidget {
  final String? text;
  final List<Map<String, dynamic>>? turns;
  final String buttonText;
  final IconData buttonIcon;
  final Color? buttonColor;
  final bool enabled;
  final VoidCallback? onPlayStart;
  final VoidCallback? onPlayComplete;
  final VoidCallback? onPlayError;

  const AudioPlayerWidget({
    super.key,
    this.text,
    this.turns,
    this.buttonText = 'Play Audio',
    this.buttonIcon = Icons.play_arrow,
    this.buttonColor,
    this.enabled = true,
    this.onPlayStart,
    this.onPlayComplete,
    this.onPlayError,
  }) : assert(
         text != null || turns != null,
         'Either text or turns must be provided',
       );

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  final Logger _logger = Logger();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // ✅ ADD: Create instance of UnifiedProgressService
  final UnifiedProgressService _progressService = UnifiedProgressService();

  bool _isLoading = false;
  bool _isPlaying = false;
  bool _isPaused = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _setupAudioPlayer();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _setupAudioPlayer() {
    _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
          _isPaused = state == PlayerState.paused;
        });

        if (state == PlayerState.completed) {
          widget.onPlayComplete?.call();
          _resetPlayer();
        }
      }
    });

    _audioPlayer.onDurationChanged.listen((Duration duration) {
      if (mounted) {
        setState(() => _duration = duration);
      }
    });

    _audioPlayer.onPositionChanged.listen((Duration position) {
      if (mounted) {
        setState(() => _position = position);
      }
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      widget.onPlayComplete?.call();
      _resetPlayer();
    });
  }

  Future<void> _playAudio() async {
    if (!widget.enabled || _isLoading) return;

    try {
      setState(() => _isLoading = true);
      widget.onPlayStart?.call();

      // ✅ FIXED: Use the service method instead of direct HTTP call
      final audioData = await _fetchAudioFromServer();

      if (audioData != null) {
        await _audioPlayer.play(BytesSource(audioData));
      } else {
        throw Exception('Failed to get audio data from server');
      }
    } catch (e) {
      _logger.e('Error playing audio: $e');
      widget.onPlayError?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing audio: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ✅ FIXED: Updated to use UnifiedProgressService
  Future<Uint8List?> _fetchAudioFromServer() async {
    try {
      if (widget.turns != null) {
        // For script playback with multiple turns
        return await _progressService.synthesizeSpeechFromTurns(widget.turns!);
      } else if (widget.text != null) {
        // For simple text playback
        return await _progressService.synthesizeSpeech(widget.text!);
      }
      return null;
    } catch (e) {
      _logger.e('Error fetching audio from server: $e');
      rethrow;
    }
  }

  Future<void> _pauseAudio() async {
    await _audioPlayer.pause();
  }

  Future<void> _resumeAudio() async {
    await _audioPlayer.resume();
  }

  Future<void> _stopAudio() async {
    await _audioPlayer.stop();
    _resetPlayer();
  }

  void _resetPlayer() {
    if (mounted) {
      setState(() {
        _isPlaying = false;
        _isPaused = false;
        _position = Duration.zero;
        _duration = Duration.zero;
      });
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Main play button
        ElevatedButton.icon(
          onPressed: widget.enabled ? _handleButtonPress : null,
          icon: _buildButtonIcon(),
          label: Text(
            _isLoading
                ? 'Loading...'
                : _isPlaying
                ? 'Playing...'
                : _isPaused
                ? 'Paused'
                : widget.buttonText,
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.buttonColor ?? Colors.indigo,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),

        // Audio controls (only show when audio is loaded)
        if (_isPlaying || _isPaused) ...[
          const SizedBox(height: 12),
          _buildAudioControls(),
        ],
      ],
    );
  }

  Widget _buildButtonIcon() {
    if (_isLoading) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      );
    }

    if (_isPlaying) {
      return const Icon(Icons.volume_up);
    }

    if (_isPaused) {
      return const Icon(Icons.pause);
    }

    return Icon(widget.buttonIcon);
  }

  Widget _buildAudioControls() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          // Progress bar
          Row(
            children: [
              Text(
                _formatDuration(_position),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Expanded(
                child: Slider(
                  value: _duration.inSeconds > 0
                      ? _position.inSeconds / _duration.inSeconds
                      : 0.0,
                  onChanged: (value) async {
                    final newPosition = Duration(
                      seconds: (value * _duration.inSeconds).round(),
                    );
                    await _audioPlayer.seek(newPosition);
                  },
                  activeColor: widget.buttonColor ?? Colors.indigo,
                ),
              ),
              Text(
                _formatDuration(_duration),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),

          // Control buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _isPaused ? _resumeAudio : _pauseAudio,
                icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                color: widget.buttonColor ?? Colors.indigo,
              ),
              IconButton(
                onPressed: _stopAudio,
                icon: const Icon(Icons.stop),
                color: Colors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleButtonPress() {
    if (_isPlaying) {
      _pauseAudio();
    } else if (_isPaused) {
      _resumeAudio();
    } else {
      _playAudio();
    }
  }
}

// Simple audio player for basic text TTS
class SimpleAudioPlayer extends StatelessWidget {
  final String text;
  final String buttonText;
  final IconData buttonIcon;
  final Color? buttonColor;
  final bool enabled;

  const SimpleAudioPlayer({
    super.key,
    required this.text,
    this.buttonText = 'Play',
    this.buttonIcon = Icons.volume_up,
    this.buttonColor,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return AudioPlayerWidget(
      text: text,
      buttonText: buttonText,
      buttonIcon: buttonIcon,
      buttonColor: buttonColor,
      enabled: enabled,
    );
  }
}

// Script audio player for call transcripts
class ScriptAudioPlayer extends StatelessWidget {
  final List<Map<String, dynamic>> turns;
  final String buttonText;
  final IconData buttonIcon;
  final Color? buttonColor;
  final bool enabled;

  const ScriptAudioPlayer({
    super.key,
    required this.turns,
    this.buttonText = 'Play Script',
    this.buttonIcon = Icons.play_arrow,
    this.buttonColor,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return AudioPlayerWidget(
      turns: turns,
      buttonText: buttonText,
      buttonIcon: buttonIcon,
      buttonColor: buttonColor,
      enabled: enabled,
    );
  }
}

// Compact audio player for inline use
class CompactAudioPlayer extends StatelessWidget {
  final String? text;
  final List<Map<String, dynamic>>? turns;
  final bool enabled;

  const CompactAudioPlayer({
    super.key,
    this.text,
    this.turns,
    this.enabled = true,
  }) : assert(
         text != null || turns != null,
         'Either text or turns must be provided',
       );

  @override
  Widget build(BuildContext context) {
    return AudioPlayerWidget(
      text: text,
      turns: turns,
      buttonText: '',
      buttonIcon: Icons.volume_up,
      buttonColor: Colors.indigo,
      enabled: enabled,
    );
  }
}
