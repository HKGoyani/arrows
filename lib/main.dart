import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_service.dart';
import 'analytics_service.dart';
import 'iap_service.dart';
import 'audio.dart';
import 'l10n.dart';
import 'challenge.dart';
import 'collection_icons.dart';
import 'collection_screen.dart';
import 'config.dart';
import 'game_controller.dart';
import 'game_screen.dart';
import 'home_screen.dart';
import 'level_legend.dart';
import 'perfect.dart';
import 'unstoppable.dart';
import 'prefs.dart';
import 'rate_prompt.dart';
import 'settings_screen.dart';
import 'streak.dart';
import 'streak_screen.dart';
import 'ui_kit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Show the arrow loader immediately so the launch gap (while the services
  // below initialise) isn't a blank white screen.
  runApp(const _SplashApp());
  await Prefs.init();
  await AnalyticsService.init();
  await AudioService.init();
  // Ad startup is bounded as ONE budget covering both SDK init and the
  // cold-start ad fetch — capping only the ad wait was useless, because
  // MobileAds.initialize() alone measured anywhere from 2.5s to 14.7s and
  // ran BEFORE that cap applied, producing a 23s splash.
  //
  // Deliberately not awaited directly: initialization continues in the
  // background past the deadline, so a slow network delays the ad but never
  // the game. If the budget runs out the cold-start ad is skipped for this
  // launch and the resume placement picks it up instead.
  final adStartup = AdService.init()
      .then((_) => AdService.awaitColdStartAppOpen(
          timeout: const Duration(seconds: 5)));
  await Future.any([
    adStartup,
    Future<void>.delayed(const Duration(seconds: 5)),
  ]);
  await IapService.init();
  // Close the launch window before Home renders: any cold-start ad that
  // finishes loading after this point must not interrupt an interactive
  // screen — it gets handed to the resume slot instead.
  AdService.onSplashDismissed();
  runApp(ArrowsApp());
}

/// Playful, on-theme loading lines — a different one each launch.
const _splashMessages = <String>[
  'Untangling the arrows…',
  'Plotting escape routes…',
  'Clearing the board…',
  'Winding the maze…',
  'Finding the way out…',
  'Charting the corridors…',
  'Lining up the shot…',
  'Loosening the knots…',
];

