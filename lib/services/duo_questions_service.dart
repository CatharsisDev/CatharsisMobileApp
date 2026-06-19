import 'package:csv/csv.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_functions/cloud_functions.dart';
import '../questions_model.dart';

/// Loads and generates questions specifically designed for Duo Mode.
///
/// These are compatibility questions — phrased so that two people can
/// compare their answers and learn how well they align on values,
/// lifestyle, communication, and future goals.
class DuoQuestionsService {
  static const _csvPath = 'assets/Duo_Questions.csv';

  // ── CSV ───────────────────────────────────────────────────────────────────

  /// Loads the bundled Duo_Questions.csv.
  /// Throws if the asset cannot be read — the provider will surface the error.
  static Future<List<Question>> loadFromCsv() async {
    final raw = await rootBundle.loadString(_csvPath);
    // Normalise line endings (Windows \r\n → \n, old Mac \r → \n)
    final normalised = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final rows = const CsvToListConverter(
      fieldDelimiter: ';',
      eol: '\n',
    ).convert(normalised);
    return rows
        .skip(1) // header row
        .where((r) => r.length >= 2)
        .map((r) {
          final text = r[0].toString().replaceAll(RegExp(r'\s+'), ' ').trim();
          final category =
              r[1].toString().replaceAll(RegExp(r'\s+'), ' ').trim();
          return Question(text: text, category: category);
        })
        .where((q) => q.text.isNotEmpty && q.category.isNotEmpty)
        .toList();
  }

  // ── AI generation ─────────────────────────────────────────────────────────

  /// Calls the Cloud Function with mode='duo' to generate extra compatibility
  /// questions for [category]. Falls back silently to an empty list on failure.
  static Future<List<Question>> generateForCategory({
    required String category,
    int count = 15,
  }) async {
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('generateQuestions');
      final result = await callable.call<Map<String, dynamic>>({
        'category': category,
        'count': count,
        'mode': 'duo',
      });
      final rawList = result.data['questions'] as List<dynamic>? ?? [];
      return rawList
          .cast<String>()
          .map((text) => Question(text: text, category: category))
          .toList();
    } catch (_) {
      // AI generation is optional — fail silently and use CSV questions only
      return [];
    }
  }

  // ── Full load ─────────────────────────────────────────────────────────────

  /// Returns all duo questions: CSV seed + AI-generated extras.
  /// If the CSV fails to load this throws, putting the provider into AsyncError.
  /// If only AI generation fails, the CSV questions are returned as-is.
  static Future<List<Question>> loadAll() async {
    // CSV must succeed — throws on failure so the provider surfaces the error
    final csv = await loadFromCsv();

    if (csv.isEmpty) {
      throw Exception('Duo_Questions.csv loaded but contained no valid rows.');
    }

    // AI extras are best-effort; any failure is caught inside generateForCategory
    final categories = csv.map((q) => q.category).toSet().toList();
    final aiQuestions = <Question>[];
    for (final cat in categories) {
      final extras = await generateForCategory(category: cat, count: 10);
      aiQuestions.addAll(extras);
    }

    final all = [...csv, ...aiQuestions];
    all.shuffle();
    return all;
  }
}
