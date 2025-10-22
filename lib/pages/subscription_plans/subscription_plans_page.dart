import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'dart:async';
import '../../provider/theme_provider.dart';
import 'package:intl/intl.dart';
import 'dart:io';

// Define price tiers for different regions
class RegionalPricing {
  final String currencyCode;
  final double? monthlyPrice; // Only used for the USD base
  final double? annualPrice;  // Only used for the USD base
  final String countryCode;

  const RegionalPricing({
    required this.currencyCode,
    this.monthlyPrice,
    this.annualPrice,
    required this.countryCode,
  });
}

class PricingService {
  // Rates used to calculate non‑USD prices from the USD base price.
  // Edit these multipliers if you want to tune regional pricing.
  static const Map<String, double> _usdToCurrencyRate = {
    'USD': 1.0,
    'EUR': 1.0,    // keep EUR roughly at parity with USD for UI display
    'GBP': 0.7526,
    'CAD': 1.3769,
    'AUD': 1.529,
    'JPY': 146.05,
    'INR': 82.80,
    'BRL': 5.17,
    'MXN': 17.35,
    'KRW': 1309.17,
  };

  // Round amounts to a sensible number of decimals for each currency.
  static double _roundForCurrency(String currencyCode, double amount) {
    switch (currencyCode) {
      case 'JPY':
      case 'KRW':
        return amount.roundToDouble(); // zero‑decimal currencies
      default:
        return double.parse(amount.toStringAsFixed(2));
    }
  }
  
  static RegionalPricing _pricesFromUSD(String countryCode, String currencyCode) {
    final baseMonthlyUSD = _regionalPricing['US']?.monthlyPrice
        ?? _regionalPricing['DEFAULT']?.monthlyPrice
        ?? 1.99;
    final baseAnnualUSD  = _regionalPricing['US']?.annualPrice
        ?? _regionalPricing['DEFAULT']?.annualPrice
        ?? 14.90;

    final rate = _usdToCurrencyRate[currencyCode] ?? 1.0;
    final monthly = _roundForCurrency(currencyCode, baseMonthlyUSD * rate);
    final annual  = _roundForCurrency(currencyCode, baseAnnualUSD  * rate);

    return RegionalPricing(
      currencyCode: currencyCode,
      monthlyPrice: monthly,
      annualPrice: annual,
      countryCode: countryCode,
    );
  }
  // Define regional currency mapping. Prices for non‑US regions are computed
  // at runtime from the USD base; only the US/DEFAULT entries carry base USD prices.
  static const Map<String, RegionalPricing> _regionalPricing = {
    // United States (source of truth for base USD prices)
    'US': RegionalPricing(
      currencyCode: 'USD',
      monthlyPrice: 1.99,
      annualPrice: 14.99,
      countryCode: 'US',
    ),

    // European Union (Euro)
    'DE': RegionalPricing(currencyCode: 'EUR', countryCode: 'DE'),
    'FR': RegionalPricing(currencyCode: 'EUR', countryCode: 'FR'),
    'IT': RegionalPricing(currencyCode: 'EUR', countryCode: 'IT'),
    'ES': RegionalPricing(currencyCode: 'EUR', countryCode: 'ES'),

    // United Kingdom
    'GB': RegionalPricing(currencyCode: 'GBP', countryCode: 'GB'),

    // Canada
    'CA': RegionalPricing(currencyCode: 'CAD', countryCode: 'CA'),

    // Australia
    'AU': RegionalPricing(currencyCode: 'AUD', countryCode: 'AU'),

    // Japan
    'JP': RegionalPricing(currencyCode: 'JPY', countryCode: 'JP'),

    // India
    'IN': RegionalPricing(currencyCode: 'INR', countryCode: 'IN'),

    // Brazil
    'BR': RegionalPricing(currencyCode: 'BRL', countryCode: 'BR'),

    // Mexico
    'MX': RegionalPricing(currencyCode: 'MXN', countryCode: 'MX'),

    // South Korea
    'KR': RegionalPricing(currencyCode: 'KRW', countryCode: 'KR'),

    // Default fallback (also USD base to match US)
    'DEFAULT': RegionalPricing(
      currencyCode: 'USD',
      monthlyPrice: 1.99,
      annualPrice: 14.90,
      countryCode: 'US',
    ),
  };

  static RegionalPricing getPricingForLocale(BuildContext context) {
    try {
      // 1) Determine a country code preference
      final locale = Localizations.localeOf(context);
      String? countryCode = locale.countryCode;

      // 2) If not available from Flutter locale, fallback to platform locale
      if (countryCode == null || !_regionalPricing.containsKey(countryCode)) {
        final platformLocale = Platform.localeName; // e.g. en_US
        final parts = platformLocale.split('_');
        final platformCountry = parts.isNotEmpty ? parts.last : null;
        if (platformCountry != null && _regionalPricing.containsKey(platformCountry)) {
          countryCode = platformCountry;
        }
      }

      // 3) Default to US if we still couldn't resolve
      countryCode ??= 'US';

      // Use the existing regional map only to resolve currency & normalized country
      final region = _regionalPricing[countryCode] ?? _regionalPricing['DEFAULT']!;
      final currencyCode = region.currencyCode;
      final normalizedCountry = region.countryCode;

      // 4) Compute prices from USD base every time
      return _pricesFromUSD(normalizedCountry, currencyCode);
    } catch (e) {
      // On any failure, fall back to USD computed prices
      return _pricesFromUSD('US', 'USD');
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
  final _kMonthlyId = Platform.isAndroid
    ? 'monthly_subscription'
    : 'com.example.catharsiscards.subscription.monthly';

final _kAnnualId = Platform.isAndroid
    ? 'annual_subscription'
    : 'com.example.catharsiscards.subscription.annual';
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
                      _PlanCard(
                        title: 'Monthly Subscription',
                        price: _pricing.monthlyPrice!,
                        currencyCode: _pricing.currencyCode,
                        period: 'per month',
                        onPressed: () => _buy(_kMonthlyId),
                        locale: Localizations.localeOf(context).toString(),
                      ),
                      _PlanCard(
                        title: 'Annual Subscription',
                        price: _pricing.annualPrice!,
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