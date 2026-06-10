import 'package:cloud_functions/cloud_functions.dart';
import '../questions_model.dart';

class OpenAIService {
  static Future<List<Question>> generateQuestions({
    required String category,
    int count = 5,
  }) async {
    try {
      final callable = FirebaseFunctions.instance
          .httpsCallable('generateQuestions');

      final result = await callable.call<Map<String, dynamic>>({
        'category': category,
        'count': count,
      });

      final rawList = result.data['questions'] as List<dynamic>? ?? [];
      return rawList
          .cast<String>()
          .map((text) => Question(text: text, category: category))
          .toList();
    } on FirebaseFunctionsException catch (e) {
      throw Exception('[OpenAI] Function error (${e.code}): ${e.message}');
    } catch (e) {
      throw Exception('[OpenAI] Unexpected error: $e');
    }
  }
}
