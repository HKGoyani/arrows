import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'audio.dart';
import 'collection_screen.dart';
import 'config.dart';
import 'game_controller.dart';
import 'game_screen.dart';
import 'home_screen.dart';
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

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _tab = 0; // Home

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
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
        .push(MaterialPageRoute(builder: (_) => const GameFlow()));
    if (mounted) setState(() {}); // refresh stats after returning
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
      bottomNavigationBar: AppBottomNav(
        index: _tab,
        level: level,
        onTap: (i) => setState(() => _tab = i),
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

  @override
  Widget build(BuildContext context) {
    return GameScreen(
      key: ValueKey('game_$_level'),
      controller: _controller,
      level: _level,
      onBack: () => Navigator.of(context).maybePop(),
      onWin: (next) {
        Prefs.setLevel(next);
        setState(() {
          _level = next;
        });
      },
    );
  }
}
