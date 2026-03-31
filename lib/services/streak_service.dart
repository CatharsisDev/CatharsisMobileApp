import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

enum StreakNotification { freezeUsed, streakLost }

// ---------------------------------------------------------------------------
// Data class
// ---------------------------------------------------------------------------

class StreakData {
  final int current;
  final int longest;
  final List<String> activeDates; // YYYY-MM-DD strings, last 30 active days
  final int freezesAvailable;     // 0-2, resets every Monday
  final String freezesWeek;       // ISO week key e.g. "2024-W03"
  final StreakNotification? pendingNotification; // shown once on next app open

  const StreakData({
    this.current = 0,
    this.longest = 0,
    this.activeDates = const [],
    this.freezesAvailable = 2,
    this.freezesWeek = '',
    this.pendingNotification,
  });

  StreakData copyWith({
    int? current,
    int? longest,
    List<String>? activeDates,
    int? freezesAvailable,
    String? freezesWeek,
    StreakNotification? pendingNotification,
    bool clearNotification = false,
  }) {
    return StreakData(
      current: current ?? this.current,
      longest: longest ?? this.longest,
      activeDates: activeDates ?? this.activeDates,
      freezesAvailable: freezesAvailable ?? this.freezesAvailable,
      freezesWeek: freezesWeek ?? this.freezesWeek,
      pendingNotification:
          clearNotification ? null : (pendingNotification ?? this.pendingNotification),
    );
  }
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

class StreakService {
  // SharedPreferences keys
  static const _countKey             = 'streak_count';
  static const _dateKey              = 'streak_last_swipe_date';
  static const _longestKey           = 'streak_longest';
  static const _activeDatesKey       = 'streak_active_dates';
  static const _freezesKey           = 'streak_freezes_available';
  static const _freezesWeekKey       = 'streak_freezes_week';
  static const _pendingNotifKey      = 'streak_pending_notification';
  static const _lastCheckKey         = 'streak_last_check_date';
  // Full ISO-8601 timestamp of the last swipe — used to schedule dynamic reminders.
  static const _lastSwipeTimestampKey = 'streak_last_swipe_timestamp';

  static const int _maxFreezesPerWeek = 2;

  // ── Date helpers ──────────────────────────────────────────────────────────

  static String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static String _yesterdayString() {
    final y = DateTime.now().subtract(const Duration(days: 1));
    return '${y.year}-${y.month.toString().padLeft(2, '0')}-${y.day.toString().padLeft(2, '0')}';
  }

  /// Returns the ISO week key for today, e.g. "2024-W03".
  static String _currentIsoWeek() {
    final now = DateTime.now();
    // ISO week number: (ordinalDay - weekday + 10) / 7
    final ordinal = now.difference(DateTime(now.year, 1, 1)).inDays + 1;
    final isoWeek = ((ordinal - now.weekday + 10) / 7).floor();
    return '${now.year}-W${isoWeek.toString().padLeft(2, '0')}';
  }

  /// Compares two YYYY-MM-DD strings as calendar days.
  static int _calendarDaysBetween(String fromDateStr, String toDateStr) {
    final f = fromDateStr.split('-');
    final t = toDateStr.split('-');
    final from = DateTime(int.parse(f[0]), int.parse(f[1]), int.parse(f[2]));
    final to   = DateTime(int.parse(t[0]), int.parse(t[1]), int.parse(t[2]));
    return to.difference(from).inDays;
  }

  static DocumentReference? _userDoc() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(user.uid);
  }

  // ── Freeze helpers ────────────────────────────────────────────────────────

