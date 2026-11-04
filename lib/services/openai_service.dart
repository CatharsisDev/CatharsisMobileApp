import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../questions_model.dart';
import 'question_quality.dart';

/// Generates AI-powered questions by calling the `generateQuestions` Firebase Cloud Function.
///
/// The Cloud Function calls the OpenAI API server-side using the OPENAI_API_KEY stored
/// in the Function's environment variables. The key never ships inside the app binary.
///
/// The function accepts { category, count } and returns { questions: [string, ...] }.
/// Returned strings are cleaned (bullets/numbering stripped) before being wrapped
/// in Question objects.
class OpenAIService {
  static Future<List<Question>> generateQuestions({
    required String category,
    int count = 5,
  }) async {
    // Backstop auth check — callers should already have waited for auth,
    // but guard here too to make the error message more useful.
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('[OpenAI] Cannot call function: no authenticated user.');
    }

    try {
      final callable = FirebaseFunctions.instance
          .httpsCallable('generateQuestions');

      final result = await callable.call<Map<String, dynamic>>({
        'category': category,
        'count': count,
      });

      final rawList = result.data['questions'] as List<dynamic>? ?? [];
      // Clean each line and drop anything incomplete or malformed (cut-off
      // text, intro lines, stray fragments). See QuestionQuality.
      return rawList
          .whereType<String>()
          .map(QuestionQuality.cleanOrNull)
          .whereType<String>()
          .toSet() // drop duplicates within the batch
          .map((text) => Question(text: text, category: category))
          .toList();
    } on FirebaseFunctionsException catch (e) {
      throw Exception('[OpenAI] Function error (${e.code}): ${e.message}');
    } catch (e) {
      throw Exception('[OpenAI] Unexpected error: $e');
    }
  }
}
