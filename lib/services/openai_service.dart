import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../questions_model.dart';

class OpenAIService {
  static final String _apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';

  static Future<List<Question>> generateQuestions({
    required String category,
    int count = 5,
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception('OpenAI API key not found');
    }

    final prompt = '''Generate $count thought-provoking conversation questions for "$category".
Make them open-ended, deep, and under 12 words each.
Return only the questions, one per line.''';
    
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
          'max_tokens': 500,
          'temperature': 0.8,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        return _parseQuestions(content, category);
      } else {
        throw Exception('Failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static List<Question> _parseQuestions(String content, String category) {
    return content.split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map((line) => line.trim().replaceAll(RegExp(r'^\d+\.?\s*'), ''))
        .map((text) => Question(text: text, category: category))
        .toList();
  }
}