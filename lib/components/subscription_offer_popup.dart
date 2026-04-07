import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../provider/theme_provider.dart';
import '../provider/theme_provider.dart' show CustomThemeExtension;

String _fmtPrice(double price, String currencyCode, {String? locale}) {
  try {
    final format = NumberFormat.simpleCurrency(name: currencyCode, locale: locale);
    return format.format(price);
  } catch (e) {
    return '$currencyCode ${price.toStringAsFixed(2)}';
  }
}

class SubscriptionOfferPopup extends ConsumerStatefulWidget {
  final VoidCallback onDismiss;
  final VoidCallback onPurchaseComplete;

  const SubscriptionOfferPopup({
    Key? key,
    required this.onDismiss,
    required this.onPurchaseComplete,
  }) : super(key: key);

  @override
  ConsumerState<SubscriptionOfferPopup> createState() =>
      _SubscriptionOfferPopupState();
}

class _SubscriptionOfferPopupState
    extends ConsumerState<SubscriptionOfferPopup> {
  final _iap = InAppPurchase.instance;
  List<ProductDetails> _products = [];
  bool _isLoading = true;
  bool _isPurchasing = false;
  late final StreamSubscription<List<PurchaseDetails>> _purchaseSub;

  // Standard product IDs — used only to show the crossed-out original price.
  String get _monthlyId =>
      Platform.isAndroid ? 'monthly_subscription' : 'com.catharsis.cards.monthly';
  String get _annualId =>
      Platform.isAndroid ? 'annual_subscription' : 'com.catharsis.cards.annual';

  String get _monthlyOfferId =>
      Platform.isAndroid ? 'monthly_subscription_offer' : 'com.catharsis.cards.monthly.offer';
  String get _annualOfferId =>
      Platform.isAndroid ? 'annual_subscription_offer' : 'com.catharsis.cards.annual.offer';

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _purchaseSub =
        _iap.purchaseStream.listen(_handlePurchaseUpdate, onError: (_) {});
  }

  Future<void> _loadProducts() async {
    final available = await _iap.isAvailable();
    if (!available || !mounted) {
      setState(() => _isLoading = false);
      return;
    }
    // Query both the standard IDs (for original price display) and
    // the offer IDs (for the actual discounted purchase).
    final response = await _iap.queryProductDetails(
        {_monthlyId, _annualId, _monthlyOfferId, _annualOfferId});

    debugPrint('[OFFER] Products found: ${response.productDetails.map((p) => '${p.id}=${p.price}').join(', ')}');
    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('[OFFER] Products NOT found in store: ${response.notFoundIDs.join(', ')}');
    }

    if (mounted) {
      setState(() {
        _products = response.productDetails;
        _isLoading = false;
      });
    }
  }

  void _handlePurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          if (mounted) {
            widget.onPurchaseComplete();
          }
          break;
        case PurchaseStatus.error:
          if (mounted) {
            setState(() => _isPurchasing = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Purchase failed: ${purchase.error?.message ?? 'Unknown error'}',
                ),
              ),
            );
          }
          break;
        case PurchaseStatus.canceled:
          if (mounted) setState(() => _isPurchasing = false);
          break;
        default:
          break;
      }
    }
  }

  void _buy(String productId) {
    try {
      final matching = _products.where((p) => p.id == productId);
      if (matching.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product not available')),
        );
        return;
      }
      setState(() => _isPurchasing = true);
      final param = PurchaseParam(productDetails: matching.first);
      _iap.buyNonConsumable(purchaseParam: param);
    } catch (e) {
      setState(() => _isPurchasing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error initiating purchase')),
      );
    }
  }

  @override
  void dispose() {
    _purchaseSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customTheme = theme.extension<CustomThemeExtension>();
    final themeName = ref.watch(themeProvider).themeName;
    final fontColor = customTheme?.fontColor ??
        theme.textTheme.bodyMedium?.color ??
        theme.primaryColor;
    final buttonBgColor =
        customTheme?.preferenceButtonColor ?? theme.primaryColor;
    final bool isDefaultTheme = customTheme?.backgroundImagePath == null;
    final locale = Localizations.localeOf(context).toString();

    // Resolve all four products (standard + offer).
    ProductDetails? monthly, annual, monthlyOffer, annualOffer;
    try { monthly      = _products.firstWhere((p) => p.id == _monthlyId);      } catch (_) {}
    try { annual       = _products.firstWhere((p) => p.id == _annualId);       } catch (_) {}
    try { monthlyOffer = _products.firstWhere((p) => p.id == _monthlyOfferId); } catch (_) {}
    try { annualOffer  = _products.firstWhere((p) => p.id == _annualOfferId);  } catch (_) {}

    // The product that will actually be purchased (offer if available, else standard).
    final monthlyToBuy = monthlyOffer ?? monthly;
    final annualToBuy  = annualOffer  ?? annual;

    // Discount badge: "50% OFF" vs the standard price.
    String? monthlyDiscountBadge;
    if (monthly != null && monthlyOffer != null && monthly.rawPrice > 0) {
      final pct = ((monthly.rawPrice - monthlyOffer.rawPrice) / monthly.rawPrice * 100).round();
      if (pct > 0) monthlyDiscountBadge = '$pct% OFF';
    }
    String? annualDiscountBadge;
    if (annual != null && annualOffer != null && annual.rawPrice > 0) {
      final pct = ((annual.rawPrice - annualOffer.rawPrice) / annual.rawPrice * 100).round();
      if (pct > 0) annualDiscountBadge = '$pct% OFF';
    }

    return Stack(
      children: [
        // ---------- dimmed background ----------
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onDismiss,
            child: Container(color: Colors.black.withOpacity(0.55)),
          ),
        ),

        // ---------- popup card ----------
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: customTheme?.preferenceBorderColor ?? theme.primaryColor,
                width: 4,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Background image — Positioned.fill so it matches content height
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      themeName == 'dark'
                          ? 'assets/images/dark_mode_background.png'
                          : themeName == 'light'
                              ? 'assets/images/light_mode_background.png'
                              : 'assets/images/default_mode_background.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        decoration: BoxDecoration(
                          color: theme.scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ),

                // Scrim — stronger on dark themes for readability
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      color: theme.brightness == Brightness.dark
                          ? Colors.black.withOpacity(0.72)
                          : Colors.black.withOpacity(0.38),
                    ),
                  ),
                ),

                // Close button
                Positioned(
                  top: 12,
                  right: 12,
                  child: GestureDetector(
                    onTap: widget.onDismiss,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),

                // ---------- content — drives the overall popup height ----------
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 32, 22, 30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // "Special offer" badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade600,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          '✦  SPECIAL OFFER  ✦',
                          style: TextStyle(
                            fontFamily: 'Runtime',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Headline
                      const Text(
                        'Go Unlimited',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Runtime',
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Benefits list
                      Column(
                        children: [
                          const _OfferBenefitRow(
                            icon: Icons.all_inclusive,
                            text: 'Unlimited swipes every day',
                          ),
                          const SizedBox(height: 8),
                          const _OfferBenefitRow(
                            icon: Icons.ac_unit,
                            text: 'Streak freezes — miss a day, keep your streak',
                          ),
                          if (Platform.isAndroid) ...[
                            const SizedBox(height: 8),
                            const _OfferBenefitRow(
                              icon: Icons.block,
                              text: 'Ad-free experience',
                            ),
                          ],
                          const SizedBox(height: 8),
                          const _OfferBenefitRow(
                            icon: Icons.favorite,
                            text: 'Support independent development',
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Monthly plan row
                      _PlanRow(
                        label: 'Monthly',
                        sublabel: 'per month',
                        priceLabel: _isLoading
                            ? '...'
                            : monthlyToBuy != null
                                ? _fmtPrice(monthlyToBuy.rawPrice,
                                    monthlyToBuy.currencyCode, locale: locale)
                                : '--',
                        originalPriceLabel: (!_isLoading &&
                                monthlyOffer != null &&
                                monthly != null)
                            ? _fmtPrice(monthly.rawPrice, monthly.currencyCode,
                                locale: locale)
                            : null,
                        badge: monthlyDiscountBadge,
                        buttonColor: buttonBgColor,
                        fontColor: isDefaultTheme
                            ? Colors.white
                            : (customTheme?.buttonFontColor ?? Colors.white),
                        onTap: (_isPurchasing || _isLoading || monthlyToBuy == null)
                            ? null
                            : () => _buy(monthlyToBuy.id),
                      ),

                      const SizedBox(height: 14),

                      // Annual plan row
                      _PlanRow(
                        label: 'Annual',
                        sublabel: 'per year',
                        priceLabel: _isLoading
                            ? '...'
                            : annualToBuy != null
                                ? _fmtPrice(annualToBuy.rawPrice,
                                    annualToBuy.currencyCode, locale: locale)
                                : '--',
                        originalPriceLabel: (!_isLoading &&
                                annualOffer != null &&
                                annual != null)
                            ? _fmtPrice(annual.rawPrice, annual.currencyCode,
                                locale: locale)
                            : null,
                        badge: annualDiscountBadge,
                        buttonColor: buttonBgColor,
                        fontColor: isDefaultTheme
                            ? Colors.white
                            : (customTheme?.buttonFontColor ?? Colors.white),
                        onTap: (_isPurchasing || _isLoading || annualToBuy == null)
                            ? null
                            : () => _buy(annualToBuy.id),
                      ),

                      const SizedBox(height: 12),

                      // Reassurance line
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline_rounded,
                              size: 13,
                              color: Colors.white.withOpacity(0.50)),
                          const SizedBox(width: 4),
                          Text(
                            'No payment due now',
                            style: TextStyle(
                              fontFamily: 'Runtime',
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.50),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Legal links — required by App Store
                      _LegalLinks(),

                      // Maybe later link
                      TextButton(
                        onPressed: widget.onDismiss,
                        child: Text(
                          'Maybe Later',
                          style: TextStyle(
                            fontFamily: 'Runtime',
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.70),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Purchasing overlay
                if (_isPurchasing)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        color: Colors.black.withOpacity(0.45),
                        child: const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Benefit row used inside the offer popup
// ---------------------------------------------------------------------------

class _OfferBenefitRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _OfferBenefitRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.orange.shade300, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'Runtime',
              fontSize: 14,
              color: Colors.white.withOpacity(0.92),
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Legal links (Privacy Policy + Terms of Use) — required by App Store
// ---------------------------------------------------------------------------

const _kPrivacyUrl = 'https://catharsisdev.github.io/CatharsisMobileApp/';
const _kTermsUrl   = 'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';

Future<void> _openUrl(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _LegalLinks extends StatelessWidget {
  const _LegalLinks();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text.rich(
        TextSpan(
          style: TextStyle(
            fontFamily: 'Runtime',
            fontSize: 11,
            color: Colors.white.withOpacity(0.55),
          ),
          children: [
            const TextSpan(text: 'By subscribing you agree to our '),
            TextSpan(
              text: 'Terms of Use',
              style: TextStyle(
                color: Colors.white.withOpacity(0.80),
                decoration: TextDecoration.underline,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () => _openUrl(_kTermsUrl),
            ),
            const TextSpan(text: ' and '),
            TextSpan(
              text: 'Privacy Policy',
              style: TextStyle(
                color: Colors.white.withOpacity(0.80),
                decoration: TextDecoration.underline,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () => _openUrl(_kPrivacyUrl),
            ),
            const TextSpan(text: '.'),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable plan row button
// ---------------------------------------------------------------------------

class _PlanRow extends StatelessWidget {
  final String label;
  final String sublabel;
  final String priceLabel;
  final String? originalPriceLabel; // shown crossed out when there's a discount
  final String? badge;
  final Color buttonColor;
  final Color fontColor;
  final VoidCallback? onTap;

  const _PlanRow({
    Key? key,
    required this.label,
    required this.sublabel,
    required this.priceLabel,
    this.originalPriceLabel,
    required this.badge,
    required this.buttonColor,
    required this.fontColor,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final effectiveColor = onTap != null ? buttonColor : Colors.grey;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
        decoration: BoxDecoration(
          color: effectiveColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Label + sublabel — always white on the coloured button surface
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Runtime',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  sublabel,
                  style: TextStyle(
                    fontFamily: 'Runtime',
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.80),
                  ),
                ),
              ],
            ),

            // Badge + prices (crossed-out original → offer price)
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (badge != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withOpacity(0.6)),
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
                  const SizedBox(width: 8),
                ],
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (originalPriceLabel != null)
                      Text(
                        originalPriceLabel!,
                        style: TextStyle(
                          fontFamily: 'Runtime',
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.70),
                          decoration: TextDecoration.lineThrough,
                          decorationColor: Colors.white.withOpacity(0.70),
                        ),
                      ),
                    Text(
                      priceLabel,
                      style: const TextStyle(
                        fontFamily: 'Runtime',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
