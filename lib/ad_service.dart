import 'dart:async';
import 'dart:io';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Orientation;
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
/// AdMob mediation: Unity Ads (see AdMob console Mediation groups for
/// waterfall/bidding config — not set in this code).
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
  // 3 minutes, raised from 1 (2026-08-27): the resume placement now shows
  // mid-gameplay and the cold-start grace is wider, so the 1-minute gap left
  // app-open close to the "excessive ad frequency" pattern that earned this
  // same AdMob account a "Modified ad behavior" policy flag on another app
  // (which settled on a 5-minute cap). 3 minutes keeps most of the recovered
  // impressions while staying clear of that pattern.
  static const _appOpenMinGap = Duration(minutes: 3);
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
  static bool _interstitialWinLoading = false;
  static bool _interstitialRestartLoading = false;
  static InterstitialAd? _interstitialRestartAd;

  // ── Cache expiry for interstitials & rewarded ──
  //
  // Google: interstitial and rewarded ads expire ~ONE hour after load; the
  // SDK doesn't surface this — show() on an expired ad simply fails at
  // display time, so the matched request dies AND the player sees nothing.
  // App-open already handles its own 4h window (see _appOpenLoadedAt); these
  // stamps do the same for the other formats, with margin under the hour.
  // Realistic case: the restart interstitial loads at two hearts, the player
  // never restarts and keeps playing — by the time they finally do, the
  // cached ad is hours old.
  static DateTime? _interstitialWinLoadedAt;
  static DateTime? _interstitialRestartLoadedAt;
  static final Map<RewardedPlacement, DateTime?> _rewardedLoadedAt = {
    RewardedPlacement.hint: null,
    RewardedPlacement.extraLives: null,
  };
  static const _fullScreenMaxCacheAge = Duration(minutes: 55);
  static bool _staleSince(DateTime? loadedAt) =>
      loadedAt != null &&
      DateTime.now().difference(loadedAt) >= _fullScreenMaxCacheAge;
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

  /// Disposes every preloaded ad this service holds (full-screen formats and
  /// the gameplay banner cache). On-screen banners are owned by the widgets
  /// that created them and are disposed there.
  static void _discardPreloadedAds() {
    for (final p in RewardedPlacement.values) {
      _rewardedAds[p]?.dispose();
      _rewardedAds[p] = null;
      _rewardedLoadedAt[p] = null;
    }
    _interstitialWinAd?.dispose();
    _interstitialWinAd = null;
    _interstitialWinLoadedAt = null;
    _interstitialRestartAd?.dispose();
    _interstitialRestartAd = null;
    _interstitialRestartLoadedAt = null;
    for (final p in AppOpenPlacement.values) {
      _appOpenAds[p]?.dispose();
      _appOpenAds[p] = null;
      _appOpenLoadedAt[p] = null;
    }
  }

  /// Builds the per-impression paid callback for one placement: forwards
  /// AdMob's estimated revenue (micros + currency) to GA4's ad_impression
  /// event, tagged with the placement and the winning mediation source, so
  /// revenue can be segmented per slot and per network instead of relying on
  /// AdMob's format-level aggregates. Attached at every load site — full
  /// screen formats via the ad's own onPaidEvent field, banners via their
  /// listener.
  static OnPaidEventCallback _paidEventFor(String placement, String format) =>
      (ad, valueMicros, precision, currencyCode) {
        AnalyticsService.adImpression(
          placement: placement,
          format: format,
          valueMicros: valueMicros,
          currencyCode: currencyCode,
          adSource: ad.responseInfo?.loadedAdapterResponseInfo?.adSourceName,
        );
      };

  /// Exponential backoff for full-screen preloads: 2s, 4s, 8s, then stop.
  /// Bounded so a sustained no-fill can't hammer AdMob.
  static void _retryLoad(int attempt, void Function() retry) {
    if (attempt >= 3) return;
    Future.delayed(Duration(seconds: 2 << attempt), () {
      if (!_adsRemoved && _canRequestAds) retry();
    });
  }

  /// Preloads only what can actually be shown outside a level.
  ///
  /// Every other format — both interstitials, both rewarded slots, the
  /// rewarded interstitial — is reachable ONLY from the game screen (win,
  /// restart, daily complete, hint, refill lives). Loading those at app start
  /// meant a player who browsed Collection and left generated five matched
  /// requests that could never produce an impression, which is precisely what
  /// drags AdMob's show rate down. Each is fetched from the in-level signal
  /// that actually predicts it — see [onLevelStart] for the full map.
  static void _preloadAll() {
    if (!_canRequestAds) return;
    // The resume app-open ad is fetched when the app is backgrounded so it is
    // fresh on return (see onAppBackgrounded), not here.
    //
    // Cold start is requested at most once per process, and never on a brand
    // new user's first launch (that launch deliberately shows no app-open ad,
    // so the request could only ever be orphaned — one wasted matched request
    // per install). Re-running this after a consent change used to fire
    // another cold-start load whose onAdLoaded handler is gated on
    // !_coldStartShown; the ad parked in the cache with no show path.
    if (!_coldStartShown && Prefs.hasCompletedFirstSession) {
      _loadAppOpen(AppOpenPlacement.coldStart);
    }
  }

  /// Call at level start. Requests NOTHING on its own.
  ///
  /// Every format now loads at the moment it becomes likely to be shown:
  ///   hint        → onFreeHintUsed (player has demonstrably used a hint)
  ///   extraLives  → onHeartsChanged (down to one heart)
  ///   restart     → onHeartsChanged (down to two — losing precedes restarting)
  ///   win         → onLevelNearlyComplete (~80% cleared AND the win qualifies)
  ///
  /// Restart used to be preloaded here on the grounds that it "can be tapped
  /// at any point in the level". That fired on EVERY level for an action the
  /// overwhelming majority of levels never take, which is exactly the matched-
  /// but-never-shown pattern that pins interstitial show rate at ~48%.
  static void onLevelStart({required bool isDaily}) {
    _isPlaying = true;
  }

  /// Call as the board nears completion (~80% cleared).
  ///
  /// Only ever fires on a WIN, so fetching it at level start wasted the
  /// request for anyone who quit or lost mid-level. At 80% the win is likely
  /// and there is still time for the load to land. Daily challenges use the
  /// same win interstitial (see [onDailyComplete]), so nothing daily-specific
  /// is needed here.
  ///
  /// A regular win must ALSO be a qualifying one. [onLevelWin] only displays
  /// on every [_winsPerInterstitial]-th win and only outside the 45s gap — so
  /// requesting unconditionally meant roughly half of these were dead before
  /// they left the device. The gap check looks 20s ahead because the ad shows
  /// at the END of the level, by which time a gap that is nearly up will have
  /// elapsed; checking it strictly here would throw away real impressions.
  static void onLevelNearlyComplete({required bool isDaily}) {
    if (_adsRemoved || !_canRequestAds) return;
    if (!isDaily) {
      if (_winCount + 1 < _winsPerInterstitial) return;
      if (!_interstitialGapOkWithin(const Duration(seconds: 20))) return;
    }
    _loadInterstitialWin();
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

  /// Runs whatever the currently-presenting ad's onDismiss/onFailedToShow
  /// path would have run, for [recoverFromStuckFullScreenAd] to fall back on
  /// when those callbacks never arrive. Cleared the instant either callback
  /// actually fires, since recovery is then no longer needed.
  static void Function()? _stuckRecovery;

  /// Call on app resume. A min-max cycle (home button, then relaunch) WHILE
  /// a full-screen ad is on screen can let the OS reclaim that ad's Activity
  /// without ever calling its onAdDismissedFullScreenContent /
  /// onAdFailedToShowFullScreenContent delegate — seen on this device. Since
  /// every caller's continuation (win navigation, reward grant, etc.) only
  /// runs inside those callbacks, and [_showingFullScreenAd] is only cleared
  /// there too, a lost callback otherwise freezes the game on that screen
  /// AND permanently blocks every full-screen ad after it for the session.
  ///
  /// A genuine dismissal's callback lands around the same platform
  /// transition as this resume event, so a short grace delay is given before
  /// concluding it was actually lost.
  static Future<void> recoverFromStuckFullScreenAd() async {
    if (!_showingFullScreenAd) return;
    await Future.delayed(const Duration(milliseconds: 400));
    if (!_showingFullScreenAd) return;
    final recovery = _stuckRecovery;
    _stuckRecovery = null;
    _showingFullScreenAd = false;
    recovery?.call();
  }

  static void setPlaying(bool playing) => _isPlaying = playing;

  /// Call when the player's hearts change.
  ///
  /// The refill-lives ad is fetched at ONE heart, not zero. The lose popup
  /// appears the instant hearts hit zero, so starting the load there would
  /// put a spinner in front of the player instead of an ad — trading a sure
  /// impression for a wait they may not sit through. One heart leaves time
  /// for the request to land while still skipping it entirely for players
  /// who never come close to losing.
  ///
  /// Losing a heart is also the best available predictor of a RESTART, so the
  /// restart interstitial is fetched at two hearts. Players who clear a level
  /// cleanly almost never restart it, and they no longer generate a request
  /// for an ad they were never going to see.
  static void onHeartsChanged(int hearts) {
    if (hearts == 1) _loadRewarded(RewardedPlacement.extraLives);
  }

  /// Call the moment the player taps Restart — before the confirm dialog is
  /// shown, so the dialog's own display time covers the request.
  ///
  /// This replaces loading at two hearts (2026-09-03). Losing a heart barely
  /// predicts restarting: most players who drop to two hearts keep playing or
  /// lose, so that trigger fired far more often than a restart ever happened
  /// — 10,150 requests/day against 2,266 impressions, with match rate falling
  /// 74% -> 55% as the volume climbed. Tapping Restart is an explicit intent
  /// signal, and the confirm dialog is exactly the runway a load needs.
  ///
  /// Self-guarded: [_loadInterstitialRestart] no-ops while one is cached or
  /// in flight, so cancelling the dialog and tapping Restart again does not
  /// fire a second request — the cached ad simply waits for the next restart.
  static void onRestartOffered() => _loadInterstitialRestart();

  /// Call after any hint is consumed. Once the free allowance is spent, every
  /// hint from here needs an ad, so fetch the NEXT one now rather than at the
  /// tap. Also refills after each ad-backed hint, so only the first paid hint
  /// of a process is ever a cold load.
  static void onFreeHintUsed() {
    if (!Prefs.hasFreeHint) _loadRewarded(RewardedPlacement.hint);
  }

  /// Whether this player has ever taken an ad-backed hint.
  ///
  /// [Prefs.hintsUsed] is a lifetime per-install counter and [Prefs.freeHints]
  /// is the free allowance, so exceeding it means at least one hint has been
  /// paid for with an ad view. Persisted, so it survives a relaunch.
  static bool get _isPaidHintUser => Prefs.hintsUsed > Prefs.freeHints;

  /// Call when the hint button becomes visible and a hint would cost an ad.
  ///
  /// Fetches ONLY for a player who has taken a paid hint before. The button
  /// merely appearing (10 idle seconds) says nothing about intent — roughly
  /// three in four players never tap it — and preloading on sight was the
  /// largest single source of matched-but-never-shown rewarded inventory
  /// (24% show rate). A proven hint user is a different bet entirely, and
  /// without this their FIRST tap of every launch would be a cold load: the
  /// in-memory cache dies with the process, and [onFreeHintUsed] can only
  /// refill it after a hint has already been taken.
  ///
  /// Everyone else still loads on demand at the tap, bounded by
  /// [_rewardedLoadTimeout] with a spinner.
  static void onHintOffered() {
    if (Prefs.hasFreeHint) return;
    if (!_isPaidHintUser) return;
    _loadRewarded(RewardedPlacement.hint);
  }

  /// Whether ads are removed (rewarded ads still show — user opts in).
  static bool get _adsRemoved => Prefs.removeAds;

  // ═══════════════════════════════════════════════════════════════════
  // REWARDED AD (hints + extra life) — always available, even with Remove Ads
  // ═══════════════════════════════════════════════════════════════════

  static String _rewardedIdFor(RewardedPlacement placement) =>
      placement == RewardedPlacement.hint ? _rewardedHintId : _rewardedLivesId;

  /// Placements with a load in flight. [onHeartsChanged] can fire more than
  /// once at the same heart count, so without this a single trigger could
  /// stack duplicate requests.
  static final Set<RewardedPlacement> _rewardedLoading = {};

  static void _loadRewarded(RewardedPlacement placement) {
    if (!_canRequestAds) return;
    // See _loadInterstitialWin — same ~1h staleness replacement.
    if (_rewardedAds[placement] != null &&
        _staleSince(_rewardedLoadedAt[placement])) {
      _rewardedAds[placement]!.dispose();
      _rewardedAds[placement] = null;
      _rewardedLoadedAt[placement] = null;
    }
    if (_rewardedAds[placement] != null) return;
    if (_rewardedLoading.contains(placement)) return;
    _rewardedLoading.add(placement);
    RewardedAd.load(
      adUnitId: _rewardedIdFor(placement),
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          ad.onPaidEvent =
              _paidEventFor('rewarded_${placement.name}', 'rewarded');
          _rewardedLoading.remove(placement);
          _rewardedAds[placement] = ad;
          _rewardedLoadedAt[placement] = DateTime.now();
        },
        onAdFailedToLoad: (error) {
          _rewardedLoading.remove(placement);
          _rewardedAds[placement] = null;
        },
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

  /// Waits up to [_rewardedLoadTimeout] for an in-flight background preload
  /// (see [_loadRewarded]) to land in the cache, then consumes it. Returns
  /// null as soon as that load fails, or at the deadline. On timeout the
  /// preload keeps going and its result stays cached for the next
  /// opportunity — nothing is lost.
  static Future<RewardedAd?> _awaitPreloadedRewarded(
      RewardedPlacement placement) async {
    final deadline = DateTime.now().add(_rewardedLoadTimeout);
    while (DateTime.now().isBefore(deadline)) {
      final ad = _rewardedAds[placement];
      if (ad != null) {
        _rewardedAds[placement] = null;
        _rewardedLoadedAt[placement] = null;
        return ad;
      }
      if (!_rewardedLoading.contains(placement)) return null; // load failed
      await Future.delayed(const Duration(milliseconds: 150));
    }
    return null;
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
          ad.onPaidEvent =
              _paidEventFor('rewarded_${placement.name}', 'rewarded');
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
    if (ad != null && _staleSince(_rewardedLoadedAt[placement])) {
      // Outlived AdMob's ~1h validity — show() would fail at display time.
      // Fall through to the live load instead of a doomed show.
      ad.dispose();
      ad = null;
    }
    _rewardedLoadedAt[placement] = null;
    if (ad == null) {
      onLoading?.call(true);
      if (_rewardedLoading.contains(placement)) {
        // A background preload is already in flight for this placement —
        // wait for ITS result (self-bounded by _rewardedLoadTimeout)
        // instead of firing a duplicate request alongside it.
        ad = await _awaitPreloadedRewarded(placement);
      } else {
        final live = _loadRewardedNow(placement);
        ad = await live.timeout(_rewardedLoadTimeout, onTimeout: () => null);
        if (ad == null) {
          // Timed out, but the request itself is still in flight — when it
          // lands, keep it as the preload for the next tap instead of
          // orphaning a matched ad. This is also why no fresh _loadRewarded
          // fires here: it would just duplicate the request it's racing.
          live.then((lateAd) {
            if (lateAd == null) return;
            if (_rewardedAds[placement] == null) {
              _rewardedAds[placement] = lateAd;
              _rewardedLoadedAt[placement] = DateTime.now();
            } else {
              lateAd.dispose();
            }
          });
        }
      }
      onLoading?.call(false);
      if (ad == null) {
        await _reportUnavailable(onUnavailable);
        return;
      }
    }
    final readyAd = ad;
    readyAd.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (a) {
        _showingFullScreenAd = true;
        AnalyticsService.adShown('rewarded_${placement.name}');
      },
      onAdDismissedFullScreenContent: (a) {
        _stuckRecovery = null;
        _showingFullScreenAd = false;
        _lastFullScreenAdClosedAt = DateTime.now();
        a.dispose();
        // Not refetched: hint reloads on the next free-hint use
        // (onFreeHintUsed) or on demand at the tap, and lives when hearts
        // next drop to one (onHeartsChanged).
      },
      onAdFailedToShowFullScreenContent: (a, error) {
        _stuckRecovery = null;
        _showingFullScreenAd = false;
        a.dispose();
        _loadRewarded(placement);
        // Loaded but wouldn't display — no view, so no reward.
        _reportUnavailable(onUnavailable);
      },
    );
    _stuckRecovery = () {
      readyAd.dispose();
      _loadRewarded(placement);
      _reportUnavailable(onUnavailable);
    };
    _markPresenting();
    readyAd.show(onUserEarnedReward: (_, __) => onRewarded());
  }

  // ═══════════════════════════════════════════════════════════════════
  // INTERSTITIAL AD — after every 2nd win, restart, daily complete
  // ═══════════════════════════════════════════════════════════════════

  static void _loadInterstitialWin([int attempt = 0]) {
    if (_adsRemoved || !_canRequestAds) return;
    // A cached ad past its ~1h validity would fail at show — replace it now,
    // while there's still runway, rather than discovering that at the win.
    if (_interstitialWinAd != null && _staleSince(_interstitialWinLoadedAt)) {
      _interstitialWinAd!.dispose();
      _interstitialWinAd = null;
      _interstitialWinLoadedAt = null;
    }
    if (_interstitialWinAd != null || _interstitialWinLoading) return;
    _interstitialWinLoading = true;
    InterstitialAd.load(
      adUnitId: _interstitialWinId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          ad.onPaidEvent = _paidEventFor('interstitial_win', 'interstitial');
          _interstitialWinLoading = false;
          _interstitialWinAd = ad;
          _interstitialWinLoadedAt = DateTime.now();
        },
        onAdFailedToLoad: (error) {
          _interstitialWinLoading = false;
          _interstitialWinAd = null;
          // Retry with backoff. Without this a single no-fill left the slot
          // empty until the NEXT win triggered a reload — and that win's
          // opportunity was already spent, so one miss could cost several.
          _retryLoad(attempt, () => _loadInterstitialWin(attempt + 1));
        },
      ),
    );
  }

  static void _loadInterstitialRestart([int attempt = 0]) {
    if (_adsRemoved || !_canRequestAds) return;
    // See _loadInterstitialWin — same ~1h staleness replacement.
    if (_interstitialRestartAd != null &&
        _staleSince(_interstitialRestartLoadedAt)) {
      _interstitialRestartAd!.dispose();
      _interstitialRestartAd = null;
      _interstitialRestartLoadedAt = null;
    }
    if (_interstitialRestartAd != null || _interstitialRestartLoading) return;
    _interstitialRestartLoading = true;
    InterstitialAd.load(
      adUnitId: _interstitialRestartId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          ad.onPaidEvent =
              _paidEventFor('interstitial_restart', 'interstitial');
          _interstitialRestartLoading = false;
          _interstitialRestartAd = ad;
          _interstitialRestartLoadedAt = DateTime.now();
        },
        onAdFailedToLoad: (error) {
          _interstitialRestartLoading = false;
          _interstitialRestartAd = null;
          // Retry with backoff. Without this a single no-fill left the slot
          // empty until the NEXT win triggered a reload — and that win's
          // opportunity was already spent, so one miss could cost several.
          _retryLoad(attempt, () => _loadInterstitialRestart(attempt + 1));
        },
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

  static bool get _interstitialGapOk => _interstitialGapOkWithin(Duration.zero);

  /// Whether the inter-ad gap will have elapsed within [lead].
  ///
  /// Preloads run ahead of the show, so they need the forward-looking form:
  /// with [lead] of zero this is the strict "can I show right now?" check.
  static bool _interstitialGapOkWithin(Duration lead) {
    final t = _lastInterstitialShownAt;
    return t == null ||
        DateTime.now().difference(t) + lead >= _interstitialMinGap;
  }

  /// Call on restart. Shows interstitial if loaded, then calls [onDone].
  /// If ad not loaded, ads removed, or shown too recently, calls [onDone]
  /// immediately — interstitials must not stack back-to-back on rapid
  /// repeated restarts.
  static void onRestart({VoidCallback? onDone}) {
    // An expired cache would fail at display — treat as not loaded (the
    // reload below then fetches a fresh one for the next restart).
    if (_interstitialRestartAd != null &&
        _staleSince(_interstitialRestartLoadedAt)) {
      _interstitialRestartAd!.dispose();
      _interstitialRestartAd = null;
      _interstitialRestartLoadedAt = null;
    }
    if (_adsRemoved || _interstitialRestartAd == null || !_interstitialGapOk) {
      _loadInterstitialRestart();
      onDone?.call();
      return;
    }
    final restartAd = _interstitialRestartAd!;
    restartAd.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _showingFullScreenAd = true;
        _lastInterstitialShownAt = DateTime.now();
        AnalyticsService.adShown('interstitial_restart');
      },
      onAdDismissedFullScreenContent: (ad) {
        _stuckRecovery = null;
        _showingFullScreenAd = false;
        _lastFullScreenAdClosedAt = DateTime.now();
        ad.dispose();
        _interstitialRestartAd = null;
        // NOT refetched. This reload existed because restart "can be tapped
        // at any moment, with no later signal to wait for" — onRestartOffered
        // is now that signal, so refetching here would be a request with
        // nothing behind it, exactly what was stripped from the other
        // formats. The next restart tap fetches it.
        onDone?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _stuckRecovery = null;
        _showingFullScreenAd = false;
        ad.dispose();
        _interstitialRestartAd = null;
        // Refetched: nothing was displayed, so the opportunity can recur
        // immediately (the player is still on the restart they asked for).
        _loadInterstitialRestart();
        onDone?.call();
      },
    );
    _stuckRecovery = () {
      restartAd.dispose();
      _interstitialRestartAd = null;
      _loadInterstitialRestart();
      onDone?.call();
    };
    _markPresenting();
    restartAd.show();
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
    // An expired cache would fail at display anyway — treat it as not loaded
    // so this win is skipped cleanly and a fresh ad is fetched for the next.
    if (_interstitialWinAd != null && _staleSince(_interstitialWinLoadedAt)) {
      _interstitialWinAd!.dispose();
      _interstitialWinAd = null;
      _interstitialWinLoadedAt = null;
    }
    if (_interstitialWinAd == null) {
      _loadInterstitialWin();
      onDone?.call(false); // not loaded — skip, don't block user
      return;
    }
    if (!_interstitialGapOk) {
      onDone?.call(false); // shown too recently — avoid stacking
      return;
    }
    final winAd = _interstitialWinAd!;
    winAd.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _showingFullScreenAd = true;
        _lastInterstitialShownAt = DateTime.now();
        AnalyticsService.adShown('interstitial');
      },
      onAdDismissedFullScreenContent: (ad) {
        _stuckRecovery = null;
        _showingFullScreenAd = false;
        _lastFullScreenAdClosedAt = DateTime.now();
        ad.dispose();
        _interstitialWinAd = null;
        // Not refetched here. Nothing can show for 45s, and the next win is
        // two levels away — onLevelNearlyComplete (~80% cleared) fetches it
        // when a win is actually approaching. A blind reload here is a
        // request with no signal behind it, wasted outright if the player
        // quits after the ad.
        onDone?.call(true);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _stuckRecovery = null;
        _showingFullScreenAd = false;
        ad.dispose();
        _interstitialWinAd = null;
        onDone?.call(false);
      },
    );
    // A min-max cycle mid-ad can lose the dismiss callback entirely (see
    // recoverFromStuckFullScreenAd) — without this, the win-flow navigation
    // that only runs inside onDone would never fire, freezing the game on
    // the finished level.
    _stuckRecovery = () {
      winAd.dispose();
      _interstitialWinAd = null;
      onDone?.call(false);
    };
    _markPresenting();
    winAd.show();
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
  ///
  /// Split by placement (2026-08-27):
  ///  - HOME keeps the Large format (2026-08-18 product decision) — it's a
  ///    non-gameplay view with room to spare, which is exactly where Google
  ///    recommends large anchors.
  ///  - GAMEPLAY uses the standard anchored adaptive size. The large format
  ///    has thinner creative liquidity (fewer buyers stock the tall size),
  ///    which at our ~12% banner match rate meant slower matches and more
  ///    retry bursts — the slot sat empty for a noticeable part of each
  ///    level. A week of large-format data showed NO eCPM premium over
  ///    standard ($0.25), so the extra height was costing board space and
  ///    load latency while paying nothing. Standard is the deepest-liquidity
  ///    banner size there is: faster fill, more impressions, bounded height.
  static Future<AdSize?> bannerSizeFor(int width,
      {BannerPlacement placement = BannerPlacement.home}) {
    // Both placements use the standard anchored-adaptive size (2026-08-27):
    // Home previously used the Large format, but gameplay was reverted to
    // standard after a week's data showed no eCPM premium ($0.25 either way)
    // while the large format's thinner inventory pool cost fill speed — so
    // Home is matched to it for a consistent banner size across the app.
    //
    // Deliberate use of a deprecated member: plugin v9 deprecates this
    // lookup to nudge everyone onto the large format, but the standard size
    // itself is fully supported (this method invokes the same platform API,
    // minus the "large" flag). Explicit portrait, since the app is
    // orientation-locked in main().
    // ignore: deprecated_member_use
    return AdSize.getAnchoredAdaptiveBannerAdSize(Orientation.portrait, width);
  }

  static Future<BannerAd?> createBanner({
    required int width,
    required BannerPlacement placement,
    int maxAttempts = 4,
    bool Function()? keepTrying,
  }) async {
    // Collapsible is a property of the placement, not an independent knob:
    // Home collapses, gameplay must never expand over the board.
    final collapsible = placement == BannerPlacement.home;
    final adUnitId = placement == BannerPlacement.home
        ? _bannerHomeId
        : _bannerGameplayId;
    if (_adsRemoved || !_canRequestAds) return null;
    final size = await bannerSizeFor(width, placement: placement);
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
        // The caller's slot is gone (screen disposed, or covered by another
        // route) — stop spending requests on a banner nobody can see.
        if (keepTrying != null && !keepTrying()) return null;
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
        onPaidEvent: _paidEventFor('banner_${placement.name}', 'banner'),
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

  /// True once the splash has been dismissed and Home is interactive.
  ///
  /// The startup budget bounds how long the splash waits, but the ad load
  /// keeps going past it — so without this a slow load would call
  /// showAppOpenIfReady() while the player is already tapping Home, which is
  /// exactly the interruption the budget exists to prevent.
  static bool _splashWindowClosed = false;
  static DateTime? _splashClosedAt;

  /// Call when the splash is dismissed (see main()).
  static void onSplashDismissed() {
    _splashWindowClosed = true;
    _splashClosedAt = DateTime.now();
    // First launch is over: from the next launch on, the cold-start ad may
    // load and show. Stamped here — after awaitColdStartAppOpen has already
    // consulted it — rather than in the ad load callback, because on a first
    // launch no cold-start ad is requested at all (see _preloadAll).
    if (!Prefs.hasCompletedFirstSession) {
      Prefs.setHasCompletedFirstSession(true);
    }
  }

  /// How long after the splash closes a cold-start ad that finishes loading
  /// late is still shown directly rather than recycled to the resume slot.
  ///
  /// The 5s splash budget covers consent + ATT + SDK init + the ad fetch, in
  /// that order — SDK init alone has been measured up to 14.7s, so on a
  /// meaningful share of launches the fetch never even starts before the
  /// budget runs out. Without this grace window, EVERY one of those launches
  /// loses its cold-start impression outright: the ad only shows if the
  /// player later backgrounds and returns, which many sessions never do.
  ///
  /// Widened from 3s to 10s (2026-08-27, app-open show rate was 26.5%): the
  /// fixed 3s cutoff recycled the whole 3-14s late-load pool to the resume
  /// slot, where most of it expired unshown. The real question is not the
  /// clock but whether the player has started doing something — so the wide
  /// window is paired with [_firstInteractionAt]: one tap anywhere in the
  /// shell and the launch moment is over, regardless of elapsed time.
  static const _coldStartGrace = Duration(seconds: 10);

  /// First pointer-down anywhere in the shell after the splash (see
  /// MainShell). Once the player has acted, a late cold-start ad no longer
  /// rides the launch transition — it would interrupt — so it is recycled to
  /// the resume slot instead.
  static DateTime? _firstInteractionAt;

  /// Call on the first user interaction after launch (any tap in the shell).
  static void onUserInteracted() => _firstInteractionAt ??= DateTime.now();

  static bool get _withinColdStartGrace {
    if (_firstInteractionAt != null) return false; // player is already acting
    final t = _splashClosedAt;
    return t == null || DateTime.now().difference(t) <= _coldStartGrace;
  }

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
          // Placement here is where the ad was REQUESTED; a recycled
          // cold-start ad showing from the resume slot still reports as
          // cold-start, matching AdMob's own attribution.
          ad.onPaidEvent =
              _paidEventFor('app_open_${placement.name}', 'app_open');
          _appOpenLoading.remove(placement);
          _appOpenAds[placement] = ad;
          _appOpenLoadedAt[placement] = DateTime.now();
          if (placement == AppOpenPlacement.coldStart) _settleColdStartAd();
          // Cold start shows itself: init() fires this load but nothing else
          // triggers a show at launch — only resume does. (A brand new user's
          // very first launch never requests one — see _preloadAll.)
          if (placement == AppOpenPlacement.coldStart && !_coldStartShown) {
            _coldStartShown = true;
            if (_splashWindowClosed && !_withinColdStartGrace) {
              // Loaded well after the launch — Home has likely already been
              // used. Hand it to the resume slot instead of interrupting.
              _recycleColdStartToResume();
            } else {
              showAppOpenIfReady(placement: AppOpenPlacement.coldStart);
            }
          } else if (placement == AppOpenPlacement.coldStart) {
            // Defensive: a cold-start ad landing after that moment has passed
            // (e.g. a consent re-run raced _preloadAll's guard) has no show
            // path of its own — recycle rather than park a matched ad.
            _recycleColdStartToResume();
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

  /// Moves a loaded cold-start ad into the resume slot, so it is shown on the
  /// next foregrounding instead of never. The impression is still attributed
  /// to the cold-start ad unit in AdMob reporting, since that is where the
  /// request came from. If a resume ad is already waiting, the older of the
  /// two is released.
  static void _recycleColdStartToResume() {
    final late = _appOpenAds[AppOpenPlacement.coldStart];
    _appOpenAds[AppOpenPlacement.coldStart] = null;
    _appOpenLoadedAt[AppOpenPlacement.coldStart] = null;
    if (late == null) return;
    if (_appOpenAds[AppOpenPlacement.resume] == null) {
      _appOpenAds[AppOpenPlacement.resume] = late;
      _appOpenLoadedAt[AppOpenPlacement.resume] = DateTime.now();
    } else {
      late.dispose();
    }
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
    if (_adsRemoved) return;
    // The RESUME placement is exempt from the gameplay gate. Backgrounding
    // mid-level is by far the most common pattern in a puzzle game, so
    // blocking it there meant onAppBackgrounded() fetched an ad that then sat
    // untouched until the 4h expiry — 5,015 matched app-open ads produced
    // only 1,327 impressions (26.5% show rate). Returning to the foreground
    // is the format's canonical, policy-approved moment to show; the frequency
    // cap and the full-screen guards below still prevent any stacking.
    //
    // Cold start keeps the gate: it can only fire inside the launch grace
    // window, and a level cannot be in progress then.
    if (_isPlaying && placement != AppOpenPlacement.resume) return;
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
        _stuckRecovery = null;
        _showingFullScreenAd = false;
        _lastFullScreenAdClosedAt = DateTime.now();
        a.dispose();
        _appOpenLoadedAt[placement] = null;
        // Neither placement is refetched here. Cold start fires once per
        // process — _coldStartShown is already true, so a reload could never
        // be shown and would be a pure wasted request. Resume is refetched on
        // the next backgrounding (see onAppBackgrounded).
      },
      onAdFailedToShowFullScreenContent: (a, error) {
        _stuckRecovery = null;
        _showingFullScreenAd = false;
        a.dispose();
        _appOpenLoadedAt[placement] = null;
        // Not refetched, for the same reason as the dismiss path above.
      },
    );
    _stuckRecovery = () {
      ad.dispose();
      _appOpenLoadedAt[placement] = null;
    };
    _markPresenting();
    ad.show();
  }
}
