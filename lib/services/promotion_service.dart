import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../components/models/promotion_model.dart';

class PromotionService {
  static const String _shownPromotionsKey = 'shown_promotions';
  static const String _lastShownDateKey = 'last_promotion_shown_date';
  
  // Check if user should see a promotion
  static Future<Promotion?> getPromotionToShow({
    required bool isPremiumUser,
  }) async {
    // Don't show promotions to premium users if the promotion requires subscription check
    final activePromotion = PromotionCampaigns.getActivePromotion();
    
    if (activePromotion == null) {
      return null;
    }

    // Check if user has already seen this promotion
    final hasSeenPromotion = await _hasSeenPromotion(activePromotion.id);
    if (hasSeenPromotion) {
      return null;
    }

    // Check if we've shown a promotion recently (avoid spam)
    final canShowPromotion = await _canShowPromotion();
    if (!canShowPromotion) {
      return null;
    }

    return activePromotion;
  }

  // Mark a promotion as seen
  static Future<void> markPromotionAsSeen(String promotionId) async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    
    // Store with user ID to handle multiple accounts
    final key = user != null 
        ? '${_shownPromotionsKey}_${user.uid}'
        : _shownPromotionsKey;
    
    final shownPromotions = prefs.getStringList(key) ?? [];
    if (!shownPromotions.contains(promotionId)) {
      shownPromotions.add(promotionId);
      await prefs.setStringList(key, shownPromotions);
    }
    
    // Update last shown date
    final dateKey = user != null
        ? '${_lastShownDateKey}_${user.uid}'
        : _lastShownDateKey;
    await prefs.setString(dateKey, DateTime.now().toIso8601String());
    
    print('[PROMOTION] Marked as seen: $promotionId');
  }

  // Check if user has seen a specific promotion
  static Future<bool> _hasSeenPromotion(String promotionId) async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    
    final key = user != null 
        ? '${_shownPromotionsKey}_${user.uid}'
        : _shownPromotionsKey;
    
    final shownPromotions = prefs.getStringList(key) ?? [];
    return shownPromotions.contains(promotionId);
  }

  // Check if we can show a promotion (avoid showing multiple promotions too quickly)
  static Future<bool> _canShowPromotion() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    
    final dateKey = user != null
        ? '${_lastShownDateKey}_${user.uid}'
        : _lastShownDateKey;
    
    final lastShownDateStr = prefs.getString(dateKey);
    if (lastShownDateStr == null) {
      return true; // Never shown a promotion before
    }
    
    final lastShownDate = DateTime.parse(lastShownDateStr);
    final hoursSinceLastShown = DateTime.now().difference(lastShownDate).inHours;
    
    // Only show one promotion per 24 hours
    return hoursSinceLastShown >= 24;
  }

  // Reset promotion tracking (useful for testing or after user signs out)
  static Future<void> resetPromotionTracking() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    
    if (user != null) {
      final key = '${_shownPromotionsKey}_${user.uid}';
      final dateKey = '${_lastShownDateKey}_${user.uid}';
      await prefs.remove(key);
      await prefs.remove(dateKey);
    } else {
      await prefs.remove(_shownPromotionsKey);
      await prefs.remove(_lastShownDateKey);
    }
    
    print('[PROMOTION] Tracking reset');
  }

  // Force show a promotion (for testing)
  static Future<void> forceShowPromotion(String promotionId) async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    
    final key = user != null 
        ? '${_shownPromotionsKey}_${user.uid}'
        : _shownPromotionsKey;
    
    final shownPromotions = prefs.getStringList(key) ?? [];
    shownPromotions.remove(promotionId);
    await prefs.setStringList(key, shownPromotions);
    
    print('[PROMOTION] Force enabled: $promotionId');
  }

  // Get all seen promotions (for debugging)
  static Future<List<String>> getSeenPromotions() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    
    final key = user != null 
        ? '${_shownPromotionsKey}_${user.uid}'
        : _shownPromotionsKey;
    
    return prefs.getStringList(key) ?? [];
  }
}