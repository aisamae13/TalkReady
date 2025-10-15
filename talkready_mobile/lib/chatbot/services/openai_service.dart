import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import '../../config/api_config.dart';
import '../../config/environment.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/message.dart';
import '../models/prompt.dart';
import '../utils/text_processing.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OpenAIService {
  final Logger logger;

  OpenAIService({required this.logger});

  Future<Map<String, dynamic>> getOpenAIResponseWithFunctions(
    String prompt,
    List<Message> conversationHistory, {
    String? userInput,
    bool enablePracticeFunctions = false,
  }) async {
    // Get Firebase auth token for authentication
    final user = FirebaseAuth.instance.currentUser;
    String? idToken;

    if (user != null) {
      try {
        idToken = await user.getIdToken();
      } catch (e) {
        logger.w('Could not get Firebase token: $e');
      }
    }

    // Retry logic
    int maxRetries = 3;
    int retryCount = 0;
    Duration retryDelay = Duration(seconds: 2);

    while (retryCount < maxRetries) {
      try {
        // Get API base URL using your config
        final baseUrl = await ApiConfig.getApiBaseUrl();
        logger.i('Using API base URL: $baseUrl');

        // Build conversation messages
        final messages = [
          {'role': 'system', 'content': prompt},
          ...conversationHistory.reversed
              .take(3) // Keep last 3 messages for context
              .where((msg) => !msg.typing)
              .map(
                (msg) => ({
                  'role': msg.isUser ? 'user' : 'assistant',
                  'content': msg.text,
                }),
              )
              .toList()
              .reversed,
        ];

        if (userInput != null) {
          messages.add({'role': 'user', 'content': userInput});
        }

        final requestBody = {
          'messages': messages,
          'maxTokens': 200,
          'temperature': 0.8,
          'enablePracticeFunctions': enablePracticeFunctions,
        };

        logger.i(
          'Sending chat request to backend (attempt ${retryCount + 1}/$maxRetries)...',
        );

        // Check if backend might be cold starting
        if (ApiConfig.mightBeColdStarting && retryCount == 0) {
          logger.i('⏳ Backend might be waking up from cold start...');
        }

        // Call your backend /chat endpoint
        final response = await http
            .post(
              Uri.parse('$baseUrl/chat'),
              headers: {
                'Content-Type': 'application/json',
                'User-Agent': 'TalkReady-Mobile/1.0',
                if (idToken != null) 'Authorization': 'Bearer $idToken',
              },
              body: jsonEncode(requestBody),
            )
            .timeout(
              EnvironmentConfig.networkTimeout, // Use your config timeout
              onTimeout: () {
                throw TimeoutException(
                  'Backend request timed out after ${EnvironmentConfig.networkTimeout.inSeconds} seconds',
                );
              },
            );

        logger.i('Backend response status: ${response.statusCode}');

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);

          // Check if backend returned a function call
          if (data['type'] == 'function_call') {
            logger.i(
              'AI called function: ${data['function_name']} with args: ${data['arguments']}',
            );
            return {
              'type': 'function_call',
              'function_name': data['function_name'],
              'arguments': data['arguments'],
              'message': null,
            };
          }

          // Regular message response
          final aiResponse =
              data['message'] ?? data['response'] ?? 'How can I help you?';
          logger.i('Backend AI response: $aiResponse');

          final cleanedResponse = cleanAIResponse(aiResponse);
          return {
            'type': 'message',
            'message': TextProcessing.cleanText(cleanedResponse),
            'function_name': null,
            'arguments': null,
          };
        } else if (response.statusCode == 429) {
          // Rate limit
          logger.w('Backend rate limit hit, waiting before retry...');
          await Future.delayed(Duration(seconds: 5));
          retryCount++;
          continue;
        } else if (response.statusCode == 503 || response.statusCode == 502) {
          // Service unavailable or Bad Gateway (Render cold start)
          logger.w(
            'Backend unavailable (${response.statusCode}) - likely cold start, retrying...',
          );

          // Reset API cache to force health check on next attempt
          ApiConfig.resetCache();

          await Future.delayed(Duration(seconds: 10));
          retryCount++;
          continue;
        } else if (response.statusCode >= 500) {
          // Server error
          logger.w(
            'Backend server error (${response.statusCode}), retrying...',
          );
          retryCount++;
          await Future.delayed(retryDelay);
          retryDelay *= 2;
          continue;
        } else {
          final errorBody = response.body;
          logger.e(
            'Backend request failed: ${response.statusCode}, Body: $errorBody',
          );

          // Try to parse error message
          try {
            final errorData = jsonDecode(errorBody);
            final errorMessage =
                errorData['error'] ?? errorData['message'] ?? 'Unknown error';
            throw Exception('Backend error: $errorMessage');
          } catch (_) {
            throw Exception('Backend request failed: ${response.statusCode}');
          }
        }
      } on TimeoutException catch (e) {
        retryCount++;
        logger.w(
          'Backend timeout (attempt $retryCount/$maxRetries): ${e.message}',
        );

        if (retryCount >= maxRetries) {
          if (ApiConfig.mightBeColdStarting) {
            throw Exception(
              'Backend is starting up. Please wait 15-30 seconds and try again.',
            );
          }
          throw Exception(
            'Backend request timed out after $maxRetries attempts. Please check your internet connection.',
          );
        }

        // Reset cache for next attempt
        ApiConfig.resetCache();
        await Future.delayed(retryDelay);
        retryDelay *= 2;
      } on SocketException catch (e) {
        retryCount++;
        logger.w('Network error (attempt $retryCount/$maxRetries): $e');

        if (retryCount >= maxRetries) {
          throw Exception(
            'Network connection failed. Please check your internet connection.',
          );
        }

        await Future.delayed(retryDelay);
        retryDelay *= 2;
      } catch (e) {
        retryCount++;
        logger.e('Backend error (attempt $retryCount/$maxRetries): $e');

        if (retryCount >= maxRetries) {
          throw Exception(
            'Failed to get AI response: ${e.toString().replaceAll('Exception: ', '')}',
          );
        }

        await Future.delayed(retryDelay);
        retryDelay *= 2;
      }
    }

    throw Exception('Failed to get AI response after $maxRetries attempts');
  }

  Future<String> getOpenAIResponse(
    String prompt,
    List<Message> conversationHistory, {
    String? userInput,
  }) async {
    final result = await getOpenAIResponseWithFunctions(
      prompt,
      conversationHistory,
      userInput: userInput,
      enablePracticeFunctions: false,
    );
    return result['message'] as String;
  }

  String cleanAIResponse(String response) {
    response = response.replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1');
    response = response.replaceAll(RegExp(r'\*([^*]+)\*'), r'$1');
    response = response.replaceAll(
      RegExp(r'^\s*[-•*]\s+', multiLine: true),
      '',
    );
    response = response.replaceAll(
      RegExp(r'^\s*\d+\.\s+', multiLine: true),
      '',
    );
    response = response.replaceAll(RegExp(r'^#+\s+', multiLine: true), '');
    return response.trim();
  }

  Future<String> generateCallCenterPhrase() async {
    try {
      final baseUrl = await ApiConfig.getApiBaseUrl();

      final response = await http
          .post(
            Uri.parse('$baseUrl/generate-phrase'),
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': 'TalkReady-Mobile/1.0',
            },
          )
          .timeout(EnvironmentConfig.networkTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final phrase = data['phrase'] ?? "Could you please repeat that?";
        logger.i('Generated phrase: $phrase');
        return phrase;
      } else {
        throw Exception('Failed to generate phrase: ${response.statusCode}');
      }
    } catch (e) {
      logger.e('Phrase generation failed: $e');
      // Fallback phrase
      return "How may I assist you today?";
    }
  }

  Future<String> generateFluencyPassage() async {
    try {
      final baseUrl = await ApiConfig.getApiBaseUrl();

      final response = await http
          .post(
            Uri.parse('$baseUrl/generate-passage'),
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': 'TalkReady-Mobile/1.0',
            },
          )
          .timeout(EnvironmentConfig.networkTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final passage =
            data['passage'] ??
            "Welcome to our customer service. How may I help you today?";
        logger.i('Generated fluency passage: $passage');
        return passage;
      } else {
        throw Exception('Failed to generate passage: ${response.statusCode}');
      }
    } catch (e) {
      logger.e('Fluency passage generation failed: $e');
      // Fallback passage
      return "Thank you for contacting our support team. I understand you need assistance. Let me help you resolve this right away.";
    }
  }

  String buildSystemPrompt({
    required Prompt? currentPrompt,
    String? userName,
    PromptCategory? practiceMode,
    Map<String, dynamic>? context,
    String? practiceTargetText,
  }) {
    String basePersonality = '''
You are TalkReady Bot, a friendly and supportive English conversation partner. You help people practice English in a warm, natural way.

CRITICAL RESPONSE STYLE RULES:
- Write like you're chatting with a friend - conversational and flowing
- NEVER use bullet points, numbered lists, or asterisks (**)
- NEVER use markdown formatting or special symbols
- Write in complete sentences and short paragraphs
- Use natural transitions like "Also," "By the way," "Oh, and" instead of lists
- Keep responses concise but warm - usually 2-4 sentences unless the topic needs more
- Sound human and relatable, not robotic or overly formal
- You can use casual phrases like "Yeah," "Sure thing," "Got it," "No worries"
- Be encouraging but genuine - avoid over-the-top praise

CONVERSATION APPROACH:
- Ask follow-up questions naturally when appropriate
- Share brief examples when explaining things (work them into your sentences)
- Give feedback in a friendly, helpful way without sounding like a teacher
- If correcting grammar, do it gently: "Just a heads up, you could say..." or "Quick note..."
- React to what the user says with genuine interest

WHAT TO AVOID:
- Don't say "Here are X things..." or "Let me give you X tips..."
- Don't structure responses like lessons or tutorials
- Don't use headers or sections
- Don't end with "Let me know if..." every single time
- Don't sound overly enthusiastic or fake
''';

    if (userName != null && userName.isNotEmpty) {
      basePersonality +=
          '\n\nUser\'s name: $userName (use it naturally, don\'t overuse it)';
    }

    if (currentPrompt != null) {
      basePersonality +=
          '\n\nCURRENT LEARNING FOCUS:\n${currentPrompt.promptText}';
      logger.i("Using prompt: ${currentPrompt.title}");
    } else {
      logger.i("Using general conversation prompt.");
    }

    if (practiceMode != null) {
      basePersonality +=
          '\n\nPractice Mode: ${Prompt.categoryToString(practiceMode)}';

      if (practiceMode == PromptCategory.pronunciation) {
        basePersonality += '''

PRONUNCIATION PRACTICE MODE - CRITICAL RULES:
1. ALWAYS include a practice phrase in your response, in double quotes
2. Format: Brief feedback (1-2 sentences) + "Let's try: "[phrase]""
3. After giving feedback, IMMEDIATELY provide the next phrase
4. Examples of correct responses:
   - "Nice job! Let's try: "How may I help you today?""
   - "Good work! Practice this: "Please hold while I transfer your call.""
5. Keep practice phrases 8-15 words, customer service related
6. The phrase must be in double quotes ("like this") so it can be extracted

EXCEPTION - User wants to stop:
If the user indicates they want to stop (e.g., "stop", "enough", "done", "change topic"), call the exit_practice_mode function instead of providing a new phrase.
''';
      } else if (practiceMode == PromptCategory.fluency) {
        basePersonality += '''

FLUENCY PRACTICE MODE - CRITICAL RULES:
1. ALWAYS provide a reading passage (2-3 sentences) in double quotes
2. Format: Brief intro/feedback (1 sentence) + "Read this smoothly: "[passage]""
3. After feedback, IMMEDIATELY provide new text to practice
4. Keep passages natural and conversational (20-35 words)
5. Focus on customer service scenarios
6. The passage must be in double quotes ("like this") so it can be extracted
7. Example: "Great flow! Now try: "Thank you for calling. I understand your concern. Let me check that for you right away.""

EXCEPTION - User wants to stop:
If the user wants to exit, call the exit_practice_mode function.
''';
      } else if (practiceMode == PromptCategory.grammar) {
        basePersonality += '''

GRAMMAR PRACTICE MODE:
- Ask the user to provide a sentence they want checked, or if they've provided one, analyze it gently
- Give feedback conversationally, not like a textbook
- Offer corrections in a friendly way: "You could say it like..." or "A better way might be..."
- After feedback, offer to check another sentence or ask if they want to continue

EXCEPTION - User wants to stop:
If the user wants to exit grammar practice, call the exit_practice_mode function.
''';
      } else if (practiceMode == PromptCategory.vocabulary) {
        basePersonality += '''

VOCABULARY PRACTICE MODE:
- Share a customer service word or phrase
- Explain what it means in simple terms
- Give a realistic example of how to use it
- Ask them to try using it in a sentence
- After they practice, give feedback and introduce a new word

EXCEPTION - User wants to stop:
If the user wants to exit vocabulary practice, call the exit_practice_mode function.
''';
      } else if (practiceMode == PromptCategory.rolePlay) {
        basePersonality += '''

ROLE-PLAY PRACTICE MODE:
- Stay in character as either a customer service agent or customer (based on what the user chose)
- Keep responses natural and realistic, like an actual customer service conversation
- Don't break character or give meta-commentary
- Keep turns short and conversational

EXCEPTION - User wants to stop:
If the user wants to exit the role-play, call the exit_practice_mode function.
''';
      }

      if (practiceTargetText != null) {
        basePersonality += '\nCurrent practice text: "$practiceTargetText"';
      }
    }

    if (context != null && context.containsKey('rolePlayDuration')) {
      final duration = context['rolePlayDuration'];
      final elapsed = context['rolePlayElapsed'] ?? 0;
      final remaining = duration - elapsed;

      basePersonality +=
          '''

ROLE-PLAY SESSION INFO:
- Total session: $duration minutes
- Time elapsed: $elapsed minutes
- Time remaining: $remaining minutes
- Stay in character throughout the session
- Keep the conversation flowing naturally as a customer service scenario
''';
    }

    if (context != null && context.containsKey('azureScoresSummary')) {
      final accuracy = context['accuracyScore']?.toStringAsFixed(0) ?? '0';
      final fluency = context['fluencyScore']?.toStringAsFixed(0) ?? '0';
      final recognizedText = context['recognizedText'] ?? '';
      final isFluentMode = context['isFluencyMode'] == true;

      if (isFluentMode) {
        basePersonality +=
            '''

The user just practiced reading fluency. They got Fluency: $fluency%, Accuracy: $accuracy%.
Their recognized text was "$recognizedText" and the target passage was "$practiceTargetText".

Give brief, friendly feedback (1-2 sentences) about their reading fluency and flow. Don't repeat the scores since they see a detailed display. Then IMMEDIATELY provide a new passage to practice in double quotes. Example: "Nice rhythm! Now read: "[new passage]""
''';
      } else {
        basePersonality +=
            '''

The user just practiced pronunciation. They got Accuracy: $accuracy%, Fluency: $fluency%.
Their recognized text was "$recognizedText" and the target was "$practiceTargetText".

Give brief, friendly feedback (1-2 sentences) about their pronunciation. Don't repeat the scores since they see a detailed display. Then IMMEDIATELY provide a new phrase to practice in double quotes. Example: "Good job on that! Now try: "[new phrase]""
''';
      }
    }

    return basePersonality;
  }

  String? extractPracticePhrase(String botMessage, PromptCategory? mode) {
    if (mode != PromptCategory.pronunciation &&
        mode != PromptCategory.fluency) {
      return null;
    }

    logger.i(
      "Attempting to extract target text for mode: $mode from bot message: $botMessage",
    );

    // Try to extract text from quotes first
    final quoteMatch = RegExp(r'[""]([^""]+)[""]').firstMatch(botMessage);
    if (quoteMatch != null && quoteMatch.group(1) != null) {
      final extracted = quoteMatch.group(1)!.trim();
      logger.i("Extracted text from quotes: $extracted");
      return extracted;
    }

    // Try common prefaces
    final prefaces = [
      "try saying:",
      "please say:",
      "try this:",
      "practice saying:",
      "say this:",
      "read this:",
      "here's the sentence:",
      "the sentence is:",
      "practice this:",
      "read aloud:",
      "let's try:",
      "practice:",
      "read smoothly:",
      "now try:",
      "now read:",
    ];

    for (final preface in prefaces) {
      final prefaceIndex = botMessage.toLowerCase().indexOf(
        preface.toLowerCase(),
      );
      if (prefaceIndex != -1) {
        String textAfterPreface = botMessage
            .substring(prefaceIndex + preface.length)
            .trim();

        // Try quotes after preface
        final innerQuoteMatch = RegExp(
          r'^[""]([^""]+)[""]',
        ).firstMatch(textAfterPreface);
        if (innerQuoteMatch != null && innerQuoteMatch.group(1) != null) {
          final extracted = innerQuoteMatch.group(1)!.trim();
          logger.i('Extracted text after preface ("$preface"): $extracted');
          return extracted;
        }

        // Try sentence ending
        final sentenceEndMatch = RegExp(
          r'^([^.!?\n]+[.!?]?)',
        ).firstMatch(textAfterPreface);
        if (sentenceEndMatch != null && sentenceEndMatch.group(1) != null) {
          String extracted = sentenceEndMatch.group(1)!.trim();
          extracted = extracted.replaceAll(RegExp(r'^["""]|["""]$'), '').trim();

          if (extracted.length > 5) {
            logger.i('Extracted text after preface ("$preface"): $extracted');
            return extracted;
          }
        }
      }
    }

    logger.i(
      "No new phrase extracted from this response (may be feedback or question)",
    );
    return null;
  }
}
