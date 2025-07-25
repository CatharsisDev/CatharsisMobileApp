import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TutorialStateNotifier extends StateNotifier<TutorialState> {
  TutorialStateNotifier() : super(TutorialState()) {
    // Initialize immediately when created
    _init();
  }

  Future<void> _init() async {
    // Set a temporary initialized state while checking
    state = state.copyWith(isInitialized: false);
    await checkIfTutorialSeen();
  }

  Future<void> checkIfTutorialSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Debug logging
      print('SharedPreferences keys: ${prefs.getKeys()}');
      
      final hasSeenTutorial = prefs.getBool('has_seen_welcome') ?? false;
      
      print('Checking tutorial state: hasSeenWelcome = $hasSeenTutorial');
      
      // Update state
      state = state.copyWith(
        hasSeenWelcome: hasSeenTutorial,
        showInAppTutorial: false,
        isInitialized: true,
      );
      
      print('Tutorial state updated: ${state.hasSeenWelcome}, initialized: ${state.isInitialized}');
    } catch (e) {
      print('Error checking tutorial state: $e');
      // On error, assume they haven't seen it
      state = state.copyWith(
        hasSeenWelcome: false,
        showInAppTutorial: false,
        isInitialized: true,
      );
    }
  }

  Future<void> setTutorialSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_welcome', true);
    state = state.copyWith(
      hasSeenWelcome: true,
      showInAppTutorial: false, // Also hide in-app tutorial when marking as seen
    );
  }

  void showInAppTutorial() {
    state = state.copyWith(showInAppTutorial: true);
  }

  void hideInAppTutorial() {
    state = state.copyWith(showInAppTutorial: false);
  }

  Future<void> resetTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_welcome', false);
    state = state.copyWith(
      hasSeenWelcome: false,
      showInAppTutorial: false,
    );
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
  (ref) => TutorialStateNotifier(), // Removed ..checkIfTutorialSeen() since it's now in constructor
);

// For backward compatibility with existing code
final tutorialVisibilityProvider = Provider<bool>((ref) {
  return ref.watch(tutorialProvider).showInAppTutorial;
});