  /// Resets freezes to 2 if we've rolled into a new ISO week.
  static Future<int> _resetFreezesIfNewWeek(SharedPreferences prefs) async {
    final storedWeek = prefs.getString(_freezesWeekKey) ?? '';
    final currentWeek = _currentIsoWeek();
    if (storedWeek != currentWeek) {
      await prefs.setInt(_freezesKey, _maxFreezesPerWeek);
      await prefs.setString(_freezesWeekKey, currentWeek);
      return _maxFreezesPerWeek;
    }
    return prefs.getInt(_freezesKey) ?? _maxFreezesPerWeek;
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Called once per calendar day on app open.
  /// Checks if the streak would break, and either consumes a freeze or
  /// resets the streak. Sets [pendingNotification] for the UI to show.
  ///
  /// Safe to call multiple times — runs at most once per calendar day.
  static Future<StreakData> checkAndApplyFreezes({required bool isPremium}) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayString();

    // Only run once per calendar day
    final lastCheck = prefs.getString(_lastCheckKey);
    if (lastCheck == today) {
      return getStreakData();
    }
    await prefs.setString(_lastCheckKey, today);

    // Reset freezes at start of a new week
    int freezesAvailable = await _resetFreezesIfNewWeek(prefs);

    final lastDate = prefs.getString(_dateKey);
    if (lastDate == null) return getStreakData(); // No streak to protect

    final diff = _calendarDaysBetween(lastDate, today);
    if (diff <= 1) return getStreakData(); // Streak still alive, nothing to do

    // Streak would break — decide what to do
    final missedDays = diff - 1;
    StreakNotification notification;

    if (isPremium && freezesAvailable >= missedDays) {
      // All missed days covered by freezes
      freezesAvailable -= missedDays;
      await prefs.setInt(_freezesKey, freezesAvailable);
      await prefs.setString(_freezesWeekKey, _currentIsoWeek());
      // Bridge the gap so the next swipe today continues the streak
      await prefs.setString(_dateKey, _yesterdayString());
      notification = StreakNotification.freezeUsed;
    } else {
      // Not enough freezes (or not premium) — streak lost
      final oldCount = prefs.getInt(_countKey) ?? 0;
      await prefs.setInt(_countKey, 0);
      // Advance lastDate to today so this check doesn't re-fire tomorrow
      await prefs.setString(_dateKey, today);
      // Consume whatever freezes were left (doesn't save the streak but drain them)
      if (isPremium && freezesAvailable > 0) {
        await prefs.setInt(_freezesKey, 0);
        freezesAvailable = 0;
      }
      print('[STREAK] Streak lost (was $oldCount). isPremium=$isPremium, '
          'missedDays=$missedDays, freezes=${freezesAvailable + (isPremium ? missedDays - freezesAvailable : 0)}');
      notification = StreakNotification.streakLost;
    }

    await prefs.setString(_pendingNotifKey, notification.name);

    // Sync to Firestore in background
    final count       = prefs.getInt(_countKey) ?? 0;
    final newLastDate = prefs.getString(_dateKey) ?? today;
    final longest     = prefs.getInt(_longestKey) ?? 0;
    final activeDates = prefs.getStringList(_activeDatesKey) ?? [];
    _syncToFirestore(count, newLastDate, longest, activeDates,
        freezesAvailable: freezesAvailable,
        freezesWeek: _currentIsoWeek());

    return getStreakData();
  }

  /// Loads streak data, merging local cache with Firestore when available.
  static Future<StreakData> getStreakData() async {
    final prefs = await SharedPreferences.getInstance();

    // Load local cache
    final localLastDate  = prefs.getString(_dateKey);
    int localCount       = prefs.getInt(_countKey) ?? 0;
    int localLongest     = prefs.getInt(_longestKey) ?? 0;
    List<String> localActiveDates = prefs.getStringList(_activeDatesKey) ?? [];
    int localFreezes     = prefs.getInt(_freezesKey) ?? _maxFreezesPerWeek;
    String localFreezesWeek = prefs.getString(_freezesWeekKey) ?? '';
    final pendingNotifStr = prefs.getString(_pendingNotifKey);
    final pendingNotif = pendingNotifStr == null
        ? null
        : StreakNotification.values.firstWhere(
            (e) => e.name == pendingNotifStr,
            orElse: () => StreakNotification.streakLost,
          );

    // Reset local streak if it's broken AND no freeze was already applied today
    // (freeze check advances _dateKey so diff <= 1 after freeze applied)
    if (localLastDate != null) {
      final diff = _calendarDaysBetween(localLastDate, _todayString());
      if (diff > 1) {
        localCount = 0;
        await prefs.setInt(_countKey, 0);
      }
    } else {
      localCount = 0;
    }

    // Try to load from Firestore and merge
    final docRef = _userDoc();
    if (docRef != null) {
      try {
        final doc = await docRef.get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data != null) {
            final fsCount      = data['streakCount'] as int? ?? 0;
            final fsLastDate   = data['streakLastSwipeDate'] as String?;
            final fsLongest    = data['streakLongest'] as int? ?? 0;
            final fsActiveDates =
                (data['streakActiveDates'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ?? [];
            final fsFreezes    = data['streakFreezesAvailable'] as int?;
            final fsFreezesWeek = data['streakFreezesWeek'] as String? ?? '';

            int validFsCount = fsCount;
            if (fsLastDate != null) {
              final diff = _calendarDaysBetween(fsLastDate, _todayString());
              if (diff > 1) validFsCount = 0;
            } else {
              validFsCount = 0;
            }

            bool useFirestore = false;
            if (fsLastDate != null && localLastDate == null) {
              useFirestore = true;
            } else if (fsLastDate != null && localLastDate != null) {
              final cmp = fsLastDate.compareTo(localLastDate);
              if (cmp > 0) {
                useFirestore = true;
              } else if (cmp == 0 && validFsCount > localCount) {
                useFirestore = true;
              }
            }

            if (useFirestore) {
              localCount = validFsCount;
              await prefs.setInt(_countKey, localCount);
              if (fsLastDate != null) {
                await prefs.setString(_dateKey, fsLastDate);
              }
            }

            if (fsLongest > localLongest) {
              localLongest = fsLongest;
              await prefs.setInt(_longestKey, localLongest);
            }

            // Merge active dates
            final merged = <String>{...localActiveDates, ...fsActiveDates}
                .toList()..sort();
            final trimmed = merged.length > 30
                ? merged.sublist(merged.length - 30)
                : merged;
            await prefs.setStringList(_activeDatesKey, trimmed);
            localActiveDates = trimmed;

            // Merge freeze count:
            // - Same week on both sides → take the lower (more conservative) value.
            // - Fresh device (no local week stored) → always trust Firestore.
            // - Different week on Firestore → Firestore is stale; keep local
            //   (which already ran _resetFreezesIfNewWeek for the current week).
            if (fsFreezes != null) {
              if (localFreezesWeek.isEmpty) {
                // Fresh install / first login on this device — trust Firestore
                localFreezes = fsFreezes.clamp(0, _maxFreezesPerWeek);
                localFreezesWeek = fsFreezesWeek;
                await prefs.setInt(_freezesKey, localFreezes);
                await prefs.setString(_freezesWeekKey, localFreezesWeek);
              } else if (fsFreezesWeek == localFreezesWeek && fsFreezes < localFreezes) {
                // Same week — take the lower value so freezes can't be regained
                // by logging in from another device
                localFreezes = fsFreezes;
                await prefs.setInt(_freezesKey, localFreezes);
              }
            }
          }
        }
      } catch (e) {
        print('[STREAK] Firestore load failed, using local cache: $e');
      }
    }

    return StreakData(
      current: localCount,
      longest: localLongest,
      activeDates: localActiveDates,
      freezesAvailable: localFreezes,
      freezesWeek: localFreezesWeek,
      pendingNotification: pendingNotif,
    );
  }

