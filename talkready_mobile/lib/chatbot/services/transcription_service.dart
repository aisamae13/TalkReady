import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';

class TranscriptionService {
  final Logger logger;

  TranscriptionService({required this.logger});

  /// Upload audio file to Firebase Storage
  Future<String> uploadToFirebaseStorage(String filePath) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('Audio file not found: $filePath');
    }

    final fileSizeInMB = await file.length() / (1024 * 1024);
    logger.i('File size: ${fileSizeInMB.toStringAsFixed(2)}MB');

    if (fileSizeInMB > 10) {
      throw Exception(
        'Audio file too large: ${fileSizeInMB.toStringAsFixed(2)}MB. Maximum is 10MB.',
      );
    }

    try {
      // Create a unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'audio_${timestamp}.wav';
      final storagePath = 'audio/${user.uid}/$fileName';

      logger.i('Uploading to Firebase Storage: $storagePath');

      // Upload file
      final storageRef = FirebaseStorage.instance.ref().child(storagePath);
      final uploadTask = await storageRef.putFile(
        file,
        SettableMetadata(contentType: 'audio/wav'),
      );

      // Get download URL
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      logger.i('Upload successful: $downloadUrl');

      return downloadUrl;
    } catch (e) {
      logger.e('Firebase Storage upload error: $e');
      throw Exception('Failed to upload audio: $e');
    }
  }

  /// Transcribe audio using Azure Speech-to-Text
  Future<String?> transcribeWithAzure(String audioUrl) async {
    final apiKey = dotenv.env['AZURE_SPEECH_KEY'];
    final region = dotenv.env['AZURE_SPEECH_REGION'];

    if (apiKey == null || apiKey.isEmpty || region == null || region.isEmpty) {
      logger.e('Azure Speech API key or region missing.');
      throw Exception('Azure Speech API key or region missing');
    }

    try {
      logger.i('Transcribing with Azure using audio URL: $audioUrl');

      // Download audio file
      final audioResponse = await http
          .get(Uri.parse(audioUrl))
          .timeout(
            Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Audio download timed out');
            },
          );

      if (audioResponse.statusCode != 200) {
        logger.e('Failed to download audio: ${audioResponse.statusCode}');
        throw Exception('Failed to retrieve audio for transcription');
      }

      final audioBytes = audioResponse.bodyBytes;
      logger.i('Audio downloaded: ${audioBytes.length} bytes');

      // Prepare Azure Speech-to-Text endpoint
      final endpoint =
          'https://$region.stt.speech.microsoft.com/speech/recognition/conversation/cognitiveservices/v1';
      final queryParams = {'language': 'en-US', 'format': 'detailed'};
      final uri = Uri.parse(endpoint).replace(queryParameters: queryParams);

      final headers = {
        'Ocp-Apim-Subscription-Key': apiKey,
        'Content-Type': 'audio/wav; codecs=audio/pcm; samplerate=16000',
        'Accept': 'application/json',
      };

      logger.i('Sending transcription request to Azure...');

      // Send transcription request
      final response = await http
          .post(uri, headers: headers, body: audioBytes)
          .timeout(
            Duration(seconds: 45),
            onTimeout: () {
              throw Exception('Transcription request timed out');
            },
          );

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

  /// Generate pronunciation feedback using Azure Pronunciation Assessment
  /// (This is only used in Practice Center, not in chatbot)
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
              "Oops! I don't have a phrase to check. Please try the practice exercises!",
          'recognizedText': recognizedText,
        };
      }

      logger.i('Downloading audio for pronunciation assessment: $audioUrl');
      final audioBytes = (await http.get(Uri.parse(audioUrl))).bodyBytes;

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
            body: audioBytes,
          )
          .timeout(const Duration(seconds: 30));

      logger.i(
        'Azure pronunciation response: ${response.statusCode}, ${response.body}',
      );

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
      final accuracy = (assessment['AccuracyScore'] as num?)?.toDouble() ?? 0.0;
      final fluency = (assessment['FluencyScore'] as num?)?.toDouble() ?? 0.0;
      final completeness =
          (assessment['CompletenessScore'] as num?)?.toDouble() ?? 0.0;
      final words = assessment['Words'] as List?;

      String feedback = "Here's your pronunciation analysis:\n\n";
      feedback += "🗣 You said: \"$recognizedText\"\n\n";
      feedback += "🎯 Target phrase: \"$targetPhrase\"\n\n";
      feedback += "📊 Scores:\n";
      feedback +=
          "• Accuracy: ${accuracy.toStringAsFixed(1)}% (sounds correct)\n";
      feedback += "• Fluency: ${fluency.toStringAsFixed(1)}% (smoothness)\n";
      feedback +=
          "• Completeness: ${completeness.toStringAsFixed(1)}% (whole phrase)\n\n";

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