/// Minimal loading screen shown during startup init, before the real app.
class _SplashApp extends StatelessWidget {
  const _SplashApp();
  @override
  Widget build(BuildContext context) {
    final msg = _splashMessages[Random().nextInt(_splashMessages.length)];
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme:
          ThemeData(scaffoldBackgroundColor: AppColors.bg, useMaterial3: true),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ArrowLoader(size: 84),
                const SizedBox(height: 30),
                Text(msg,
                    textAlign: TextAlign.center,
                    style: poppins(15, FontWeight.w800, AppColors.muted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final appKey = GlobalKey<_ArrowsAppState>();

/// Lets [MainShell] know when another route is covering it, so it can release
/// its banner instead of leaving one refreshing behind an opaque full-screen
/// route (gameplay, daily challenge, celebrations, record detail screens).
final routeObserver = RouteObserver<PageRoute<dynamic>>();

class ArrowsApp extends StatefulWidget {
  ArrowsApp() : super(key: appKey);
  @override
  State<ArrowsApp> createState() => _ArrowsAppState();
}

class _ArrowsAppState extends State<ArrowsApp> {
  void rebuildTheme() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arrows – Escape Puzzle',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(scaffoldBackgroundColor: AppColors.bg, useMaterial3: true),
      navigatorObservers: [routeObserver],
      home: MainShell(),
    );
  }
}

final mainShellKey = GlobalKey<_MainShellState>();

void navigateToChallenge(int year, int month) {
  mainShellKey.currentState?.switchToChallenge(year, month);
}

/// Home · Streak · Settings tabs. The game launches full-screen on top.
class MainShell extends StatefulWidget {
  MainShell() : super(key: mainShellKey);
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin, RouteAware {
  int _tab = 0;
  int? _challengeYear;
  int? _challengeMonth;

  void switchToChallenge(int year, int month) {
    setState(() {
      _challengeYear = year;
      _challengeMonth = month;
      _tab = 1;
    });
  }
  late final AnimationController _navSlideCtrl;
  BannerAd? _bannerAd; // collapsible — shared across all bottom nav tabs
  bool _bannerRequested = false;
  AdSize? _bannerSize; // reserved as soon as known, before the ad itself loads
  Timer? _bannerRetryTimer; // slow retry after the initial burst is exhausted
  int _bannerWidth = 0; // remembered so the banner can be re-acquired on return
  int _bannerRetries = 0;

  /// See [_requestBanner] — the retry loop is bounded, not endless.
  static const _maxBannerRetries = 2;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _navSlideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: 1.0,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Anchored adaptive banner needs the screen width, which isn't reliably
    // available until dependencies (MediaQuery) are attached — not in
    // initState.
    final route = ModalRoute.of(context);
    if (route is PageRoute) routeObserver.subscribe(this, route);
    if (!_bannerRequested) {
      _bannerRequested = true;
      _bannerWidth = MediaQuery.of(context).size.width.truncate();
      // Reserve the banner's exact space as soon as the size is known (fast,
      // local — no ad request) so the nav bar settles into its final
      // position immediately, instead of jumping once the ad itself finishes
      // loading (which can take several seconds, longer with retries).
      AdService.bannerSizeFor(_bannerWidth).then((size) {
        if (mounted && size != null) setState(() => _bannerSize = size);
      });
      _requestBanner(_bannerWidth);
      // Warm the session's FIRST gameplay banner while the player is still
      // on Home — Play is the app's primary action, so this request has a
      // near-certain impression ahead of it, and the first level opens with
      // its banner already attached. Later levels re-warm at ~80% cleared.
      AdService.preloadGameplayBanner(_bannerWidth);
    }
  }

  // ── Banner visibility ──
  //
  // The shell is never unmounted: gameplay, daily challenges and the detail
  // screens are all PUSHED on top of it, so its State (and its banner) stayed
  // alive underneath an opaque route. The banner kept auto-refreshing there
  // for the whole time the player was on the board — requests for a slot
  // nobody could see, and any impression they did record was unviewable,
  // which is what AdMob's "request only when the slot is visible" note is
  // about. The reserved SizedBox stays put either way, so releasing the ad
  // costs no layout shift.

  @override
  void didPushNext() => _releaseBanner();

  @override
  void didPopNext() {
    if (_bannerAd == null && _bannerWidth > 0) {
      _bannerRetries = 0;
      _requestBanner(_bannerWidth);
    }
  }

  void _releaseBanner() {
    _bannerRetryTimer?.cancel();
    _bannerRetryTimer = null;
    if (_bannerAd == null) return;
    final ad = _bannerAd;
    setState(() => _bannerAd = null);
    // Disposed after the frame that removes its AdWidget from the tree —
    // tearing down the platform view while it is still mounted throws.
    WidgetsBinding.instance.addPostFrameCallback((_) => ad?.dispose());
  }

  /// Requests the banner, and keeps trying on a slow cadence if it fails.
  /// [AdService.createBanner]'s own retry burst gives up after ~14s.
  ///
  /// BOUNDED at [_maxBannerRetries]: this used to reschedule itself every 60s
  /// forever, so a player in a low-fill region emitted a 4-attempt burst every
  /// ~74 seconds for the entire session and never received an impression.
  void _requestBanner(int width) {
    AdService.createBanner(
      width: width,
      placement: BannerPlacement.home,
      // Abort the in-flight retry burst if a route covers the shell mid-wait
      // — those stragglers were requests with no visible slot to land in.
      keepTrying: () =>
          mounted && (ModalRoute.of(context)?.isCurrent ?? false),
    ).then((ad) {
      // The load (with retries) can take several seconds; if this shell is
      // gone — or a route has since covered it — by the time it resolves,
      // dispose the ad so it doesn't leak or refresh out of sight.
      if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) {
        ad?.dispose();
        return;
      }
      if (ad == null) {
        if (_bannerRetries >= _maxBannerRetries) return;
        _bannerRetries++;
        _bannerRetryTimer?.cancel();
        _bannerRetryTimer = Timer(Duration(seconds: 60 * _bannerRetries), () {
          if (mounted) _requestBanner(width);
        });
        return;
      }
      setState(() => _bannerAd = ad);
    });
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _bannerRetryTimer?.cancel();
    _bannerAd?.dispose();
    _navSlideCtrl.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AudioService.onAppResume();
      // A min-max cycle while a full-screen ad was on screen can lose its
      // dismiss callback entirely (OS reclaims the ad's Activity) — without
      // this, the game freezes waiting on a callback that never arrives, and
      // every full-screen ad after it is silently blocked for the session.
      AdService.recoverFromStuckFullScreenAd();
      // If the UMP consent flow didn't clear us to request ads at startup
      // (network failure, or the user hadn't consented yet), retry here so a
      // single bad launch doesn't leave the session ad-free. No-op otherwise.
      AdService.retryConsentIfBlocked();
      AdService.showAppOpenIfReady();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      AudioService.onAppPause();
      // Fetch the resume app-open ad now, while backgrounded, so it's fresh
      // when the player returns. Self-guards against the duplicate calls
      // these three states produce for a single backgrounding.
      AdService.onAppBackgrounded();
    }
  }

