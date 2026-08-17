import 'dart:async';
import 'dart:io';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:gma_mediation_unity/gma_mediation_unity.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'analytics_service.dart';
import 'prefs.dart';

/// Why a rewarded ad could not be shown, so the UI can explain it rather
/// than silently handing out the reward.
enum RewardedUnavailable {
  /// The ad request failed with a network error — in practice, no connection.
  noInternet,

  /// No ad was available: no fill, load timed out, or it failed to display.
  notReady,
}

/// Which banner slot an ad is for. Determines both the ad unit and whether
/// the collapsible format is requested — the two always go together, so
/// callers pick a placement rather than setting them independently.
enum BannerPlacement {
  /// Under the bottom nav, shared across Home/Challenge/Collection/Settings.
  /// Collapsible.
  home,

  /// Gameplay screen. Never collapsible — it must not expand over the board.
  gameplay,
}

/// Which app-open slot an ad is for. Cold start and resume are separate
/// placements: they have very different user context (fresh launch vs
/// returning mid-session) and separate ad units.
enum AppOpenPlacement {
  /// First show after the app process starts.
  coldStart,

  /// Every subsequent foreground.
  resume,
}

/// Which rewarded slot an ad is for.
enum RewardedPlacement {
  /// "Watch for a hint", after the 5 free hints are used.
  hint,

  /// "Refill lives" on the lose overlay.
  extraLives,
}

/// Centralized ad management: rewarded, interstitial, banner, app-open.
/// AdMob mediation: Meta Audience Network + Unity Ads (see AdMob console
/// Mediation groups for waterfall/bidding config — not set in this code).
class AdService {
  static bool _initialized = false;
  static int _winCount = 0;
  static bool _isPlaying = false;

  /// Whether the UMP flow has cleared us to request ads.
  ///
  /// Google requires `canRequestAds()` to be checked before ANY ad request.
  /// Skipping it is what produced AdMob's "Consent requirement: No CMP"
  /// policy issue (2026-08-13): for users in the EEA/UK/Switzerland, ads were
  /// requested even when consent hadn't been gathered — because the form was
  /// declined, the info update failed, or no European regulations message was
  /// published for this app — so the requests carried no TC string.
  ///
  /// Fails CLOSED: if the check itself errors we serve nothing rather than
  /// risk another non-consented request.
  static bool _canRequestAds = false;
  static bool get canRequestAds => _canRequestAds;

  /// Whether UMP says this user must be offered a way to change their consent
  /// after the initial prompt — true for EEA/UK/Switzerland users who were
  /// shown a consent form. GDPR requires the choice to be revisitable, so
  /// Settings shows a "Privacy options" entry only when this is true (it
  /// stays false everywhere else, keeping Settings clean for most users).
  static bool _privacyOptionsRequired = false;
  static bool get privacyOptionsRequired => _privacyOptionsRequired;

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

  /// How long a rewarded ad may take to load on demand before we stop making
  /// the user wait and grant the reward anyway (see [showRewarded]).
  static const _rewardedLoadTimeout = Duration(seconds: 5);

  // ── Ad Unit IDs ── production for both platforms (Arrows – Escape Puzzle).
  // iOS AdMob app ca-app-pub-4818503743858431~5166233161; Android AdMob app
  // ca-app-pub-4818503743858431~7394089061.
  //
  // Debug builds use Google's official sample test ad unit IDs instead —
  // unlike a real ID requested from an auto-recognized test device (which
  // still runs through real inventory/fill logic and can genuinely no-fill,
  // as seen repeatedly during dev testing), these are hardcoded by Google to
  // always return a placeholder ad. Zero risk to the real ad units/account —
  // release builds are completely unaffected, still real IDs as before.
  //
  // Android release builds are back on production IDs as of 2026-07-14 —
  // the Play Store listing is live, so real end users must never be served
  // Google's sample test units (AdMob policy, and it also means $0 revenue).
  // Each PLACEMENT has its own ad unit (2026-08-14) rather than one unit per
  // format, so per-placement performance is visible in AdMob reporting.
  // Google's sample test IDs are per-FORMAT, so placements of the same format
  // share a test ID in debug — only the production IDs differ.

  /// Rewarded, "watch for a hint" (game screen).
  static String get _rewardedHintId {
    if (kDebugMode) return _testRewardedId;
    return Platform.isIOS
        ? 'ca-app-pub-4818503743858431/5160499311'
        : 'ca-app-pub-4818503743858431/9945922137';
  }

