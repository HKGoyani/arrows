import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_service.dart';
import 'analytics_service.dart';
import 'audio.dart';
import 'l10n.dart';
import 'board_painter.dart';
import 'config.dart';
import 'confetti.dart';
import 'fly_off.dart';
import 'game_controller.dart';
import 'hand_levels.dart';
import 'models.dart';
import 'perfect.dart';
import 'records.dart';
import 'unstoppable.dart';
import 'prefs.dart';
import 'rng.dart';
import 'ui_kit.dart';
import 'widgets.dart';

class GameScreen extends StatefulWidget {
  final GameController controller;
  final int level;
  final VoidCallback onBack;
  final void Function(int nextLevel) onWin;
  // daily-challenge mode: skips main-progression award tracking and lets the
  // caller restore a saved board right after the level loads.
  final bool isDaily;
  final void Function(GameController c)? onLoaded;
  final VoidCallback? onDidRestart;
  const GameScreen({
    super.key,
    required this.controller,
    required this.level,
    required this.onBack,
    required this.onWin,
    this.isDaily = false,
    this.onLoaded,
    this.onDidRestart,
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
  bool _restartHidden = false;
  BannerAd? _bannerAd;

  // Pinch-to-zoom: board is scaled to fit viewport at 1x.
  // User can zoom in up to _maxZoom. Intro animates from 1x to _defaultZoom.
  final TransformationController _zoomCtrl = TransformationController();
  late final AnimationController _zoomIntroCtrl;
  bool _introPlayed = false;
  // Dynamic zoom based on grid size — computed in _boardArea.
  double _maxZoom = 2.0;
  double _defaultZoom = 1.2;

  // Tutorial (level 1): minimal UI + "Tap to move" prompt with a finger that
  // bounces over an arrow. Both disappear after the player's first move.
  late final AnimationController _fingerCtrl;
  bool _tutorialDone = false;
  bool get _isTutorial => !widget.isDaily && widget.level == tutorialLevel;

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
    _fingerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..addListener(_rebuild)
      ..repeat();
    _zoomIntroCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))
      ..addListener(_onZoomIntroTick);
    c.addListener(_rebuild);
    AdService.setPlaying(true);
    _bannerAd = AdService.createBanner();
    AnalyticsService.levelStart(widget.level, daily: widget.isDaily);
    c.loadLevel(widget.level, daily: widget.isDaily);
    if (widget.isDaily) {
      widget.onLoaded?.call(c); // restore saved board if any
    } else {
      PerfectPlay.onLevelStart(widget.level);
    }
    _resetHintTimer();
  }

  void _resetHintTimer() {
    _hintTimer?.cancel();
    _showHint = false;
    _startHintTimer();
  }

  void _startHintTimer() {
    _hintTimer?.cancel();
    _hintTimer = Timer(const Duration(seconds: 10), () {
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
    AnalyticsService.hintUsed(widget.level);
    if (Prefs.hasFreeHint) {
      _applyHint(safe.first);
    } else {
      // Show rewarded ad for paid hint
      AdService.showRewarded(onRewarded: () {
        if (mounted && safe.isNotEmpty) _applyHint(safe.first);
      });
    }
  }

  void _applyHint(Arrow arrow) {
    Prefs.setHintsUsed(Prefs.hintsUsed + 1);
    setState(() {
      _hintArrow = arrow;
      _hintedIds.add(arrow.id);
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
    _fingerCtrl.dispose();
    _zoomIntroCtrl.dispose();
    _zoomCtrl.dispose();
    for (final f in _flights) {
      _disposeFlight(f);
    }
    AdService.setPlaying(false);
    _bannerAd?.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  Matrix4 _centeredMatrix(double scale) {
    final bp = _lastBoardPx ?? const Size(400, 700);
    final vp = _lastViewportSize ?? const Size(400, 700);
    final dx = (vp.width - bp.width * scale) / 2;
    final dy = (vp.height - bp.height * scale) / 2;
    return Matrix4.identity()
      ..setEntry(0, 0, scale)
      ..setEntry(1, 1, scale)
      ..setEntry(0, 3, dx)
      ..setEntry(1, 3, dy);
  }

  void _onZoomIntroTick() {
    final t = Curves.easeInOut.transform(_zoomIntroCtrl.value);
    final scale = _introStartScale + (_introEndScale - _introStartScale) * t;
    _zoomCtrl.value = _centeredMatrix(scale);
  }

  Size? _lastBoardPx;
  Size? _lastViewportSize;
  double _introStartScale = 1.0;
  double _introEndScale = 1.2;

  bool _introAnimating = false;

  void _playIntroZoom() {
    if (_introPlayed || _isTutorial) return;
    _introPlayed = true;
    if (c.total < 15) return;
    final bp = _lastBoardPx!;
    final vp = _lastViewportSize!;
    _introStartScale = min(vp.width / bp.width, vp.height / bp.height)
        .clamp(0.1, 1.0);
    _introEndScale = (_introStartScale * _defaultZoom)
        .clamp(_introStartScale, _maxZoom);
    _zoomCtrl.value = _centeredMatrix(_introStartScale);
    _introAnimating = true;
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _zoomIntroCtrl.forward(from: 0).then((_) {
          if (mounted) setState(() => _introAnimating = false);
        });
      }
    });
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
      _tutorialDone = true; // first successful move ends the prompt
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
        PerfectPlay.onFail(); // lost all hearts → attempt no longer perfect
        RecordsService.onLoss(); // breaks the win streak
        AnalyticsService.levelLose(widget.level, daily: widget.isDaily);
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
    AudioService.swipe();
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
    if (!widget.isDaily) {
      PerfectPlay.onWin(c.level);
      Unstoppable.onWin(c.level);
    }
    RecordsService.onWin(); // win-streak + most-wins-in-a-day (main + daily)
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
    AnalyticsService.levelRestart(widget.level);
    // Hide board BEFORE ad plays — prevents any visible jump
    setState(() => _restartHidden = true);
    AdService.onRestart(onDone: () {
      if (!mounted) return;
      _doRestart();
    });
  }

  void _confirmRestart() {
    // Only show confirmation if player has made progress (3+ arrows fired)
    final arrowsFired = c.total - c.arrows.where((a) => a.state != ArrowState.leaving).length;
    if (arrowsFired < 3) {
      _restart();
      return;
    }
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${Tr.get('restart')}?',
                  style: poppins(22, FontWeight.w900, AppColors.ink)),
              const SizedBox(height: 12),
              Text(Tr.get('restartMessage'),
                  textAlign: TextAlign.center,
                  style: poppins(14, FontWeight.w600, AppColors.ink)),
              const SizedBox(height: 24),
              Pressable(
                onTap: () {
                  Navigator.pop(context);
                  _restart();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.blue,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  alignment: Alignment.center,
                  child: Text(Tr.get('restart'),
                      style: poppins(17, FontWeight.w900, Colors.white)),
                ),
              ),
              const SizedBox(height: 10),
              Pressable(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: AppColors.cardBorder, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(Tr.get('cancel'),
                      style: poppins(16, FontWeight.w900, AppColors.muted)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _doRestart() {
    if (!widget.isDaily) {
      PerfectPlay.onRestart();
    }
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
    _zoomIntroCtrl.reset();
    _introPlayed = false;
    _introAnimating = false;
    c.loadLevel(c.level, daily: widget.isDaily);
    if (widget.isDaily) widget.onDidRestart?.call();
    _resetHintTimer();
    // Set zoom to fitScale and reveal immediately — no delay after ad
    final bp = _lastBoardPx;
    final vp = _lastViewportSize;
    if (bp != null && vp != null && c.total >= 15) {
      final fitScale = min(vp.width / bp.width, vp.height / bp.height)
          .clamp(0.1, 1.0);
      _zoomCtrl.value = _centeredMatrix(fitScale);
    } else {
      _zoomCtrl.value = Matrix4.identity();
    }
    _restartHidden = false;
    setState(() {});
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
                  // Tutorial hides the header (back/restart/progress) and shows
                  // only the hearts, matching the reference onboarding.
                  child: _isTutorial
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(0, 18, 0, 8),
                          child: Center(child: HeartsRow(hearts: c.hearts)),
                        )
                      : Column(
                          children: [
                            GameTopBar(
                                c: c, onBack: widget.onBack, onRestart: _confirmRestart),
                            ProgressBar(progress: c.progress),
                          ],
                        ),
                ),
                Expanded(
                  child: ClipRect(
                    child: Stack(
                      children: [
                        Opacity(
                          opacity: _restartHidden ? 0.0 : 1.0,
                          child: _boardArea(),
                        ),
                        if (_clashFlashCtrl.isAnimating) _clashFlashOverlay(),
                      ],
                    ),
                  ),
                ),
                if (_bannerAd != null)
                  SizedBox(
                    height: _bannerAd!.size.height.toDouble(),
                    width: _bannerAd!.size.width.toDouble(),
                    child: AdWidget(ad: _bannerAd!),
                  ),
              ],
            ),
            if (_showHint && c.status == GameStatus.playing && !_isTutorial)
              Positioned(
                right: 0,
                top: 14,
                child: Pressable(
                  onTap: _useHint,
                  alignment: Alignment.centerRight,
                  child: Prefs.hasFreeHint
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 9),
                          decoration: BoxDecoration(
                            color: AppColors.btnBg,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(22),
                              bottomLeft: Radius.circular(22),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lightbulb_rounded,
                                  color: AppColors.btnInk, size: 20),
                              const SizedBox(width: 5),
                              Text(Tr.get('hint'),
                                  style: poppins(
                                      16, FontWeight.w900, AppColors.btnInk)),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDFE2F0),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text('${Prefs.freeHintsLeft}',
                                    style: poppins(12, FontWeight.w900,
                                        AppColors.btnInk)),
                              ),
                            ],
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 10),
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
                              const Icon(Icons.videocam_rounded,
                                  color: Colors.white, size: 20),
                              const SizedBox(width: 6),
                              Text(Tr.get('hint'),
                                  style: poppins(
                                      16, FontWeight.w900, Colors.white)),
                            ],
                          ),
                        ),
                ),
              ),
            if (!_isTutorial)
              Positioned(
              right: 14,
              bottom: 10 + MediaQuery.of(context).padding.bottom +
                  (_bannerAd?.size.height.toDouble() ?? 0),
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
            if (_isTutorial)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _tutorialDone ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOut,
                    child: _tutorialOverlay(),
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
      _lastBoardPx = boardPx;
      _lastViewportSize = Size(constraints.maxWidth, constraints.maxHeight);

      final isDense = c.total >= 15;

      // Dynamic zoom based on grid density: bigger boards need more zoom range.
      final gridPoints = (c.cols + 1) * (c.rows + 1);
      if (gridPoints > 1200) {
        _maxZoom = 3.0;
        _defaultZoom = 2.0;
      } else if (gridPoints > 800) {
        _maxZoom = 3.0;
        _defaultZoom = 1.75;
      } else if (gridPoints > 300) {
        _maxZoom = 2.5;
        _defaultZoom = 1.5;
      } else {
        _maxZoom = 2.0;
        _defaultZoom = 1.2;
      }

      if (!_introPlayed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _playIntroZoom();
        });
      }

      final flights = _flights.map((f) {
        final elapsed = f.ctrl.value * (Cfg.flyHoldMs + Cfg.flyDurMs);
        final p = ((elapsed - Cfg.flyHoldMs) / Cfg.flyDurMs).clamp(0.0, 1.0);
        return (fly: f.fly, adv: flyEase(p) * f.fly.total);
      }).toList();

      final boardWidget = SizedBox.fromSize(
        size: boardPx,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
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
            if (_isTutorial) _tutorialFinger(boardPx),
          ],
        ),
      );

      // Small/tutorial boards: just center, no zoom.
      if (!isDense) {
        return Center(child: boardWidget);
      }

      // Dense boards: InteractiveViewer with constrained: false.
      // Boundary margin allows centering at fitScale; when zoomed in
      // the board covers the viewport with limited overflow at edges.
      final fitScale = min(
        constraints.maxWidth / boardPx.width,
        constraints.maxHeight / boardPx.height,
      ).clamp(0.1, 1.0);
      final marginH = max(0.0, (constraints.maxWidth / fitScale - boardPx.width) / 2);
      final marginV = max(0.0, (constraints.maxHeight / fitScale - boardPx.height) / 2);

      return InteractiveViewer(
        transformationController: _zoomCtrl,
        constrained: false,
        minScale: fitScale,
        maxScale: _maxZoom,
        panEnabled: !_introAnimating,
        scaleEnabled: !_introAnimating,
        boundaryMargin: EdgeInsets.symmetric(
          horizontal: marginH,
          vertical: marginV,
        ),
        child: boardWidget,
      );
    });
  }

  /// Pointing finger anchored to the middle arrow's actual board position so
  /// it lands exactly on the arrow on any screen size. Fades out on first move.
  Widget _tutorialFinger(Size boardPx) {
    Arrow? mid;
    var best = double.infinity;
    for (final a in c.arrows) {
      final d = (a.head.x - c.cols / 2).abs().toDouble();
      if (d < best) {
        best = d;
        mid = a;
      }
    }
    if (mid == null) return const SizedBox.shrink();
    // a point on the lower part of the arrow's shaft
    final idx = (mid.pts.length * 0.62).floor().clamp(0, mid.pts.length - 1);
    final p = mid.pts[idx];
    final fx = (Cfg.margin + p.x * Cfg.cell) * _scale;
    final fy = (Cfg.margin + p.y * Cfg.cell) * _scale;
    final t = _fingerCtrl.value;
    final bounce = (sin(t * 2 * pi - pi / 2) + 1) / 2; // 0 → 1 → 0
    final dy = 12 * bounce;
    final scale = 1.0 - 0.12 * bounce;
    const iconSize = 58.0;
    // touch_app's fingertip sits ~(17,10) up-left of the icon centre after the
    // −45° rotation, so offset the icon to land the fingertip on (fx, fy).
    return Positioned(
      left: fx - iconSize / 2 + 17,
      top: fy - iconSize / 2 + 10 + dy,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: _tutorialDone ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOut,
          child: Transform.rotate(
            angle: -pi / 4,
            child: Transform.scale(
              scale: scale,
              child: Icon(Icons.touch_app,
                  size: iconSize, color: AppColors.arrow),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tutorialOverlay() {
    // "Tap to move" prompt (the finger is rendered in the board, anchored to
    // the middle arrow — see _tutorialFinger).
    return Align(
      alignment: const Alignment(0, 0.62),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 38, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEDEFF7),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(Tr.get('tapToMove'),
            style: poppins(20, FontWeight.w900, AppColors.blue)),
      ),
    );
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

  String _winMessage() => Tr.winWord(c.level);

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
                      child: Text(_winMessage(), style: poppins(22, FontWeight.w900, AppColors.ink)),
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
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.5),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Continue?',
                    style: poppins(26, FontWeight.w900, AppColors.ink)),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (_) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.favorite, size: 36, color: AppColors.heart),
                  )),
                ),
                const SizedBox(height: 16),
                Text('Watch an ad to refill your lives\nand keep playing!',
                    textAlign: TextAlign.center,
                    style: poppins(15.5, FontWeight.w700, AppColors.ink)),
                const SizedBox(height: 24),
                Pressable(
                  onTap: () => AdService.showRewarded(onRewarded: () {
                    if (mounted) _addLife();
                  }),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.blue,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.videocam_rounded,
                            size: 24, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(Tr.get('addMoreLives'),
                            style: poppins(19, FontWeight.w900, Colors.white)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Pressable(
                  onTap: _restart,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: AppColors.cardBorder, width: 1.5),
                    ),
                    child: Center(
                      child: Text(Tr.get('restart'),
                          style: poppins(18, FontWeight.w900, AppColors.muted)),
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
