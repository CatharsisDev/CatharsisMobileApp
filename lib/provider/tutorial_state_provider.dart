import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TutorialStateNotifier extends StateNotifier<TutorialState> {
  TutorialStateNotifier() : super(TutorialState());

  Future<void> checkIfTutorialSeen() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenTutorial = prefs.getBool('has_seen_welcome') ?? false;
    state = state.copyWith(
      hasSeenWelcome: hasSeenTutorial,
      showInAppTutorial: false,
      isInitialized: true,
    );
  }

  Future<void> setTutorialSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_welcome', true);
    state = state.copyWith(hasSeenWelcome: true);
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
    state = state.copyWith(hasSeenWelcome: false);
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
  (ref) => TutorialStateNotifier()..checkIfTutorialSeen(),
);

// For backward compatibility with existing code
final tutorialVisibilityProvider = Provider<bool>((ref) {
  return ref.watch(tutorialProvider).showInAppTutorial;
});