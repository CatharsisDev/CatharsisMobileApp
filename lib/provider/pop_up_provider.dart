import 'package:flutter_riverpod/flutter_riverpod.dart';

class PopUpNotifier extends StateNotifier<bool> {
  PopUpNotifier() : super(false);

  void showPopUp(DateTime? resetTime) {
    state = true;
    print("Pop-up triggered. Reset time: $resetTime");
  }

  void hidePopUp() {
    state = false;
    print("Pop-up dismissed.");
  }
}

final popUpProvider = StateNotifierProvider<PopUpNotifier, bool>((ref) {
  return PopUpNotifier();
});