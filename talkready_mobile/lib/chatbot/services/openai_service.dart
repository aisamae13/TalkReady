import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/message.dart';
import '../models/prompt.dart';
import '../utils/text_processing.dart';

class OpenAIService {
  final Logger logger;

  OpenAIService({required this.logger});

  Future<Map<String, dynamic>> getOpenAIResponseWithFunctions(
    String prompt,
    List<Message> conversationHistory, {
    String? userInput,
    bool enablePracticeFunctions = false,
  }) async {
    final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      logger.e('OpenAI API key missing.');
      throw Exception('OpenAI API key missing');
    }

    try {
      final messages = [
        {'role': 'system', 'content': prompt},
        ...conversationHistory.reversed
            .take(5)
            .where((msg) => !msg.typing)
            .map((msg) => ({
                  'role': msg.isUser ? 'user' : 'assistant',
                  'content': msg.text,
                }))
            .toList()
            .reversed,
      ];

      if (userInput != null) {
        messages.add({'role': 'user', 'content': userInput});
      }

      // Define available functions for ALL practice modes
      final functions = enablePracticeFunctions ? [
        {
          'name': 'exit_practice_mode',
          'description': 'Call this function when the user wants to stop the current practice session and do something else. Use this for ANY practice mode (pronunciation, fluency, vocabulary, grammar) when they say things like "stop", "enough", "done", "let\'s try something different", "change topic", "I want to practice something else", etc.',
          'parameters': {
            'type': 'object',
            'properties': {
              'reason': {
                'type': 'string',
                'description': 'Brief reason why the user wants to exit (e.g., "user requested stop", "wants different activity", "switching to vocabulary practice")'
              }
            },
            'required': ['reason']
          }
        }
      ] : null;

      final requestBody = {
        'model': 'gpt-4o-mini',
        'messages': messages,
        'max_tokens': 200,
        'temperature': 0.8,
      };

      if (functions != null) {
        requestBody['functions'] = functions;
        requestBody['function_call'] = 'auto';
      }

      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final choice = data['choices'][0];
        final message = choice['message'];

        // Check if AI called a function
        if (message['function_call'] != null) {
          final functionName = message['function_call']['name'];
          final functionArgs = jsonDecode(message['function_call']['arguments']);

          logger.i('AI called function: $functionName with args: $functionArgs');

          return {
            'type': 'function_call',
            'function_name': functionName,
            'arguments': functionArgs,
            'message': null,
          };
        }

        // Regular text response
        final aiResponse = message['content'] ?? 'How can I help you?';
        logger.i('OpenAI response: $aiResponse');

        final cleanedResponse = cleanAIResponse(aiResponse);
        return {
          'type': 'message',
          'message': TextProcessing.cleanText(cleanedResponse),
          'function_name': null,
          'arguments': null,
        };
      } else {
        logger.e('OpenAI failed: ${response.statusCode}, ${response.body}');
        throw Exception('OpenAI request failed: ${response.statusCode}');
      }
    } catch (e) {
      logger.e('Error: $e');
      rethrow;
    }
  }

  // Keep the original method for backwards compatibility
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
    // Remove markdown bold
    response = response.replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1');
    response = response.replaceAll(RegExp(r'\*([^*]+)\*'), r'$1');

    // Remove bullet points and dashes at start of lines
    response = response.replaceAll(RegExp(r'^\s*[-•*]\s+', multiLine: true), '');

    // Remove numbered lists
    response = response.replaceAll(RegExp(r'^\s*\d+\.\s+', multiLine: true), '');

    // Remove headers (lines starting with #)
    response = response.replaceAll(RegExp(r'^#+\s+', multiLine: true), '');

    return response.trim();
  }

  Future<String> generateCallCenterPhrase() async {
    final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    if (apiKey.isEmpty) throw Exception('OpenAI key missing');

    try {
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-4',
          'messages': [
            {
              'role': 'system',
              'content': '''
              Generate ONE concise call-center practice phrase (8-12 words) for English learners.
              Examples:
              - "How may I assist you today?"
              - "Could you hold for a moment please?"
              - "Let me transfer you to the right department."
              Return ONLY the phrase. No quotes or numbering.
            '''
            }
          ],
          'temperature': 0.7,
          'max_tokens': 30,
        }),
      );

      if (response.statusCode == 200) {
        final phrase = jsonDecode(response.body)['choices'][0]['message']['content']
            .trim()
            .replaceAll('"', '');
        logger.i('Generated phrase: $phrase');
        return phrase;
      } else {
        throw Exception('OpenAI error: ${response.statusCode}');
      }
    } catch (e) {
      logger.e('Phrase generation failed: $e');
      return "Could you please repeat that?";
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
      basePersonality += '\n\nUser\'s name: $userName (use it naturally, don\'t overuse it)';
    }

    if (currentPrompt != null) {
      basePersonality += '\n\nCURRENT LEARNING FOCUS:\n${currentPrompt.promptText}';
      logger.i("Using prompt: ${currentPrompt.title}");
    } else {
      logger.i("Using general conversation prompt.");
    }

    if (practiceMode != null) {
      basePersonality += '\n\nPractice Mode: ${Prompt.categoryToString(practiceMode)}';

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
1. ALWAYS provide text to read (2-3 sentences) in double quotes
2. Format: Brief intro + "Read this smoothly: "[2-3 sentences]""
3. After feedback, IMMEDIATELY provide new text to practice
4. NEVER respond without quoted text for fluency practice

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
        basePersonality += '\nCurrent practice phrase: "$practiceTargetText"';
      }
    }

    if (context != null && context.containsKey('rolePlayDuration')) {
      final duration = context['rolePlayDuration'];
      final elapsed = context['rolePlayElapsed'] ?? 0;
      final remaining = duration - elapsed;

      basePersonality += '''

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

      basePersonality += '''

The user just practiced pronunciation. They got Accuracy: $accuracy%, Fluency: $fluency%.
Their recognized text was "$recognizedText" and the target was "$practiceTargetText".

Give brief, friendly feedback (1-2 sentences) about their pronunciation. Don't repeat the scores since they see a detailed display. Then IMMEDIATELY provide a new phrase to practice in double quotes. Example: "Good job on that! Now try: "[new phrase]""
''';
    }

    return basePersonality;
  }

  String? extractPracticePhrase(String botMessage, PromptCategory? mode) {
    if (mode != PromptCategory.pronunciation && mode != PromptCategory.fluency) {
      return null;
    }

    logger.i("Attempting to extract target text for mode: $mode from bot message: $botMessage");

    // Try to extract text from quotes first
    final quoteMatch = RegExp(r'[""]([^""]+)[""]').firstMatch(botMessage);
    if (quoteMatch != null && quoteMatch.group(1) != null) {
      final extracted = quoteMatch.group(1)!.trim();
      logger.i("Extracted text from quotes: $extracted");
      return extracted;
    }

    // Try common prefaces
    final prefaces = [
      "try saying:", "please say:", "try this:",
      "practice saying:", "say this:", "read this:",
      "here's the sentence:", "the sentence is:",
      "practice this:", "read aloud:", "let's try:",
      "practice:", "read smoothly:"
    ];

    for (final preface in prefaces) {
      final prefaceIndex = botMessage.toLowerCase().indexOf(preface.toLowerCase());
      if (prefaceIndex != -1) {
        String textAfterPreface = botMessage.substring(prefaceIndex + preface.length).trim();

        // Try quotes after preface
        final innerQuoteMatch = RegExp(r'^[""]([^""]+)[""]').firstMatch(textAfterPreface);
        if (innerQuoteMatch != null && innerQuoteMatch.group(1) != null) {
          final extracted = innerQuoteMatch.group(1)!.trim();
          logger.i('Extracted text after preface ("$preface"): $extracted');
          return extracted;
        }

        // Try sentence ending
        final sentenceEndMatch = RegExp(r'^([^.!?\n]+[.!?]?)').firstMatch(textAfterPreface);
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

    logger.i("No new phrase extracted from this response (may be feedback or question)");
    return null;
  }
}