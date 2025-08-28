import 'package:catharsis_cards/questions_model.dart';
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
  bool _isInitialized = false;

  Future<void> _init() async {
    // First, check if user is already authenticated
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      _currentUserId = currentUser.uid;
      await _loadSeenCardsCount();
      _isInitialized = true;
    }

    // Then listen for future auth changes
    ref.listen<AsyncValue<User?>>(authStateProvider, (previous, next) {
      next.when(
        data: (user) async {
          final previousUserId = _currentUserId;
          
          if (user != null && user.uid != previousUserId) {
            // New user logged in
            _currentUserId = user.uid;
            await _loadSeenCardsCount();
            _isInitialized = true;
          } else if (user == null && previousUserId != null) {
            // User logged out
            _currentUserId = null;
            _isInitialized = false;
            if (mounted) {
              state = 0;
            }
          }
        },
        loading: () {
          // Keep current state while loading
        },
        error: (error, stack) {
          print('Auth error in SeenCardsNotifier: $error');
          _currentUserId = null;
          _isInitialized = false;
          if (mounted) {
            state = 0;
          }
        },
      );
    });
  }

  Future<void> _loadSeenCardsCount() async {
    if (!mounted || _currentUserId == null) return;

    try {
      final count = await UserBehaviorService.getSeenCardsCount();
      if (mounted) {
        state = count;
        print('[PROVIDER] Loaded seen cards count: $count for user: $_currentUserId');
      }
    } catch (e) {
      print('Error loading seen cards count: $e');
      if (mounted) {
        state = 0;
      }
    }
  }

  // Call this when a user views a new card
  Future<void> incrementSeenCards() async {
    if (!mounted || _currentUserId == null) return;

    try {
      // Update local state immediately for better UX
      if (mounted) {
        state = state + 1;
      }
      
      // Update Firestore in background
      await UserBehaviorService.incrementSeenCardsCount();
      print('[PROVIDER] Incremented seen cards to: $state');
    } catch (e) {
      print('Error incrementing seen cards count: $e');
      // Revert local state on error
      if (mounted && state > 0) {
        state = state - 1;
      }
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

  // Force reload when user becomes available
  void forceReload() {
    if (_currentUserId != null && !_isInitialized) {
      _loadSeenCardsCount();
    }
  }
}

// Provider for the seen cards count
final seenCardsProvider = StateNotifierProvider<SeenCardsNotifier, int>(
  (ref) => SeenCardsNotifier(ref),
);

// Liked Questions Provider
class LikedQuestionsNotifier extends StateNotifier<AsyncValue<List<Question>>> {
  LikedQuestionsNotifier(this.ref) : super(const AsyncValue.loading()) {
    _init();
  }

  final Ref ref;
  String? _currentUserId;

  Future<void> _init() async {
    // Check if user is already authenticated
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      _currentUserId = currentUser.uid;
      await _loadLikedQuestions();
    } else {
      state = const AsyncValue.data([]);
    }

    // Listen for auth changes
    ref.listen<AsyncValue<User?>>(authStateProvider, (previous, next) {
      next.when(
        data: (user) async {
          if (user != null && user.uid != _currentUserId) {
            _currentUserId = user.uid;
            await _loadLikedQuestions();
          } else if (user == null) {
            _currentUserId = null;
            state = const AsyncValue.data([]);
          }
        },
        loading: () {},
        error: (error, stack) {
          _currentUserId = null;
          state = const AsyncValue.data([]);
        },
      );
    });
  }

  Future<void> _loadLikedQuestions() async {
    if (_currentUserId == null) {
      state = const AsyncValue.data([]);
      return;
    }

    try {
      state = const AsyncValue.loading();
      final questions = await UserBehaviorService.getLikedQuestions();
      state = AsyncValue.data(questions);
      print('[PROVIDER] Loaded ${questions.length} liked questions');
    } catch (e, stack) {
      print('Error loading liked questions: $e');
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> toggleLike(Question question) async {
    if (_currentUserId == null) return;

    final currentQuestions = state.valueOrNull ?? [];
    final isCurrentlyLiked = currentQuestions.any((q) => q.trackingId == question.trackingId);
    
    try {
      // Update local state immediately
      if (isCurrentlyLiked) {
        state = AsyncValue.data(
          currentQuestions.where((q) => q.trackingId != question.trackingId).toList()
        );
      } else {
        state = AsyncValue.data([question, ...currentQuestions]);
      }

      // Update Firestore
      await UserBehaviorService.trackQuestionLike(
        question: question,
        isLiked: !isCurrentlyLiked,
      );

      print('[PROVIDER] Toggled like for question: ${question.text}');
    } catch (e) {
      print('Error toggling question like: $e');
      // Revert on error
      state = AsyncValue.data(currentQuestions);
    }
  }

  Future<void> refreshLikedQuestions() async {
    await _loadLikedQuestions();
  }

  bool isQuestionLiked(Question question) {
    final questions = state.valueOrNull ?? [];
    return questions.any((q) => q.trackingId == question.trackingId);
  }
}

final likedQuestionsProvider = StateNotifierProvider<LikedQuestionsNotifier, AsyncValue<List<Question>>>(
  (ref) => LikedQuestionsNotifier(ref),
);

// Convenience providers
final likedQuestionsCountProvider = Provider<int>((ref) {
  return ref.watch(likedQuestionsProvider).valueOrNull?.length ?? 0;
});
