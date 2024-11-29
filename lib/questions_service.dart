import 'package:csv/csv.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'questions_model.dart';

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
            return Question.fromCsv(row);
          })
          .toList();
      
      
      return questions;
    } catch (e) {
      return [];
    }
  }
}