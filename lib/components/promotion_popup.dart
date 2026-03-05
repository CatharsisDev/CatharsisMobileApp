import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models/promotion_model.dart';
import '../provider/theme_provider.dart';
import '../../services/promotion_service.dart';

class PromotionPopup extends ConsumerStatefulWidget {
  final Promotion promotion;
  final VoidCallback onDismiss;
  final VoidCallback? onPurchase;

  const PromotionPopup({
    Key? key,
    required this.promotion,
    required this.onDismiss,
    this.onPurchase,
  }) : super(key: key);

  @override
  ConsumerState<PromotionPopup> createState() => _PromotionPopupState();
}

class _PromotionPopupState extends ConsumerState<PromotionPopup> {
  final ScrollController _scrollController = ScrollController();
  bool _isScrollable = false;

  Future<void> _openXPage() async {
    final uri = Uri.parse('https://x.com/catharsisxyz');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  void initState() {
    super.initState();
    // Determine whether content is scrollable after first layout
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final scrollable = _scrollController.hasClients &&
          _scrollController.position.maxScrollExtent > 0;
      if (scrollable != _isScrollable) {
        setState(() => _isScrollable = scrollable);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final promotion = widget.promotion;
    final onDismiss = widget.onDismiss;
    final onPurchase = widget.onPurchase;

    final theme = Theme.of(context);
    final customTheme = theme.extension<CustomThemeExtension>();
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: screenHeight * 0.8,
          maxWidth: screenWidth * 0.9,
        ),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background texture if available
            if (customTheme?.showBackgroundTexture ?? false)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Opacity(
                    opacity: 0.1,
                    child: customTheme?.backgroundImagePath != null
                        ? Image.asset(
                            customTheme!.backgroundImagePath!,
                            fit: BoxFit.cover,
                          )
                        : SizedBox(),
                  ),
                ),
              ),
            
            // Main content (scrollable to avoid bottom overflow)
            SingleChildScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Close button
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: InkWell(
                        onTap: () {
                          PromotionService.markPromotionAsSeen(promotion.id);
                          onDismiss();
                        },
                        customBorder: CircleBorder(),
                        child: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.brightness == Brightness.dark
                                ? Colors.white.withOpacity(0.1)
                                : Colors.black.withOpacity(0.05),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close,
                            color: theme.iconTheme.color,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Promotion graphic
                  SizedBox(
                    height: screenHeight * 0.26,
                    width: double.infinity,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          promotion.imagePath,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            // Fallback if image not found
                            return Container(
                              height: 200,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    customTheme?.categoryChipColor ?? theme.primaryColor,
                                    (customTheme?.categoryChipColor ?? theme.primaryColor)
                                        .withOpacity(0.7),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.celebration,
                                  size: 80,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 24),

                  // Title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      promotion.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Runtime',
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.titleLarge?.color,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),

                  SizedBox(height: 16),

                  // Description
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      promotion.description,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Runtime',
                        fontSize: 16,
                        height: 1.5,
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                  ),

                  // Discount badge if available
                  if (promotion.discountPercentage != null) ...[
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: customTheme?.categoryChipColor ?? theme.primaryColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${(promotion.discountPercentage! * 100).toInt()}% OFF',
                        style: TextStyle(
                          fontFamily: 'Runtime',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: customTheme?.buttonFontColor ?? Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],

                  SizedBox(height: 24),

                  // Action buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        // Primary CTA button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              PromotionService.markPromotionAsSeen(promotion.id);

                              // Women’s Day: "Gift a subscription" should open X for claiming the code.
                              if (promotion.id == 'womens_day_2026') {
                                // Close the dialog first to avoid overlay issues.
                                if (Navigator.of(context).canPop()) {
                                  Navigator.of(context).pop();
                                }
                                await _openXPage();
                                return;
                              }

                              if (onPurchase != null) {
                                onPurchase!();
                              } else {
                                // Navigate to subscription page
                                Navigator.of(context).pop();
                                context.push('/subscription', extra: {
                                  'discountCode': promotion.discountCode,
                                  'discountPercentage': promotion.discountPercentage,
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  customTheme?.categoryChipColor ?? theme.primaryColor,
                              foregroundColor:
                                  customTheme?.buttonFontColor ?? Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              promotion.ctaText ?? 'Get Premium',
                              style: TextStyle(
                                fontFamily: 'Runtime',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: 12),

                        // "Maybe later" button
                        TextButton(
                          onPressed: () {
                            PromotionService.markPromotionAsSeen(promotion.id);
                            onDismiss();
                          },
                          child: Text(
                            'Maybe Later',
                            style: TextStyle(
                              fontFamily: 'Runtime',
                              color: theme.brightness == Brightness.dark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 24),
                ],
              ),
            ),

            // Subtle scroll hint (only if content overflows)
            if (_isScrollable)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: Container(
                    height: 28,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          theme.cardColor.withOpacity(0.0),
                          theme.cardColor.withOpacity(0.85),
                        ],
                      ),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                    ),
                    child: Center(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 6.0),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeInOut,
                        builder: (context, value, child) {
                          return Transform.translate(
                            offset: Offset(0, value),
                            child: child,
                          );
                        },
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 24,
                          color: (theme.textTheme.bodyMedium?.color ?? Colors.black)
                              .withOpacity(0.65),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}