  Future<void> _play() async {
    await Navigator.of(context)
        .push(PageRouteBuilder(
          pageBuilder: (_, __, ___) => const GameFlow(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 300),
        ));
    if (mounted) {
      _navSlideCtrl.forward(from: 0);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final level = Prefs.level;
    return PopScope(
      // System back is disabled on the tab shell too, so it can't quit the
      // app out from under the player. Tabs are switched via the bottom nav;
      // there is no back stack to unwind here.
      canPop: false,
      // First tap anywhere ends the cold-start ad's launch window — a
      // late-loading ad must ride the launch transition, never interrupt a
      // player who has already started doing something. Translucent, so
      // every event still reaches its real target.
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => AdService.onUserInteracted(),
        child: Scaffold(
      backgroundColor: AppColors.bg,
      body: IndexedStack(
        index: _tab,
        children: [
          HomeScreen(onPlay: _play),
          MonthDetailScreen(
            key: ValueKey('$_challengeYear-$_challengeMonth'),
            initialYear: _challengeYear ?? DateTime.now().year,
            initialMonth: _challengeMonth ?? DateTime.now().month,
          ),
          CollectionScreen(onBadgeCleared: () => setState(() {})),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _navSlideCtrl,
          curve: Curves.easeOut,
        )),
        child: AppBottomNav(
          index: _tab,
          level: level,
          onTap: (i) {
            if (i == 1) ChallengeService.markSeen();
            if (i == 2 && Prefs.collectionUnseen) Prefs.setCollectionUnseen(false);
            setState(() => _tab = i);
          },
          showChallengeBadge: ChallengeService.hasUnseen,
          showCollectionBadge: Prefs.collectionUnseen || LevelLegend.hasUnseen || PerfectPlay.hasUnseen || Unstoppable.hasUnseen,
        ),
      ),
          // Separation between the nav's tap targets and the ad. AdMob
          // prohibits placements likely to draw accidental clicks, and
          // accidental clicks also depress eCPM over time because advertisers
          // see the poor post-click behaviour. The nav's own 10px bottom
          // padding alone left the tap row too close to the banner edge.
          Container(color: AppColors.navBg, height: 6),
          // Anchored collapsible banner sits below the nav bar, at the very
          // bottom edge of the screen — matches Google's anchored-adaptive
          // banner placement guidance. Space is reserved (empty) as soon as
          // the size is known, before the ad itself finishes loading, and
          // kept reserved even if the load ultimately fails — collapsing it
          // back would just trade one layout shift for another.
          if (_bannerAd != null)
            SizedBox(
              height: _bannerAd!.size.height.toDouble(),
              width: _bannerAd!.size.width.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            )
          else if (_bannerSize != null)
            Container(
              color: AppColors.navBg,
              height: _bannerSize!.height.toDouble(),
              width: _bannerSize!.width.toDouble(),
            ),
          // Safe-area bottom inset only (no extra fixed padding — the inset
          // alone is enough to keep the ad off the home-indicator edge).
          // Colored to match the nav bar so it reads as one continuous
          // bottom bar, not a stray gap.
          // Half the home-indicator safe-area inset — device-adaptive (0 on
          // older home-button phones, ~17pt on notch/Dynamic-Island phones)
          // but tighter than the full 34pt Apple inset, which is more than
          // the gesture zone needs. Banner sits above this, so it stays clear
          // of the home-indicator gesture. Colored to match the nav bar.
          Container(
            color: AppColors.navBg,
            height: MediaQuery.of(context).padding.bottom * 0.5,
          ),
        ],
      ),
      ),
      ),
    );
  }
}

