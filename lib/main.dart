import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'audio.dart';
import 'collection_icons.dart';
import 'collection_screen.dart';
import 'config.dart';
import 'game_controller.dart';
import 'game_screen.dart';
import 'home_screen.dart';
import 'level_legend.dart';
import 'unstoppable.dart';
import 'prefs.dart';
import 'settings_screen.dart';
import 'streak.dart';
import 'ui_kit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await Prefs.init();
  await AudioService.init();
  runApp(const ArrowsApp());
}

class ArrowsApp extends StatelessWidget {
  const ArrowsApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arrow Escape',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(scaffoldBackgroundColor: AppColors.bg, useMaterial3: true),
      home: const MainShell(),
    );
  }
}

/// Home · Streak · Settings tabs. The game launches full-screen on top.
class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  int _tab = 0;
  late final AnimationController _navSlideCtrl;

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
  void dispose() {
    _navSlideCtrl.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AudioService.onAppResume();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      AudioService.onAppPause();
    }
  }

  Future<void> _play() async {
    StreakService.registerPlayToday();
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
          const SizedBox.shrink(), // Level 20 placeholder (locked)
          const CollectionScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: SlideTransition(
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
            if (i == 2 && LevelLegend.hasUnseen) {
              // don't clear yet — clear when they view the detail
            }
            setState(() => _tab = i);
          },
          showCollectionBadge: LevelLegend.hasUnseen || Unstoppable.hasUnseen,
        ),
      ),
    );
  }
}

/// Immersive game flow (full-screen, no nav): intro card → gameplay, advancing
/// through levels. Back returns to the shell; the level is persisted on win.
class GameFlow extends StatefulWidget {
  const GameFlow({super.key});
  @override
  State<GameFlow> createState() => _GameFlowState();
}

class _GameFlowState extends State<GameFlow> {
  final GameController _controller = GameController();
  late int _level;

  @override
  void initState() {
    super.initState();
    _level = Prefs.level;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showCelebration(int newLevel) {
    final solved = newLevel - 1;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => _CelebrationScreen(milestone: solved),
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
      onBack: () => Navigator.of(context).maybePop(),
      onWin: (next) {
        Prefs.setLevel(next);
        LevelLegend.onWin(next);
        if (!mounted) return;
        if (LevelLegend.justUnlockedMilestone(next)) {
          _showCelebration(next);
        } else {
          Navigator.of(context).maybePop();
        }
      },
    );
  }
}

class _CelebrationScreen extends StatelessWidget {
  final int milestone;
  const _CelebrationScreen({required this.milestone});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
                  color: const Color(0xFFF1F2F8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('New Unlock!',
                    style: poppins(13.5, FontWeight.w700, AppColors.muted)),
              ),
              const SizedBox(height: 18),
              Text(
                'You earned Level Legend by\nreaching level $milestone!',
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
                  child: Text('Continue',
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
                ..color = const Color(0xFF6F7596),
            )),
        Text(value, style: base),
      ],
    );
  }
}
