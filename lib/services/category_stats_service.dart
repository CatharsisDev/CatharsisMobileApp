import 'dart:math';
import 'package:hive_flutter/hive_flutter.dart';

/// Per-category engagement stats used to compute weighted deck sampling.
class CategoryStats {
  final int seen;
  final int liked;
  final int reflected;
  final String? lastLiked; // 'yyyy-MM-dd'

  const CategoryStats({
    this.seen = 0,
    this.liked = 0,
    this.reflected = 0,
    this.lastLiked,
  });

  CategoryStats copyWith({
    int? seen,
    int? liked,
    int? reflected,
    String? lastLiked,
    bool clearLastLiked = false,
  }) =>
      CategoryStats(
        seen: seen ?? this.seen,
        liked: liked ?? this.liked,
        reflected: reflected ?? this.reflected,
        lastLiked: clearLastLiked ? null : (lastLiked ?? this.lastLiked),
      );

  Map<String, dynamic> toMap() => {
        'seen': seen,
        'liked': liked,
        'reflected': reflected,
        'lastLiked': lastLiked,
      };

  factory CategoryStats.fromMap(Map map) => CategoryStats(
        seen: (map['seen'] as int?) ?? 0,
        liked: (map['liked'] as int?) ?? 0,
        reflected: (map['reflected'] as int?) ?? 0,
        lastLiked: map['lastLiked'] as String?,
      );

  @override
  String toString() =>
      'CategoryStats(seen=$seen, liked=$liked, reflected=$reflected, lastLiked=$lastLiked)';
}

/// Service that persists per-category engagement stats and exposes
/// weighted sampling weights for deck ordering.
class CategoryStatsService {
  static const String _boxPrefix = 'categoryStats';

  Box? _box;

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  Future<void> init(String userId) async {
    final boxName = '${_boxPrefix}_$userId';
    if (!Hive.isBoxOpen(boxName)) {
      _box = await Hive.openBox(boxName);
    } else {
      _box = Hive.box(boxName);
    }
  }

  Future<void> close() async {
    if (_box != null && _box!.isOpen) {
      await _box!.close();
      _box = null;
    }
  }

  // ── Read / write helpers ────────────────────────────────────────────────────

  CategoryStats _get(String category) {
    if (_box == null || !_box!.isOpen) return const CategoryStats();
    final raw = _box!.get(category);
    if (raw == null) return const CategoryStats();
    return CategoryStats.fromMap(raw as Map);
  }

  Future<void> _put(String category, CategoryStats stats) async {
    if (_box == null || !_box!.isOpen) return;
    await _box!.put(category, stats.toMap());
  }

  // ── Public recording methods ────────────────────────────────────────────────

  Future<void> recordSwipe(String category) async {
    final s = _get(category);
    await _put(category, s.copyWith(seen: s.seen + 1));
  }

  Future<void> recordLike(String category) async {
    final today = _todayString();
    final s = _get(category);
    await _put(category, s.copyWith(
      liked: s.liked + 1,
      lastLiked: today,
    ));
  }

  Future<void> recordUnlike(String category) async {
    final s = _get(category);
    if (s.liked > 0) {
      await _put(category, s.copyWith(liked: s.liked - 1));
    }
  }

  Future<void> recordReflection(String category) async {
    final s = _get(category);
    await _put(category, s.copyWith(reflected: s.reflected + 1));
  }

  // ── Weight computation ──────────────────────────────────────────────────────

