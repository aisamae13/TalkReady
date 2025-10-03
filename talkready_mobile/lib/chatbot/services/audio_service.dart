import 'dart:io';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';

class AudioService {
  final Logger logger;
  late FlutterSoundRecorder _recorder;
  late FlutterSoundPlayer _player;
  final ap.AudioPlayer _audioPlayer = ap.AudioPlayer();

  bool _isRecorderInitialized = false;
  bool _isPlayerInitialized = false;
  String? _currentAudioFilePath;

  AudioService({required this.logger});

  bool get isRecorderInitialized => _isRecorderInitialized;
  bool get isPlayerInitialized => _isPlayerInitialized;
  String? get currentAudioFilePath => _currentAudioFilePath;

  Future<void> initialize() async {
    _recorder = FlutterSoundRecorder();
    _player = FlutterSoundPlayer();

    await _initRecorder();
    await _initPlayer();
    await requestPermissions();
  }

  Future<void> _initRecorder() async {
    try {
      await _recorder.openRecorder();
      final tempDir = await getTemporaryDirectory();
      _currentAudioFilePath = '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.aac';
      _isRecorderInitialized = true;
      logger.i('Recorder initialized successfully');
    } catch (e) {
      _isRecorderInitialized = false;
      logger.e('Error initializing recorder: $e');
      rethrow;
    }
  }

  Future<void> _initPlayer() async {
    try {
      await _player.openPlayer();
      _isPlayerInitialized = true;
      logger.i('Player initialized successfully');
    } catch (e) {
      _isPlayerInitialized = false;
      logger.e('Error initializing player: $e');
      rethrow;
    }
  }

  Future<bool> requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.microphone,
    ].request();

    if (statuses[Permission.microphone]!.isDenied ||
        statuses[Permission.microphone]!.isPermanentlyDenied) {
      logger.w('Microphone permission denied.');
      return false;
    }
    return true;
  }

  Future<String?> startRecording() async {
    if (!_isRecorderInitialized) {
      throw Exception('Recorder not initialized');
    }

    try {
      if (_recorder.isRecording) {
        await _recorder.stopRecorder();
      }

      final tempDir = await getTemporaryDirectory();
      _currentAudioFilePath = '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.aac';

      await _recorder.startRecorder(
        toFile: _currentAudioFilePath!,
        codec: Codec.aacADTS,
        sampleRate: 16000,
      );

      logger.d('Recording started: $_currentAudioFilePath');
      return _currentAudioFilePath;
    } catch (e) {
      logger.e('Error starting recording: $e');
      rethrow;
    }
  }

  Future<String?> stopRecording() async {
    try {
      if (!_recorder.isRecording) {
        logger.w('No active recording to stop.');
        return null;
      }

      String? path = await _recorder.stopRecorder();
      logger.d('Recording stopped: $path');

      if (path != null && await File(path).exists()) {
        _currentAudioFilePath = path;
        return path;
      }

      logger.w('Audio file not found after stopping recorder');
      return null;
    } catch (e) {
      logger.e('Error stopping recording: $e');
      rethrow;
    }
  }

  Future<void> playUserAudio(String audioPath) async {
    if (!_isPlayerInitialized) {
      throw Exception('Player not initialized');
    }

    final file = File(audioPath);
    if (!await file.exists() || await file.length() == 0) {
      throw Exception('Invalid audio file');
    }

    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(ap.DeviceFileSource(audioPath));
      logger.i('Playing user recording: $audioPath');
    } catch (e) {
      logger.e('Error playing user audio: $e');
      rethrow;
    }
  }

  Future<void> playBotAudio(String audioPath) async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(ap.DeviceFileSource(audioPath));
      logger.i('Playing bot audio: $audioPath');
    } catch (e) {
      logger.e('Error playing bot audio: $e');
      rethrow;
    }
  }

  Future<void> stopAllAudio() async {
    try {
      if (_audioPlayer.state == ap.PlayerState.playing) {
        await _audioPlayer.stop();
        logger.i('AudioPlayer stopped.');
      }
      if (_player.isPlaying) {
        await _player.stopPlayer();
        logger.i('FlutterSoundPlayer stopped.');
      }
    } catch (e) {
      logger.e('Error stopping audio: $e');
      rethrow;
    }
  }

  void dispose() {
    stopAllAudio();
    if (_recorder.isRecording) {
      _recorder.stopRecorder().catchError((e) {
        logger.e('Error stopping recorder on dispose: $e');
        return null;
      });
    }
    _recorder.closeRecorder();
    if (_player.isPlaying) {
      _player.stopPlayer();
    }
    _player.closePlayer();
    _audioPlayer.release();
    _audioPlayer.dispose();
    logger.i('AudioService disposed.');
  }
}