/// Launches today's (or [date]'s) daily challenge full-screen.
/// Completes when the player leaves the challenge.
Future<void> startDailyChallenge(BuildContext context, DateTime date) {
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder(
      pageBuilder: (_, __, ___) => GameFlow(challengeDate: date),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 250),
    ),
  );
}

/// A deterministic difficulty seed for a given calendar day. Daily challenges
/// run in [daily] mode (large boards, Hard+ tiers) so this maps to the harder
/// end of the curve; the value also drives the daily tier cycle (H/SH/NM).
int dailyLevelFor(DateTime date) {
  final ord = DateTime(date.year, date.month, date.day)
      .difference(DateTime(2026, 1, 1))
      .inDays;
  return 40 + (ord % 60); // 40..99 — big, varied, consistent per day
}

/// Immersive game flow (full-screen, no nav): intro card → gameplay, advancing
/// through levels. Back returns to the shell; the level is persisted on win.
/// When [challengeDate] is set, runs that day's daily challenge instead of the
/// main progression (completion is recorded against the date, not Prefs.level).
class GameFlow extends StatefulWidget {
  final DateTime? challengeDate;
  const GameFlow({super.key, this.challengeDate});
  @override
  State<GameFlow> createState() => _GameFlowState();
}

class _GameFlowState extends State<GameFlow> {
  final GameController _controller = GameController();
  late int _level;

  bool get _isDaily => widget.challengeDate != null;

