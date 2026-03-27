import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks whether the subscription offer popup is currently visible,
/// and enforces a cooldown so the popup isn't shown too frequently.
class SubscriptionOfferNotifier extends StateNotifier<bool> {
  SubscriptionOfferNotifier() : super(false);

  // SharedPreferences key for the last-shown timestamp.
  static const _kLastShownKey = 'subscription_offer_last_shown_ms';

  // Minimum hours between successive showings.
  static const int _minHoursBetweenShows = 24;

  /// Returns `true` if enough time has passed since the popup was last shown
  /// (or if it has never been shown before).
  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    final lastShownMs = prefs.getInt(_kLastShownKey);
    if (lastShownMs == null) return true;
    final lastShown = DateTime.fromMillisecondsSinceEpoch(lastShownMs);
    return DateTime.now().difference(lastShown).inHours >= _minHoursBetweenShows;
  }

  /// Persists the current timestamp so the cooldown is respected across restarts.
  static Future<void> markShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastShownKey, DateTime.now().millisecondsSinceEpoch);
  }

  void show() => state = true;
  void hide() => state = false;
}

final subscriptionOfferProvider =
    StateNotifierProvider<SubscriptionOfferNotifier, bool>((ref) {
  return SubscriptionOfferNotifier();
});