  /// Returns a normalised weight map for [activeCategories].
  ///
  /// Score for each category:
  ///   bayesian_like_rate  = (liked + 1) / (seen + 2)
  ///   recency_boost       = 1.5 if liked in last 7 days, 1.2 in last 30, 1.0 otherwise
  ///   reflection_mult     = 1.3 if any reflections, 1.0 otherwise
  ///   raw_score           = like_rate × recency_boost × reflection_mult
  ///
  /// Diversity floor: each category gets at least min(15%, 1/n) of the weight.
  Map<String, double> getWeights(List<String> activeCategories) {
    if (activeCategories.isEmpty) return {};

    final n = activeCategories.length;
    final scores = <String, double>{};

    for (final cat in activeCategories) {
      final s = _get(cat);

      // Bayesian-smoothed like rate
      final likeRate = (s.liked + 1) / (s.seen + 2);

      // Recency boost
      double recencyBoost = 1.0;
      if (s.lastLiked != null) {
        try {
          final lastDate = DateTime.parse(s.lastLiked!);
          final daysAgo = DateTime.now().difference(lastDate).inDays;
          if (daysAgo <= 7) {
            recencyBoost = 1.5;
          } else if (daysAgo <= 30) {
            recencyBoost = 1.2;
          }
        } catch (_) {
          // Malformed date — ignore
        }
      }

      // Reflection multiplier
      final reflectionMult = s.reflected > 0 ? 1.3 : 1.0;

      scores[cat] = likeRate * recencyBoost * reflectionMult;
    }

    // Normalise raw scores to initial weights
    final total = scores.values.fold(0.0, (a, b) => a + b);
    if (total <= 0) {
      // No data yet — return uniform weights
      return {for (final c in activeCategories) c: 1.0 / n};
    }

    final weights = <String, double>{
      for (final entry in scores.entries) entry.key: entry.value / total,
    };

    // Apply diversity floor
    // Each category gets at least min(0.15, 1/n) so no category is totally starved.
    final minShare = min(0.15, 1.0 / n);
    double deficit = 0.0;
    final aboveFloor = <String>[];

    for (final cat in activeCategories) {
      if (weights[cat]! < minShare) {
        deficit += minShare - weights[cat]!;
        weights[cat] = minShare;
      } else {
        aboveFloor.add(cat);
      }
    }

    // Redistribute deficit from categories that are above the floor
    if (deficit > 0 && aboveFloor.isNotEmpty) {
      final aboveTotal = aboveFloor.fold(0.0, (s, c) => s + weights[c]!);
      for (final cat in aboveFloor) {
        weights[cat] = weights[cat]! -
            deficit * (weights[cat]! / aboveTotal);
      }
    }

    return weights;
  }

  // ── Weighted interleaving ───────────────────────────────────────────────────

  /// Interleaves cards from [buckets] according to [weights].
  ///
  /// Cards within each category are shuffled first, then the interleaved
  /// deck is built by weighted random selection without replacement so that
  /// higher-weight categories appear proportionally more often throughout
  /// the session rather than being front-loaded.
  static List<T> weightedInterleave<T>({
    required Map<String, List<T>> buckets,
    required Map<String, double> weights,
    Random? rng,
  }) {
    final random = rng ?? Random();

    // Shuffle within each bucket
    final remaining = <String, List<T>>{};
    for (final entry in buckets.entries) {
      remaining[entry.key] = List<T>.from(entry.value)..shuffle(random);
    }

    final result = <T>[];

    while (remaining.isNotEmpty) {
      final totalWeight = remaining.keys
          .fold(0.0, (sum, cat) => sum + (weights[cat] ?? 0.0));

      if (totalWeight <= 0) {
        // Fallback: just append in any order
        for (final list in remaining.values) {
          result.addAll(list);
        }
        break;
      }

      final pick = random.nextDouble() * totalWeight;
      double cumulative = 0.0;
      String? chosen;
      for (final cat in remaining.keys) {
        cumulative += weights[cat] ?? 0.0;
        if (pick < cumulative) {
          chosen = cat;
          break;
        }
      }
      chosen ??= remaining.keys.last;

      final list = remaining[chosen]!;
      result.add(list.removeAt(0));
      if (list.isEmpty) remaining.remove(chosen);
    }

    return result;
  }

  // ── Utility ─────────────────────────────────────────────────────────────────

  static String _todayString() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}
