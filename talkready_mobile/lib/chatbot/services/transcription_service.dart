import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';

class TranscriptionService {
  final Logger logger;

  TranscriptionService({required this.logger});

  Future<String> uploadToCloudinary(String filePath) async {
    final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
    final uploadPreset = dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '';

    if (cloudName.isEmpty || uploadPreset.isEmpty) {
      throw Exception('Cloudinary credentials missing');
    }

    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('Audio file not found: $filePath');
    }

    final fileSizeInMB = await file.length() / (1024 * 1024);
    logger.i('File size: ${fileSizeInMB.toStringAsFixed(2)}MB');

    if (fileSizeInMB > 10) {
      throw Exception(
        'Audio file too large: ${fileSizeInMB.toStringAsFixed(2)}MB',
      );
    }

    try {
      final url = 'https://api.cloudinary.com/v1_1/$cloudName/raw/upload';
      final request = http.MultipartRequest('POST', Uri.parse(url));

      request.fields['upload_preset'] = uploadPreset;
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          filePath,
          filename: 'audio.wav',
        ),
      );

      logger.i('Uploading to Cloudinary: $filePath');
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      logger.i('Cloudinary response: ${response.statusCode}, $responseBody');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(responseBody);
        final secureUrl = data['secure_url'] as String?;
        if (secureUrl == null || secureUrl.isEmpty) {
          throw Exception('Cloudinary returned invalid URL');
        }
        logger.i('Upload successful: $secureUrl');
        return secureUrl;
      } else {
        String errorMessage = 'Status ${response.statusCode}';
        try {
          final errorData = jsonDecode(responseBody);
          errorMessage = errorData['error']?['message'] ?? responseBody;
        } catch (_) {
          errorMessage = responseBody;
        }

        logger.e('Cloudinary upload failed: $errorMessage');
        throw Exception('Upload failed: $errorMessage');
      }
    } catch (e) {
      logger.e('Cloudinary error: $e');
      throw Exception('Cloudinary upload failed: $e');
    }
  }

  Future<String?> transcribeWithAssemblyAI(String audioUrl) async {
    final apiKey = dotenv.env['ASSEMBLYAI_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      logger.e('AssemblyAI API key missing.');
      throw Exception('AssemblyAI API key missing');
    }

    logger.i('Attempting transcription with AssemblyAI for: $audioUrl');

    try {
      final submitResponse = await http.post(
        Uri.parse('https://api.assemblyai.com/v2/transcript'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'audio_url': audioUrl}),
      );

      logger.i(
        'AssemblyAI status: ${submitResponse.statusCode}, body: ${submitResponse.body}',
      );

      if (submitResponse.statusCode != 200) {
        logger.e('Submission error: ${submitResponse.body}');
        throw Exception(
          'Failed to submit transcription: ${submitResponse.statusCode}',
        );
      }

      final submitData = jsonDecode(submitResponse.body);
      String transcriptId = submitData['id'];
      logger.i('Transcript ID: $transcriptId');

      int attempts = 0;
      const maxAttempts = 30;

      while (attempts < maxAttempts) {
        attempts++;
        await Future.delayed(Duration(seconds: 2));

        final pollResponse = await http.get(
          Uri.parse('https://api.assemblyai.com/v2/transcript/$transcriptId'),
          headers: {'Authorization': 'Bearer $apiKey'},
        );

        if (pollResponse.statusCode != 200) {
          logger.w('Poll error: ${pollResponse.statusCode}');
          if (attempts > 5 && pollResponse.statusCode >= 500) {
            throw Exception('AssemblyAI server error');
          }
          continue;
        }

        final pollData = jsonDecode(pollResponse.body);
        String status = pollData['status'];
        logger.i('Status: $status ($attempts/$maxAttempts)');

        if (status == 'completed') {
          logger.i('Transcription completed.');
          return pollData['text'] as String? ?? '';
        } else if (status == 'error') {
          logger.e('Error: ${pollData['error']}');
          throw Exception('Transcription error: ${pollData['error']}');
        }
      }

      logger.w('Transcription timed out.');
      throw Exception('Transcription timed out');
    } catch (e) {
      logger.e('AssemblyAI error: $e');
      rethrow;
    }
  }

  Future<String?> transcribeWithAzure(String audioUrl) async {
    final apiKey = dotenv.env['AZURE_SPEECH_KEY'];
    final region = dotenv.env['AZURE_SPEECH_REGION'];

    if (apiKey == null || apiKey.isEmpty || region == null || region.isEmpty) {
      logger.e('Azure Speech API key or region missing.');
      throw Exception('Azure Speech API key or region missing');
    }

    try {
      logger.i('Transcribing with Azure using audio URL: $audioUrl');
      final audioResponse = await http.get(Uri.parse(audioUrl));

      if (audioResponse.statusCode != 200) {
        logger.e('Failed to download audio: ${audioResponse.statusCode}');
        throw Exception('Failed to retrieve audio for transcription');
      }

      final audioBytes = audioResponse.bodyBytes;
      final endpoint =
          'https://$region.stt.speech.microsoft.com/speech/recognition/conversation/cognitiveservices/v1';
      final queryParams = {'language': 'en-US', 'format': 'detailed'};
      final uri = Uri.parse(endpoint).replace(queryParameters: queryParams);
      final headers = {
        'Ocp-Apim-Subscription-Key': apiKey,
        'Content-Type': 'audio/wav; codecs=audio/pcm; samplerate=16000',
        'Accept': 'application/json',
      };

      final response = await http.post(uri, headers: headers, body: audioBytes);
      logger.i(
        'Azure STT response status: ${response.statusCode}, body: ${response.body}',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final transcript = data['DisplayText'] as String?;

        if (transcript == null || transcript.isEmpty) {
          logger.w('Azure STT returned empty transcript.');
          return null;
        }

        logger.i('Azure STT successful: $transcript');
        return transcript;
      } else {
        logger.e(
          'Azure STT failed: Status ${response.statusCode}, body: ${response.body}',
        );
        throw Exception('Azure transcription failed: ${response.statusCode}');
      }
    } catch (e) {
      logger.e('Error during Azure transcription: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> generatePronunciationFeedback(
    String audioUrl,
    String recognizedText,
    String? targetPhrase,
  ) async {
    final apiKey = dotenv.env['AZURE_SPEECH_KEY'] ?? '';
    final region = dotenv.env['AZURE_SPEECH_REGION'] ?? '';

    if (apiKey.isEmpty || region.isEmpty) {
      logger.e('Azure keys missing');
      return {
        'feedback':
            "Hi! I couldn't check your pronunciation due to a setup issue. Try again later!",
        'recognizedText': recognizedText,
      };
    }

    try {
      if (targetPhrase == null || targetPhrase.isEmpty) {
        return {
          'feedback':
              "Oops! I don't have a phrase to check. Try saying 'Thank you for calling, how may I assist you?'",
          'recognizedText': recognizedText,
        };
      }

      final response = await http
          .post(
            Uri.parse(
              'https://$region.stt.speech.microsoft.com/speech/recognition/conversation/cognitiveservices/v1?language=en-US',
            ),
            headers: {
              'Ocp-Apim-Subscription-Key': apiKey,
              'Content-Type': 'audio/wav; codecs=audio/pcm; samplerate=16000',
              'Pronunciation-Assessment': base64Encode(
                utf8.encode(
                  jsonEncode({
                    'referenceText': targetPhrase,
                    'gradingSystem': 'HundredMark',
                    'granularity': 'Phoneme',
                    'dimension': 'Comprehensive',
                  }),
                ),
              ),
            },
            body: (await http.get(Uri.parse(audioUrl))).bodyBytes,
          )
          .timeout(const Duration(seconds: 30));

      logger.i('Azure response: ${response.statusCode}, ${response.body}');

      if (response.statusCode != 200) {
        return {
          'feedback':
              "Oops! The pronunciation service is unavailable right now. Please try again later.",
          'recognizedText': recognizedText,
        };
      }

      final result = jsonDecode(response.body);
      if (result == null || result['RecognitionStatus'] != 'Success') {
        return {
          'feedback':
              "I couldn't understand that clearly. Please try saying it again!",
          'recognizedText': recognizedText,
        };
      }

      final nBest = result['NBest'] as List?;
      if (nBest == null || nBest.isEmpty) {
        logger.w('Azure NBest is null or empty: $result');
        return {
          'feedback':
              "Hmm, I couldn't analyze your pronunciation. Let's try again!",
          'recognizedText': recognizedText,
        };
      }

      final assessment = nBest.first;
      String feedback = "Here's your pronunciation analysis:\n\n";
      feedback += "🗣 You said: \"$recognizedText\"\n\n";
      feedback += "🎯 Target phrase: \"$targetPhrase\"\n\n";
      feedback += "📊 Scores:\n";
      feedback +=
          "• Accuracy: ${assessment['AccuracyScore']?.toStringAsFixed(1) ?? 'N/A'}% (sounds correct)\n";
      feedback +=
          "• Fluency: ${assessment['FluencyScore']?.toStringAsFixed(1) ?? 'N/A'}% (smoothness)\n";
      feedback +=
          "• Completeness: ${assessment['CompletenessScore']?.toStringAsFixed(1) ?? 'N/A'}% (whole phrase)\n\n";

      final words = assessment['Words'] as List?;
      if (words != null && words.isNotEmpty) {
        feedback += "🔍 Detailed feedback:\n";
        for (var word in words.cast<Map>()) {
          final wordText = word['Word'] as String? ?? '';
          final errorType = word['ErrorType'] as String?;
          final score =
              (word['PronunciationAssessment']?['AccuracyScore'] as num?)
                  ?.toDouble() ??
              0.0;
          if (errorType != null && errorType != 'None') {
            feedback += "- \"$wordText\": ";
            if (errorType == 'Mispronunciation') {
              feedback +=
                  "Needs better pronunciation (${score.toStringAsFixed(1)}%)\n";
            } else if (errorType == 'Omission') {
              feedback += "Missing this word\n";
            } else if (errorType == 'Insertion') {
              feedback += "Extra word added\n";
            }
          }
        }
      }

      final accuracy = (assessment['AccuracyScore'] as num?)?.toDouble() ?? 0.0;
      final fluency = (assessment['FluencyScore'] as num?)?.toDouble() ?? 0.0;
      final completeness =
          (assessment['CompletenessScore'] as num?)?.toDouble() ?? 0.0;

      if (accuracy < 60 || fluency < 60 || completeness < 60) {
        feedback += "\nKeep practicing! Focus on each sound.\n";
      } else if (accuracy < 80 || fluency < 80 || completeness < 80) {
        feedback += "\nGood effort! A little more practice will help.\n";
      } else {
        feedback += "\nExcellent pronunciation!\n";
      }

      return {
        'feedback': feedback,
        'recognizedText': recognizedText,
        'accuracyScore': accuracy,
        'fluencyScore': fluency,
        'completenessScore': completeness,
        'words': words,
        'textRecognized': recognizedText,
      };
    } catch (e) {
      logger.e('Pronunciation analysis error: $e');
      return {
        'feedback':
            "Sorry, I couldn't analyze your pronunciation. Please try again!",
        'recognizedText': recognizedText,
      };
    }
  }
}
