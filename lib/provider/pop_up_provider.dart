import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

class PopUpNotifier extends StateNotifier<bool> {
  PopUpNotifier() : super(false);

  late final Box _swipeDataBox;

  Future<void> initialize() async {
    // Initialize the Hive box for swipe data
    _swipeDataBox = await Hive.openBox('swipeData');
  }

  void showPopUp(DateTime? resetTime) {
    state = true;

    // Save the reset time in Hive for persistence
    if (resetTime != null) {
      _swipeDataBox.put('resetTime', resetTime.toIso8601String());
    }
    print("Pop-up triggered. Reset time: $resetTime");
  }

  void hidePopUp() {
    state = false;

    // Clear the stored reset time to ensure the popup logic resets
    if (_swipeDataBox.containsKey('resetTime')) {
      _swipeDataBox.delete('resetTime');
    }
    print("Pop-up dismissed.");
  }

  DateTime? getResetTime() {
    // Retrieve the reset time from Hive, if available
    final resetTimeString = _swipeDataBox.get('resetTime');
    if (resetTimeString != null) {
      return DateTime.parse(resetTimeString);
    }
    return null;
  }

  bool shouldShowPopUp() {
    final resetTime = getResetTime();
    if (resetTime == null) {
      return false;
    }
    return DateTime.now().isBefore(resetTime);
  }
}

// Create the provider
final popUpProvider = StateNotifierProvider<PopUpNotifier, bool>((ref) {
  final notifier = PopUpNotifier();

  // Initialize Hive box asynchronously (e.g., in main.dart)
  Future(() async {
    await notifier.initialize();
  });

  return notifier;
});