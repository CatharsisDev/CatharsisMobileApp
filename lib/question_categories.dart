import 'package:flutter/material.dart';
import 'questions_model.dart';

// Helper class to group questions by category
class QuestionsByCategory {
  static Map<String, List<Question>> groupByCategory(List<Question> questions) {
    Map<String, List<Question>> grouped = {};
    for (var question in questions) {
      if (!grouped.containsKey(question.category)) {
        grouped[question.category] = [];
      }
      grouped[question.category]!.add(question);
    }
    return grouped;
  }
}

class QuestionCategories {
  // Define category constants to match CSV exactly
  static const String loveAndIntimacy = 'Love and Intimacy';
  static const String spirituality = 'Spirituality';
  static const String society = 'Society';
  static const String interactionsAndRelationships = 'Interactions and Relationships';

  // Map using exact CSV names
  static const Map<String, String> categoryDisplayNames = {
    loveAndIntimacy: 'Love and Intimacy',
    spirituality: 'Spirituality',
    society: 'Society',
    interactionsAndRelationships: 'Interactions and Relationships',
  };

  // Get display name for category
  static String getDisplayName(String category) {
    return categoryDisplayNames[category] ?? 'Unknown Category';
  }

  // Get internal name from display name
  static String getInternalName(String displayName) {
    return displayName;  // No conversion needed anymore
  }

  // Get all categories
  static List<String> getAllCategories() {
    return [
      loveAndIntimacy,
      spirituality,
      society,
      interactionsAndRelationships,
    ];
  }

  // Get category color (you can customize these colors)
  static Color getCategoryColor(String category, {double opacity = 1.0}) {
    switch (category) {
      case loveAndIntimacy:
        return Color(0xFFE57373).withOpacity(opacity); // Red
      case spirituality:
        return Color(0xFF81C784).withOpacity(opacity); // Green
      case society:
        return Color(0xFF64B5F6).withOpacity(opacity); // Blue
      case interactionsAndRelationships:
        return Color(0xFFFFB74D).withOpacity(opacity); // Orange
      default:
        return Color(0xFF9E9E9E).withOpacity(opacity); // Grey
    }
  }

  // Check if category exists
  static bool isValidCategory(String category) {
    return getAllCategories().contains(category);
  }

  // Get number of categories
  static int getCategoryCount() {
    return getAllCategories().length;
  }
}

// Extension to add category-related functionality to String
extension CategoryStringExtension on String {
  String toDisplayName() {
    return QuestionCategories.getDisplayName(this);
  }

  String toInternalName() {
    return QuestionCategories.getInternalName(this);
  }

  bool isValidCategory() {
    return QuestionCategories.isValidCategory(this);
  }

  Color toCategoryColor({double opacity = 1.0}) {
    return QuestionCategories.getCategoryColor(this, opacity: opacity);
  }
}