import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  // ==========================================
  // Global Ad Settings
  // ==========================================

  // Set this to 'false' if you want to turn off ALL ads globally (e.g., for premium users)
  static bool adsEnabled = true;
  static bool isAdShowing = false;

  // Set this to 'true' to show verbose console debug logs
  static const bool _debugLogEnabled = true;

  // Minimum cooldown period between showing consecutive Interstitial ads to prevent invalid traffic
  // Recommended: 2-3 minutes (180 seconds)
  static const Duration interstitialCooldown = Duration(minutes: 3);
  static DateTime? _lastInterstitialShowTime;

  // ==========================================
  // Centralized Ad Unit IDs Configuration
  // ==========================================

  // Official Test Ad Unit IDs provided by Google AdMob
  static const String _testAndroidBannerId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _testAndroidInterstitialId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _testAndroidRewardedId =
      'ca-app-pub-3940256099942544/5224354917';

  static const String _testIosBannerId =
      'ca-app-pub-3940256099942544/2934735716';
  static const String _testIosInterstitialId =
      'ca-app-pub-3940256099942544/4411468910';
  static const String _testIosRewardedId =
      'ca-app-pub-3940256099942544/1712485313';

  // REPLACE THESE STRING CONSTANTS WITH YOUR REAL PRODUCTION AD UNIT IDS LATER
  static const String _prodAndroidBannerId =
      'ca-app-pub-9816661566128786/1079689083';
  static const String _prodAndroidInterstitialId =
      'ca-app-pub-9816661566128786/3753953881';
  static const String _prodAndroidRewardedId =
      'ca-app-pub-9816661566128786/3791128275';
  // Note: iOS production is not live yet. Using official iOS test IDs to prevent errors.
  static const String _prodIosBannerId =
      'ca-app-pub-3940256099942544/2934735716';
  static const String _prodIosInterstitialId =
      'ca-app-pub-3940256099942544/4411468910';
  static const String _prodIosRewardedId =
      'ca-app-pub-3940256099942544/1712485313';

  // Getter to automatically resolve target banner ID based on Platform & Mode
  static String get bannerAdUnitId {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return '';
    if (kReleaseMode) {
      return Platform.isAndroid ? _prodAndroidBannerId : _prodIosBannerId;
    }
    return Platform.isAndroid ? _testAndroidBannerId : _testIosBannerId;
  }

  // Getter to automatically resolve target interstitial ID based on Platform & Mode
  static String get interstitialAdUnitId {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return '';
    if (kReleaseMode) {
      return Platform.isAndroid
          ? _prodAndroidInterstitialId
          : _prodIosInterstitialId;
    }
    return Platform.isAndroid
        ? _testAndroidInterstitialId
        : _testIosInterstitialId;
  }

  // Getter to automatically resolve target rewarded ID based on Platform & Mode
  static String get rewardedAdUnitId {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return '';
    if (kReleaseMode) {
      return Platform.isAndroid ? _prodAndroidRewardedId : _prodIosRewardedId;
    }
    return Platform.isAndroid ? _testAndroidRewardedId : _testIosRewardedId;
  }

  // ==========================================
  // Preloaded Caching Handles
  // ==========================================
  static InterstitialAd? _preloadedInterstitialAd;
  static bool _isPreloadingInterstitial = false;

  static RewardedAd? _preloadedRewardedAd;
  static bool _isPreloadingRewarded = false;

  // ==========================================
  // Lifecycle Initialization
  // ==========================================

  /// Initializes the Google Mobile Ads SDK safely in the background
  static Future<void> initialize() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      adsEnabled = false;
      _log("AdMob is not supported on this platform. Disabling ads.");
      return;
    }

    if (!adsEnabled) {
      _log("AdMob is globally disabled. Skipping SDK initialization.");
      return;
    }
    try {
      _log("Initializing AdMob SDK...");
      await MobileAds.instance.initialize();

      // Register developer test device IDs so Google AdMob serves test ads to physical devices
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          testDeviceIds: <String>[
            "3AADB797CBEF6C8C20BFB19C192F2639", // Your physical Realme device
          ],
        ),
      );

      _log("AdMob SDK Initialized Successfully!");

      // Warm up / Pre-cache Interstitial and Rewarded ads so they are ready instantly
      preloadInterstitial();
      preloadRewarded();
    } catch (e) {
      _log("CRITICAL: Failed to initialize AdMob SDK: $e");
    }
  }

  // ==========================================
  // Interstitial Ad Management
  // ==========================================

  /// Preloads an Interstitial Ad and stores it in cache
  static void preloadInterstitial() {
    if (!adsEnabled ||
        _preloadedInterstitialAd != null ||
        _isPreloadingInterstitial)
      return;

    _isPreloadingInterstitial = true;
    _log("Preloading Interstitial Ad in background...");

    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _preloadedInterstitialAd = ad;
          _isPreloadingInterstitial = false;
          _log("Interstitial Ad loaded and cached successfully.");

          // Set up content callbacks for reload logic on dismiss/failure
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              _log("Interstitial Ad dismissed by user.");
              ad.dispose();
              _preloadedInterstitialAd = null;
              preloadInterstitial(); // Immediately preload next ad
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              _log("Interstitial Ad failed to show: $error");
              ad.dispose();
              _preloadedInterstitialAd = null;
              preloadInterstitial(); // Try preloading next ad
            },
          );
        },
        onAdFailedToLoad: (error) {
          _isPreloadingInterstitial = false;
          _preloadedInterstitialAd = null;
          _log("Failed to preload Interstitial Ad: $error. Hint: If debugging on a physical device, ensure its AdMob Test Device ID is added to testDeviceIds in AdService.initialize(). Check logs for 'setTestDeviceIds'.");
        },
      ),
    );
  }

  /// Displays the preloaded Interstitial Ad with built-in cooldown protection and auto-reload callback
  static void showInterstitial(VoidCallback onAdClosed) {
    if (!adsEnabled) {
      _log("Ads are disabled. Bypassing show Interstitial.");
      onAdClosed();
      return;
    }

    // 1. Policy Protection: check cooldown to prevent aggressive popups (Invalid Traffic protection)
    final now = DateTime.now();
    if (_lastInterstitialShowTime != null &&
        now.difference(_lastInterstitialShowTime!) < interstitialCooldown) {
      _log(
        "Cooldown active. Skipping Interstitial to protect user experience.",
      );
      onAdClosed();
      return;
    }

    // 2. Validate cache
    final ad = _preloadedInterstitialAd;
    if (ad == null) {
      _log("No preloaded Interstitial Ad ready. Bypassing.");
      preloadInterstitial(); // Trigger load in background
      onAdClosed();
      return;
    }

    // Update timestamps and show
    _lastInterstitialShowTime = now;
    _log("Showing Interstitial Ad...");
    isAdShowing = true;

    // Intercept callback to trigger onAdClosed
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        _log("Interstitial dismissed. Running navigation callbacks.");
        isAdShowing = false;
        ad.dispose();
        _preloadedInterstitialAd = null;
        preloadInterstitial(); // Auto preload next
        onAdClosed();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _log("Interstitial failed to show. Running navigation callbacks.");
        isAdShowing = false;
        ad.dispose();
        _preloadedInterstitialAd = null;
        preloadInterstitial(); // Auto preload next
        onAdClosed();
      },
    );

    ad.show();
  }

  // ==========================================
  // Rewarded Ad Management
  // ==========================================

  /// Preloads a Rewarded Ad and stores it in cache
  static void preloadRewarded() {
    if (!adsEnabled || _preloadedRewardedAd != null || _isPreloadingRewarded)
      return;

    _isPreloadingRewarded = true;
    _log("Preloading Rewarded Ad in background...");

    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _preloadedRewardedAd = ad;
          _isPreloadingRewarded = false;
          _log("Rewarded Ad loaded and cached successfully.");

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              _log("Rewarded Ad dismissed by user.");
              ad.dispose();
              _preloadedRewardedAd = null;
              preloadRewarded(); // Immediately preload next ad
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              _log("Rewarded Ad failed to show: $error");
              ad.dispose();
              _preloadedRewardedAd = null;
              preloadRewarded(); // Try preloading next ad
            },
          );
        },
        onAdFailedToLoad: (error) {
          _isPreloadingRewarded = false;
          _preloadedRewardedAd = null;
          _log("Failed to preload Rewarded Ad: $error. Hint: If debugging on a physical device, ensure its AdMob Test Device ID is added to testDeviceIds in AdService.initialize(). Check logs for 'setTestDeviceIds'.");
        },
      ),
    );
  }

  /// Displays the preloaded Rewarded Ad, triggers reward logic if watched, and auto-reloads
  static void showRewarded({
    required VoidCallback onRewardEarned,
    required VoidCallback onAdClosed,
    required VoidCallback onAdFailed,
  }) {
    if (!adsEnabled) {
      _log("Ads are disabled. Rewarding user automatically.");
      onRewardEarned();
      return;
    }

    final ad = _preloadedRewardedAd;
    if (ad == null) {
      _log("No preloaded Rewarded Ad ready. Triggering dynamic fetch...");
      onAdFailed();
      preloadRewarded(); // Trigger preload
      return;
    }

    isAdShowing = true;
    bool earnedReward = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        _log("Rewarded dismissed.");
        isAdShowing = false;
        ad.dispose();
        _preloadedRewardedAd = null;
        preloadRewarded(); // Auto preload next

        if (earnedReward) {
          onRewardEarned();
        } else {
          onAdClosed();
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _log("Rewarded failed to show: $error");
        isAdShowing = false;
        ad.dispose();
        _preloadedRewardedAd = null;
        preloadRewarded(); // Auto preload next
        onAdFailed();
      },
    );

    ad.show(
      onUserEarnedReward: (adWithoutReward, reward) {
        _log(
          "User successfully earned reward: ${reward.amount} ${reward.type}",
        );
        earnedReward = true;
      },
    );
  }

  // ==========================================
  // Helper / Logging utilities
  // ==========================================
  static void _log(String msg) {
    if (_debugLogEnabled) {
      debugPrint("[AdService] $msg");
    }
  }
}
