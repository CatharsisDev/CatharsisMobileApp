import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_provider.dart';

class TutorialStateNotifier extends StateNotifier<TutorialState> {
  TutorialStateNotifier(this.ref) : super(TutorialState()) {
    _init();
  }

  final Ref ref;
  String? _currentUserId;

  void _init() async {
    // Listen for auth changes from the beginning
    ref.listen<AsyncValue<User?>>(authStateProvider, (previous, next) {
      next.when(
        data: (user) {
          final previousUser = previous?.whenOrNull(data: (user) => user);
          
          // Only update if user actually changed
          if (previousUser?.uid != user?.uid) {
            if (user != null) {
              _currentUserId = user.uid;
              checkIfTutorialSeen();
            } else {
              // User logged out
              _currentUserId = null;
              if (mounted) {
                state = TutorialState(); // Reset to default state
              }
            }
          }
        },
        loading: () {
          // Don't do anything while loading, keep current state
        },
        error: (error, stack) {
          // Handle error case - maybe reset to default state
          print('Auth error: $error');
          if (mounted) {
            state = TutorialState();
          }
        },
      );
    });

    // Also check current state immediately
    final currentAuthState = ref.read(authStateProvider);
    currentAuthState.whenData((user) {
      if (user != null && _currentUserId != user.uid) {
        _currentUserId = user.uid;
        checkIfTutorialSeen();
      }
    });
  }

  Future<void> checkIfTutorialSeen() async {
    if (!mounted || _currentUserId == null) return;
  
    // Set loading state
    state = state.copyWith(isLoading: true);
  
    try {
      // Try Firestore first
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .get();

      final hasSeenTutorial = doc.data()?['hasSeenWelcome'] ?? false;

      // Store in local prefs as cache
      final prefs = await SharedPreferences.getInstance();
      final key = 'has_seen_tutorial_$_currentUserId';
      await prefs.setBool(key, hasSeenTutorial);

      if (mounted) {
        state = TutorialState(
          hasSeenWelcome: hasSeenTutorial,
          showInAppTutorial: false,
          isInitialized: true,
          isLoading: false,
        );
      }
    } catch (e) {
      // If Firestore fails, fall back to local cache
      try {
        final prefs = await SharedPreferences.getInstance();
        final key = 'has_seen_tutorial_$_currentUserId';
        final hasSeenTutorial = prefs.getBool(key) ?? false;
        if (mounted) {
          state = TutorialState(
            hasSeenWelcome: hasSeenTutorial,
            showInAppTutorial: false,
            isInitialized: true,
            isLoading: false,
          );
        }
      } catch (e2) {
        if (mounted) {
          state = TutorialState(
            hasSeenWelcome: false,
            showInAppTutorial: false,
            isInitialized: true,
            isLoading: false,
          );
        }
      }
    }
  }

  Future<void> setTutorialSeen() async {
    if (!mounted || _currentUserId == null) return;

    try {
      // Set in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .set({'hasSeenWelcome': true}, SetOptions(merge: true));

      // Also cache locally
      final prefs = await SharedPreferences.getInstance();
      final key = 'has_seen_tutorial_$_currentUserId';
      await prefs.setBool(key, true);

      if (mounted) {
        state = state.copyWith(
          hasSeenWelcome: true,
          showInAppTutorial: false,
        );
      }
    } catch (e) {
      print('Error setting tutorial seen: $e');
    }
  }

  void showInAppTutorial() {
    if (!mounted) return;
    state = state.copyWith(showInAppTutorial: true);
  }

  void hideInAppTutorial() {
    if (!mounted) return;
    state = state.copyWith(showInAppTutorial: false);
  }

  Future<void> resetTutorial() async {
    if (!mounted || _currentUserId == null) return;

    try {
      // Reset in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .set({'hasSeenWelcome': false}, SetOptions(merge: true));

      // Remove from local prefs
      final prefs = await SharedPreferences.getInstance();
      final key = 'has_seen_tutorial_$_currentUserId';
      await prefs.remove(key);

      if (mounted) {
        state = state.copyWith(
          hasSeenWelcome: false,
          showInAppTutorial: false,
        );
      }
    } catch (e) {
      print('Error resetting tutorial: $e');
    }
  }
}

class TutorialState {
  final bool hasSeenWelcome;
  final bool showInAppTutorial;
  final bool isInitialized;
  final bool isLoading;

  TutorialState({
    this.hasSeenWelcome = false,
    this.showInAppTutorial = false,
    this.isInitialized = false,
    this.isLoading = false,
  });

  TutorialState copyWith({
    bool? hasSeenWelcome,
    bool? showInAppTutorial,
    bool? isInitialized,
    bool? isLoading,
  }) {
    return TutorialState(
      hasSeenWelcome: hasSeenWelcome ?? this.hasSeenWelcome,
      showInAppTutorial: showInAppTutorial ?? this.showInAppTutorial,
      isInitialized: isInitialized ?? this.isInitialized,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

final tutorialProvider = StateNotifierProvider<TutorialStateNotifier, TutorialState>(
  (ref) => TutorialStateNotifier(ref),
);

// For backward compatibility with existing code
final tutorialVisibilityProvider = Provider<bool>((ref) {
  return ref.watch(tutorialProvider).showInAppTutorial;
});