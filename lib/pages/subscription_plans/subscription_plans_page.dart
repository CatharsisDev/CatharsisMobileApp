import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'dart:async';
import '../../provider/theme_provider.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../../services/subscription_service.dart';
import 'package:url_launcher/url_launcher.dart';

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

class SubscriptionPlansPage extends StatefulWidget {
  final VoidCallback onMonthlyPurchase;
  final VoidCallback onAnnualPurchase;
  final VoidCallback? onCancel;
  final SubscriptionService subscriptionService;

  const SubscriptionPlansPage({
    Key? key,
    required this.onMonthlyPurchase,
    required this.onAnnualPurchase,
    required this.subscriptionService,
    this.onCancel,
  }) : super(key: key);

  @override
  _SubscriptionPlansPageState createState() => _SubscriptionPlansPageState();
}

class _SubscriptionPlansPageState extends State<SubscriptionPlansPage> {
  final _iap = InAppPurchase.instance;
  List<ProductDetails> _products = [];

  final _kMonthlyId = Platform.isAndroid
    ? 'monthly_subscription'
    : 'com.catharsis.cards.monthly';

final _kAnnualId = Platform.isAndroid
    ? 'annual_subscription'
    : 'com.catharsis.cards.annual';

  late final StreamSubscription<List<PurchaseDetails>> _subscription;

  String? _currentSubscriptionType;
  DateTime? _subscriptionExpiry;
  bool _isAlreadySubscribed = false;

