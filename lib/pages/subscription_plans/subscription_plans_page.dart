import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'dart:async';
import '../../provider/theme_provider.dart';
import 'package:intl/intl.dart';
import 'dart:io';

// Simple price formatting helper
String _formatPrice(double price, String currencyCode, {String? locale}) {
  try {
    final format = NumberFormat.simpleCurrency(
      name: currencyCode,
      locale: locale,
    );
    return format.format(price);
  } catch (e) {
    return '$currencyCode ${price.toStringAsFixed(2)}';
  }
}

/// A full‑screen page presenting subscription options.
class SubscriptionPlansPage extends StatefulWidget {
  final VoidCallback onMonthlyPurchase;
  final VoidCallback onAnnualPurchase;
  final VoidCallback? onCancel;

  const SubscriptionPlansPage({
    Key? key,
    required this.onMonthlyPurchase,
    required this.onAnnualPurchase,
    this.onCancel,
  }) : super(key: key);

  @override
  _SubscriptionPlansPageState createState() => _SubscriptionPlansPageState();
}

class _SubscriptionPlansPageState extends State<SubscriptionPlansPage> {
  final PageController _pageController = PageController(viewportFraction: 0.85);
  int _currentPage = 0;

final _iap = InAppPurchase.instance;
List<ProductDetails> _products = [];

final _kMonthlyId = Platform.isAndroid
  ? 'monthly_subscription'
  : 'monthly_subscription';

final _kAnnualId = Platform.isAndroid
  ? 'annual_subscription'
  : 'annual_subscription1';

late final StreamSubscription<List<PurchaseDetails>> _subscription;

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      final page = _pageController.page?.round() ?? 0;
      if (page != _currentPage) {
        setState(() {
          _currentPage = page;
        });
      }
    });
    _iap.isAvailable().then((available) {
      print('▶︎ IAP available? $available');
      if (available) {
        final ids = {_kMonthlyId, _kAnnualId};
        _iap.queryProductDetails(ids).then((response) {
          print('▶︎ queryProductDetails response: '
                '${response.productDetails.map((p) => p.id).toList()} '
                'errors: ${response.notFoundIDs}');
          print('Available products: ${response.productDetails.map((p) => p.id).toList()}');
          setState(() {
            _products = response.productDetails;
          });
        });
      }
    });
    // Listen for purchase updates
    _subscription = _iap.purchaseStream.listen(
      _listenToPurchaseUpdates,
      onError: (error) {
        print('Purchase stream error: $error');
      },
    );
  }
  void _listenToPurchaseUpdates(List<PurchaseDetails> purchases) {
    for (var purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (purchase.productID == _kMonthlyId) {
            widget.onMonthlyPurchase();
          } else if (purchase.productID == _kAnnualId) {
            widget.onAnnualPurchase();
          }
          _iap.completePurchase(purchase);
          break;
        case PurchaseStatus.error:
          final errorMsg = purchase.error?.message ?? 'Unknown error';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Purchase error: $errorMsg')),
          );
          break;
        case PurchaseStatus.pending:
          // You can show a pending indicator here if desired
          break;
        default:
          break;
      }
    }
  }
  void _buy(String id) {
    print('▶︎ _buy() called for: $id, have products: ${_products.length}');
    try {
      final matching = _products.where((p) => p.id == id);
      if (matching.isEmpty) {
        print('‼️ Product not found for id: $id');
        return;
      }
      final product = matching.first;
      print('Found product: ${product.id}, initiating purchase...');
      final param = PurchaseParam(productDetails: product);
      print('▶︎ calling buyNonConsumable for: ${product.id}');
      _iap.buyNonConsumable(purchaseParam: param);
    } catch (e) {
      print('Error in _buy(): $e');
    }
  }
  
  Widget _buildPlanCard(String productId, String title, String period, {bool showSavings = false}) {
    // Find the actual product from the store
    ProductDetails? product;
    try {
      product = _products.firstWhere((p) => p.id == productId);
    } catch (e) {
      // Product not loaded yet
      return _PlanCard(
        title: title,
        price: 0.0,
        currencyCode: 'USD',
        period: period,
        onPressed: () {},
        locale: Localizations.localeOf(context).toString(),
        isLoading: true,
      );
    }

    // Use actual store price
    final price = product.rawPrice;
    final currencyCode = product.currencyCode;
    
    // Calculate monthly price for savings
    double? monthlyPrice;
    if (showSavings) {
      try {
        final monthlyProduct = _products.firstWhere((p) => p.id == _kMonthlyId);
        monthlyPrice = monthlyProduct.rawPrice;
      } catch (e) {}
    }

    return _PlanCard(
      title: title,
      price: price,
      currencyCode: currencyCode,
      period: period,
      onPressed: () => _buy(productId),
      locale: Localizations.localeOf(context).toString(),
      showSavings: showSavings,
      monthlyPrice: monthlyPrice,
    );
  }

  @override
  void dispose() {
    _subscription.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customTheme = theme.extension<CustomThemeExtension>();
    final indicatorColor = theme.textTheme.bodyMedium?.color ?? theme.primaryColor;
    final fontColor = customTheme?.fontColor
        ?? theme.textTheme.bodyMedium?.color
        ?? theme.primaryColor;
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Upgrade to Unlimited',
          style: TextStyle(
            fontFamily: 'Runtime',
            color: fontColor,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.close, color: theme.iconTheme.color),
          onPressed: widget.onCancel ?? () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                image: customTheme?.backgroundImagePath != null
                    ? DecorationImage(
                        image: AssetImage(customTheme!.backgroundImagePath!),
                        fit: BoxFit.cover,
                        opacity: 0.4,
                      )
                    : null,
              ),
            ),
          ),
          SafeArea(
            child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Choose a plan',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontFamily: 'Runtime', color: fontColor),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                SizedBox(
                  height: 500,
                  child: PageView(
                    controller: _pageController,
                    children: [
                      _buildPlanCard(_kMonthlyId, 'Monthly Subscription', 'per month'),
                      _buildPlanCard(_kAnnualId, 'Annual Subscription', 'per year', showSavings: true),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    2,
                    (index) => Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentPage == index
                            ? indicatorColor
                            : indicatorColor.withOpacity(0.3),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final double price;
  final String currencyCode;
  final String period;
  final VoidCallback onPressed;
  final String locale;
  final bool showSavings;
  final double? monthlyPrice;
  final bool isLoading;

  const _PlanCard({
    Key? key,
    required this.title,
    required this.price,
    required this.currencyCode,
    required this.period,
    required this.onPressed,
    required this.locale,
    this.showSavings = false,
    this.monthlyPrice,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final priceString = isLoading 
        ? '...' 
        : _formatPrice(price, currencyCode, locale: locale);
    
    // Calculate savings for annual plan
    String? savingsText;
    if (showSavings && monthlyPrice != null) {
      final yearlyFromMonthly = monthlyPrice! * 12;
      final savings = yearlyFromMonthly - price;
      final savingsPercentage = (savings / yearlyFromMonthly * 100).round();
      if (savingsPercentage > 0) {
        savingsText = 'Save $savingsPercentage%';
      }
    }

    final theme = Theme.of(context);
    final customTheme = theme.extension<CustomThemeExtension>();
    final fontColor = customTheme?.fontColor
        ?? theme.textTheme.bodyMedium?.color
        ?? theme.primaryColor;
    final buttonFontColor = customTheme?.buttonFontColor ?? fontColor;
    
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      elevation: 4,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: theme.cardColor,
          image: customTheme?.backgroundImagePath != null
              ? DecorationImage(
                  image: AssetImage(customTheme!.backgroundImagePath!),
                  fit: BoxFit.cover,
                  opacity: 0.4,
                )
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontFamily: 'Runtime',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: fontColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                priceString,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontFamily: 'Runtime',
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: fontColor,
                ),
              ),
              Text(
                period,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontFamily: 'Runtime',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: fontColor,
                ),
              ),
              if (savingsText != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green, width: 1),
                  ),
                  child: Text(
                    savingsText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Runtime',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.extension<CustomThemeExtension>()?.preferenceButtonColor
                                   ?? theme.primaryColor,
                ),
                onPressed: onPressed,
                child: Text(
                  'Select',
                  style: TextStyle(
                    fontFamily: 'Runtime',
                    fontWeight: FontWeight.bold,
                    color: buttonFontColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}