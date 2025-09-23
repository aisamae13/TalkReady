// lib/services/ai_feedback_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AIFeedbackService {
  final Logger _logger = Logger();
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';

  Future<Map<String, dynamic>> evaluateCallSimulation(
    Map<String, dynamic> conversationData,
  ) async {
    try {
      final apiKey = dotenv.env['OPENAI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('OpenAI API key not found');
      }

      final prompt = _buildEvaluationPrompt(conversationData);

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are an expert call center trainer who evaluates customer service calls and provides detailed feedback.',
            },
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.3,
          'max_tokens': 1500,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        return _parseAIResponse(content);
      } else {
        _logger.e('AI API Error: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to get AI feedback');
      }
    } catch (e) {
      _logger.e('Error in AI feedback service: $e');
      rethrow;
    }
  }

  String _buildEvaluationPrompt(Map<String, dynamic> data) {
    final scenario = data['scenario'];
    final conversation = data['conversation'] as List<dynamic>;
    final duration = data['duration'];

    final conversationText = conversation
        .map((entry) => '${entry['speaker']}: ${entry['message']}')
        .join('\n');

    return '''
Evaluate this customer service call simulation for a new call center agent:

SCENARIO:
- Customer: ${scenario['customerName']}
- Request: ${scenario['details']['question']}
- Expected Response: ${scenario['details']['expectedInfo']}

CONVERSATION:
$conversationText

CALL DURATION: ${duration} seconds

Please evaluate the agent's performance and provide feedback in the following JSON format:
{
  "overallScore": [0-100],
  "callCenterReadiness": "[Poor|Fair|Good|Excellent]",
  "skillScores": {
    "Grammar": [0-100],
    "Conversation": [0-100], 
    "Speaking": [0-100],
    "Handling": [0-100]
  },
  "strengths": [
    "List specific things the agent did well"
  ],
  "improvements": [
    "List specific areas for improvement"
  ],
  "stepFeedback": {
    "greeting": {"score": [0-100], "feedback": "specific feedback"},
    "listening": {"score": [0-100], "feedback": "specific feedback"},
    "information": {"score": [0-100], "feedback": "specific feedback"},
    "closing": {"score": [0-100], "feedback": "specific feedback"}
  }
}

Focus on:
1. Professional greeting and introduction
2. Active listening and acknowledgment
3. Clear and accurate information delivery
4. Professional closing and additional help offer
5. Overall communication skills and tone
''';
  }

  Map<String, dynamic> _parseAIResponse(String content) {
    try {
      // Try to extract JSON from the response
      final jsonStart = content.indexOf('{');
      final jsonEnd = content.lastIndexOf('}') + 1;

      if (jsonStart != -1 && jsonEnd > jsonStart) {
        final jsonString = content.substring(jsonStart, jsonEnd);
        return jsonDecode(jsonString);
      }

      throw Exception('No valid JSON found in response');
    } catch (e) {
      _logger.e('Error parsing AI response: $e');

      // Return fallback feedback
      return {
        'overallScore': 75.0,
        'callCenterReadiness': 'Good',
        'skillScores': {
          'Grammar': 75,
          'Conversation': 73,
          'Speaking': 78,
          'Handling': 72,
        },
        'strengths': [
          'Attempted professional communication',
          'Responded to customer inquiry',
          'Maintained appropriate call duration',
        ],
        'improvements': [
          'Work on structured greetings',
          'Practice active listening techniques',
          'Improve call closing procedures',
        ],
        'stepFeedback': {
          'greeting': {'score': 70, 'feedback': 'Good attempt at greeting'},
          'listening': {'score': 75, 'feedback': 'Showed understanding'},
          'information': {
            'score': 78,
            'feedback': 'Information delivered clearly',
          },
          'closing': {'score': 72, 'feedback': 'Professional closing attempt'},
        },
      };
    }
  }
}
