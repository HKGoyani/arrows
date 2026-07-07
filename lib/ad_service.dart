import 'dart:async';
import 'dart:io';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'analytics_service.dart';
import 'prefs.dart';

/// Centralized ad management: rewarded, interstitial, banner, app-open.
/// Uses test ad unit IDs — replace with production IDs before release.
class AdService {
  static bool _initialized = false;
  static int _winCount = 0;
  static bool _isPlaying = false;

  // Tracks whether ANY full-screen ad (rewarded/interstitial/app-open) is
  // currently up, plus a brief cooldown after one closes. Dismissing a
  // full-screen ad fires AppLifecycleState.resumed (the ad's view controller
  // tears down), which would otherwise immediately trigger an App Open ad
  // stacked right on top of the one that just closed.
  static bool _showingFullScreenAd = false;
  static DateTime? _lastFullScreenAdClosedAt;
  static bool get _inFullScreenAdCooldown {
    final t = _lastFullScreenAdClosedAt;
    return t != null && DateTime.now().difference(t) < const Duration(seconds: 1);
  }

  // AdMob policy: ads must not be shown excessively frequently. These track
  // the last time each full-screen format was actually displayed, so rapid
  // repeated triggers (e.g. quick app-switching, repeated restarts) can't
  // stack ad impressions back-to-back.
  static DateTime? _lastAppOpenShownAt;
  static DateTime? _lastInterstitialShownAt;
  static const _appOpenMinGap = Duration(minutes: 1);
  static const _interstitialMinGap = Duration(seconds: 45);

  // ── Ad Unit IDs ── iOS: production (Arrows – Escape Puzzle). Android: test
  // IDs until a separate Android AdMob app/ad units are created.
  static String get _rewardedId => Platform.isIOS
      ? 'ca-app-pub-4818503743858431/1504787383'
      : 'ca-app-pub-3940256099942544/5224354917';

  static String get _interstitialId => Platform.isIOS
      ? 'ca-app-pub-4818503743858431/7988636380'
      : 'ca-app-pub-3940256099942544/1033173712';

  static String get _bannerId => Platform.isIOS
      ? 'ca-app-pub-4818503743858431/1614799726'
      : 'ca-app-pub-3940256099942544/6300978111';

  static String get _appOpenId => Platform.isIOS
      ? 'ca-app-pub-4818503743858431/3939379036'
      : 'ca-app-pub-3940256099942544/9257395921';

  // ── Preloaded ads ──
  static RewardedAd? _rewardedAd;
  static RewardedAd? _rewardedBackup;
  static InterstitialAd? _interstitialAd;
  static AppOpenAd? _appOpenAd;

  /// Call once at app startup. Requests Apple's ATT permission first (iOS),
  /// then Google's GDPR/UMP consent (required by Google's EU User Consent
  /// Policy for EEA/UK users, and recommended for US state privacy laws)
  /// before any ad is loaded, then preloads all ad formats. ATT must run
  /// first so the UMP form reflects the user's actual tracking choice
  /// instead of asking to track again after they already said no.
  static Future<void> init() async {
    if (_initialized) return;
    await _requestTrackingAuthorization();
    await _requestConsent();
    await MobileAds.instance.initialize();
    _initialized = true;
    // Preload all formats in parallel for fastest availability
    _loadRewarded();
    _loadInterstitial();
    _loadAppOpen();
    // Preload a second rewarded ad so one is always ready
    _loadRewardedBackup();
  }

