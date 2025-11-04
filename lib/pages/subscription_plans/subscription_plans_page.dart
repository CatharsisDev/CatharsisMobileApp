import 'package:flutter/material.dart';
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
  final PageController _pageController = PageController(viewportFraction: 0.85);
  int _currentPage = 0;

  final _iap = InAppPurchase.instance;
  List<ProductDetails> _products = [];

  final _kMonthlyId = Platform.isAndroid
      ? 'monthly_subscription'
      : 'monthly_subscription';

  final _kAnnualId = Platform.isAndroid
      ? 'annual_subscription'
      : 'annual_subscription';

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
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customTheme = theme.extension<CustomThemeExtension>();
    final indicatorColor = theme.textTheme.bodyMedium?.color ?? theme.primaryColor;
    final fontColor = customTheme?.fontColor ??
        theme.textTheme.bodyMedium?.color ??
        theme.primaryColor;
    final bool isDefaultTheme = customTheme?.backgroundImagePath == null;

    // Build list of available plans
    List<Widget> planCards = [];
    
    if (_canPurchaseMonthly()) {
      planCards.add(
        _buildPlanCard(_kMonthlyId, 'Monthly Subscription', 'per month'),
      );
    }
    
    if (_canPurchaseAnnual()) {
      planCards.add(
        _buildPlanCard(
          _kAnnualId,
          'Annual Subscription',
          'per year',
          showSavings: true,
          upgradeMessage: _currentSubscriptionType == 'monthly' ? _getUpgradeMessage() : null,
        ),
      );
    }

    // If already subscribed and can't purchase anything, show subscription info
    if (_isAlreadySubscribed && planCards.isEmpty) {
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Make the card height responsive and clamp it to sensible bounds
                  final double cardHeight =
                      (constraints.maxHeight * 0.55).clamp(320.0, 480.0);

                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isAlreadySubscribed && _currentSubscriptionType != null) ...[
                            Container(
                              padding: EdgeInsets.all(16),
                              margin: EdgeInsets.only(bottom: 20),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.green, width: 1),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.green, size: 32),
                                  SizedBox(height: 8),
                                  Text(
                                    'Current Plan: ${_currentSubscriptionType == 'monthly' ? 'Monthly' : 'Annual'}',
                                    style: TextStyle(
                                      fontFamily: 'Runtime',
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: fontColor,
                                    ),
                                  ),
                                  if (_subscriptionExpiry != null) ...[
                                    SizedBox(height: 4),
                                    Text(
                                      'Expires: ${DateFormat('MMM dd, yyyy').format(_subscriptionExpiry!)}',
                                      style: TextStyle(
                                        fontFamily: 'Runtime',
                                        fontSize: 14,
                                        color: fontColor.withOpacity(0.7),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                          Text(
                            planCards.isEmpty
                                ? 'You\'re all set!'
                                : (_isAlreadySubscribed ? 'Upgrade your plan' : 'Choose a plan'),
                            style: theme.textTheme.titleLarge
                                ?.copyWith(fontFamily: 'Runtime', color: fontColor),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 30),
                          if (planCards.isNotEmpty) ...[
                            SizedBox(
                              height: cardHeight,
                              child: planCards.length == 1
                                  ? Center(child: planCards[0])
                                  : PageView(
                                      controller: _pageController,
                                      children: planCards,
                                    ),
                            ),
                            const SizedBox(height: 16),
                            if (planCards.length > 1)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  planCards.length,
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
                          ],
                          const SizedBox(height: 24),
                          if (_isAlreadySubscribed)
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    customTheme?.preferenceButtonColor ?? theme.primaryColor,
                                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                              onPressed: _manageSubscription,
                              icon: Icon(
                                Icons.settings,
                                color: isDefaultTheme ? Colors.white : (customTheme?.buttonFontColor ?? fontColor),
                              ),
                              label: Text(
                                'Manage Subscription',
                                style: TextStyle(
                                  fontFamily: 'Runtime',
                                  fontWeight: FontWeight.bold,
                                  color: isDefaultTheme ? Colors.white : (customTheme?.buttonFontColor ?? fontColor),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
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
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 80),
                    SizedBox(height: 24),
                    Text(
                      'You\'re Premium!',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontFamily: 'Runtime',
                        fontWeight: FontWeight.bold,
                        color: fontColor,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'You have an active ${_currentSubscriptionType} subscription',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontFamily: 'Runtime',
                        color: fontColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_subscriptionExpiry != null) ...[
                      SizedBox(height: 8),
                      Text(
                        'Renews on ${DateFormat('MMM dd, yyyy').format(_subscriptionExpiry!)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontFamily: 'Runtime',
                          color: fontColor.withOpacity(0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    SizedBox(height: 32),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: customTheme?.preferenceButtonColor ?? theme.primaryColor,
                        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      ),
                      onPressed: _manageSubscription,
                      child: Text(
                        'Manage Subscription',
                        style: TextStyle(
                          fontFamily: 'Runtime',
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDefaultTheme ? Colors.white : (customTheme?.buttonFontColor ?? fontColor),
                        ),
                      ),
                    ),
                  ],
                ),
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