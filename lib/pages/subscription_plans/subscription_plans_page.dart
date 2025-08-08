import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'dart:async';
import '../../provider/theme_provider.dart';
import 'package:intl/intl.dart';
import 'dart:io';

// Define price tiers for different regions
class RegionalPricing {
  final String currencyCode;
  final double monthlyPrice;
  final double annualPrice;
  final String countryCode;

  const RegionalPricing({
    required this.currencyCode,
    required this.monthlyPrice,
    required this.annualPrice,
    required this.countryCode,
  });
}

class PricingService {
  // Define regional pricing tiers
  static const Map<String, RegionalPricing> _regionalPricing = {
    // United States
    'US': RegionalPricing(
      currencyCode: 'USD',
      monthlyPrice: 1.99,
      annualPrice: 19.10,
      countryCode: 'US',
    ),
    // European Union (Euro)
    'DE': RegionalPricing(
      currencyCode: 'EUR',
      monthlyPrice: 1.99,
      annualPrice: 19.10,
      countryCode: 'DE',
    ),
    'FR': RegionalPricing(
      currencyCode: 'EUR',
      monthlyPrice: 1.99,
      annualPrice: 19.10,
      countryCode: 'FR',
    ),
    'IT': RegionalPricing(
      currencyCode: 'EUR',
      monthlyPrice: 1.99,
      annualPrice: 19.10,
      countryCode: 'IT',
    ),
    'ES': RegionalPricing(
      currencyCode: 'EUR',
      monthlyPrice: 1.99,
      annualPrice: 19.10,
      countryCode: 'ES',
    ),
    // United Kingdom
    'GB': RegionalPricing(
      currencyCode: 'GBP',
      monthlyPrice: 1.50, // 1.99 * 0.7526
      annualPrice: 14.98, // 19.91 * 0.7526
      countryCode: 'GB',
    ),
    // Canada
    'CA': RegionalPricing(
      currencyCode: 'CAD',
      monthlyPrice: 2.74, // 1.99 * 1.3769
      annualPrice: 27.42, // 19.91 * 1.3769
      countryCode: 'CA',
    ),
    // Australia
    'AU': RegionalPricing(
      currencyCode: 'AUD',
      monthlyPrice: 3.04, // 1.99 * 1.529
      annualPrice: 30.43, // 19.91 * 1.529
      countryCode: 'AU',
    ),
    // Japan
    'JP': RegionalPricing(
      currencyCode: 'JPY',
      monthlyPrice: 290.60, // 1.99 * 146.05
      annualPrice: 2905.30, // 19.91 * 146.05
      countryCode: 'JP',
    ),
    // India
    'IN': RegionalPricing(
      currencyCode: 'INR',
      monthlyPrice: 164.65, // 1.99 * 82.80
      annualPrice: 1648.60, // 19.91 * 82.80
      countryCode: 'IN',
    ),
    // Brazil
    'BR': RegionalPricing(
      currencyCode: 'BRL',
      monthlyPrice: 10.29, // 1.99 * 5.17
      annualPrice: 102.92, // 19.91 * 5.17
      countryCode: 'BR',
    ),
    // Mexico
    'MX': RegionalPricing(
      currencyCode: 'MXN',
      monthlyPrice: 34.52, // 1.99 * 17.35
      annualPrice: 345.57, // 19.91 * 17.35
      countryCode: 'MX',
    ),
    // South Korea
    'KR': RegionalPricing(
      currencyCode: 'KRW',
      monthlyPrice: 2605.25, // 1.99 * 1309.17
      annualPrice: 26076.80, // 19.91 * 1309.17
      countryCode: 'KR',
    ),
    // Default fallback (USD)
    'DEFAULT': RegionalPricing(
      currencyCode: 'USD',
      monthlyPrice: 1.99,
      annualPrice: 19.91,
      countryCode: 'US',
    ),
  };

  static RegionalPricing getPricingForLocale(BuildContext context) {
    try {
      // Get the device locale
      final locale = Localizations.localeOf(context);
      final countryCode = locale.countryCode ?? '';
      
      // Try to get regional pricing for the country
      final pricing = _regionalPricing[countryCode];
      if (pricing != null) {
        return pricing;
      }
      
      // If country not found, try to get by currency from platform
      final platformLocale = Platform.localeName;
      final platformCountry = platformLocale.split('_').last;
      
      final platformPricing = _regionalPricing[platformCountry];
      if (platformPricing != null) {
        return platformPricing;
      }
      
      // Default to USD pricing
      return _regionalPricing['DEFAULT']!;
    } catch (e) {
      print('Error getting regional pricing: $e');
      return _regionalPricing['DEFAULT']!;
    }
  }

  static String formatPrice(double price, String currencyCode, {String? locale}) {
    try {
      final format = NumberFormat.simpleCurrency(
        name: currencyCode,
        locale: locale,
      );
      return format.format(price);
    } catch (e) {
      // Fallback formatting
      return '$currencyCode ${price.toStringAsFixed(2)}';
    }
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
  late RegionalPricing _pricing;

  final _iap = InAppPurchase.instance;
  List<ProductDetails> _products = [];
  // Use the exact IDs from your StoreKit configuration
  final _kMonthlyId = 'com.example.catharsiscards.subscription.monthly';
  final _kAnnualId  = 'com.example.catharsiscards.subscription.annual';
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get regional pricing based on device locale
    _pricing = PricingService.getPricingForLocale(context);
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
          Padding(
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
                      _PlanCard(
                        title: 'Monthly Subscription',
                        price: _pricing.monthlyPrice,
                        currencyCode: _pricing.currencyCode,
                        period: 'per month',
                        onPressed: () => _buy(_kMonthlyId),
                        locale: Localizations.localeOf(context).toString(),
                      ),
                      _PlanCard(
                        title: 'Annual Subscription',
                        price: _pricing.annualPrice,
                        currencyCode: _pricing.currencyCode,
                        period: 'per year',
                        onPressed: () => _buy(_kAnnualId),
                        locale: Localizations.localeOf(context).toString(),
                        showSavings: true,
                        monthlyPrice: _pricing.monthlyPrice,
                      ),
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
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final priceString = PricingService.formatPrice(price, currencyCode, locale: locale);
    
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
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontFamily: 'Runtime',
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: fontColor,
                ),
              ),
              Text(
                period,
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