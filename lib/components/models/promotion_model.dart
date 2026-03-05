class Promotion {
  final String id; // Unique identifier (e.g., 'womens_day_2025')
  final String title;
  final String description;
  final String imagePath; // Asset path for promotion graphic
  final String? ctaText; // Call-to-action button text
  final DateTime startDate;
  final DateTime endDate;
  final bool requiresSubscriptionCheck; // Only show to non-premium users
  final String? discountCode; // Optional discount code
  final double? discountPercentage; // e.g., 0.30 for 30% off

  const Promotion({
    required this.id,
    required this.title,
    required this.description,
    required this.imagePath,
    this.ctaText = 'Get Premium',
    required this.startDate,
    required this.endDate,
    this.requiresSubscriptionCheck = true,
    this.discountCode,
    this.discountPercentage,
  });

  bool get isActive {
    final now = DateTime.now();
    return now.isAfter(startDate) && now.isBefore(endDate);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'imagePath': imagePath,
      'ctaText': ctaText,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'requiresSubscriptionCheck': requiresSubscriptionCheck,
      'discountCode': discountCode,
      'discountPercentage': discountPercentage,
    };
  }

  factory Promotion.fromJson(Map<String, dynamic> json) {
    return Promotion(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      imagePath: json['imagePath'] as String,
      ctaText: json['ctaText'] as String? ?? 'Get Premium',
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      requiresSubscriptionCheck: json['requiresSubscriptionCheck'] as bool? ?? true,
      discountCode: json['discountCode'] as String?,
      discountPercentage: json['discountPercentage'] as double?,
    );
  }
}

class PromotionCampaigns {
  static final womensDay2026 = Promotion(
    id: 'womens_day_2026',
    title: 'Women\'s Day Special!',
    description: 'Celebrate International Women\'s Day and gift an annual subscription to a special woman in your life.\n\nUnlock unlimited reflection, exclusive categories, and a personal growth journey. \n Send us a direct message on X @catharsisxyz to claim your promo code today.',
    imagePath: 'assets/images/promotions/womens_day_banner.jpg',
    ctaText: 'Gift a subscription',
    startDate: DateTime(2026, 3, 5), // March 5st
    endDate: DateTime(2026, 3, 9), // March 9th
  );

  static final valentinesDay2026 = Promotion(
    id: 'valentines_day_2025',
    title: 'Love Yourself First ❤️',
    description: 'This Valentine\'s Day, invest in your inner growth.\n\n25% off Premium for deeper self-reflection.',
    imagePath: 'assets/images/promotions/valentines_banner.png',
    ctaText: 'Get Premium',
    startDate: DateTime(2025, 2, 10),
    endDate: DateTime(2025, 2, 15),
    requiresSubscriptionCheck: true,
    discountCode: 'LOVE25',
    discountPercentage: 0.25,
  );

  static final newYear2026 = Promotion(
    id: 'new_year_2025',
    title: 'New Year, New You 🎉',
    description: 'Start 2025 with deeper self-awareness.\n\n40% off Premium - Limited Time!',
    imagePath: 'assets/images/promotions/new_year_banner.png',
    ctaText: 'Start Your Journey',
    startDate: DateTime(2024, 12, 28),
    endDate: DateTime(2025, 1, 7),
    requiresSubscriptionCheck: true,
    discountCode: 'NEWYEAR40',
    discountPercentage: 0.40,
  );

  // Flash sale example (no specific dates)
  static final flashSale = Promotion(
    id: 'flash_sale_2025_q1',
    title: '⚡ Flash Sale!',
    description: '24 hours only - 50% off Premium!\n\nUnlock unlimited cards and exclusive content.',
    imagePath: 'assets/images/promotions/flash_sale_banner.png',
    ctaText: 'Grab the Deal',
    startDate: DateTime(2025, 3, 15, 0, 0), // Set specific dates when activating
    endDate: DateTime(2025, 3, 16, 0, 0),
    requiresSubscriptionCheck: true,
    discountCode: 'FLASH50',
    discountPercentage: 0.50,
  );

  // Get all active promotions
  static List<Promotion> getAllCampaigns() {
    return [
      womensDay2026,
      valentinesDay2026,
      newYear2026,
      flashSale,
    ];
  }

  // Get the currently active promotion (if any)
  static Promotion? getActivePromotion() {
    final campaigns = getAllCampaigns();
    for (final campaign in campaigns) {
      if (campaign.isActive) {
        return campaign;
      }
    }
    return null;
  }
}