  /// Runs Google's User Messaging Platform consent flow. Shows a consent
  /// form only where legally required (EEA/UK/applicable US states) —
  /// no-op elsewhere. Ad loading waits for this to complete so no ad
  /// request fires before consent is resolved.
  static Future<void> _requestConsent() async {
    final completer = Completer<void>();
    final params = ConsentRequestParameters();
    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        try {
          if (await ConsentInformation.instance.isConsentFormAvailable()) {
            await _loadAndShowConsentFormIfRequired();
          }
        } catch (_) {
          // consent flow is non-critical — never block app startup
        } finally {
          if (!completer.isCompleted) completer.complete();
        }
      },
      (error) {
        // Consent info update failed — proceed without blocking (e.g. no
        // network). Ads will load in non-personalized mode wherever consent
        // is legally required and not obtained.
        if (!completer.isCompleted) completer.complete();
      },
    );
    // Safety timeout — never let a stalled consent flow block the app.
    await completer.future.timeout(const Duration(seconds: 8), onTimeout: () {});
  }

  static Future<void> _loadAndShowConsentFormIfRequired() {
    final completer = Completer<void>();
    ConsentForm.loadAndShowConsentFormIfRequired((formError) {
      // Called whether or not a form was actually shown.
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }

  /// Shows Apple's native App Tracking Transparency system prompt
  /// (iOS only — the NSUserTrackingUsageDescription dialog). Required
  /// before AdMob can use IDFA for personalized ads on iOS 14.5+.
  /// If denied or restricted, ads still load — just non-personalized.
  static Future<void> _requestTrackingAuthorization() async {
    if (!Platform.isIOS) return;
    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        // Small delay recommended by Apple/Google so the prompt doesn't
        // race with the app's own UI appearing on screen.
        await Future.delayed(const Duration(milliseconds: 300));
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
    } catch (_) {
      // Tracking authorization is non-critical — never block app startup.
    }
  }

  /// Set true when entering GameScreen, false when leaving.
  static void setPlaying(bool playing) => _isPlaying = playing;

  /// Whether ads are removed (rewarded ads still show — user opts in).
  static bool get _adsRemoved => Prefs.removeAds;

  // ═══════════════════════════════════════════════════════════════════
  // REWARDED AD (hints + extra life) — always available, even with Remove Ads
  // ═══════════════════════════════════════════════════════════════════

  static void _loadRewarded() {
    RewardedAd.load(
      adUnitId: _rewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewardedAd = ad,
        onAdFailedToLoad: (error) => _rewardedAd = null,
      ),
    );
  }

  static void _loadRewardedBackup() {
    RewardedAd.load(
      adUnitId: _rewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewardedBackup = ad,
        onAdFailedToLoad: (error) => _rewardedBackup = null,
      ),
    );
  }

  /// True if a rewarded ad is ready to show.
  static bool get rewardedReady => _rewardedAd != null || _rewardedBackup != null;

  /// Shows a rewarded ad. Calls [onRewarded] when the user earns the reward.
  /// Falls back to backup ad if primary isn't ready.
  static void showRewarded({required void Function() onRewarded}) {
    // Use primary, fall back to backup
    final ad = _rewardedAd ?? _rewardedBackup;
    if (ad == null) {
      _loadRewarded();
      _loadRewardedBackup();
      onRewarded(); // no ad available — give reward anyway (don't block user)
      return;
    }
    if (ad == _rewardedAd) {
      _rewardedAd = null;
    } else {
      _rewardedBackup = null;
    }
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (a) {
        _showingFullScreenAd = true;
        AnalyticsService.adShown('rewarded');
      },
      onAdDismissedFullScreenContent: (a) {
        _showingFullScreenAd = false;
        _lastFullScreenAdClosedAt = DateTime.now();
        a.dispose();
        _loadRewarded();
        _loadRewardedBackup();
      },
      onAdFailedToShowFullScreenContent: (a, error) {
        _showingFullScreenAd = false;
        a.dispose();
        _loadRewarded();
        _loadRewardedBackup();
        onRewarded(); // ad failed — give reward anyway
      },
    );
    ad.show(onUserEarnedReward: (_, __) => onRewarded());
  }

  // ═══════════════════════════════════════════════════════════════════
  // INTERSTITIAL AD — after every 3rd win, restart, daily complete
  // ═══════════════════════════════════════════════════════════════════

  static void _loadInterstitial() {
    if (_adsRemoved) return;
    InterstitialAd.load(
      adUnitId: _interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (error) => _interstitialAd = null,
      ),
    );
  }

  /// Call after a level win. Shows an interstitial every 3rd win, then calls
  /// [onDone] once the ad is dismissed. If no ad shows (not the 3rd win, ads
  /// removed, not loaded, or shown too recently) [onDone] fires immediately.
  /// [onDone] always runs exactly once — callers sequence the streak/rate
  /// celebration off it so nothing stacks on top of the ad.
  static void onLevelWin({void Function(bool adShown)? onDone}) {
    if (_adsRemoved) {
      onDone?.call(false);
      return;
    }
    _winCount++;
    if (_winCount >= 3) {
      _winCount = 0;
      _showInterstitial(onDone: onDone);
    } else {
      onDone?.call(false);
    }
  }

  static bool get _interstitialGapOk {
    final t = _lastInterstitialShownAt;
    return t == null || DateTime.now().difference(t) >= _interstitialMinGap;
  }

  /// Call on restart. Shows interstitial if loaded, then calls [onDone].
  /// If ad not loaded, ads removed, or shown too recently, calls [onDone]
  /// immediately — interstitials must not stack back-to-back on rapid
  /// repeated restarts.
  static void onRestart({VoidCallback? onDone}) {
    if (_adsRemoved || _interstitialAd == null || !_interstitialGapOk) {
      _loadInterstitial();
      onDone?.call();
      return;
    }
    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _showingFullScreenAd = true;
        _lastInterstitialShownAt = DateTime.now();
        AnalyticsService.adShown('interstitial');
      },
      onAdDismissedFullScreenContent: (ad) {
        _showingFullScreenAd = false;
        _lastFullScreenAdClosedAt = DateTime.now();
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitial();
        onDone?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _showingFullScreenAd = false;
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitial();
        onDone?.call();
      },
    );
    _interstitialAd!.show();
  }

  /// Call after daily challenge completion. Calls [onDone] after the ad is
  /// dismissed (or immediately if none shows).
  static void onDailyComplete({void Function(bool adShown)? onDone}) {
    if (_adsRemoved) {
      onDone?.call(false);
      return;
    }
    _showInterstitial(onDone: onDone);
  }

  /// Shows interstitial if loaded, then calls [onDone] when it's dismissed —
  /// with `true` if an ad actually displayed, `false` otherwise. Never blocks:
  /// if not loaded or shown too recently, skips silently, preloads for next
  /// time, and calls `onDone(false)` immediately. [onDone] runs exactly once.
  static void _showInterstitial({void Function(bool adShown)? onDone}) {
    if (_interstitialAd == null) {
      _loadInterstitial();
      onDone?.call(false); // not loaded — skip, don't block user
      return;
    }
    if (!_interstitialGapOk) {
      onDone?.call(false); // shown too recently — avoid stacking
      return;
    }
    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _showingFullScreenAd = true;
        _lastInterstitialShownAt = DateTime.now();
        AnalyticsService.adShown('interstitial');
      },
      onAdDismissedFullScreenContent: (ad) {
        _showingFullScreenAd = false;
        _lastFullScreenAdClosedAt = DateTime.now();
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitial();
        onDone?.call(true);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _showingFullScreenAd = false;
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitial();
        onDone?.call(false);
      },
    );
    _interstitialAd!.show();
  }

  // ═══════════════════════════════════════════════════════════════════
  // BANNER — collapsible on Home, normal elsewhere (Challenge, Collection,
  // Settings, gameplay)
  // ═══════════════════════════════════════════════════════════════════

  /// Creates a banner ad widget. Caller manages the lifecycle.
  /// [collapsible] requests AdMob's collapsible banner format, anchored to
  /// the bottom of the screen — used on Home; other placements use a
  /// regular fixed banner.
  static BannerAd? createBanner({bool collapsible = false}) {
    if (_adsRemoved) return null;
    return BannerAd(
      adUnitId: _bannerId,
      size: AdSize.banner,
      request: collapsible
          ? const AdRequest(extras: {'collapsible': 'bottom'})
          : const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) => AnalyticsService.adShown('banner'),
        onAdFailedToLoad: (ad, error) => ad.dispose(),
      ),
    )..load();
  }

  // ═══════════════════════════════════════════════════════════════════
  // APP OPEN AD — on resume / cold start (not during gameplay)
  // ═══════════════════════════════════════════════════════════════════

  static bool _coldStartShown = false;

  static void _loadAppOpen() {
    if (_adsRemoved) return;
    AppOpenAd.load(
      adUnitId: _appOpenId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd = ad;
          // Show immediately on cold start once the first load completes —
          // init() fires this load but nothing else triggers a show at
          // launch, only app-resume does.
          if (!_coldStartShown) {
            _coldStartShown = true;
            showAppOpenIfReady();
          }
        },
        onAdFailedToLoad: (error) => _appOpenAd = null,
      ),
    );
  }

  /// Call on app resume / cold start. Skipped if user is actively playing,
  /// or if a rewarded/interstitial ad is currently showing or just closed
  /// (its dismissal triggers the same resume event this responds to).
  static void showAppOpenIfReady() {
    if (_adsRemoved || _isPlaying) return;
    if (_showingFullScreenAd || _inFullScreenAdCooldown) return;
    final lastShown = _lastAppOpenShownAt;
    if (lastShown != null && DateTime.now().difference(lastShown) < _appOpenMinGap) {
      return; // shown too recently — avoid stacking ads on rapid app-switching
    }
    if (_appOpenAd == null) {
      _loadAppOpen(); // not ready — reload for next opportunity
      return;
    }
    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _lastAppOpenShownAt = DateTime.now();
        AnalyticsService.adShown('app_open');
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _appOpenAd = null;
        _loadAppOpen();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _appOpenAd = null;
        _loadAppOpen();
      },
    );
    _appOpenAd!.show();
  }
}
