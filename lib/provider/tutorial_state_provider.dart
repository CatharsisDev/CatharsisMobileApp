import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_provider.dart';

class TutorialStateNotifier extends StateNotifier<TutorialState> {
  TutorialStateNotifier(this.ref) : super(TutorialState()) {
    _init();
  }

  final Ref ref;
  String? _currentUserId;

  void _init() async {
    // Get initial user immediately
    final currentUser = ref.read(authStateProvider).whenOrNull(data: (user) => user);
    if (currentUser != null) {
      _currentUserId = currentUser.uid;
      await checkIfTutorialSeen();
    }
    
    // Then listen for changes
    ref.listen<AsyncValue<User?>>(authStateProvider, (previous, next) {
      final previousUser = previous?.whenOrNull(data: (user) => user);
      final nextUser = next.whenOrNull(data: (user) => user);
      
      // Only update if user actually changed
      if (previousUser?.uid != nextUser?.uid) {
        if (nextUser != null) {
          _currentUserId = nextUser.uid;
          checkIfTutorialSeen();
        } else {
          // User logged out
          _currentUserId = null;
          if (mounted) {
            state = TutorialState(); // Reset to default state
          }
        }
      }
    });
  }

  Future<void> checkIfTutorialSeen() async {
    if (!mounted || _currentUserId == null) return;
    
    // Set loading state
    state = state.copyWith(isLoading: true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Use user-specific key
      final key = 'has_seen_tutorial_$_currentUserId';
      final hasSeenTutorial = prefs.getBool(key) ?? false;
      
      print('Tutorial check for user $_currentUserId: key=$key, value=$hasSeenTutorial');
      
      // Add a small delay to ensure state updates properly
      await Future.delayed(Duration(milliseconds: 50));
      
      if (mounted) {
        state = TutorialState(
          hasSeenWelcome: hasSeenTutorial,
          showInAppTutorial: false,
          isInitialized: true,
          isLoading: false,
        );
        
        print('Tutorial state updated: hasSeenWelcome=${state.hasSeenWelcome}, initialized=${state.isInitialized}');
      }
    } catch (e) {
      print('Error checking tutorial state: $e');
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

  Future<void> setTutorialSeen() async {
    if (!mounted || _currentUserId == null) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'has_seen_tutorial_$_currentUserId';
      await prefs.setBool(key, true);
      
      print('Setting tutorial as seen: key=$key');
      
      if (mounted) {
        state = state.copyWith(
          hasSeenWelcome: true,
          showInAppTutorial: false,
        );
      }
      
      print('Tutorial marked as seen for user $_currentUserId');
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
      final prefs = await SharedPreferences.getInstance();
      final key = 'has_seen_tutorial_$_currentUserId';
      await prefs.remove(key);
      
      if (mounted) {
        state = state.copyWith(
          hasSeenWelcome: false,
          showInAppTutorial: false,
        );
      }
      
      print('Tutorial reset for user $_currentUserId');
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