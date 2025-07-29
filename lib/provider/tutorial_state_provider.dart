import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TutorialStateNotifier extends StateNotifier<TutorialState> {
  TutorialStateNotifier() : super(TutorialState()) {
    _init();
  }

  void _init() async {
    if (mounted) {
      await checkIfTutorialSeen();
    }
  }

  Future<void> checkIfTutorialSeen() async {
    if (!mounted) return; // Exit if disposed
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Debug logging
      print('SharedPreferences keys: ${prefs.getKeys()}');
      
      final hasSeenTutorial = prefs.getBool('has_seen_welcome') ?? false;
      
      print('Checking tutorial state: hasSeenWelcome = $hasSeenTutorial');
      
      // Update state only if still mounted
      if (mounted) {
        state = state.copyWith(
          hasSeenWelcome: hasSeenTutorial,
          showInAppTutorial: false,
          isInitialized: true,
        );
        
        print('Tutorial state updated: ${state.hasSeenWelcome}, initialized: ${state.isInitialized}');
      }
    } catch (e) {
      print('Error checking tutorial state: $e');
      // On error, assume they haven't seen it
      if (mounted) {
        state = state.copyWith(
          hasSeenWelcome: false,
          showInAppTutorial: false,
          isInitialized: true,
        );
      }
    }
  }

  Future<void> setTutorialSeen() async {
    if (!mounted) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_seen_welcome', true);
      
      if (mounted) {
        state = state.copyWith(
          hasSeenWelcome: true,
          showInAppTutorial: false, // Also hide in-app tutorial when marking as seen
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
    if (!mounted) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_seen_welcome', false);
      
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

  TutorialState({
    this.hasSeenWelcome = false,
    this.showInAppTutorial = false,
    this.isInitialized = false,
  });

  TutorialState copyWith({
    bool? hasSeenWelcome,
    bool? showInAppTutorial,
    bool? isInitialized,
  }) {
    return TutorialState(
      hasSeenWelcome: hasSeenWelcome ?? this.hasSeenWelcome,
      showInAppTutorial: showInAppTutorial ?? this.showInAppTutorial,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }
}

final tutorialProvider = StateNotifierProvider<TutorialStateNotifier, TutorialState>(
  (ref) => TutorialStateNotifier(),
);

// For backward compatibility with existing code
final tutorialVisibilityProvider = Provider<bool>((ref) {
  return ref.watch(tutorialProvider).showInAppTutorial;
});