import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'audio.dart';
import 'board_painter.dart';
import 'config.dart';
import 'confetti.dart';
import 'fly_off.dart';
import 'game_controller.dart';
import 'models.dart';
import 'prefs.dart';
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
  late final AnimationController _clashFlashCtrl;
  late final AnimationController _lurchCtrl;
  Offset? _rippleCenter;
  final List<_Flight> _flights = [];
  Arrow? _flashBlocker;
  Arrow? _lurchArrow;
  double _lurchDist = 0;
  bool _clashImpactFired = false;
  bool _showGrid = false;
  bool _showHint = false;
  Arrow? _hintArrow;
  final Set<int> _hintedIds = {};
  Timer? _hintTimer;
  late final AnimationController _hintPulseCtrl;
  late final AnimationController _heartCtrl;
  bool _showWinText = false;
  bool _showWinConfetti = false;
  double _scale = 1;
  bool _winHandled = false;

  GameController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _rippleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420))
      ..addListener(_rebuild);
    _clashFlashCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500))
      ..addListener(_rebuild);
    _lurchCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350))
      ..addListener(_onLurchTick);
    _hintPulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..addListener(_rebuild);
    _heartCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..addListener(_rebuild);
    c.addListener(_rebuild);
    c.loadLevel(widget.level);
    _resetHintTimer();
  }

  void _resetHintTimer() {
    _hintTimer?.cancel();
    _showHint = false;
    _startHintTimer();
  }

  void _startHintTimer() {
    _hintTimer?.cancel();
    _hintTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && c.status == GameStatus.playing) {
        setState(() => _showHint = true);
      }
    });
  }

  void _useHint() {
    if (_lurchCtrl.isAnimating || _clashFlashCtrl.isAnimating) return;
    final safe = c.arrows
        .where((a) => a.state == ArrowState.idle && c.isClear(a) && !_hintedIds.contains(a.id))
        .toList();
    if (safe.isEmpty) {
      setState(() => _showHint = false);
      _startHintTimer();
      return;
    }
    setState(() {
      _hintArrow = safe.first;
      _hintedIds.add(safe.first.id);
      _showHint = false;
    });
    _hintPulseCtrl.forward(from: 0);
    _startHintTimer();
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    c.removeListener(_rebuild);
    _rippleCtrl.dispose();
    _heartCtrl.dispose();
    _clashFlashCtrl.dispose();
    _lurchCtrl.dispose();
    _hintPulseCtrl.dispose();
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

  void _onTapUp(TapUpDetails d) {
    final cell = d.localPosition / _scale;
    final a = c.hitTest(cell.dx, cell.dy);
    if (a == null || c.status != GameStatus.playing) return;
    _spawnRipple(a);
    if (c.isClear(a)) {
      if (a.state == ArrowState.clashed) a.state = ArrowState.idle;
      _showGrid = false;
      if (_hintArrow != null && a.id == _hintArrow!.id) {
        _hintArrow = null;
        _hintPulseCtrl.reset();
      }
      _resetHintTimer();
      _fire(a);
    } else {
      _flashBlocker = c.findBlocker(a);
      if (a.state == ArrowState.idle) c.clash(a);
      if (c.status == GameStatus.lost) {
        _hintTimer?.cancel();
        _showHint = false;
      }
      _lurchArrow = a;
      _lurchDist = _calcBlockerDist(a);
      _clashImpactFired = false;
      _lurchCtrl.forward(from: 0).then((_) {
        _lurchArrow = null;
        _rebuild();
      });
    }
  }

  void _onLurchTick() {
    if (!_clashImpactFired && _lurchCtrl.value >= 0.3) {
      _clashImpactFired = true;
      AudioService.clash();
      AudioService.vibrate(Haptic.heavy);
      _clashFlashCtrl.forward(from: 0).then((_) {
        _flashBlocker = null;
        _rebuild();
      });
    }
    _rebuild();
  }

  double _calcBlockerDist(Arrow a) {
    var x = a.head.x, y = a.head.y;
    var steps = 0;
    while (true) {
      x += a.dir.dx;
      y += a.dir.dy;
      steps++;
      final o = c.occ[cellKey(x, y)];
      if (o != null && o != a.id) break;
      if (x < 0 || x > c.cols || y < 0 || y > c.rows) break;
    }
    return max(0, (steps - 0.3)) * Cfg.cell;
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
    c.startFire(a);
    final remaining = c.arrows.where((ar) => ar.state != ArrowState.leaving).length;
    if (remaining == 0 && !_winHandled) {
      _heartCtrl.forward(from: 0);
      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        setState(() {
          _showWinText = true;
          _showWinConfetti = true;
        });
      });
    }
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
    _hintTimer?.cancel();
    _showHint = false;
    _showGrid = false;
    AudioService.win();
    AudioService.vibrate(Haptic.medium);
    if (!_heartCtrl.isAnimating) _heartCtrl.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 2800), () {
      if (mounted) widget.onWin(c.level + 1);
    });
  }

  void _restart() {
    _clashFlashCtrl.reset();
    _lurchCtrl.reset();
    _flashBlocker = null;
    _lurchArrow = null;
    for (final f in _flights) {
      _disposeFlight(f);
    }
    _flights.clear();
    _rippleCenter = null;
    _winHandled = false;
    _showGrid = false;
    _hintArrow = null;
    _hintedIds.clear();
    _hintPulseCtrl.reset();
    _heartCtrl.reset();
    _showWinText = false;
    _showWinConfetti = false;
    c.loadLevel(c.level);
    _resetHintTimer();
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
                AnimatedBuilder(
                  animation: _heartCtrl,
                  builder: (_, child) => Opacity(
                    opacity: (1.0 - _heartCtrl.value * 3.0).clamp(0.0, 1.0),
                    child: child,
                  ),
                  child: Column(
                    children: [
                      GameTopBar(c: c, onBack: widget.onBack, onRestart: _restart),
                      ProgressBar(progress: c.progress),
                    ],
                  ),
                ),
                Expanded(
                  child: ClipRect(
                    child: Stack(
                      children: [
                        _boardArea(),
                        if (_clashFlashCtrl.isAnimating) _clashFlashOverlay(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (_showHint && c.status == GameStatus.playing)
              Positioned(
                right: 0,
                top: 14,
                child: Pressable(
                  onTap: _useHint,
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.blue,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(22),
                        bottomLeft: Radius.circular(22),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.videocam_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 6),
                        Text('Hint', style: poppins(16, FontWeight.w800, Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),
            Positioned(
              right: 14,
              bottom: 10 + MediaQuery.of(context).padding.bottom,
              child: AnimatedBuilder(
                animation: _heartCtrl,
                builder: (_, child) => Opacity(
                  opacity: (1.0 - _heartCtrl.value * 3.0).clamp(0.0, 1.0),
                  child: child,
                ),
                child: GestureDetector(
                  onTap: () => setState(() => _showGrid = !_showGrid),
                  child: Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _showGrid ? AppColors.navPill : AppColors.btnBg,
                      borderRadius: BorderRadius.circular(_showGrid ? 13 : 23),
                      border: _showGrid ? Border.all(color: AppColors.blue, width: 1.5) : null,
                    ),
                    child: Icon(Icons.tag,
                        size: 32,
                        color: AppColors.btnInk,
                        shadows: [Shadow(color: AppColors.btnInk, blurRadius: 1)]),
                  ),
                ),
              ),
            ),
            if (_showWinText || _showWinConfetti) _winOverlay(),
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
            onTapUp: _onTapUp,
            child: CustomPaint(
              painter: BoardPainter(
                c: c,
                flights: flights,
                rippleCenter: _rippleCenter,
                rippleT: _rippleCtrl.value,
                flashBlocker: _flashBlocker,
                lurchArrow: _lurchArrow,
                lurchT: _lurchCtrl.value,
                lurchDist: _lurchDist,
                showGrid: _showGrid,
                hintArrow: _hintArrow,
                hintPulse: _hintPulseCtrl.value,
                hintedIds: _hintedIds,
                heartT: _heartCtrl.value,
                clashTint: _clashFlashCtrl.isAnimating
                    ? (_clashFlashCtrl.value < 0.15
                        ? _clashFlashCtrl.value / 0.15
                        : 1 - ((_clashFlashCtrl.value - 0.15) / 0.85))
                    : 0,
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _clashFlashOverlay() {
    final t = _clashFlashCtrl.value;
    final alpha = t < 0.15 ? t / 0.15 : 1 - ((t - 0.15) / 0.85);
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _RedVignettePainter(alpha * 0.6),
        ),
      ),
    );
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
            if (_showWinConfetti)
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeIn,
                  builder: (_, opacity, child) => Opacity(opacity: opacity, child: child!),
                  child: const ConfettiOverlay(),
                ),
              ),
            if (_showWinText)
              Align(
                alignment: const Alignment(0, -0.08),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 2800),
                  builder: (_, v, __) {
                    double opacity;
                    if (v < 0.14) {
                      opacity = v / 0.14;
                    } else if (v < 0.75) {
                      opacity = 1.0;
                    } else {
                      opacity = 1.0 - (v - 0.75) / 0.25;
                    }
                    return Opacity(
                      opacity: opacity.clamp(0.0, 1.0),
                      child: Text(_winMessage(), style: poppins(24, FontWeight.w800, const Color(0xFF3D3D5C))),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _addLife() {
    Prefs.setUsedFreeLife();
    c.addLife();
  }

  Widget _loseOverlay() {
    final canAddFree = !Prefs.usedFreeLife;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.5),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Out of lives',
                    style: poppins(24, FontWeight.w800, AppColors.ink)),
                const SizedBox(height: 24),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppColors.heartEmpty.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.favorite,
                          size: 52, color: AppColors.red),
                    ),
                    Positioned(
                      right: -8,
                      top: -4,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: canAddFree
                              ? const Color(0xFF4CAF50)
                              : AppColors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text('+1',
                              style: poppins(16, FontWeight.w800, Colors.white)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                GestureDetector(
                  onTap: canAddFree ? _addLife : null,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: canAddFree
                          ? const Color(0xFF4CAF50)
                          : AppColors.navPill,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!canAddFree) ...[
                          Icon(Icons.videocam_rounded,
                              size: 20,
                              color: canAddFree
                                  ? Colors.white
                                  : AppColors.blue),
                          const SizedBox(width: 8),
                        ],
                        Text('Add More Lives',
                            style: poppins(17, FontWeight.w800,
                                canAddFree ? Colors.white : AppColors.blue)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _restart,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: AppColors.cardBorder, width: 1.5),
                    ),
                    child: Center(
                      child: Text('Restart',
                          style: poppins(16, FontWeight.w800, AppColors.muted)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RedVignettePainter extends CustomPainter {
  final double alpha;
  _RedVignettePainter(this.alpha);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final inset = size.width * 0.15;

    canvas.saveLayer(rect, Paint());
    canvas.drawRect(rect, Paint()..color = AppColors.red.withValues(alpha: alpha));
    final erasePaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..blendMode = BlendMode.dstOut
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, inset * 1.2);
    canvas.drawRect(rect.deflate(inset * 0.4), erasePaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RedVignettePainter old) => old.alpha != alpha;
}
