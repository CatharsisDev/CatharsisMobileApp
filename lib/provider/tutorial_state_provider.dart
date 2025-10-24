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
    ref.listen<AsyncValue<User?>>(authStateProvider, (previous, next) {
      next.when(
        data: (user) {
          final previousUser = previous?.whenOrNull(data: (user) => user);
          
          if (previousUser?.uid != user?.uid) {
            if (user != null) {
              _currentUserId = user.uid;
              print('TutorialState: User changed to ${user.uid}');
              checkIfTutorialSeen();
            } else {
              _currentUserId = null;
              if (mounted) {
                state = TutorialState();
              }
            }
          }
        },
        loading: () {},
        error: (error, stack) {
          print('Auth error: $error');
          if (mounted) {
            state = TutorialState();
          }
        },
      );
    });

    final currentAuthState = ref.read(authStateProvider);
    currentAuthState.whenData((user) {
      if (user != null && _currentUserId != user.uid) {
        _currentUserId = user.uid;
        print('TutorialState: Initial user ${user.uid}');
        checkIfTutorialSeen();
      }
    });
  }

  Future<void> checkIfTutorialSeen() async {
    if (!mounted || _currentUserId == null) {
      print('TutorialState: Cannot check - mounted: $mounted, userId: $_currentUserId');
      return;
    }
  
    print('TutorialState: Checking tutorial state for $_currentUserId');
    state = state.copyWith(isLoading: true);
  
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .get();

      if (!doc.exists) {
        print('TutorialState: New user - no Firestore doc yet');
        if (mounted) {
          state = TutorialState(
            hasSeenWelcome: false,
            showInAppTutorial: false,
            isInitialized: true,
            isLoading: false,
          );
        }
        return;
      }

      final hasSeenTutorial = doc.data()?['hasSeenWelcome'] ?? false;
      print('TutorialState: Firestore hasSeenWelcome = $hasSeenTutorial');

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
        print('TutorialState: State updated - hasSeenWelcome: $hasSeenTutorial');
      }
    } catch (e) {
      print('TutorialState: Firestore error: $e');
      try {
        final prefs = await SharedPreferences.getInstance();
        final key = 'has_seen_tutorial_$_currentUserId';
        final hasSeenTutorial = prefs.getBool(key) ?? false;
        print('TutorialState: Using cached value: $hasSeenTutorial');
        if (mounted) {
          state = TutorialState(
            hasSeenWelcome: hasSeenTutorial,
            showInAppTutorial: false,
            isInitialized: true,
            isLoading: false,
          );
        }
      } catch (e2) {
        print('TutorialState: Cache error: $e2');
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

    print('TutorialState: Setting tutorial seen for $_currentUserId');
    
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .set({'hasSeenWelcome': true}, SetOptions(merge: true));

      final prefs = await SharedPreferences.getInstance();
      final key = 'has_seen_tutorial_$_currentUserId';
      await prefs.setBool(key, true);

      if (mounted) {
        state = state.copyWith(
          hasSeenWelcome: true,
          showInAppTutorial: false,
        );
        print('TutorialState: Tutorial marked as seen');
      }
    } catch (e) {
      print('TutorialState: Error setting tutorial seen: $e');
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
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .set({'hasSeenWelcome': false}, SetOptions(merge: true));

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
      print('TutorialState: Error resetting tutorial: $e');
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

final tutorialVisibilityProvider = Provider<bool>((ref) {
  return ref.watch(tutorialProvider).showInAppTutorial;
});