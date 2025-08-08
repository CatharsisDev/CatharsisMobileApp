import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_provider.dart'; // Your existing auth provider
import '../services/user_behavior_service.dart'; // The service we just updated

class SeenCardsNotifier extends StateNotifier<int> {
  SeenCardsNotifier(this.ref) : super(0) {
    _init();
  }

  final Ref ref;
  String? _currentUserId;

  void _init() {
    // Listen for auth changes
    ref.listen<AsyncValue<User?>>(authStateProvider, (previous, next) {
      next.when(
        data: (user) {
          final previousUser = previous?.whenOrNull(data: (user) => user);
          
          // Only update if user actually changed
          if (previousUser?.uid != user?.uid) {
            if (user != null) {
              _currentUserId = user.uid;
              _loadSeenCardsCount();
            } else {
              // User logged out - reset count
              _currentUserId = null;
              if (mounted) {
                state = 0;
              }
            }
          }
        },
        loading: () {
          // Keep current state while loading
        },
        error: (error, stack) {
          print('Auth error in SeenCardsNotifier: $error');
          if (mounted) {
            state = 0;
          }
        },
      );
    });

    // Also check current state immediately
    final currentAuthState = ref.read(authStateProvider);
    currentAuthState.whenData((user) {
      if (user != null && _currentUserId != user.uid) {
        _currentUserId = user.uid;
        _loadSeenCardsCount();
      }
    });
  }

  Future<void> _loadSeenCardsCount() async {
    if (!mounted || _currentUserId == null) return;

    try {
      final count = await UserBehaviorService.getSeenCardsCount();
      if (mounted) {
        state = count;
      }
    } catch (e) {
      print('Error loading seen cards count: $e');
      if (mounted) {
        state = 0;
      }
    }
  }

  // Call this when a user views a new card
  void incrementSeenCards() {
    if (mounted) {
      state = state + 1;
    }
  }

  // Call this to manually refresh the count from Firestore
  Future<void> refreshCount() async {
    await _loadSeenCardsCount();
  }

  // Reset the count (useful for testing)
  Future<void> resetCount() async {
    if (!mounted || _currentUserId == null) return;

    try {
      await UserBehaviorService.resetSeenCardsCount();
      if (mounted) {
        state = 0;
      }
    } catch (e) {
      print('Error resetting seen cards count: $e');
    }
  }
}

// Provider for the seen cards count
final seenCardsProvider = StateNotifierProvider<SeenCardsNotifier, int>(
  (ref) => SeenCardsNotifier(ref),
);

// Convenience provider to just watch the count
final seenCardsCountProvider = Provider<int>((ref) {
  return ref.watch(seenCardsProvider);
});