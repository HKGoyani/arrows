import 'dart:math';
import 'package:flutter/material.dart';
import 'audio.dart';
import 'config.dart';
import 'difficulty.dart';
import 'game_controller.dart';
import 'ui_kit.dart';

/// "Arrows" wordmark — a filled triangle "A" + "rrows".
class ArrowsWordmark extends StatelessWidget {
  const ArrowsWordmark({super.key});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 2),
          child: CustomPaint(size: const Size(26, 30), painter: _TrianglePainter()),
        ),
        Text(
          'rrows',
          style: TextStyle(
            fontFamily: 'Area',
            fontFamilyFallback: ['Poppins'],
            fontSize: 36,
            fontWeight: FontWeight.w900,
            shadows: [Shadow(color: AppColors.ink, blurRadius: 1)],
            color: AppColors.ink,
            letterSpacing: 0.5,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Path()
      ..moveTo(s.width / 2, 0)
      ..lineTo(s.width, s.height)
      ..lineTo(0, s.height)
      ..close();
    canvas.drawPath(p, Paint()..color = AppColors.ink);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class CircleButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  const CircleButton({super.key, required this.child, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AudioService.uiTap();
        onTap();
      },
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(color: AppColors.btnBg, shape: BoxShape.circle),
        child: Center(child: child),
      ),
    );
  }
}

class HeartsRow extends StatefulWidget {
  final int hearts;
  // Optional per-heart keys (exactly 3) so callers can measure each heart
  // icon's own on-screen position — e.g. to fly a reward heart to the exact
  // slot it will land in, rather than the row's overall center.
  final List<GlobalKey>? heartKeys;
  // When true (default), the staggered reveal plays immediately on mount.
  // Pass false initially and flip to true later (e.g. once the header's own
  // fade-in finishes) to defer the reveal until that external trigger.
  final bool startReveal;
  const HeartsRow({super.key, required this.hearts, this.heartKeys, this.startReveal = true});
  @override
  State<HeartsRow> createState() => _HeartsRowState();
}

class _HeartsRowState extends State<HeartsRow> with TickerProviderStateMixin {
  late final AnimationController _bounceCtrl;
  late final AnimationController _revealCtrl;
  int _lastLost = -1;
  bool _hasRevealed = false;

  @override
  void initState() {
    super.initState();
    _bounceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _revealCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 650));
    if (widget.startReveal) {
      // Fresh mount (new level load) — reveal hearts staggered instead of
      // just appearing instantly.
      _hasRevealed = true;
      _revealCtrl.forward(from: 0);
    }
  }

  @override
  void didUpdateWidget(HeartsRow old) {
    super.didUpdateWidget(old);
    if (widget.hearts < old.hearts) {
      _lastLost = widget.hearts;
      _bounceCtrl.forward(from: 0);
    } else if (widget.hearts > old.hearts) {
      // Gained lives (restart reset, or an "Add More Lives" ad refill) —
      // replay the same staggered reveal used on first mount.
      _hasRevealed = true;
      _revealCtrl.forward(from: 0);
    } else if (widget.startReveal && !old.startReveal) {
      // External trigger fired (header fade-in finished) — start now.
      _hasRevealed = true;
      _revealCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    _revealCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_bounceCtrl, _revealCtrl]),
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final filled = i < widget.hearts;
          final isLosing = i == _lastLost && _bounceCtrl.isAnimating;
          final isRevealing = filled && _revealCtrl.isAnimating;
          double scale;
          double opacity = 1;
          if (isLosing) {
            final t = _bounceCtrl.value;
            scale = t < 0.2 ? 1 + 0.3 * (t / 0.2) : 1.3 - 0.38 * ((t - 0.2) / 0.8);
          } else if (isRevealing) {
            // Each heart's own window within the shared controller, staggered
            // left to right, with a slight pop/overshoot on arrival.
            const start = 0.15;
            final from = i * start;
            final to = (from + 0.7).clamp(0.0, 1.0);
            final t = ((_revealCtrl.value - from) / (to - from)).clamp(0.0, 1.0);
            scale = Curves.easeOutBack.transform(t);
            opacity = Curves.easeOut.transform(t);
          } else if (filled && !_hasRevealed) {
            // Filled but the reveal hasn't been triggered yet (waiting on an
            // external signal, e.g. the header fade-in) — stay hidden rather
            // than flashing solid right before the staggered reveal begins.
            scale = 0.6;
            opacity = 0;
          } else {
            scale = filled ? 1 : 0.92;
          }
          return Padding(
            key: widget.heartKeys?[i],
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                child: Icon(Icons.favorite,
                    size: 24,
                    color: isLosing
                        ? Color.lerp(AppColors.heart, AppColors.heartEmpty, _bounceCtrl.value)!
                        : filled
                            ? AppColors.heart
                            : AppColors.heartEmpty),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class ProgressBar extends StatelessWidget {
  final double progress; // 0..1
  const ProgressBar({super.key, required this.progress});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 2, 24, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: SizedBox(
          height: 5,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: AppColors.progressTrack),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut,
                builder: (context, value, _) => FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: value,
                  child: const ColoredBox(color: Color(0xFFC5CAF0)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GameTopBar extends StatelessWidget {
  final GameController c;
  final VoidCallback onBack, onRestart;
  final List<GlobalKey>? heartKeys;
  final bool startReveal;
  const GameTopBar({super.key, required this.c, required this.onBack, required this.onRestart, this.heartKeys, this.startReveal = true});

  (String, Color) get _difficultyInfo {
    // Daily challenges have their own tier cycle (dailyTier), independent of
    // the main-progression tier of the same level number — using
    // tierForLevel here mislabels dailies (e.g. a Nightmare daily showing as
    // Normal → no label). Always match the tier the board was generated with.
    final tier = c.isDaily ? dailyTier(c.level) : tierForLevel(c.level);
    return (tier.label, tier.color);
  }

  @override
  Widget build(BuildContext context) {
    final (label, color) = _difficultyInfo;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 0, 8),
      child: Row(
        children: [
          CircleButton(
            onTap: onBack,
            child: Icon(Icons.play_arrow, color: AppColors.btnInk, size: 40)
                .rotated(),
          ),
          const SizedBox(width: 14),
          CircleButton(
            onTap: onRestart,
            child: Transform.rotate(
              angle: -30 * pi / 180,
              child: Icon(Icons.replay_rounded, color: AppColors.btnInk, size: 28,
                shadows: [Shadow(color: AppColors.btnInk, blurRadius: 1)],
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                // Normal tier shows no label (just hearts), matching the
                // reference — the tier name only surfaces at Hard and above.
                if (label != 'Normal') ...[
                  Text(label,
                      style: poppins(14, FontWeight.w900, color)),
                  const SizedBox(height: 4),
                ],
                HeartsRow(
                    key: ValueKey('hearts_${c.loadGen}'),
                    hearts: c.hearts,
                    heartKeys: heartKeys,
                    startReveal: startReveal),
              ],
            ),
          ),
          // Right reserve of 120 (vs 128 left controls) sits the hearts/label
          // ~4px right of true screen center — matches the reference's slight
          // rightward bias. (Each 2px cut here nudges the hearts 1px right.)
          const SizedBox(width: 120),
        ],
      ),
    );
  }
}

extension _RotatedIcon on Icon {
  Widget rotated() => Transform.rotate(angle: pi, child: this);
}
