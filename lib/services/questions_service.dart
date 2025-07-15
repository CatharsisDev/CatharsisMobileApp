import 'package:csv/csv.dart';
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
          .map((row) {
            row[1] = row[1]
                .toString()
                .replaceAll(RegExp(r'\s+'), ' ')
                .trim(); // Normalize category string
            return Question.fromCsv(row);
          })
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
    List<Question> aiQuestions = [];
    final categories = ['Love and Intimacy', 'Spirituality', 'Society', 'Interactions and Relationships', 'Personal Development'];
    for (String category in categories) {
      final normalizedCategory = category.replaceAll(RegExp(r'\s+'), ' ').trim();
      final aiQuestionsBatch = await OpenAIService.generateQuestions(category: normalizedCategory, count: countPerCategory);
      aiQuestions.addAll(aiQuestionsBatch);
    }
    return aiQuestions;
  }
}