  /// Records a swipe for today, updates local + Firestore, returns new data.
  static Future<StreakData> recordSwipe() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayString();
    final lastDate = prefs.getString(_dateKey);
    int current = prefs.getInt(_countKey) ?? 0;
    int longest = prefs.getInt(_longestKey) ?? 0;
    List<String> activeDates = prefs.getStringList(_activeDatesKey) ?? [];
    int freezesAvailable = prefs.getInt(_freezesKey) ?? _maxFreezesPerWeek;
    String freezesWeek = prefs.getString(_freezesWeekKey) ?? _currentIsoWeek();

    // Already counted today
    if (lastDate == today) {
      final pendingNotifStr = prefs.getString(_pendingNotifKey);
      final pendingNotif = pendingNotifStr == null
          ? null
          : StreakNotification.values.firstWhere(
              (e) => e.name == pendingNotifStr,
              orElse: () => StreakNotification.streakLost,
            );
      return StreakData(
        current: current,
        longest: longest,
        activeDates: activeDates,
        freezesAvailable: freezesAvailable,
        freezesWeek: freezesWeek,
        pendingNotification: pendingNotif,
      );
    }

    if (lastDate != null) {
      final diff = _calendarDaysBetween(lastDate, today);
      current = diff == 1 ? current + 1 : 1;
    } else {
      current = 1;
    }

    if (!activeDates.contains(today)) {
      activeDates = [...activeDates, today];
      if (activeDates.length > 30) {
        activeDates = activeDates.sublist(activeDates.length - 30);
      }
    }

    if (current > longest) longest = current;

    await prefs.setInt(_countKey, current);
    await prefs.setString(_dateKey, today);
    // Store full timestamp so notification scheduling can compute an exact offset.
    await prefs.setString(_lastSwipeTimestampKey, DateTime.now().toIso8601String());
    await prefs.setInt(_longestKey, longest);
    await prefs.setStringList(_activeDatesKey, activeDates);
    // Clear any pending notification on swipe (user is active again)
    await prefs.remove(_pendingNotifKey);

    _syncToFirestore(current, today, longest, activeDates,
        freezesAvailable: freezesAvailable, freezesWeek: freezesWeek);

    return StreakData(
      current: current,
      longest: longest,
      activeDates: activeDates,
      freezesAvailable: freezesAvailable,
      freezesWeek: freezesWeek,
    );
  }

  /// Returns the exact [DateTime] of the most recent swipe, or null if none.
  /// Used to schedule streak reminders for the following calendar day.
  static Future<DateTime?> getLastSwipeTime() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastSwipeTimestampKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  /// Clears the pending notification flag so the screen isn't shown again.
  static Future<void> clearPendingNotification() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingNotifKey);
  }

  /// Clears the local cache only (call on logout).
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_countKey);
    await prefs.remove(_dateKey);
    await prefs.remove(_longestKey);
    await prefs.remove(_activeDatesKey);
    await prefs.remove(_pendingNotifKey);
    await prefs.remove(_lastCheckKey);
    // Keep freeze state so it survives logout/login on same device
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  static void _syncToFirestore(
    int count,
    String lastDate,
    int longest,
    List<String> activeDates, {
    int? freezesAvailable,
    String? freezesWeek,
  }) {
    final docRef = _userDoc();
    if (docRef == null) return;

    final Map<String, dynamic> payload = {
      'streakCount':          count,
      'streakLastSwipeDate':  lastDate,
      'streakLongest':        longest,
      'streakActiveDates':    activeDates,
    };
    if (freezesAvailable != null) {
      payload['streakFreezesAvailable'] = freezesAvailable;
    }
    if (freezesWeek != null) {
      payload['streakFreezesWeek'] = freezesWeek;
    }

    docRef.set(payload, SetOptions(merge: true)).catchError((e) {
      print('[STREAK] Firestore sync failed: $e');
    });
  }
}
