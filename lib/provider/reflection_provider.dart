import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../questions_model.dart';
import '../services/reflection_service.dart';

// ── State ────────────────────────────────────────────────────────────────────

/// Holds all reflection notes for the signed-in user.
/// Key   = ReflectionService.docId(question)  (stable per card)
/// Value = note text (never empty — absent key means no note)
typedef ReflectionMap = Map<String, String>;

// ── Notifier ─────────────────────────────────────────────────────────────────

class ReflectionNotifier extends StateNotifier<ReflectionMap> {
  ReflectionNotifier() : super(const {});

  /// Fetch all notes from Firestore and populate state.
  Future<void> load() async {
    final all = await ReflectionService.loadAll();
    // Drop any empty-string entries that may have slipped through.
    state = Map.fromEntries(all.entries.where((e) => e.value.isNotEmpty));
  }

  /// Persist a note and update local state immediately.
  Future<void> saveNote(Question q, String note) async {
    final key = ReflectionService.docId(q);
    // Optimistic local update first.
    if (note.trim().isEmpty) {
      state = {...state}..remove(key);
    } else {
      state = {...state, key: note.trim()};
    }
    await ReflectionService.saveNote(q, note);
  }

  /// Returns the note for [q], or null if none.
  String? noteFor(Question q) => state[ReflectionService.docId(q)];

  /// Clear all in-memory notes (call on logout).
  void reset() => state = const {};
}

// ── Provider ─────────────────────────────────────────────────────────────────

final reflectionProvider =
    StateNotifierProvider<ReflectionNotifier, ReflectionMap>(
  (ref) => ReflectionNotifier(),
);
