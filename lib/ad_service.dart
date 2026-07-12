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

  // ── Ad Unit IDs ── production for both platforms (Arrows – Escape Puzzle).
  // iOS AdMob app ca-app-pub-4818503743858431~5166233161; Android AdMob app
  // ca-app-pub-4818503743858431~7394089061.
  static String get _rewardedId => Platform.isIOS
      ? 'ca-app-pub-4818503743858431/1504787383'
      : 'ca-app-pub-4818503743858431/8458959963';

  static String get _interstitialId => Platform.isIOS
      ? 'ca-app-pub-4818503743858431/7988636380'
      : 'ca-app-pub-4818503743858431/9963613329';

  static String get _bannerId => Platform.isIOS
      ? 'ca-app-pub-4818503743858431/1614799726'
      : 'ca-app-pub-4818503743858431/6704813607';

  static String get _appOpenId => Platform.isIOS
      ? 'ca-app-pub-4818503743858431/3939379036'
      : 'ca-app-pub-4818503743858431/1075293965';

  // ── Preloaded ads ──
  static RewardedAd? _rewardedAd;
  static RewardedAd? _rewardedBackup;
  static InterstitialAd? _interstitialAd;
  static AppOpenAd? _appOpenAd;

  /// Call once at app startup. Runs Google's GDPR/UMP consent flow FIRST and
  /// waits for it to fully finish, THEN requests Apple's ATT permission, then
  /// preloads all ad formats. Order matters for App Review (Guideline
  /// 5.1.1(iv)): the ATT prompt must be the LAST tracking-related ask, so the
  /// user is never shown a consent prompt about personalized ads *after* they
  /// tapped "Ask App Not to Track". The consent step below is fully awaited
  /// (form display is never time-boxed) so it can't leak past ATT.
  static Future<void> init() async {
    if (_initialized) return;
    await _requestConsent();
    await _requestTrackingAuthorization();
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
  /// no-op elsewhere.
  ///
  /// Split into two awaited steps so the ordering guarantee holds (see
  /// [init]): the 8s safety timeout guards ONLY the network info-update call
  /// (which can stall with no connectivity); the consent form itself is then
  /// awaited with NO timeout, so this method never returns while the form is
  /// still on screen. That is what keeps the ATT prompt strictly after the
  /// consent prompt and fixes the original race (form leaking past ATT).
  static Future<void> _requestConsent() async {
    final params = ConsentRequestParameters();
    // Step 1 — fetch consent info (network round-trip). Time-boxed.
    final infoCompleter = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () {
        if (!infoCompleter.isCompleted) infoCompleter.complete();
      },
      (error) {
        // Info update failed (e.g. no network) — proceed without blocking.
        if (!infoCompleter.isCompleted) infoCompleter.complete();
      },
    );
    await infoCompleter.future
        .timeout(const Duration(seconds: 8), onTimeout: () {});

    // Step 2 — if a form is required, show it and WAIT for the user to
    // finish. No timeout: the form must fully resolve before ATT is shown.
    try {
      if (await ConsentInformation.instance.isConsentFormAvailable()) {
        await _loadAndShowConsentFormIfRequired();
      }
    } catch (_) {
      // consent flow is non-critical — never block app startup
    }
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

  /// Creates an Anchored Adaptive banner ad widget — spans the full device
  /// width and picks the best height for the device, per Google's Anchored
  /// Adaptive Banner format (replaces the old fixed 320x50 AdSize.banner).
  /// Caller manages the lifecycle. [collapsible] requests AdMob's collapsible
  /// banner format on top of that — used on Home; other placements (incl.
  /// gameplay) use a plain (non-collapsible) anchored adaptive banner.
  /// [width] is the available width in logical pixels (e.g. from
  /// MediaQuery), used to compute the adaptive size — required because this
  /// call is async and must resolve before the BannerAd is constructed.
  static Future<BannerAd?> createBanner({
    required int width,
    bool collapsible = false,
  }) async {
    if (_adsRemoved) return null;
    // Deliberately NOT getLargeAnchoredAdaptiveBannerAdSize — despite the
    // name, "Large" is Google's newer jumbo format and can return a banner
    // several times taller than a normal one (confirmed: it overflowed off
    // the bottom of the screen in testing). getCurrentOrientationAnchored...
    // is deprecated but still fully functional, and is the one that's
    // actually bounded (never > 15% of screen height, never < 50px) — the
    // correct compact anchored adaptive format for a bottom banner strip.
    // ignore: deprecated_member_use
    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
    if (size == null) return null;
    final completer = Completer<BannerAd?>();
    final ad = BannerAd(
      adUnitId: _bannerId,
      size: size,
      request: collapsible
          ? const AdRequest(extras: {'collapsible': 'bottom'})
          : const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          AnalyticsService.adShown('banner');
          if (!completer.isCompleted) completer.complete(ad as BannerAd);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!completer.isCompleted) completer.complete(null);
        },
      ),
    );
    ad.load();
    return completer.future;
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
          // launch, only app-resume does. EXCEPT on a brand-new user's very
          // first-ever launch — Google's App Open Ads guidance advises
          // against an ad being the first thing a new user sees, so that one
          // launch is skipped; every launch after it shows normally.
          if (!_coldStartShown) {
            _coldStartShown = true;
            if (Prefs.hasCompletedFirstSession) {
              showAppOpenIfReady();
            } else {
              Prefs.setHasCompletedFirstSession(true);
            }
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
