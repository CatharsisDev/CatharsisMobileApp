import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';

class SubscriptionService {
  /// The product identifiers you configured in App Store Connect
  static const _productIds = <String>{
    'com.yourcompany.yourapp.monthly',
    'com.yourcompany.yourapp.yearly',
  };

  List<ProductDetails> _products = [];
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  bool _initialized = false;

  /// Call this on app start (or when showing paywall)
  Future<void> init() async {
    final available = await InAppPurchase.instance.isAvailable();
    if (!available) {
      throw Exception('In-app purchases not available');
    }
    final response = await InAppPurchase.instance.queryProductDetails(_productIds);
    _products = response.productDetails;
    _subscription = InAppPurchase.instance.purchaseStream.listen(
      _listenToPurchaseUpdated,
      onDone: () => _subscription.cancel(),
    );
    _initialized = true;
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.purchased:
          // unlock unlimited swipes
          InAppPurchase.instance.completePurchase(purchase);
          break;
        case PurchaseStatus.error:
          // handle error
          break;
        case PurchaseStatus.pending:
          // handle pending
          break;
        case PurchaseStatus.restored:
          // handle restore
          InAppPurchase.instance.completePurchase(purchase);
          break;
        default:
          break;
      }
    }
  }

  /// Returns the ProductDetails for a given id, or null if not found.
  ProductDetails? productById(String id) {
    for (final product in _products) {
      if (product.id == id) return product;
    }
    return null;
  }

  /// Kick off a purchase for that product.
  Future<void> purchase(String id) async {
    if (!_initialized) await init();
    final product = productById(id);
    if (product == null) throw Exception('Product $id not found');
    final param = PurchaseParam(productDetails: product);
    await InAppPurchase.instance.buyNonConsumable(purchaseParam: param);
  }
}