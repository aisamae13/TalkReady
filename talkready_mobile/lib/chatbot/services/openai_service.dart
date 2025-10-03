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

  Future<String> getOpenAIResponse(
    String prompt,
    List<Message> conversationHistory, {
    String? userInput,
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

      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': messages,
          'max_tokens': 200,
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiResponse = data['choices'][0]['message']['content'] ?? 'How can I help you?';
        logger.i('OpenAI response: $aiResponse');
        return TextProcessing.cleanText(aiResponse);
      } else {
        logger.e('OpenAI failed: ${response.statusCode}, ${response.body}');
        throw Exception('OpenAI request failed: ${response.statusCode}');
      }
    } catch (e) {
      logger.e('Error: $e');
      rethrow;
    }
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
    String systemPrompt;

    if (currentPrompt != null) {
      systemPrompt = currentPrompt.promptText;
      logger.i("Using prompt: ${currentPrompt.title}");
    } else {
      systemPrompt = 'You are TalkReady, a friendly English-speaking assistant for call-center practice. Be encouraging. User: ${userName ?? "User"}.';
      logger.i("Using general conversation prompt.");
    }

    // Add practice mode specific instructions (from web version)
    final modeForPrompt = practiceMode;
    if (modeForPrompt != null) {
      systemPrompt += ' The user is currently in \'${Prompt.categoryToString(modeForPrompt)}\' practice mode.';

      if (modeForPrompt == PromptCategory.pronunciation) {
        systemPrompt += " Provide a short, clear sentence (around 8-15 words) enclosed in double quotes for the user to read aloud. For example: User says 'I want to practice pronunciation.' You reply: 'Okay, let's practice! Please say: \"The weather is lovely today.\"'.";
      } else if (modeForPrompt == PromptCategory.fluency) {
        systemPrompt += " Provide a slightly longer text (2-3 short sentences) enclosed in double quotes for the user to read to practice fluency. For example: 'Great! For fluency, please read this: \"Call center agents need to be clear and efficient. Good communication is key to customer satisfaction.\"'";
      } else if (modeForPrompt == PromptCategory.grammar) {
        systemPrompt += " Ask the user to provide the sentence they want you to check for grammar, or if they've provided one, analyze it for grammatical correctness.";
      } else if (modeForPrompt == PromptCategory.vocabulary) {
        systemPrompt += " Provide a customer service-related vocabulary word, its definition, and an example sentence. Then ask the user to try using it in their own sentence.";
      } else if (modeForPrompt == PromptCategory.rolePlay) {
        systemPrompt += " Initiate a simple customer service role-play scenario. You can be the customer first, or ask the user if they want to be the customer or agent. Keep turns short.";
      }
    }

    // Add Azure feedback context
    if (context != null && context['azureScoresSummary'] != null) {
      systemPrompt += ' The user just received Azure speech feedback. Comment briefly on their scores (Accuracy: ${context['accuracyScore']?.toStringAsFixed(0)}%, Fluency: ${context['fluencyScore']?.toStringAsFixed(0)}). Their recognized text was "${context['recognizedText']}". Their original target was "$practiceTargetText". Ask if they\'d like to try another sentence for ${modeForPrompt != null ? Prompt.categoryToString(modeForPrompt) : "this"} practice, OR if they want to switch to a different activity.';
    }

    return systemPrompt;
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
      "Here's the first one:", "Here's the next one:",
      "Here's the sentence again for you to practice:",
      "Okay, please say this for pronunciation practice:",
      "Alright, let's practice fluency. Please read this:",
      "The sentence for you to practice is:",
      "Practice this sentence:", "Try this sentence:",
      "Please say:"
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

    logger.w("Could not reliably extract practice text.");
    return null;
  }
}