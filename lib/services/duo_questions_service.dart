import 'package:csv/csv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:hive/hive.dart';
import '../questions_model.dart';

/// Loads and generates questions specifically designed for Duo Mode.
///
/// These are compatibility questions — phrased so that two people can
/// compare their answers and learn how well they align on values,
/// lifestyle, communication, and future goals.
class DuoQuestionsService {
  static const _csvPath = 'assets/Duo_Questions.csv';

  /// Hive box name for caching AI-generated duo questions between sessions.
  static const String duoCacheBoxName = 'duo_questions_cache';

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

  // ── Hive cache ────────────────────────────────────────────────────────────

  /// Opens the duo questions Hive box (idempotent).
  static Future<Box<Question>> _openBox() async {
    if (Hive.isBoxOpen(duoCacheBoxName)) {
      return Hive.box<Question>(duoCacheBoxName);
    }
    return await Hive.openBox<Question>(duoCacheBoxName);
  }

  /// Returns all AI-generated duo questions stored in the local cache.
  static Future<List<Question>> loadFromCache() async {
    try {
      final box = await _openBox();
      return box.values.toList();
    } catch (e) {
      return [];
    }
  }

  /// Persists a list of AI questions to the Hive cache.
  static Future<void> saveToCache(List<Question> questions) async {
    try {
      final box = await _openBox();
      await box.clear();
      await box.addAll(questions);
    } catch (_) {}
  }

  // ── AI generation ─────────────────────────────────────────────────────────

  /// Calls the Cloud Function with mode='duo' to generate extra compatibility
  /// questions for [category]. Falls back silently to an empty list on failure.
  static Future<List<Question>> generateForCategory({
    required String category,
    int count = 15,
  }) async {
    // Wait for auth state before calling the Cloud Function.
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      try {
        user = await FirebaseAuth.instance
            .authStateChanges()
            .where((u) => u != null)
            .first
            .timeout(const Duration(seconds: 10));
      } catch (_) {
        return [];
      }
    }
    if (user == null) return [];
    try {
      await user.getIdToken(true);
    } catch (_) {}

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

  /// Returns all duo questions as quickly as possible:
  ///
  /// 1. CSV questions are loaded immediately (always fast).
  /// 2. If Hive cache has AI questions from a previous session, they are
  ///    included right away — no waiting for the network.
  /// 3. AI generation is kicked off in parallel for all categories at once.
  ///    When it finishes the cache is updated (affects next session).
  ///
  /// This means the lobby is usable almost instantly after the first-ever load.
  static Future<List<Question>> loadAll() async {
    // Phase 1: CSV (must succeed)
    final csv = await loadFromCsv();
    if (csv.isEmpty) {
      throw Exception('Duo_Questions.csv loaded but contained no valid rows.');
    }

    // Phase 2: serve cached AI questions immediately (empty on first-ever launch)
    final cached = await loadFromCache();

    // Phase 3: refresh AI questions in parallel (all categories at once)
    // Fire and forget — result updates the cache for next time.
    _refreshAIInBackground(csv.map((q) => q.category).toSet().toList());

    // Return CSV + whatever is already cached — lobby opens immediately.
    final all = [...csv, ...cached];
    all.shuffle();
    return all;
  }

  /// Generates AI questions for all [categories] in parallel, then writes the
  /// result to the Hive cache. Errors are silently ignored per category.
  static Future<void> _refreshAIInBackground(List<String> categories) async {
    try {
      // All categories fire simultaneously — total wait ≈ time for one call
      final results = await Future.wait(
        categories.map((cat) => generateForCategory(category: cat, count: 10)),
      );
      final aiQuestions = results.expand((list) => list).toList();
      if (aiQuestions.isNotEmpty) {
        await saveToCache(aiQuestions);
      }
    } catch (_) {
      // Background refresh failing is non-fatal
    }
  }
}
