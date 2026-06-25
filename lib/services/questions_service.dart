import 'package:csv/csv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../questions_model.dart';
import 'openai_service.dart';

class QuestionsService {
  static Future<List<Question>> loadQuestions() async {
    try {
      final rawData = await rootBundle.loadString('assets/Card_Statements_Questions.csv');
      
      List<List<dynamic>> csvTable = const CsvToListConverter(fieldDelimiter: ';')
          .convert(rawData);
      
      for (var i = 0; i < 5 && i < csvTable.length; i++) {
        print(csvTable[i]);
      }
      
      List<Question> questions = csvTable
          .skip(1)
          .where((row) => row.length >= 2)
          .map((row) {
            // Normalize both text and category so the same question
            // is never stored under two different string representations.
            final text = row[0]
                .toString()
                .replaceAll(RegExp(r'[^\x20-\x7E]'), '')
                .replaceAll(RegExp(r'\s+'), ' ')
                .trim();
            final category = row[1]
                .toString()
                .replaceAll(RegExp(r'[^\x20-\x7E]'), '')
                .replaceAll(RegExp(r'\s+'), ' ')
                .trim();
            return Question(text: text, category: category);
          })
          .where((q) => q.text.isNotEmpty && q.category.isNotEmpty)
          .toList();
      
      return questions;
    } catch (e) {
      return [];
    }
  }

  static Future<List<Question>> loadQuestionsWithAI() async {
    List<Question> allQuestions = [];
    
    // Load CSV questions first
    try {
      final csvQuestions = await loadQuestions();
      allQuestions.addAll(csvQuestions);
      print('Loaded ${csvQuestions.length} CSV questions');
    } catch (e) {
      print('CSV loading failed: $e');
    }

    try {
      final categories = ['Love and Intimacy', 'Spirituality', 'Society', 'Interactions and Relationships', 'Personal Development'];
      int aiCount = 0;
      
      for (String category in categories) {
        final normalizedCategory = category.replaceAll(RegExp(r'\s+'), ' ').trim();
        final aiQuestions = await OpenAIService.generateQuestions(category: normalizedCategory, count: 25);
        allQuestions.addAll(aiQuestions);
        aiCount += aiQuestions.length;
      }
      
      print('Added $aiCount AI questions');
    } catch (e) {
      print('AI generation failed: $e');
    }
    
    return allQuestions..shuffle();
  }

  static Future<List<Question>> generateAdditionalQuestions({int countPerCategory = 25}) async {
    // --- Auth guard ---
    // On cold start, Firebase Auth restores the persisted session asynchronously.
    // currentUser can be null for a few seconds even though the user IS signed in.
    // Calling a Cloud Function with no token causes UNAUTHENTICATED, so we wait.
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('[QuestionsService] currentUser is null — waiting for auth state...');
      try {
        user = await FirebaseAuth.instance
            .authStateChanges()
            .where((u) => u != null)
            .first
            .timeout(const Duration(seconds: 10));
      } catch (_) {
        // Still null after 10 s — truly not signed in; skip AI generation.
        print('[QuestionsService] Auth not available after timeout, skipping AI.');
        return [];
      }
    }
    if (user == null) {
      print('[QuestionsService] No authenticated user, skipping AI generation.');
      return [];
    }

    // Force a token refresh so the callable function never gets UNAUTHENTICATED.
    try {
      await user.getIdToken(true);
    } catch (_) {
      // If refresh fails we still try — the existing token may still be valid.
    }

    final List<Question> aiQuestions = [];
    const categories = [
      'Love and Intimacy',
      'Spirituality',
      'Society',
      'Interactions and Relationships',
      'Personal Development',
    ];
    for (final category in categories) {
      try {
        final normalizedCategory = category.replaceAll(RegExp(r'\s+'), ' ').trim();
        final batch = await OpenAIService.generateQuestions(
            category: normalizedCategory, count: countPerCategory);
        aiQuestions.addAll(batch);
      } catch (e) {
        // One category failing should not stop the rest.
        print('[QuestionsService] AI generation failed for "$category": $e');
      }
    }
    return aiQuestions;
  }
}