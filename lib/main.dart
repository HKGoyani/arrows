import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_service.dart';
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
import 'settings_screen.dart';
import 'streak.dart';
import 'streak_screen.dart';
import 'ui_kit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await Prefs.init();
  await AudioService.init();
  await AdService.init();
  await IapService.init();
  runApp(ArrowsApp());
}

final appKey = GlobalKey<_ArrowsAppState>();

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
      title: 'Arrow Escape',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(scaffoldBackgroundColor: AppColors.bg, useMaterial3: true),
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

class _MainShellState extends State<MainShell> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
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
  BannerAd? _bannerAd;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bannerAd = AdService.createBanner();
    _navSlideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _navSlideCtrl.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AudioService.onAppResume();
      AdService.showAppOpenIfReady();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      AudioService.onAppPause();
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
    return Scaffold(
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
          if (_bannerAd != null)
            SizedBox(
              height: _bannerAd!.size.height.toDouble(),
              width: _bannerAd!.size.width.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            ),
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
        ],
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

  void _showLevelLegendCelebration(int newLevel) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => _LevelLegendCelebration(milestone: newLevel),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _showPerfectPlayCelebration() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => _PerfectPlayCelebration(milestone: PerfectPlay.reached),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
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
      onBack: () async {
        final nav = Navigator.of(context);
        if (_isDaily) await _saveDailyProgress();
        nav.maybePop();
      },
      onWin: (next) async {
        final streakExtended = !StreakService.playedToday;
        StreakService.registerPlayToday();
        if (_isDaily) {
          await _completeDaily();
          AdService.onDailyComplete();
          if (!mounted) return;
        } else {
          Prefs.setLevel(next);
          LevelLegend.onWin(next);
          AdService.onLevelWin();
          if (next == 10) Prefs.setCollectionUnseen(true);
          if (!mounted) return;
        }
        // First install day (streak == 1): defer celebration until level 10.
        // Subsequent days (streak 2+): celebrate on first win as usual.
        final isFirstDay = StreakService.current == 1;
        final showStreak = isFirstDay
            ? (!_isDaily && next == 10)
            : streakExtended;
        if (showStreak) {
          Navigator.of(context).pushReplacement(PageRouteBuilder(
            pageBuilder: (ctx, __, ___) => StreakCelebration(
              streak: StreakService.current,
              onContinue: () => Navigator.of(ctx).maybePop(),
            ),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 300),
          ));
        } else if (!_isDaily && LevelLegend.justUnlockedMilestone(next)) {
          _showLevelLegendCelebration(next);
        } else if (!_isDaily && PerfectPlay.justUnlockedMilestone()) {
          _showPerfectPlayCelebration();
        } else {
          Navigator.of(context).maybePop();
        }
      },
    );
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
