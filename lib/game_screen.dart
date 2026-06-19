import 'dart:math';
import 'package:flutter/material.dart';
import 'audio.dart';
import 'board_painter.dart';
import 'config.dart';
import 'confetti.dart';
import 'fly_off.dart';
import 'game_controller.dart';
import 'models.dart';
import 'rng.dart';
import 'ui_kit.dart';
import 'widgets.dart';

class GameScreen extends StatefulWidget {
  final GameController controller;
  final int level;
  final VoidCallback onBack;
  final void Function(int nextLevel) onWin;
  const GameScreen({
    super.key,
    required this.controller,
    required this.level,
    required this.onBack,
    required this.onWin,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _Flight {
  final FlyOff fly;
  final Arrow arrow;
  final AnimationController ctrl;
  bool disposed = false;
  _Flight(this.fly, this.arrow, this.ctrl);
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late final AnimationController _rippleCtrl;
  Offset? _rippleCenter;
  final List<_Flight> _flights = [];
  double _scale = 1;
  bool _winHandled = false;

  GameController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _rippleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420))
      ..addListener(_rebuild);
    c.addListener(_rebuild);
    c.loadLevel(widget.level);
  }

  @override
  void dispose() {
    c.removeListener(_rebuild);
    _rippleCtrl.dispose();
    for (final f in _flights) {
      _disposeFlight(f);
    }
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _disposeFlight(_Flight f) {
    if (f.disposed) return;
    f.disposed = true;
    f.ctrl.removeListener(_rebuild);
    f.ctrl.dispose();
  }

  void _onTapDown(TapDownDetails d) {
    final cell = d.localPosition / _scale;
    final a = c.hitTest(cell.dx, cell.dy);
    if (a == null || c.status != GameStatus.playing) return;
    _spawnRipple(a);
    if (c.isClear(a)) {
      _fire(a);
    } else {
      AudioService.clash();
      AudioService.vibrate(Haptic.heavy);
      c.clash(a);
    }
  }

  void _spawnRipple(Arrow a) {
    double sx = 0, sy = 0;
    for (final p in a.pts) {
      sx += Cfg.margin + p.x * Cfg.cell;
      sy += Cfg.margin + p.y * Cfg.cell;
    }
    _rippleCenter = Offset(sx / a.pts.length, sy / a.pts.length);
    _rippleCtrl.forward(from: 0);
  }

  void _fire(Arrow a) {
    AudioService.tap();
    AudioService.vibrate(Haptic.light);
    final ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: Cfg.flyHoldMs + Cfg.flyDurMs));
    final flight = _Flight(FlyOff.forArrow(a), a, ctrl);
    ctrl.addListener(_rebuild);
    ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) _finish(flight);
    });
    _flights.add(flight);
    c.startFire(a); // free cells now so neighbours open up
    ctrl.forward();
  }

  void _finish(_Flight f) {
    if (!_flights.remove(f)) return;
    c.completeFire(f.arrow);
    WidgetsBinding.instance.addPostFrameCallback((_) => _disposeFlight(f));
    if (c.status == GameStatus.won) _handleWin();
    _rebuild();
  }

  void _handleWin() {
    if (_winHandled) return;
    _winHandled = true;
    AudioService.win();
    AudioService.vibrate(Haptic.medium);
    Future.delayed(const Duration(milliseconds: 2300), () {
      if (mounted) widget.onWin(c.level + 1);
    });
  }

  void _restart() {
    for (final f in _flights) {
      _disposeFlight(f);
    }
    _flights.clear();
    _rippleCenter = null;
    _winHandled = false;
    c.loadLevel(c.level);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GameTopBar(c: c, onBack: widget.onBack, onRestart: _restart),
                ProgressBar(progress: c.progress),
                Expanded(child: _boardArea()),
              ],
            ),
            if (c.status == GameStatus.won) _winOverlay(),
            if (c.status == GameStatus.lost) _loseOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _boardArea() {
    return LayoutBuilder(builder: (context, constraints) {
      final vbW = c.cols * Cfg.cell + 2 * Cfg.margin;
      final vbH = c.rows * Cfg.cell + 2 * Cfg.margin;
      final availW = constraints.maxWidth - 24;
      final availH = constraints.maxHeight - 16;
      final screenW = MediaQuery.of(context).size.width;
      final maxW = min(availW, screenW * Cfg.widthFraction);
      final maxH = availH * Cfg.heightFraction;
      _scale = [Cfg.targetCell / Cfg.cell, maxW / vbW, maxH / vbH]
          .reduce((a, b) => a < b ? a : b);
      final boardPx = Size(vbW * _scale, vbH * _scale);

      final flights = _flights.map((f) {
        final elapsed = f.ctrl.value * (Cfg.flyHoldMs + Cfg.flyDurMs);
        final p = ((elapsed - Cfg.flyHoldMs) / Cfg.flyDurMs).clamp(0.0, 1.0);
        return (fly: f.fly, adv: flyEase(p) * f.fly.total);
      }).toList();

      return Center(
        child: SizedBox.fromSize(
          size: boardPx,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: _onTapDown,
            child: CustomPaint(
              painter: BoardPainter(
                c: c,
                flights: flights,
                rippleCenter: _rippleCenter,
                rippleT: _rippleCtrl.value,
              ),
            ),
          ),
        ),
      );
    });
  }

  static const _winWords = [
    'Awesome!', 'Fabulous!', 'Fantastic!', 'Terrific!', 'Excellent!',
    'Great!', 'Wonderful!', 'Superb!', 'Magnificent!', 'Phenomenal!',
    'Stunning!', 'Stellar!', 'Mind-blowing!', 'Marvelous!',
    'Brilliant!', 'Well done!', 'Outstanding!',
  ];

  String _winMessage() => _winWords[c.level % _winWords.length];

  Widget _winOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            const Positioned.fill(child: ConfettiOverlay()),
            Align(
              alignment: const Alignment(0, -0.10),
              child: Text(_winMessage(), style: poppins(34, FontWeight.w800, AppColors.ink)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _loseOverlay() {
    return Positioned.fill(
      child: Container(
        color: AppColors.bg,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Game Over', style: poppins(34, FontWeight.w800, AppColors.red)),
            const SizedBox(height: 26),
            PrimaryButton(label: 'Retry level', onTap: _restart, width: 220),
          ],
        ),
      ),
    );
  }
}