  /// Rewarded, "refill lives" (lose overlay).
  static String get _rewardedLivesId {
    if (kDebugMode) return _testRewardedId;
    return Platform.isIOS
        ? 'ca-app-pub-4818503743858431/1504787383'
        : 'ca-app-pub-4818503743858431/8458959963';
  }

  /// Interstitial after a level win, and after a daily challenge completes.
  static String get _interstitialWinId {
    if (kDebugMode) return _testInterstitialId;
    return Platform.isIOS
        ? 'ca-app-pub-4818503743858431/7988636380'
        : 'ca-app-pub-4818503743858431/9963613329';
  }

  /// Interstitial on level restart.
  static String get _interstitialRestartId {
    if (kDebugMode) return _testInterstitialId;
    return Platform.isIOS
        ? 'ca-app-pub-4818503743858431/4805225764'
        : 'ca-app-pub-4818503743858431/5268310525';
  }

  /// Banner under the bottom nav (Home, Challenge, Collection, Settings).
  static String get _bannerHomeId {
    if (kDebugMode) return _testBannerId;
    return Platform.isIOS
        ? 'ca-app-pub-4818503743858431/1614799726'
        : 'ca-app-pub-4818503743858431/6704813607';
  }

  /// Banner on the gameplay screen.
  static String get _bannerGameplayId {
    if (kDebugMode) return _testBannerId;
    return Platform.isIOS
        ? 'ca-app-pub-4818503743858431/8988013355'
        : 'ca-app-pub-4818503743858431/5571512520';
  }

  /// Rewarded interstitial shown after a daily challenge completes.
  static String get _rewardedInterstitialDailyId {
    if (kDebugMode) {
      return Platform.isIOS
          ? 'ca-app-pub-3940256099942544/6978759866'
          : 'ca-app-pub-3940256099942544/5354046379';
    }
    return Platform.isIOS
        ? 'ca-app-pub-4818503743858431/5567643094'
        : 'ca-app-pub-4818503743858431/6216073458';
  }

  static String _appOpenIdFor(AppOpenPlacement placement) {
    if (kDebugMode) {
      return Platform.isIOS
          ? 'ca-app-pub-3940256099942544/5662855259'
          : 'ca-app-pub-3940256099942544/9257395921';
    }
    if (placement == AppOpenPlacement.coldStart) {
      return Platform.isIOS
          ? 'ca-app-pub-4818503743858431/3939379036'
          : 'ca-app-pub-4818503743858431/1075293965';
    }
    return Platform.isIOS
        ? 'ca-app-pub-4818503743858431/2035592190'
        : 'ca-app-pub-4818503743858431/1951831717';
  }

  static String get _testRewardedId => Platform.isIOS
      ? 'ca-app-pub-3940256099942544/1712485313'
      : 'ca-app-pub-3940256099942544/5224354917';
  static String get _testInterstitialId => Platform.isIOS
      ? 'ca-app-pub-3940256099942544/4411468910'
      : 'ca-app-pub-3940256099942544/1033173712';
  static String get _testBannerId => Platform.isIOS
      ? 'ca-app-pub-3940256099942544/2934735716'
      : 'ca-app-pub-3940256099942544/6300978111';

