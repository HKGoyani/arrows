import 'dart:io';
import "dart:ui";
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'prefs.dart';

/// Centralized ad management: rewarded, interstitial, banner, app-open.
/// Uses test ad unit IDs — replace with production IDs before release.
class AdService {
  static bool _initialized = false;
  static int _winCount = 0;
  static bool _isPlaying = false;

  // ── Test Ad Unit IDs ──
  static String get _rewardedId => Platform.isIOS
      ? 'ca-app-pub-3940256099942544/1712485313'
      : 'ca-app-pub-3940256099942544/5224354917';

  static String get _interstitialId => Platform.isIOS
      ? 'ca-app-pub-3940256099942544/4411468910'
      : 'ca-app-pub-3940256099942544/1033173712';

  static String get _bannerId => Platform.isIOS
      ? 'ca-app-pub-3940256099942544/2934735716'
      : 'ca-app-pub-3940256099942544/6300978111';

  static String get _appOpenId => Platform.isIOS
      ? 'ca-app-pub-3940256099942544/5575463023'
      : 'ca-app-pub-3940256099942544/9257395921';

  // ── Preloaded ads ──
  static RewardedAd? _rewardedAd;
  static RewardedAd? _rewardedBackup;
  static InterstitialAd? _interstitialAd;
  static AppOpenAd? _appOpenAd;

  /// Call once at app startup. Preloads all ad formats immediately.
  static Future<void> init() async {
    if (_initialized) return;
    await MobileAds.instance.initialize();
    _initialized = true;
    // Preload all formats in parallel for fastest availability
    _loadRewarded();
    _loadInterstitial();
    _loadAppOpen();
    // Preload a second rewarded ad so one is always ready
    _loadRewardedBackup();
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
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _loadRewarded();
        _loadRewardedBackup();
      },
      onAdFailedToShowFullScreenContent: (a, error) {
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

  /// Call after a level win. Shows interstitial every 3rd win.
  static void onLevelWin() {
    if (_adsRemoved) return;
    _winCount++;
    if (_winCount >= 3) {
      _winCount = 0;
      _showInterstitial();
    }
  }

  /// Call on restart. Shows interstitial if loaded, then calls [onDone].
  /// If ad not loaded or ads removed, calls [onDone] immediately.
  static void onRestart({VoidCallback? onDone}) {
    if (_adsRemoved || _interstitialAd == null) {
      _loadInterstitial();
      onDone?.call();
      return;
    }
    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitial();
        onDone?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitial();
        onDone?.call();
      },
    );
    _interstitialAd!.show();
  }

  /// Call after daily challenge completion.
  static void onDailyComplete() {
    if (_adsRemoved) return;
    _showInterstitial();
  }

  /// Shows interstitial if loaded. Never blocks — if not loaded, skips
  /// silently and preloads for next time.
  static void _showInterstitial() {
    if (_interstitialAd == null) {
      _loadInterstitial();
      return; // not loaded — skip, don't block user
    }
    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitial();
      },
    );
    _interstitialAd!.show();
  }

  // ═══════════════════════════════════════════════════════════════════
  // SMART BANNER — bottom of Home, Collection, Settings, Challenge
  // ═══════════════════════════════════════════════════════════════════

  /// Creates a banner ad widget. Caller manages the lifecycle.
  static BannerAd? createBanner() {
    if (_adsRemoved) return null;
    return BannerAd(
      adUnitId: _bannerId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
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

  /// Call on app resume / cold start. Skipped if user is actively playing.
  static void showAppOpenIfReady() {
    if (_adsRemoved || _isPlaying) return;
    if (_appOpenAd == null) {
      _loadAppOpen(); // not ready — reload for next opportunity
      return;
    }
    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
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
