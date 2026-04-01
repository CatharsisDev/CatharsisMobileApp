import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../questions_model.dart';

/// Persists per-card reflection notes in Firestore under:
///   users/{uid}/reflections/{docId}
/// where docId is derived deterministically from the question so the same
/// note is found regardless of which screen opens it.
class ReflectionService {
  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Stable, Firestore-safe document ID for a question.
  /// Uses `category|text` (truncated to 500 chars to stay well under the
  /// Firestore 1500-byte doc-ID limit).  The `|` character is allowed.
  static String docId(Question q) {
    final key = '${q.category.trim()}|${q.text.trim()}';
    return key.length > 500 ? key.substring(0, 500) : key;
  }

  static DocumentReference? _ref(Question q) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('reflections')
        .doc(docId(q));
  }

  static CollectionReference? _collection() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('reflections');
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Save (or overwrite) the reflection note for [q].
  /// Passing an empty string deletes the document.
  static Future<void> saveNote(Question q, String note) async {
    final ref = _ref(q);
    if (ref == null) return;
    try {
      if (note.trim().isEmpty) {
        await ref.delete();
      } else {
        await ref.set({
          'note': note.trim(),
          'questionText': q.text.trim(),
          'questionCategory': q.category.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('[REFLECTION] saveNote error: $e');
    }
  }

  /// Load all reflection notes for the current user.
  /// Returns a map of docId → note text.
  static Future<Map<String, String>> loadAll() async {
    final col = _collection();
    if (col == null) return {};
    try {
      final snap = await col.get();
      return {
        for (final doc in snap.docs)
          doc.id: (doc.data() as Map<String, dynamic>)['note'] as String? ?? ''
      };
    } catch (e) {
      print('[REFLECTION] loadAll error: $e');
      return {};
    }
  }
}
