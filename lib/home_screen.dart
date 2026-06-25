import 'package:flutter/material.dart';
import 'config.dart';
import 'prefs.dart';
import 'streak.dart';
import 'streak_screen.dart';
import 'ui_kit.dart';
import 'widgets.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onPlay;
  const HomeScreen({super.key, required this.onPlay});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  int _prevLevel = 0;
  int _currLevel = 0;

  @override
  void initState() {
    super.initState();
    _currLevel = Prefs.level;
    _prevLevel = _currLevel;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newLevel = Prefs.level;
    if (newLevel != _currLevel) {
      _prevLevel = _currLevel;
      _currLevel = newLevel;
      _ctrl.forward(from: 0).then((_) {
        if (mounted) setState(() => _prevLevel = _currLevel);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final streak = StreakService.current;
    final showCounter = _prevLevel != _currLevel;

    final appearAnim = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
    );
    final levelBumpAnim = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.25, 0.55, curve: Curves.easeOut),
    );
    final playAnim = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.55, 0.85, curve: Curves.easeOut),
    );

    return Stack(
      children: [
        const Positioned.fill(child: CustomPaint(painter: DotGridPainter())),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
            child: Column(
              children: [
                FadeTransition(
                  opacity: appearAnim,
                  child: Center(
                    // hidden entirely when there's no streak yet
                    child: streak == 0
                        ? const SizedBox(height: 19)
                        : GestureDetector(
                            onTap: () => showStreakDetail(context, streak),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 11, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  streakFlame(
                                      size: 28,
                                      active: StreakService.playedToday),
                                  const SizedBox(width: 4),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 1),
                                    child: Text('$streak',
                                        style: poppins(20, FontWeight.w900,
                                            const Color(0xFF535B83))),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),
                ),
                const Spacer(flex: 4),
                FadeTransition(
                  opacity: appearAnim,
                  child: const ArrowsWordmark(),
                ),
                const SizedBox(height: 8),
                FadeTransition(
                  opacity: appearAnim,
                  child: Text('Clear every arrow on the board',
                      style: poppins(13.5, FontWeight.w800, AppColors.muted)),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 32,
                  child: showCounter
                      ? AnimatedBuilder(
                          animation: levelBumpAnim,
                          builder: (_, __) {
                            final t = levelBumpAnim.value;
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Level ', style: poppins(20, FontWeight.w900, AppColors.blue)),
                                ClipRect(
                                  child: SizedBox(
                                    width: 30,
                                    height: 32,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Transform.translate(
                                          offset: Offset(0, 30 * t),
                                          child: Opacity(
                                            opacity: (1 - t).clamp(0.0, 1.0),
                                            child: Text('$_prevLevel',
                                                style: poppins(20, FontWeight.w900, AppColors.blue)),
                                          ),
                                        ),
                                        Transform.translate(
                                          offset: Offset(0, -30 * (1 - t)),
                                          child: Opacity(
                                            opacity: t.clamp(0.0, 1.0),
                                            child: Text('$_currLevel',
                                                style: poppins(20, FontWeight.w900, AppColors.blue)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        )
                      : FadeTransition(
                          opacity: appearAnim,
                          child: Text('Level $_currLevel',
                              style: poppins(20, FontWeight.w900, AppColors.blue)),
                        ),
                ),
                const Spacer(flex: 3),
                AnimatedBuilder(
                  animation: _ctrl,
                  builder: (_, __) => IgnorePointer(
                    ignoring: _ctrl.value < 0.85,
                    child: FadeTransition(
                      opacity: playAnim,
                      child: PrimaryButton(
                          label: 'Play',
                          onTap: widget.onPlay,
                          width: 280),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FadeTransition(
                  opacity: playAnim,
                  child: Text(_currLevel > 1 ? 'Continue your run' : 'Tap to begin',
                      style: poppins(13, FontWeight.w800, AppColors.muted)),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
