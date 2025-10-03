import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'audio_service.dart';

class TTSService {
  final Logger logger;
  final AudioService audioService;

  TTSService({required this.logger, required this.audioService});

  Future<void> speakText(String text, {bool skipTTS = false}) async {
    if (text.trim().isEmpty || skipTTS) {
      logger.w("Skip TTS: emptyText=${text.trim().isEmpty}, skipTTS=$skipTTS");
      return;
    }

    final apiKey = dotenv.env['AZURE_SPEECH_API_KEY'];
    final region = dotenv.env['AZURE_SPEECH_REGION'];

    if (apiKey == null || region == null) {
      logger.e('Azure TTS missing: API Key: $apiKey, Region: $region');
      throw Exception('TTS configuration error');
    }

    try {
      final endpoint = 'https://$region.tts.speech.microsoft.com/cognitiveservices/v1';
      final cleanText = _escapeXml(text);

      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Ocp-Apim-Subscription-Key': apiKey,
          'Content-Type': 'application/ssml+xml',
          'X-Microsoft-OutputFormat': 'audio-16khz-128kbitrate-mono-mp3',
          'User-Agent': 'TalkReady',
        },
        body: '''
<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="en-US">
  <voice name="en-US-JennyNeural">
    <prosody rate="0.9" pitch="+0%">
      <break time="100ms" />$cleanText<break time="100ms" />
    </prosody>
  </voice>
</speak>''',
      ).timeout(Duration(seconds: 30), onTimeout: () {
        logger.e('Azure TTS request timed out');
        throw Exception('TTS request timed out');
      });

      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final audioPath = '${tempDir.path}/tts_output_${DateTime.now().millisecondsSinceEpoch}.mp3';
        final file = File(audioPath);
        await file.writeAsBytes(response.bodyBytes);
        await audioService.playBotAudio(audioPath);
        logger.i('Azure TTS played: $text');
      } else {
        logger.e('Azure TTS failed: ${response.statusCode}, Response: ${response.body}');
        throw Exception('Failed to generate speech: ${response.statusCode}');
      }
    } catch (e) {
      logger.e('TTS error: $e');
      rethrow;
    }
  }

  String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}