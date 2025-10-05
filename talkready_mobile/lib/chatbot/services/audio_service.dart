import 'dart:io';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';

class AudioService {
  final Logger logger;
  late AudioRecorder _recorder;
  final ap.AudioPlayer _audioPlayer = ap.AudioPlayer();

  bool _isRecorderInitialized = false;
  String? _currentAudioFilePath;

  AudioService({required this.logger});

  bool get isRecorderInitialized => _isRecorderInitialized;
  String? get currentAudioFilePath => _currentAudioFilePath;
  ap.AudioPlayer get audioPlayer => _audioPlayer;  // ADD THIS GETTER

  Future<void> initialize() async {
    _recorder = AudioRecorder();
    await requestPermissions();
    _isRecorderInitialized = true;
    logger.i('Recorder initialized successfully');
  }

  Future<bool> requestPermissions() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
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
      final tempDir = await getTemporaryDirectory();
      _currentAudioFilePath = '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.wav';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: _currentAudioFilePath!,
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
      final path = await _recorder.stop();

      if (path != null && await File(path).exists()) {
        final fileSize = await File(path).length();
        logger.i('Recorded file size: $fileSize bytes');

        if (fileSize < 1000) {
          logger.e('Recording file too small: $fileSize bytes');
          return null;
        }

        // Don't update _currentAudioFilePath here
        logger.d('Recording stopped: $path');
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
    final file = File(audioPath);
    if (!await file.exists() || await file.length() == 0) {
      throw Exception('Invalid audio file: $audioPath');
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
    } catch (e) {
      logger.e('Error stopping audio: $e');
      rethrow;
    }
  }

  void dispose() {
    stopAllAudio();
    _recorder.dispose();
    _audioPlayer.release();
    _audioPlayer.dispose();
    logger.i('AudioService disposed.');
  }
}
