import 'dart:math';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../questions_model.dart';
import '../questions_service.dart';
import 'pop_up_provider.dart';

class TutorialStateNotifier extends StateNotifier<bool> {
  TutorialStateNotifier() : super(false);

  void hideTutorial() {
    state = false;
  }

  Future<void> checkIfTutorialSeen() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenTutorial = prefs.getBool('has_seen_tutorial') ?? false;
    state = !hasSeenTutorial; // Show tutorial if not seen
  }

  Future<void> setTutorialSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_tutorial', true);
    state = false; // Hide tutorial
  }
}

final tutorialProvider = StateNotifierProvider<TutorialStateNotifier, bool>(
  (ref) => TutorialStateNotifier()..checkIfTutorialSeen(),
);