  @override
  void initState() {
    super.initState();
    
    // Check current subscription status
    _currentSubscriptionType = widget.subscriptionService.getCurrentSubscriptionType();
    _subscriptionExpiry = widget.subscriptionService.getSubscriptionExpiry();
    _isAlreadySubscribed = widget.subscriptionService.isUserSubscribed();

    _iap.isAvailable().then((available) {
      print('▶︎ IAP available? $available');
      print('🔴 Querying product IDs: $_kMonthlyId, $_kAnnualId');
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
          
          // Update UI after purchase
          setState(() {
            _currentSubscriptionType = widget.subscriptionService.getCurrentSubscriptionType();
            _subscriptionExpiry = widget.subscriptionService.getSubscriptionExpiry();
            _isAlreadySubscribed = true;
          });
          break;
        case PurchaseStatus.error:
          final errorMsg = purchase.error?.message ?? 'Unknown error';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Purchase error: $errorMsg')),
          );
          break;
        case PurchaseStatus.pending:
          // Show pending indicator
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Purchase pending...')),
          );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Product not available')),
        );
        return;
      }
      final product = matching.first;
      print('Found product: ${product.id}, initiating purchase...');
      final param = PurchaseParam(productDetails: product);
      print('▶︎ calling buyNonConsumable for: ${product.id}');
      _iap.buyNonConsumable(purchaseParam: param);
    } catch (e) {
      print('Error in _buy(): $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error initiating purchase')),
      );
    }
  }

  bool _canPurchaseMonthly() {
    // Can't purchase monthly if already have monthly or annual
    return !_isAlreadySubscribed;
  }

  bool _canPurchaseAnnual() {
    // Can purchase annual if no subscription or upgrading from monthly
    return !_isAlreadySubscribed || _currentSubscriptionType == 'monthly';
  }

  String _getUpgradeMessage() {
    if (_currentSubscriptionType == 'monthly') {
      return 'Upgrade to Annual';
    }
    return '';
  }

  void _manageSubscription() async {
    // Open subscription management
    final Uri url;
    if (Platform.isIOS) {
      url = Uri.parse('https://apps.apple.com/account/subscriptions');
    } else {
      url = Uri.parse('https://play.google.com/store/account/subscriptions');
    }
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open subscription management')),
      );
    }
  }

  Widget _buildPlanCard(
    String productId,
    String title,
    String period, {
    bool showSavings = false,
    bool canPurchase = true,
    String? upgradeMessage,
  }) {
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
        canPurchase: false,
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
      onPressed: canPurchase ? () => _buy(productId) : () {},
      locale: Localizations.localeOf(context).toString(),
      showSavings: showSavings,
      monthlyPrice: monthlyPrice,
      canPurchase: canPurchase,
      upgradeMessage: upgradeMessage,
    );
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customTheme = theme.extension<CustomThemeExtension>();
    final fontColor = customTheme?.fontColor ??
        theme.textTheme.bodyMedium?.color ??
        theme.primaryColor;
    final bool isDefaultTheme = customTheme?.backgroundImagePath == null;
    final locale = Localizations.localeOf(context).toString();

    final bool showMonthly = _canPurchaseMonthly();
    final bool showAnnual  = _canPurchaseAnnual();

    // Fully subscribed with no upgrade path → dedicated view
    if (_isAlreadySubscribed && !showMonthly && !showAnnual) {
      return _buildAlreadySubscribedView(theme, customTheme, fontColor);
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _isAlreadySubscribed ? 'Manage Subscription' : 'Upgrade to Unlimited',
          style: TextStyle(fontFamily: 'Runtime', color: fontColor),
        ),
        leading: IconButton(
          icon: Icon(Icons.close, color: theme.iconTheme.color),
          onPressed: widget.onCancel ?? () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          // Background
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

          // Content — fixed column, no scroll
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Upgrading banner (monthly → annual) ──────────────────
                  if (_isAlreadySubscribed && _currentSubscriptionType != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green, width: 1),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Current: ${_currentSubscriptionType == 'monthly' ? 'Monthly' : 'Annual'}${_subscriptionExpiry != null ? '  ·  renews ${DateFormat('MMM d, yyyy').format(_subscriptionExpiry!)}' : ''}',
                              style: TextStyle(
                                fontFamily: 'Runtime',
                                fontSize: 13,
                                color: fontColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ── Title ────────────────────────────────────────────────
                  Text(
                    _isAlreadySubscribed ? 'Upgrade your plan' : 'Choose a plan',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontFamily: 'Runtime', color: fontColor),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // ── Benefits ─────────────────────────────────────────────
                  _BenefitsBlock(fontColor: fontColor),
                  const SizedBox(height: 24),

                  // ── Plan cards — side by side, sized to content ──────────
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showMonthly)
                          Expanded(
                            child: _CompactPlanCard(
                              productId: _kMonthlyId,
                              label: 'Monthly',
                              sublabel: 'per month',
                              products: _products,
                              isLoading: _products.isEmpty,
                              canPurchase: _canPurchaseMonthly(),
                              onBuy: () => _buy(_kMonthlyId),
                              locale: locale,
                              theme: theme,
                              customTheme: customTheme,
                              fontColor: fontColor,
                              isDefaultTheme: isDefaultTheme,
                            ),
                          ),
                        if (showMonthly && showAnnual)
                          const SizedBox(width: 12),
                        if (showAnnual)
                          Expanded(
                            child: _CompactPlanCard(
                              productId: _kAnnualId,
                              label: 'Annual',
                              sublabel: 'per year',
                              products: _products,
                              isLoading: _products.isEmpty,
                              canPurchase: _canPurchaseAnnual(),
                              onBuy: () => _buy(_kAnnualId),
                              locale: locale,
                              theme: theme,
                              customTheme: customTheme,
                              fontColor: fontColor,
                              isDefaultTheme: isDefaultTheme,
                              badge: 'Best Value',
                              highlighted: true,
                              showSavings: true,
                              monthlyId: _kMonthlyId,
                            ),
                          ),
                      ],
                    ),
                  ),

                  const Spacer(),
                  _PlansLegalLinks(fontColor: fontColor),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlreadySubscribedView(ThemeData theme, CustomThemeExtension? customTheme, Color fontColor) {
    final bool isDefaultTheme = customTheme?.backgroundImagePath == null;
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Subscription Active',
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
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),

                  // Crown / check icon
                  const Icon(Icons.check_circle, color: Colors.green, size: 64),
                  const SizedBox(height: 16),

                  Text(
                    'You\'re Premium!',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontFamily: 'Runtime',
                      fontWeight: FontWeight.bold,
                      color: fontColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),

                  Text(
                    'You have an active ${_currentSubscriptionType} subscription',
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontFamily: 'Runtime', color: fontColor),
                    textAlign: TextAlign.center,
                  ),
                  if (_subscriptionExpiry != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Renews on ${DateFormat('MMM dd, yyyy').format(_subscriptionExpiry!)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: 'Runtime',
                        color: fontColor.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  const SizedBox(height: 24),
                  _BenefitsBlock(fontColor: fontColor),

                  const Spacer(),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          customTheme?.preferenceButtonColor ?? theme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: _manageSubscription,
                    child: Text(
                      'Manage Subscription',
                      style: TextStyle(
                        fontFamily: 'Runtime',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDefaultTheme
                            ? Colors.white
                            : (customTheme?.buttonFontColor ?? fontColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _PlansLegalLinks(fontColor: fontColor),
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
  final bool canPurchase;
  final String? upgradeMessage;

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
    this.canPurchase = true,
    this.upgradeMessage,
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
    final fontColor = customTheme?.fontColor ??
        theme.textTheme.bodyMedium?.color ??
        theme.primaryColor;
    final buttonFontColor = customTheme?.buttonFontColor ?? fontColor;
    final bool isDefaultTheme = customTheme?.backgroundImagePath == null;

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
              if (upgradeMessage != null) ...[
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue, width: 1),
                  ),
                  child: Text(
                    upgradeMessage!,
                    style: TextStyle(
                      fontFamily: 'Runtime',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
                SizedBox(height: 12),
              ],
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
                  backgroundColor: canPurchase
                      ? (theme.extension<CustomThemeExtension>()?.preferenceButtonColor ??
                          theme.primaryColor)
                      : Colors.grey,
                ),
                onPressed: canPurchase ? onPressed : null,
                child: Text(
                  canPurchase ? (upgradeMessage != null ? 'Upgrade' : 'Select') : 'Unavailable',
                  style: TextStyle(
                    fontFamily: 'Runtime',
                    fontWeight: FontWeight.bold,
                    color: canPurchase ? (isDefaultTheme ? Colors.white : buttonFontColor) : Colors.white,
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

// ---------------------------------------------------------------------------
// Compact plan card — shown side-by-side in the no-scroll layout
// ---------------------------------------------------------------------------

class _CompactPlanCard extends StatelessWidget {
  final String productId;
  final String label;
  final String sublabel;
  final List<ProductDetails> products;
  final bool isLoading;
  final bool canPurchase;
  final VoidCallback onBuy;
  final String locale;
  final ThemeData theme;
  final CustomThemeExtension? customTheme;
  final Color fontColor;
  final bool isDefaultTheme;
  final String? badge;
  final bool highlighted;
  final bool showSavings;
  final String? monthlyId;

  const _CompactPlanCard({
    required this.productId,
    required this.label,
    required this.sublabel,
    required this.products,
    required this.isLoading,
    required this.canPurchase,
    required this.onBuy,
    required this.locale,
    required this.theme,
    required this.customTheme,
    required this.fontColor,
    required this.isDefaultTheme,
    this.badge,
    this.highlighted = false,
    this.showSavings = false,
    this.monthlyId,
  });

  @override
  Widget build(BuildContext context) {
    ProductDetails? product;
    try { product = products.firstWhere((p) => p.id == productId); } catch (_) {}

    ProductDetails? monthlyProduct;
    if (showSavings && monthlyId != null) {
      try { monthlyProduct = products.firstWhere((p) => p.id == monthlyId); } catch (_) {}
    }

    final priceStr = isLoading
        ? '...'
        : product != null
            ? _formatPrice(product.rawPrice, product.currencyCode, locale: locale)
            : '--';

    String? savingsText;
    if (showSavings && product != null && monthlyProduct != null) {
      final yearlyFromMonthly = monthlyProduct.rawPrice * 12;
      final pct = ((yearlyFromMonthly - product.rawPrice) / yearlyFromMonthly * 100).round();
      if (pct > 0) savingsText = 'Save $pct%';
    }

    final accentColor = customTheme?.preferenceButtonColor ?? theme.primaryColor;
    final buttonColor = canPurchase ? accentColor : Colors.grey;

    return Card(
      color: theme.cardColor,          // same background on both cards
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: highlighted
            ? BorderSide(color: accentColor, width: 2)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      elevation: highlighted ? 6 : 2,
      child: Container(
        decoration: BoxDecoration(
          image: customTheme?.backgroundImagePath != null
              ? DecorationImage(
                  image: AssetImage(customTheme!.backgroundImagePath!),
                  fit: BoxFit.cover,
                  opacity: 0.3,
                )
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 20, 14, 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Badge — takes up space even when absent so buttons stay aligned
              SizedBox(
                height: 28,
                child: badge != null
                    ? Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            badge!,
                            style: const TextStyle(
                              fontFamily: 'Runtime',
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 12),

              // Plan name
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Runtime',
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: fontColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),

              // Price
              Text(
                priceStr,
                style: TextStyle(
                  fontFamily: 'Runtime',
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: fontColor,
                ),
                textAlign: TextAlign.center,
              ),

              // Period
              Text(
                sublabel,
                style: TextStyle(
                  fontFamily: 'Runtime',
                  fontSize: 13,
                  color: fontColor.withOpacity(0.58),
                ),
                textAlign: TextAlign.center,
              ),

              // Savings badge — reserved height keeps buttons aligned
              const SizedBox(height: 8),
              SizedBox(
                height: 26,
                child: savingsText != null
                    ? Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.green),
                          ),
                          child: Text(
                            savingsText,
                            style: const TextStyle(
                              fontFamily: 'Runtime',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      )
                    : null,
              ),

              const SizedBox(height: 14),

              // Reassurance line
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline_rounded,
                        size: 13, color: fontColor.withOpacity(0.45)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'No payment due now',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Runtime',
                          fontSize: 11,
                          color: fontColor.withOpacity(0.45),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Select button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: canPurchase ? onBuy : null,
                  child: Text(
                    canPurchase ? 'Select' : 'Unavailable',
                    style: TextStyle(
                      fontFamily: 'Runtime',
                      fontWeight: FontWeight.bold,
                      color: canPurchase
                          ? (isDefaultTheme
                              ? Colors.white
                              : (customTheme?.buttonFontColor ?? fontColor))
                          : Colors.white,
                    ),
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

// ---------------------------------------------------------------------------
// Legal links widget — required by App Store guideline 3.1.2(c)
// ---------------------------------------------------------------------------

const _kPrivacyUrl = 'https://catharsisdev.github.io/CatharsisMobileApp/';
const _kTermsUrl   = 'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';

Future<void> _openLegalUrl(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _PlansLegalLinks extends StatelessWidget {
  final Color fontColor;
  const _PlansLegalLinks({required this.fontColor});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: TextStyle(
          fontFamily: 'Runtime',
          fontSize: 12,
          color: fontColor.withOpacity(0.50),
        ),
        children: [
          const TextSpan(text: 'By subscribing you agree to our '),
          TextSpan(
            text: 'Terms of Use',
            style: TextStyle(
              color: fontColor.withOpacity(0.75),
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () => _openLegalUrl(_kTermsUrl),
          ),
          const TextSpan(text: ' and '),
          TextSpan(
            text: 'Privacy Policy',
            style: TextStyle(
              color: fontColor.withOpacity(0.75),
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () => _openLegalUrl(_kPrivacyUrl),
          ),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

// ---------------------------------------------------------------------------
// Benefits block — shared across the plans page and already-subscribed view
// ---------------------------------------------------------------------------

class _BenefitsBlock extends StatelessWidget {
  final Color fontColor;
  const _BenefitsBlock({required this.fontColor});

  @override
  Widget build(BuildContext context) {
    final benefits = [
      (Icons.all_inclusive, 'Unlimited swipes every day'),
      (Icons.ac_unit,       'Streak freezes — miss a day, keep your streak'),
      if (Platform.isAndroid)
        (Icons.block,       'Ad-free experience'),
      (Icons.favorite,      'Support independent development'),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: fontColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: fontColor.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What you get',
            style: TextStyle(
              fontFamily: 'Runtime',
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: fontColor.withOpacity(0.55),
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          ...benefits.map((b) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Icon(b.$1, color: Colors.orange, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    b.$2,
                    style: TextStyle(
                      fontFamily: 'Runtime',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: fontColor,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}