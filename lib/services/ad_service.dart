import 'dart:io' show Platform;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;

class AdService {
  // Show an interstitial every N swipes
  static const int frequency = 12;
  static int _swipesSinceAd = 0;

  static InterstitialAd? _interstitial;
  static bool _loading = false;

  static String get _androidInterstitialUnitId => kReleaseMode
      ? 'ca-app-pub-2028088731421171/6845706769'  
      : 'ca-app-pub-3940256099942544/1033173712'; // Google TEST interstitial unit ID

  static Future<void> preload() async {
    if (!Platform.isAndroid || _interstitial != null || _loading) return;
    _loading = true;

    await InterstitialAd.load(
      // Google TEST interstitial unit. Replace with your real one later.
      adUnitId: _androidInterstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitial = ad;
          _loading = false;
          _attachCallbacks(ad);
        },
        onAdFailedToLoad: (err) {
          _loading = false;
          _interstitial = null;
          // Optionally retry later
        },
      ),
    );
  }

  static void _attachCallbacks(InterstitialAd ad) {
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitial = null;
        preload(); // prime the next one
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitial = null;
        preload();
      },
    );
  }

  static Future<void> onSwipeAndMaybeShow(BuildContext context) async {
    if (!Platform.isAndroid) return;

    _swipesSinceAd++;
    // Not time yet → keep preloading
    if (_swipesSinceAd % frequency != 0) {
      if (_interstitial == null) preload();
      return;
    }

    if (_interstitial != null) {
      // Show and let callbacks handle reloading
      _interstitial!.show();
      _interstitial = null;
    } else {
      // Not ready; try to load for next time
      preload();
    }
  }

  static void resetCounter() {
    _swipesSinceAd = 0;
  }
}