import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SwipeQuota {
  final int remaining;
  final DateTime resetsAt; // UTC
  SwipeQuota({required this.remaining, required this.resetsAt});
  bool get blocked => remaining <= 0 && DateTime.now().toUtc().isBefore(resetsAt);
}

class SwipeQuotaService {
  static final _auth = FirebaseAuth.instance;
  static final _db = FirebaseFirestore.instance;
  static const int _dailyQuota = 25;

  static String _docPath(String uid) => 'users/$uid/limits/swipe';
  static DateTime _nextResetUtc() {
    final now = DateTime.now().toUtc();
    return DateTime.utc(now.year, now.month, now.day + 1);
  }

  static String _kRemainKey(String uid) => 'swipe_quota_remaining_$uid';
  static String _kResetKey(String uid)  => 'swipe_quota_resets_at_$uid';

  static Future<void> _cache(String uid, int remaining, DateTime resetsAt) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kRemainKey(uid), remaining);
    await p.setString(_kResetKey(uid), resetsAt.toIso8601String());
  }

  static Future<SwipeQuota> getQuota() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return SwipeQuota(remaining: 0, resetsAt: DateTime.now().toUtc());
    final ref = _db.doc(_docPath(uid));

    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        final resetsAt = _nextResetUtc();
        tx.set(ref, {
          'remaining': _dailyQuota,
          'resetsAt': Timestamp.fromDate(resetsAt),
          'dailyQuota': _dailyQuota,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        await _cache(uid, _dailyQuota, resetsAt);
        return SwipeQuota(remaining: _dailyQuota, resetsAt: resetsAt);
      }
      final data = snap.data()!;
      final remaining = (data['remaining'] ?? _dailyQuota) as int;
      final resetsAt = ((data['resetsAt'] as Timestamp?)?.toDate() ?? _nextResetUtc()).toUtc();
      await _cache(uid, remaining, resetsAt);
      return SwipeQuota(remaining: remaining, resetsAt: resetsAt);
    });
  }

  /// Atomically consume one swipe. Returns true if allowed; false if blocked.
  static Future<bool> consumeOne() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    final ref = _db.doc(_docPath(uid));
    final now = DateTime.now().toUtc();

    final allowed = await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);

      int remaining;
      DateTime resetsAt;
      int dailyQuota = _dailyQuota;

      if (!snap.exists) {
        remaining = _dailyQuota - 1;
        resetsAt = _nextResetUtc();
        tx.set(ref, {
          'remaining': remaining,
          'resetsAt': Timestamp.fromDate(resetsAt),
          'dailyQuota': dailyQuota,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return true;
      }

      final data = snap.data()!;
      remaining = (data['remaining'] ?? _dailyQuota) as int;
      resetsAt = ((data['resetsAt'] as Timestamp?)?.toDate() ?? _nextResetUtc()).toUtc();
      dailyQuota = (data['dailyQuota'] ?? _dailyQuota) as int;

      if (now.isAfter(resetsAt) || now.isAtSameMomentAs(resetsAt)) {
        remaining = dailyQuota - 1;
        resetsAt = _nextResetUtc();
        tx.update(ref, {
          'remaining': remaining,
          'resetsAt': Timestamp.fromDate(resetsAt),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return true;
      }

      if (remaining > 0) {
        remaining -= 1;
        tx.update(ref, {
          'remaining': remaining,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return true;
      }

      return false;
    });

    // refresh cache (best effort)
    final q = await getQuota();
    await _cache(uid, q.remaining, q.resetsAt);

    return allowed;
  }
}