  @override
  void initState() {
    super.initState();
    _level = _isDaily ? dailyLevelFor(widget.challengeDate!) : Prefs.level;
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool get _isToday {
    final n = DateTime.now();
    final d = widget.challengeDate!;
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  /// Restores a partly-played daily board for this challenge's date.
  void _restoreDaily(GameController c) {
    final date = widget.challengeDate!;
    final remaining = ChallengeService.remainingFor(date);
    if (remaining == null || remaining.isEmpty) return;
    c.restoreState(remaining.toSet(), ChallengeService.heartsFor(date));
  }

  /// Wipes this date's saved board (after an in-game restart).
  void _clearDailyState() {
    ChallengeService.clearFor(widget.challengeDate!);
  }

  /// Saves the partly-played board when leaving an unfinished daily so
  /// "Continue" resumes from the last state (and drives the calendar ring).
  /// A fresh/reset board (progress 0) clears any stale saved state instead.
  /// Awaited before popping so it survives an app kill.
  Future<void> _saveDailyProgress() async {
    if (!_isDaily) return;
    final date = widget.challengeDate!;
    final total = _controller.total;
    if (total == 0) return;
    // exclude arrows mid-flight — they're committed as fired
    final remainingArrows = _controller.liveArrows;
    final prog = 1 - remainingArrows.length / total;
    if (prog > 0 && prog < 1) {
      await ChallengeService.saveFor(
        date,
        remainingIds: remainingArrows.map((a) => a.id).toList(),
        hearts: _controller.hearts,
        progress: prog,
      );
    } else {
      await ChallengeService.clearFor(date); // fresh board → no ring
    }
  }

  Future<void> _completeDaily() async {
    final date = widget.challengeDate!;
    // record the day so the trophy count + green dot update
    final days = List<String>.from(Prefs.playedDays);
    final key = _fmt(date);
    if (!days.contains(key)) {
      days.add(key);
      await Prefs.setPlayedDays(days);
    }
    await ChallengeService.clearFor(date); // no leftover progress
    if (_isToday) {
      await ChallengeService.completeToday();
    }
  }

  // Return the pushReplacement future so callers can run code (the rate prompt)
  // after the celebration is dismissed.
  Future<void> _showLevelLegendCelebration(int newLevel) {
    return Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => _LevelLegendCelebration(milestone: newLevel),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  Future<void> _showPerfectPlayCelebration() {
    return Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => _PerfectPlayCelebration(milestone: PerfectPlay.reached),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  /// Shows the after-win rate prompt (if gated) once we're back on home. Called
  /// from the plain-win branch after maybePop(). Uses the app-level [context]
  /// (above the game/home navigator) so the dialog — and its 1-4★ feedback /
  /// 5★ native-review follow-ups — layer cleanly over home instead of racing
  /// the just-popped game screen.
  void _maybeShowRatePrompt() {
    if (_isDaily) return;
    if (!RatePrompt.shouldShowForNotedWin()) return;
    RatePrompt.markShown();
    // By the time this runs we're back on home and this GameFlow route (and its
    // State) is gone — so show the prompt on the home shell's context, which
    // survives, once the return transition settles. Layering the dialog over
    // home (rather than the game screen) is also what keeps the 1-4★ feedback
    // follow-up from corrupting the navigation stack.
    Future.delayed(const Duration(milliseconds: 350), () {
      final ctx = mainShellKey.currentContext;
      if (ctx != null) {
        showRateDialog(ctx, onFiveStars: requestNativeReview);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GameScreen(
      key: ValueKey('game_$_level'),
      controller: _controller,
      level: _level,
      isDaily: _isDaily,
      onLoaded: _isDaily ? _restoreDaily : null,
      onDidRestart: _isDaily ? _clearDailyState : null,
      // Rewarded skip from the lose overlay — main progression only (a
      // skipped daily would grant the calendar trophy unearned). Advances the
      // level WITHOUT the win path: no LevelLegend/Perfect awards for a level
      // that wasn't beaten, and no win interstitial — the player just watched
      // a rewarded ad, stacking a second full-screen ad on top of it is how
      // "Modified ad behavior" policy flags happen.
      onSkip: _isDaily
          ? null
          : () {
              StreakService.registerPlayToday();
              final next = _level + 1;
              Prefs.setLevel(next);
              AnalyticsService.levelSkip(_level);
              Navigator.of(context).pop();
            },
      onBack: () async {
        final nav = Navigator.of(context);
        if (_isDaily) await _saveDailyProgress();
        // pop(), not maybePop(): GameScreen wraps itself in
        // PopScope(canPop: false) to disable the system back gesture, and
        // maybePop() honours that — it would block this button too.
        nav.pop();
      },
      onWin: (next) async {
        final streakExtended = !StreakService.playedToday;
        StreakService.registerPlayToday();
        if (streakExtended) {
          AnalyticsService.streakExtended(StreakService.current);
        }
        if (_isDaily) {
          await _completeDaily();
          AnalyticsService.levelWin(_level, daily: true);
          AnalyticsService.dailyChallengeComplete();
          if (!mounted) return;
        } else {
          Prefs.setLevel(next);
          LevelLegend.onWin(next);
          AnalyticsService.levelWin(_level);
          if (next == 10) Prefs.setCollectionUnseen(true);
          if (!mounted) return;
        }
        // First install day (streak == 1): defer celebration until level 10.
        // Subsequent days (streak 2+): celebrate on first win as usual.
        final isFirstDay = StreakService.current == 1;
        final showStreak = isFirstDay
            ? (!_isDaily && next == 10)
            : streakExtended;

        // Interstitial has top priority (every 2nd win / each daily complete).
        // Everything else — streak/legend/perfect celebration, then the rate
        // prompt — is sequenced AFTER the ad is dismissed so nothing stacks on
        // top of it. When no ad shows, [afterAd] fires immediately with
        // adShown=false. The rate prompt runs after a celebration too, EXCEPT
        // when an ad also played this win (ad + celebration + rate = too much).
        void afterAd(bool adShown) {
          if (!mounted) return;
          if (showStreak) {
            Navigator.of(context).pushReplacement(PageRouteBuilder(
              pageBuilder: (ctx, __, ___) => StreakCelebration(
                streak: StreakService.current,
                onContinue: () => Navigator.of(ctx).maybePop(),
              ),
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 300),
            )).then((_) {
              if (!adShown) _maybeShowRatePrompt();
            });
          } else if (!_isDaily && LevelLegend.justUnlockedMilestone(next)) {
            _showLevelLegendCelebration(next).then((_) {
              if (!adShown) _maybeShowRatePrompt();
            });
          } else if (!_isDaily && PerfectPlay.justUnlockedMilestone()) {
            _showPerfectPlayCelebration().then((_) {
              if (!adShown) _maybeShowRatePrompt();
            });
          } else {
            // Plain win → return home, then (occasionally) ask for a rating
            // (whether or not an ad played this win). pop(), not maybePop(),
            // for the same reason as onBack: GameScreen's PopScope would
            // otherwise trap the player on the finished level.
            Navigator.of(context).pop();
            _maybeShowRatePrompt();
          }
        }

        if (_isDaily) {
          _dailyCompleteAd(afterAd);
        } else {
          AdService.onLevelWin(onDone: afterAd);
        }
      },
    );
  }

  /// Daily challenge completion ad. Same plain interstitial as a normal
  /// level win — no reward, no intro screen. [afterAd] runs exactly once,
  /// since the celebration sequencing hangs off it.
  void _dailyCompleteAd(void Function(bool adShown) afterAd) {
    AdService.onDailyComplete(onDone: afterAd);
  }
}
class _LevelLegendCelebration extends StatelessWidget {
  final int milestone;
  const _LevelLegendCelebration({required this.milestone});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            children: [
              const Spacer(flex: 3),
              SizedBox(
                width: 230,
                height: 230,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                          painter: StarMedalPainter(unlocked: true)),
                    ),
                    Align(
                      alignment: const Alignment(0, 0.96),
                      child: _CelebBadge('$milestone'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(Tr.get('newUnlock'),
                    style: poppins(13.5, FontWeight.w700, AppColors.muted)),
              ),
              const SizedBox(height: 18),
              Text(
                Tr.param('levelLegendEarned', {'milestone': '$milestone'}),
                textAlign: TextAlign.center,
                style: poppins(20, FontWeight.w800, AppColors.ink),
              ),
              const Spacer(flex: 5),
              GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: AppColors.blue,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  alignment: Alignment.center,
                  child: Text(Tr.get('continueButton'),
                      style: poppins(18, FontWeight.w800, Colors.white)),
                ),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class _PerfectPlayCelebration extends StatelessWidget {
  final int milestone;
  const _PerfectPlayCelebration({required this.milestone});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            children: [
              const Spacer(flex: 3),
              SizedBox(
                width: 230,
                height: 230,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                          painter: TargetMedalPainter(unlocked: true)),
                    ),
                    Align(
                      alignment: const Alignment(0, 0.96),
                      child: _CelebBadge('$milestone'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(Tr.get('newUnlock'),
                    style: poppins(13.5, FontWeight.w700, AppColors.muted)),
              ),
              const SizedBox(height: 18),
              Text(
                Tr.param('perfectPlayEarned', {'milestone': '$milestone'}),
                textAlign: TextAlign.center,
                style: poppins(20, FontWeight.w800, AppColors.ink),
              ),
              const Spacer(flex: 5),
              GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: AppColors.blue,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  alignment: Alignment.center,
                  child: Text(Tr.get('continueButton'),
                      style: poppins(18, FontWeight.w800, Colors.white)),
                ),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class _CelebBadge extends StatelessWidget {
  final String value;
  const _CelebBadge(this.value);
  @override
  Widget build(BuildContext context) {
    const fs = 40.0;
    final base = poppins(fs, FontWeight.w900, Colors.white);
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(value,
            style: base.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = fs * 0.3
                ..strokeJoin = StrokeJoin.round
                ..color = Prefs.darkMode ? const Color(0xFF3A4060) : const Color(0xFF6F7596),
            )),
        Text(value, style: base),
      ],
    );
  }
}
