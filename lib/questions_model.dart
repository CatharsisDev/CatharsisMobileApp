import 'package:hive/hive.dart';

part 'questions_model.g.dart';  // This is required for linking the generated file

@HiveType(typeId: 0)  // Assign a unique typeId for this model
class Question extends HiveObject {
  @HiveField(0)
  final String text;

  @HiveField(1)
  final String category;

  Question({
    required this.text,
    required this.category,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      text: json['text'] as String,
      category: json['category'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'category': category,
    };
  }

  factory Question.fromCsv(List<dynamic> row) {
  // Normalize the category string when creating the question
  String normalizedCategory = row[1].toString()
      .replaceAll(RegExp(r'[^\x20-\x7E]'), '') 
      .replaceAll(RegExp(r'\s+'), ' ') // Normalize multiple spaces to single space
      .trim();
  
  return Question(
    text: row[0],
    category: normalizedCategory,
  );
}

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Question &&
        other.text == text &&
        other.category == category;
  }

  @override
  int get hashCode => text.hashCode ^ category.hashCode;

  @override
  String toString() => 'Question(text: $text, category: $category)';
}