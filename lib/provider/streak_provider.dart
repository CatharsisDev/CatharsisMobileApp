import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/streak_service.dart';
import 'auth_provider.dart';

export '../services/streak_service.dart' show StreakData, StreakNotification;

class StreakNotifier extends StateNotifier<StreakData> {
  StreakNotifier() : super(const StreakData()) {
    _init();
  }

  Future<void> _init() async {
    state = await StreakService.getStreakData();
  }

  /// Reloads streak from Firestore — call when a user logs in.
  Future<void> reload() async {
    state = await StreakService.getStreakData();
  }

  /// Runs the daily freeze / streak-loss check. Call once per app open
  /// after subscription status is known.
  Future<void> checkOnAppOpen({required bool isPremium}) async {
    state = await StreakService.checkAndApplyFreezes(isPremium: isPremium);
  }

  /// Call on every successful swipe.
  Future<void> recordSwipe() async {
    state = await StreakService.recordSwipe();
  }

  /// Clears the pending notification flag so screens are not shown again.
  Future<void> clearPendingNotification() async {
    await StreakService.clearPendingNotification();
    state = state.copyWith(clearNotification: true);
  }

  /// Call on logout so a new user starts fresh (Firestore data preserved).
  Future<void> reset() async {
    await StreakService.reset();
    state = const StreakData();
  }
}

final streakProvider = StateNotifierProvider<StreakNotifier, StreakData>((ref) {
  final notifier = StreakNotifier();

  // Re-fetch from Firestore whenever a user signs in (or switches accounts).
  ref.listen<AsyncValue<User?>>(authStateProvider, (previous, next) {
    final previousUid = previous?.whenOrNull(data: (u) => u?.uid);
    final currentUser = next.whenOrNull(data: (u) => u);

    if (currentUser != null && currentUser.uid != previousUid) {
      notifier.reload();
    }
  });

  return notifier;
});
