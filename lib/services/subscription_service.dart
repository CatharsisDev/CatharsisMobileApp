import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SubscriptionService {
  Set<String> get _productIds {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return {
        'monthly_subscription',
        'annual_subscription',
      };
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return {
        'com.example.catharsiscards.subscription.monthly',
        'com.example.catharsiscards.subscription.annual',
      };
    }
    return {};
  }

  static const _kPremiumKey = 'is_premium';
  static const _kSubscriptionExpiryKey = 'subscription_expiry';

  final ValueNotifier<bool> isPremium = ValueNotifier<bool>(false);
  final StreamController<bool> _premiumStatusController = StreamController<bool>.broadcast();
  Stream<bool> get premiumStatusStream => _premiumStatusController.stream;

  List<ProductDetails> _products = [];
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  bool _initialized = false;
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    
    // Check if subscription is still valid
    await _checkSubscriptionValidity();

    final available = await InAppPurchase.instance.isAvailable();
    if (!available) {
      _initialized = true;
      return;
    }

    final response = await InAppPurchase.instance.queryProductDetails(_productIds);
    _products = response.productDetails;

    _subscription = InAppPurchase.instance.purchaseStream.listen(
      _listenToPurchaseUpdated,
      onDone: () => _subscription?.cancel(),
      onError: (Object _, __) {},
    );

    // Restore purchases to verify subscription status
    await InAppPurchase.instance.restorePurchases();

    _initialized = true;
  }

  Future<void> _checkSubscriptionValidity() async {
    final expiryTimestamp = _prefs?.getInt(_kSubscriptionExpiryKey);
    if (expiryTimestamp != null) {
      final expiryDate = DateTime.fromMillisecondsSinceEpoch(expiryTimestamp);
      if (DateTime.now().isBefore(expiryDate)) {
        isPremium.value = true;
        await _prefs?.setBool(_kPremiumKey, true);
      } else {
        // Subscription expired
        await _revokeSubscription();
      }
    } else {
      isPremium.value = _prefs?.getBool(_kPremiumKey) ?? false;
    }
  }

  Future<void> _grantSubscription({Duration? duration}) async {
    isPremium.value = true;
    await _prefs?.setBool(_kPremiumKey, true);
    
    // Set expiry date if duration provided (for subscriptions)
    if (duration != null) {
      final expiry = DateTime.now().add(duration);
      await _prefs?.setInt(_kSubscriptionExpiryKey, expiry.millisecondsSinceEpoch);
    }
    
    // Notify listeners that premium status changed
    _premiumStatusController.add(true);
  }

  Future<void> _revokeSubscription() async {
    isPremium.value = false;
    await _prefs?.setBool(_kPremiumKey, false);
    await _prefs?.remove(_kSubscriptionExpiryKey);
    _premiumStatusController.add(false);
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // Determine subscription duration based on product ID
          Duration? subscriptionDuration;
          if (purchase.productID.contains('monthly')) {
            subscriptionDuration = Duration(days: 30);
          } else if (purchase.productID.contains('annual') || purchase.productID.contains('yearly')) {
            subscriptionDuration = Duration(days: 365);
          }
          
          await _grantSubscription(duration: subscriptionDuration);
          
          if (purchase.pendingCompletePurchase) {
            await InAppPurchase.instance.completePurchase(purchase);
          }
          break;
        case PurchaseStatus.error:
        case PurchaseStatus.canceled:
        case PurchaseStatus.pending:
          break;
      }
    }
  }

  ProductDetails? productById(String id) {
    for (final product in _products) {
      if (product.id == id) return product;
    }
    return null;
  }

  Future<void> purchase(String id) async {
    if (!_initialized) await init();
    final product = productById(id);
    if (product == null) throw Exception('Product $id not found');
    final param = PurchaseParam(productDetails: product);
    await InAppPurchase.instance.buyNonConsumable(purchaseParam: param);
  }

  bool isUserSubscribed() {
    final expiryTimestamp = _prefs?.getInt(_kSubscriptionExpiryKey);
    if (expiryTimestamp != null) {
      final expiryDate = DateTime.fromMillisecondsSinceEpoch(expiryTimestamp);
      return DateTime.now().isBefore(expiryDate);
    }
    return _prefs?.getBool(_kPremiumKey) ?? false;
  }

  Future<bool> isUserSubscribedAsync() async {
    final expiryTimestamp = _prefs?.getInt(_kSubscriptionExpiryKey);
    if (expiryTimestamp != null) {
      final expiryDate = DateTime.fromMillisecondsSinceEpoch(expiryTimestamp);
      return DateTime.now().isBefore(expiryDate);
    }
    return _prefs?.getBool(_kPremiumKey) ?? false;
  }

  void dispose() {
    _subscription?.cancel();
    _premiumStatusController.close();
  }
}

// Create a provider for the subscription service
final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  final service = SubscriptionService();
  service.init();
  ref.onDispose(() => service.dispose());
  return service;
});

// Provider to watch premium status
final isPremiumProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(subscriptionServiceProvider);
  return service.premiumStatusStream.asBroadcastStream();
});