  // ── Preloaded ads ── one cache per placement.
  //
  // Rewarded previously kept a primary + backup on a single unit. With two
  // units that would mean four concurrent loads, so each placement now holds
  // one; showRewarded()'s on-demand load (bounded by _rewardedLoadTimeout)
  // is the fallback when a cache is empty.
  static final Map<RewardedPlacement, RewardedAd?> _rewardedAds = {
    RewardedPlacement.hint: null,
    RewardedPlacement.extraLives: null,
  };
  static InterstitialAd? _interstitialWinAd;
  static RewardedInterstitialAd? _rewardedInterstitialAd;
  static InterstitialAd? _interstitialRestartAd;
  static final Map<AppOpenPlacement, AppOpenAd?> _appOpenAds = {
    AppOpenPlacement.coldStart: null,
    AppOpenPlacement.resume: null,
  };

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
    await _forwardConsentToMediationPartners();
    // Declare the audience explicitly rather than relying on SDK defaults.
    // The published privacy policy states the app "is configured to treat all
    // ad requests as coming from a general audience" — this is what actually
    // makes that true, and it matches the 13+ target audience declared in
    // Play Console. Deliberately NOT setting maxAdContentRating: capping it
    // restricts eligible inventory and eCPM, so that stays a revenue decision
    // rather than a silent default.
    await MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(
        tagForChildDirectedTreatment: TagForChildDirectedTreatment.no,
        tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.no,
      ),
    );
    await MobileAds.instance.initialize();
    _initialized = true;
    await _refreshCanRequestAds();
    _preloadAll();
  }

  /// Re-reads the UMP verdict on whether ads may be requested, and whether a
  /// privacy-options entry point has to be offered in Settings.
  static Future<void> _refreshCanRequestAds() async {
    try {
      _canRequestAds = await ConsentInformation.instance.canRequestAds();
    } catch (_) {
      _canRequestAds = false; // fail closed — never request without consent
    }
    try {
      final status =
          await ConsentInformation.instance.getPrivacyOptionsRequirementStatus();
      _privacyOptionsRequired =
          status == PrivacyOptionsRequirementStatus.required;
    } catch (_) {
      _privacyOptionsRequired = false;
    }
  }

  /// Shows Google's privacy options form so the user can change the consent
  /// choice they made at first launch. Only reachable when
  /// [privacyOptionsRequired] is true.
  ///
  /// Consent can move either way here, so the ad state is re-resolved after
  /// the form closes: withdrawing consent must stop further ad requests, and
  /// granting it should start them without needing an app restart.
  static Future<void> showPrivacyOptions() async {
    final completer = Completer<void>();
    try {
      await ConsentForm.showPrivacyOptionsForm((formError) {
        if (!completer.isCompleted) completer.complete();
      });
      await completer.future;
    } catch (_) {
      // Form failed to present — leave consent state untouched.
      return;
    }
    await _refreshCanRequestAds();
    await _forwardConsentToMediationPartners();
    // Always discard, whichever way the choice went. Anything preloaded was
    // fetched under the PREVIOUS consent state — showing it now could serve a
    // personalized ad to someone who just withdrew personalization consent.
    // Note canRequestAds() alone can't detect that: it reports only that the
    // consent flow completed, and stays true even after "Do not consent".
    _discardPreloadedAds();
    _preloadAll();
  }

  /// Disposes every preloaded full-screen ad. Banners are owned by the
  /// widgets that created them and are disposed there.
  static void _discardPreloadedAds() {
    for (final p in RewardedPlacement.values) {
      _rewardedAds[p]?.dispose();
      _rewardedAds[p] = null;
    }
    _interstitialWinAd?.dispose();
    _interstitialWinAd = null;
    _interstitialRestartAd?.dispose();
    _interstitialRestartAd = null;
    _rewardedInterstitialAd?.dispose();
    _rewardedInterstitialAd = null;
    for (final p in AppOpenPlacement.values) {
      _appOpenAds[p]?.dispose();
      _appOpenAds[p] = null;
      _appOpenLoadedAt[p] = null;
    }
  }

  static void _preloadAll() {
    if (!_canRequestAds) return;
    // Preload every placement in parallel for fastest availability
    for (final p in RewardedPlacement.values) {
      _loadRewarded(p);
    }
    _loadInterstitialWin();
    _loadInterstitialRestart();
    _loadRewardedInterstitial();
    // Only cold start is preloaded; the resume ad is fetched when the app is
    // backgrounded so it is fresh on return (see onAppBackgrounded).
    _loadAppOpen(AppOpenPlacement.coldStart);
  }

  /// Re-runs the consent flow when ads are currently blocked. Called on app
  /// resume so a transient network failure during startup — or a user who
  /// accepts on a later run — recovers without needing an app restart.
  /// No-op once ads are already permitted, so it costs nothing in the
  /// overwhelming majority of sessions.
  static Future<void> retryConsentIfBlocked() async {
    if (!_initialized || _canRequestAds) return;
    await _requestConsent();
    await _forwardConsentToMediationPartners();
    await _refreshCanRequestAds();
    _preloadAll();
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

  /// Forwards the UMP consent outcome to mediation partners whose adapters
  /// don't automatically read the IAB TCF string Google's SDK already wrote.
  ///
  /// Unity Ads requires this explicit call (per Google's mediation guide).
  /// Meta Audience Network's adapter reads the TCF string automatically once
  /// Meta is added as an Ad Partner in AdMob console → Privacy & messaging —
  /// its Flutter wrapper (gma_mediation_meta) exposes no consent API at all,
  /// confirmed empty in its source, so there is nothing to call here for it.
  ///
  /// `consented` reflects whether the UMP flow completed without being
  /// blocked (obtained/notRequired) — the Flutter UMP API doesn't expose
  /// granular per-purpose consent, only this coarse status.
  static Future<void> _forwardConsentToMediationPartners() async {
    try {
      final status = await ConsentInformation.instance.getConsentStatus();
      final consented = status != ConsentStatus.required &&
          status != ConsentStatus.unknown;
      final unity = GmaMediationUnity();
      await unity.setGDPRConsent(consented);
      await unity.setCCPAConsent(consented);
    } catch (_) {
      // Non-critical — never block app startup on a mediation SDK call.
    }
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
  /// Set true from the moment show() is CALLED, not when the ad appears.
  /// The OS reports the app inactive during the presentation transition, so a
  /// flag set only in onAdShowedFullScreenContent leaves a window where
  /// lifecycle handlers mistake our own ad for a real backgrounding.
  static void _markPresenting() => _showingFullScreenAd = true;

  static void setPlaying(bool playing) => _isPlaying = playing;

  /// Whether ads are removed (rewarded ads still show — user opts in).
  static bool get _adsRemoved => Prefs.removeAds;

  // ═══════════════════════════════════════════════════════════════════
  // REWARDED AD (hints + extra life) — always available, even with Remove Ads
  // ═══════════════════════════════════════════════════════════════════

  static String _rewardedIdFor(RewardedPlacement placement) =>
      placement == RewardedPlacement.hint ? _rewardedHintId : _rewardedLivesId;

  static void _loadRewarded(RewardedPlacement placement) {
    if (!_canRequestAds) return;
    RewardedAd.load(
      adUnitId: _rewardedIdFor(placement),
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewardedAds[placement] = ad,
        onAdFailedToLoad: (error) => _rewardedAds[placement] = null,
      ),
    );
  }

  /// True if a rewarded ad is cached for [placement].
  static bool rewardedReady(RewardedPlacement placement) =>
      _rewardedAds[placement] != null;

  /// Best-effort connectivity probe, used only to pick the right "can't show
  /// an ad" message.
  ///
  /// Deliberately not driven off AdMob's `LoadAdError.code`: an offline
  /// request usually stalls until our own timeout rather than reporting
  /// `ERROR_CODE_NETWORK_ERROR`, so the code was almost never the network one
  /// and every offline failure read as a plain no-fill. A DNS lookup answers
  /// the actual question, fails fast when offline, and needs no extra
  /// dependency (dart:io is already imported).
  static Future<bool> _hasInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 2));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Reports why a rewarded ad couldn't be shown, distinguishing "you're
  /// offline" from "nothing to serve right now".
  static Future<void> _reportUnavailable(
      void Function(RewardedUnavailable reason)? onUnavailable) async {
    if (onUnavailable == null) return;
    onUnavailable(await _hasInternet()
        ? RewardedUnavailable.notReady
        : RewardedUnavailable.noInternet);
  }

  /// One rewarded load attempt, surfaced as a Future so [showRewarded] can
  /// wait on it rather than refusing the instant nothing is preloaded.
  /// Completes with null on failure.
  static Future<RewardedAd?> _loadRewardedNow(RewardedPlacement placement) {
    if (!_canRequestAds) return Future.value(null);
    final completer = Completer<RewardedAd?>();
    RewardedAd.load(
      adUnitId: _rewardedIdFor(placement),
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          if (!completer.isCompleted) completer.complete(ad);
        },
        onAdFailedToLoad: (error) {
          if (!completer.isCompleted) completer.complete(null);
        },
      ),
    );
    return completer.future;
  }

  /// Shows a rewarded ad. Calls [onRewarded] only when the user actually
  /// earns the reward by watching one. Falls back to the backup ad if the
  /// primary isn't ready, and if neither is, makes one live load attempt
  /// bounded by [_rewardedLoadTimeout].
  ///
  /// If no ad can be shown, [onUnavailable] fires with the reason and the
  /// reward is NOT granted — the UI is expected to explain why. Earlier
  /// versions granted it anyway, which meant an offline user (or any no-fill)
  /// got unlimited free hints and life refills from the highest-value ad
  /// format in the app.
  ///
  /// Callers can pass [onLoading] to show a spinner while the live attempt is
  /// in flight.
  static Future<void> showRewarded({
    required RewardedPlacement placement,
    required void Function() onRewarded,
    void Function(bool loading)? onLoading,
    void Function(RewardedUnavailable reason)? onUnavailable,
  }) async {
    // Consume this placement's cache up front — a background preload can land
    // while we're awaiting the live load below, so clearing the slot
    // afterwards would be ambiguous.
    RewardedAd? ad = _rewardedAds[placement];
    _rewardedAds[placement] = null;
    if (ad == null) {
      onLoading?.call(true);
      ad = await _loadRewardedNow(placement)
          .timeout(_rewardedLoadTimeout, onTimeout: () => null);
      onLoading?.call(false);
      if (ad == null) {
        _loadRewarded(placement);
        await _reportUnavailable(onUnavailable);
        return;
      }
    }
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (a) {
        _showingFullScreenAd = true;
        AnalyticsService.adShown('rewarded_${placement.name}');
      },
      onAdDismissedFullScreenContent: (a) {
        _showingFullScreenAd = false;
        _lastFullScreenAdClosedAt = DateTime.now();
        a.dispose();
        _loadRewarded(placement);
      },
      onAdFailedToShowFullScreenContent: (a, error) {
        _showingFullScreenAd = false;
        a.dispose();
        _loadRewarded(placement);
        // Loaded but wouldn't display — no view, so no reward.
        _reportUnavailable(onUnavailable);
      },
    );
    _markPresenting();
    ad.show(onUserEarnedReward: (_, __) => onRewarded());
  }

  // ═══════════════════════════════════════════════════════════════════
  // INTERSTITIAL AD — after every 2nd win, restart, daily complete
  // ═══════════════════════════════════════════════════════════════════

  static void _loadInterstitialWin() {
    if (_adsRemoved || !_canRequestAds) return;
    InterstitialAd.load(
      adUnitId: _interstitialWinId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialWinAd = ad,
        onAdFailedToLoad: (error) => _interstitialWinAd = null,
      ),
    );
  }

  static void _loadInterstitialRestart() {
    if (_adsRemoved || !_canRequestAds) return;
    InterstitialAd.load(
      adUnitId: _interstitialRestartId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialRestartAd = ad,
        onAdFailedToLoad: (error) => _interstitialRestartAd = null,
      ),
    );
  }

  /// Wins between interstitials. The counter is only consumed when an ad
  /// actually displays (see [onLevelWin]).
  ///
  /// Raised from every 3rd win to every 2nd on 2026-08-12. Watch D1/D7
  /// retention against the impression lift — interstitial frequency is the
  /// fastest lever on revenue and also the fastest way to lose retention.
  static const _winsPerInterstitial = 2;

  /// Call after a level win. Shows an interstitial every 2nd win, then calls
  /// [onDone] once the ad is dismissed. If no ad shows (not a qualifying win,
  /// ads removed, not loaded, or shown too recently) [onDone] fires immediately.
  /// [onDone] always runs exactly once — callers sequence the streak/rate
  /// celebration off it so nothing stacks on top of the ad.
  static void onLevelWin({void Function(bool adShown)? onDone}) {
    if (_adsRemoved) {
      onDone?.call(false);
      return;
    }
    _winCount++;
    if (_winCount >= _winsPerInterstitial) {
      _showInterstitial(onDone: (shown) {
        // Only consume the counter when an ad really displayed. Resetting
        // unconditionally meant a no-fill or a gap-skip silently cost three
        // levels' worth of interstitial opportunities — the next attempt was
        // pushed out even though nothing was ever shown. Leaving the counter
        // at the threshold retries on the next win instead; the 45s
        // _interstitialGapOk check still prevents back-to-back ads.
        if (shown) _winCount = 0;
        onDone?.call(shown);
      });
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
    if (_adsRemoved || _interstitialRestartAd == null || !_interstitialGapOk) {
      _loadInterstitialRestart();
      onDone?.call();
      return;
    }
    _interstitialRestartAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _showingFullScreenAd = true;
        _lastInterstitialShownAt = DateTime.now();
        AnalyticsService.adShown('interstitial_restart');
      },
      onAdDismissedFullScreenContent: (ad) {
        _showingFullScreenAd = false;
        _lastFullScreenAdClosedAt = DateTime.now();
        ad.dispose();
        _interstitialRestartAd = null;
        _loadInterstitialRestart();
        onDone?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _showingFullScreenAd = false;
        ad.dispose();
        _interstitialRestartAd = null;
        _loadInterstitialRestart();
        onDone?.call();
      },
    );
    _markPresenting();
    _interstitialRestartAd!.show();
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

  // ═══════════════════════════════════════════════════════════════════
  // REWARDED INTERSTITIAL — daily challenge complete
  // ═══════════════════════════════════════════════════════════════════

  static void _loadRewardedInterstitial() {
    // Suppressed for Remove Ads buyers: the IAP promises "Remove all
    // fullscreen ads between levels", and this is one — the opt-out screen
    // doesn't change that.
    if (_adsRemoved || !_canRequestAds) return;
    RewardedInterstitialAd.load(
      adUnitId: _rewardedInterstitialDailyId,
      request: const AdRequest(),
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (ad) => _rewardedInterstitialAd = ad,
        onAdFailedToLoad: (error) => _rewardedInterstitialAd = null,
      ),
    );
  }

  /// True when a rewarded interstitial is cached and allowed. The UI checks
  /// this BEFORE showing the intro screen — offering a reward and then
  /// failing to deliver it is worse than never offering.
  static bool get rewardedInterstitialReady =>
      !_adsRemoved && _canRequestAds && _rewardedInterstitialAd != null;

  /// Shows the rewarded interstitial. Google requires the caller to have
  /// already presented an intro screen with the reward and a skip option —
  /// the SDK does not provide one.
  ///
  /// [onRewarded] fires only if the user actually earns the reward.
  /// [onDone] always fires exactly once, so the caller can sequence whatever
  /// comes next off it.
  static void showRewardedInterstitial({
    required void Function() onRewarded,
    VoidCallback? onDone,
  }) {
    final ad = _rewardedInterstitialAd;
    if (ad == null) {
      _loadRewardedInterstitial();
      onDone?.call();
      return;
    }
    _rewardedInterstitialAd = null;
    var finished = false;
    void finish() {
      if (finished) return;
      finished = true;
      onDone?.call();
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (a) {
        _showingFullScreenAd = true;
        _lastInterstitialShownAt = DateTime.now();
        AnalyticsService.adShown('rewarded_interstitial_daily');
      },
      onAdDismissedFullScreenContent: (a) {
        _showingFullScreenAd = false;
        _lastFullScreenAdClosedAt = DateTime.now();
        a.dispose();
        _loadRewardedInterstitial();
        finish();
      },
      onAdFailedToShowFullScreenContent: (a, error) {
        _showingFullScreenAd = false;
        a.dispose();
        _loadRewardedInterstitial();
        finish();
      },
    );
    _markPresenting();
    ad.show(onUserEarnedReward: (_, __) => onRewarded());
  }

  /// Shows interstitial if loaded, then calls [onDone] when it's dismissed —
  /// with `true` if an ad actually displayed, `false` otherwise. Never blocks:
  /// if not loaded or shown too recently, skips silently, preloads for next
  /// time, and calls `onDone(false)` immediately. [onDone] runs exactly once.
  static void _showInterstitial({void Function(bool adShown)? onDone}) {
    if (_interstitialWinAd == null) {
      _loadInterstitialWin();
      onDone?.call(false); // not loaded — skip, don't block user
      return;
    }
    if (!_interstitialGapOk) {
      onDone?.call(false); // shown too recently — avoid stacking
      return;
    }
    _interstitialWinAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _showingFullScreenAd = true;
        _lastInterstitialShownAt = DateTime.now();
        AnalyticsService.adShown('interstitial');
      },
      onAdDismissedFullScreenContent: (ad) {
        _showingFullScreenAd = false;
        _lastFullScreenAdClosedAt = DateTime.now();
        ad.dispose();
        _interstitialWinAd = null;
        _loadInterstitialWin();
        onDone?.call(true);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _showingFullScreenAd = false;
        ad.dispose();
        _interstitialWinAd = null;
        _loadInterstitialWin();
        onDone?.call(false);
      },
    );
    _markPresenting();
    _interstitialWinAd!.show();
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
  /// Computes the Anchored Adaptive banner size for [width] — a fast, local
  /// calculation (no ad request), safe to call before the actual ad is ready.
  /// Callers use this to reserve the banner's exact layout space immediately,
  /// instead of the surrounding UI jumping when the ad itself finishes
  /// loading (which can take several seconds, longer still with retries).
  static Future<AdSize?> bannerSizeFor(int width) {
    // Deliberately NOT getLargeAnchoredAdaptiveBannerAdSize — despite the
    // name, "Large" is Google's newer jumbo format and can return a banner
    // several times taller than a normal one (confirmed: it overflowed off
    // the bottom of the screen in testing). getCurrentOrientationAnchored...
    // is deprecated but still fully functional, and is the one that's
    // actually bounded (never > 15% of screen height, never < 50px) — the
    // correct compact anchored adaptive format for a bottom banner strip.
    // ignore: deprecated_member_use
    return AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
  }

  static Future<BannerAd?> createBanner({
    required int width,
    required BannerPlacement placement,
    int maxAttempts = 4,
  }) async {
    // Collapsible is a property of the placement, not an independent knob:
    // Home collapses, gameplay must never expand over the board.
    final collapsible = placement == BannerPlacement.home;
    final adUnitId = placement == BannerPlacement.home
        ? _bannerHomeId
        : _bannerGameplayId;
    if (_adsRemoved || !_canRequestAds) return null;
    final size = await bannerSizeFor(width);
    if (size == null) return null;

    // Retry with exponential backoff: a BannerAd is single-use, so a
    // transient no-fill on the first try would otherwise leave the slot empty
    // for the whole session. Each retry builds a fresh BannerAd after a
    // growing delay (2s, 4s, 8s) — bounded so we never hammer AdMob or retry
    // a sustained no-fill forever.
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (attempt > 0) {
        await Future.delayed(Duration(seconds: 2 << (attempt - 1)));
        if (_adsRemoved) return null; // user bought Remove Ads mid-wait
      }
      final ad = await _loadOneBanner(size, collapsible, adUnitId, placement);
      if (ad != null) return ad;
    }
    return null;
  }

  /// One BannerAd load attempt. Completes with the ad on success, or null on
  /// failure (disposing the dead ad object).
  static Future<BannerAd?> _loadOneBanner(AdSize size, bool collapsible,
      String adUnitId, BannerPlacement placement) {
    final completer = Completer<BannerAd?>();
    final ad = BannerAd(
      adUnitId: adUnitId,
      size: size,
      request: collapsible
          ? const AdRequest(extras: {'collapsible': 'bottom'})
          : const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          AnalyticsService.adShown('banner_${placement.name}');
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
  // APP OPEN AD — cold start + resume (never during gameplay)
  // ═══════════════════════════════════════════════════════════════════

  static bool _coldStartShown = false;

  /// Settles as soon as the cold-start app-open ad either loads or fails.
  /// [awaitColdStartAppOpen] waits on this so the splash can stay up until
  /// the ad is ready.
  static final Completer<void> _coldStartAdSettled = Completer<void>();

  static void _settleColdStartAd() {
    if (!_coldStartAdSettled.isCompleted) _coldStartAdSettled.complete();
  }

  /// Holds the caller (the splash screen) until the cold-start app-open ad is
  /// ready, up to [timeout].
  ///
  /// Without this the ad reliably lost a race it could never win: Home needs
  /// only SDK init (~3.9s measured) while the ad needs SDK init AND a ~3.2s
  /// fetch, so it landed ~3.4s after Home was already interactive — covering
  /// a screen the player was touching instead of the launch transition.
  ///
  /// Returns immediately when there will be no ad to wait for: Remove Ads
  /// purchasers, consent not granted, or a brand-new user's first launch
  /// (which deliberately shows no app-open ad at all).
  static Future<void> awaitColdStartAppOpen({
    Duration timeout = const Duration(seconds: 5),
  }) {
    if (_adsRemoved || !_canRequestAds) return Future.value();
    if (!Prefs.hasCompletedFirstSession) return Future.value();
    return _coldStartAdSettled.future
        .timeout(timeout, onTimeout: () {});
  }

  /// When each cached app-open ad was fetched.
  ///
  /// Google: "Ad references in the app open beta will time out after four
  /// hours. Ads rendered more than four hours after request time will no
  /// longer be valid and may not earn revenue." The SDK does NOT enforce this
  /// — an expired ad stays non-null and `show()` is still accepted, it just
  /// fails at display time — so a null check alone cannot detect staleness.
  static final Map<AppOpenPlacement, DateTime?> _appOpenLoadedAt = {
    AppOpenPlacement.coldStart: null,
    AppOpenPlacement.resume: null,
  };

  /// Placements with a load in flight, so overlapping lifecycle events can't
  /// fire duplicate requests (`paused`, `inactive` and `hidden` can all fire
  /// for a single backgrounding).
  static final Set<AppOpenPlacement> _appOpenLoading = {};

  static const _appOpenMaxCacheAge = Duration(hours: 4);

  static bool _appOpenExpired(AppOpenPlacement placement) {
    final t = _appOpenLoadedAt[placement];
    return t == null || DateTime.now().difference(t) >= _appOpenMaxCacheAge;
  }

  static void _loadAppOpen(AppOpenPlacement placement) {
    if (_adsRemoved || !_canRequestAds) return;
    if (_appOpenLoading.contains(placement)) return;
    _appOpenLoading.add(placement);
    AppOpenAd.load(
      adUnitId: _appOpenIdFor(placement),
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenLoading.remove(placement);
          _appOpenAds[placement] = ad;
          _appOpenLoadedAt[placement] = DateTime.now();
          // Cold start shows itself: init() fires this load but nothing else
          // triggers a show at launch — only resume does. EXCEPT on a brand
          // new user's very first launch; Google advises against an ad being
          // the first thing they see, so that one is skipped.
          if (placement == AppOpenPlacement.coldStart && !_coldStartShown) {
            _coldStartShown = true;
            if (Prefs.hasCompletedFirstSession) {
              showAppOpenIfReady(placement: AppOpenPlacement.coldStart);
            } else {
              Prefs.setHasCompletedFirstSession(true);
            }
          }
        },
        onAdFailedToLoad: (error) {
          _appOpenLoading.remove(placement);
          if (placement == AppOpenPlacement.coldStart) _settleColdStartAd();
          _appOpenAds[placement] = null;
          _appOpenLoadedAt[placement] = null;
        },
      ),
    );
  }

  /// Call when the app goes to background.
  ///
  /// The resume ad is fetched HERE rather than preloaded at startup, so it is
  /// seconds old when the player returns instead of potentially hours — which
  /// also sidesteps the 4h expiry above for the common case, and avoids
  /// spending a request at launch on an ad that may never be needed.
  static void onAppBackgrounded() {
    // `inactive` also fires while one of our own full-screen ads is on
    // screen; that is not a real backgrounding and must not trigger a fetch.
    if (_showingFullScreenAd) return;
    final cached = _appOpenAds[AppOpenPlacement.resume];
    if (cached != null && !_appOpenExpired(AppOpenPlacement.resume)) {
      return; // a still-valid ad is already waiting
    }
    if (cached != null) {
      cached.dispose();
      _appOpenAds[AppOpenPlacement.resume] = null;
      _appOpenLoadedAt[AppOpenPlacement.resume] = null;
    }
    _loadAppOpen(AppOpenPlacement.resume);
  }

  /// Call on app resume (or, for [AppOpenPlacement.coldStart], once the
  /// launch ad loads). Skipped if the user is actively playing, or if a
  /// rewarded/interstitial ad is currently showing or just closed — its
  /// dismissal fires the same resume event this responds to.
  static void showAppOpenIfReady({
    AppOpenPlacement placement = AppOpenPlacement.resume,
  }) {
    if (_adsRemoved || _isPlaying) return;
    if (_showingFullScreenAd || _inFullScreenAdCooldown) return;
    final lastShown = _lastAppOpenShownAt;
    if (lastShown != null && DateTime.now().difference(lastShown) < _appOpenMinGap) {
      return; // shown too recently — avoid stacking on rapid app-switching
    }
    final ad = _appOpenAds[placement];
    if (ad == null) {
      _loadAppOpen(placement); // not ready — fetch for the next opportunity
      return;
    }
    if (_appOpenExpired(placement)) {
      // Past the 4h validity window: showing it would fail and waste the
      // impression. Drop it and fetch a fresh one.
      ad.dispose();
      _appOpenAds[placement] = null;
      _appOpenLoadedAt[placement] = null;
      _loadAppOpen(placement);
      return;
    }
    _appOpenAds[placement] = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (a) {
        // Maintain the shared full-screen guard like rewarded/interstitial
        // do; _appOpenMinGap is a frequency cap, not a stacking guard.
        _showingFullScreenAd = true;
        _lastAppOpenShownAt = DateTime.now();
        AnalyticsService.adShown('app_open_${placement.name}');
      },
      onAdDismissedFullScreenContent: (a) {
        _showingFullScreenAd = false;
        _lastFullScreenAdClosedAt = DateTime.now();
        a.dispose();
        _appOpenLoadedAt[placement] = null;
        // Resume ads are refetched on the next backgrounding, not now.
        if (placement == AppOpenPlacement.coldStart) {
          _loadAppOpen(placement);
        }
      },
      onAdFailedToShowFullScreenContent: (a, error) {
        _showingFullScreenAd = false;
        a.dispose();
        _appOpenLoadedAt[placement] = null;
        if (placement == AppOpenPlacement.coldStart) {
          _loadAppOpen(placement);
        }
      },
    );
    _markPresenting();
    ad.show();
  }
}
