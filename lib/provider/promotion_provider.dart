import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../components/models/promotion_model.dart';
import '../services/promotion_service.dart';
import 'package:catharsis_cards/services/subscription_service.dart';

// Provider to check if a promotion should be shown
final shouldShowPromotionProvider = FutureProvider.autoDispose<Promotion?>((ref) async {
  // Watch subscription status
  final subscriptionService = ref.watch(subscriptionServiceProvider);
  final isPremium = subscriptionService.isPremium.value;
  
  // Get promotion to show
  final promotion = await PromotionService.getPromotionToShow(
    isPremiumUser: isPremium,
  );
  
  return promotion;
});

// State provider to track if promotion popup is currently showing
final isPromotionPopupShowingProvider = StateProvider<bool>((ref) => false);

// Provider to get all seen promotions (for debugging)
final seenPromotionsProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  return await PromotionService.getSeenPromotions();
});