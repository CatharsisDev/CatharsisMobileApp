import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/duo_session.dart';
import '../questions_model.dart';

/// Manages Firestore reads/writes for duo sessions.
class DuoSessionService {
  static final _db = FirebaseFirestore.instance;
  static const _col = 'duoSessions';

  // ── Session code ────────────────────────────────────────────────────────────

  /// Generates a random 6-character session code (uppercase, no ambiguous chars).
  static String generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  // ── Create ──────────────────────────────────────────────────────────────────

  /// Creates a new duo session with [questions] as the card deck.
  /// Returns the session code (document ID).
  static Future<String> createSession({
    required String hostUid,
    required String hostName,
    required List<Question> questions,
  }) async {
    final code = generateCode();
    final cards = questions
        .map((q) => DuoCard(
              questionText: q.text,
              questionCategory: q.category,
            ))
        .toList();

    final session = DuoSession(
      sessionCode: code,
      hostUid: hostUid,
      hostName: hostName,
      status: DuoSessionStatus.waiting,
      cards: cards,
      createdAt: DateTime.now(),
    );

    await _db.collection(_col).doc(code).set(session.toMap());
    return code;
  }

  // ── Join ────────────────────────────────────────────────────────────────────

  /// Joins an existing session as guest. Throws if code not found or
  /// session is no longer waiting.
  static Future<DuoSession> joinSession({
    required String code,
    required String guestUid,
    required String guestName,
  }) async {
    final ref = _db.collection(_col).doc(code.toUpperCase().trim());
    final snap = await ref.get();

    if (!snap.exists) {
      throw Exception('Session not found. Check the code and try again.');
    }

    final session = DuoSession.fromDoc(snap);

    if (session.status != DuoSessionStatus.waiting) {
      throw Exception('This session has already started or ended.');
    }

    if (session.hostUid == guestUid) {
      throw Exception('You cannot join your own session.');
    }

    await ref.update({
      'guestUid': guestUid,
      'guestName': guestName,
      'status': DuoSessionStatus.active.name,
    });

    final updated = await ref.get();
    return DuoSession.fromDoc(updated);
  }

  // ── Stream ──────────────────────────────────────────────────────────────────

  /// Real-time stream of session updates.
  static Stream<DuoSession?> streamSession(String code) {
    return _db
        .collection(_col)
        .doc(code.toUpperCase().trim())
        .snapshots()
        .map((snap) => snap.exists ? DuoSession.fromDoc(snap) : null);
  }

  // ── Swipe ───────────────────────────────────────────────────────────────────

  /// Records a swipe for [cardIndex]. [isHost] determines which field is set.
  /// [swipe] is 'like' or 'pass'.
  static Future<void> recordSwipe({
    required String code,
    required int cardIndex,
    required bool isHost,
    required String swipe,
  }) async {
    final field = isHost
        ? 'cards.$cardIndex.hostSwipe'
        : 'cards.$cardIndex.guestSwipe';
    await _db.collection(_col).doc(code).update({field: swipe});
  }

  // ── Complete session ────────────────────────────────────────────────────────

  /// Marks the session as complete. Called once all cards are done.
  static Future<void> completeSession(String code) async {
    await _db.collection(_col).doc(code).update({
      'status': DuoSessionStatus.complete.name,
    });
  }

  // ── Cancel session ──────────────────────────────────────────────────────────

  /// Marks the session as cancelled (e.g. one player left early).
  /// The other player's stream listener will detect this and navigate away.
  static Future<void> cancelSession(String code) async {
    await _db.collection(_col).doc(code).update({
      'status': DuoSessionStatus.cancelled.name,
    });
  }

  // ── Reflection ──────────────────────────────────────────────────────────────

  /// Saves a player's answer/reflection for [cardIndex].
  /// Called during gameplay (before the reveal), so both players can read
  /// each other's answers once both have submitted.
  static Future<void> saveReflection({
    required String code,
    required int cardIndex,
    required bool isHost,
    required String text,
  }) async {
    final field = isHost
        ? 'cards.$cardIndex.hostReflection'
        : 'cards.$cardIndex.guestReflection';
    await _db.collection(_col).doc(code).update({field: text.trim()});
  }

  // ── Past sessions ───────────────────────────────────────────────────────────

  /// Fetches all completed sessions where [uid] participated (host or guest).
  /// Runs two queries and merges them client-side to avoid composite indexes.
  static Future<List<DuoSession>> fetchPastSessions(String uid,
      {int limit = 30}) async {
    final hostSnap = await _db
        .collection(_col)
        .where('hostUid', isEqualTo: uid)
        .where('status', isEqualTo: 'complete')
        .get();

    final guestSnap = await _db
        .collection(_col)
        .where('guestUid', isEqualTo: uid)
        .where('status', isEqualTo: 'complete')
        .get();

    // Merge + deduplicate by sessionCode (shouldn't overlap, but safe)
    final map = <String, DuoSession>{};
    for (final doc in [...hostSnap.docs, ...guestSnap.docs]) {
      final s = DuoSession.fromDoc(doc);
      map[s.sessionCode] = s;
    }

    return map.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  // ── Match choice ────────────────────────────────────────────────────────────

  /// Records a player's explicit match/differ choice for [cardIndex].
  /// [choice] must be 'matched' or 'differed'.
  static Future<void> recordMatchChoice({
    required String code,
    required int cardIndex,
    required bool isHost,
    required String choice,
  }) async {
    final field = isHost
        ? 'cards.$cardIndex.hostMatchChoice'
        : 'cards.$cardIndex.guestMatchChoice';
    await _db.collection(_col).doc(code).update({field: choice});
  }
}
