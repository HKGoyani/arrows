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
  const HeartsRow({super.key, required this.hearts});
  @override
  State<HeartsRow> createState() => _HeartsRowState();
}

class _HeartsRowState extends State<HeartsRow> with SingleTickerProviderStateMixin {
  late final AnimationController _bounceCtrl;
  int _lastLost = -1;

  @override
  void initState() {
    super.initState();
    _bounceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
  }

  @override
  void didUpdateWidget(HeartsRow old) {
    super.didUpdateWidget(old);
    if (widget.hearts < old.hearts) {
      _lastLost = widget.hearts;
      _bounceCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bounceCtrl,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final filled = i < widget.hearts;
          final isLosing = i == _lastLost && _bounceCtrl.isAnimating;
          double scale;
          if (isLosing) {
            final t = _bounceCtrl.value;
            scale = t < 0.2 ? 1 + 0.3 * (t / 0.2) : 1.3 - 0.38 * ((t - 0.2) / 0.8);
          } else {
            scale = filled ? 1 : 0.92;
          }
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
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
  const GameTopBar({super.key, required this.c, required this.onBack, required this.onRestart});

  (String, Color) get _difficultyInfo {
    final tier = tierForLevel(c.level);
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
                HeartsRow(hearts: c.hearts),
              ],
            ),
          ),
          const SizedBox(width: 90),
        ],
      ),
    );
  }
}

extension _RotatedIcon on Icon {
  Widget rotated() => Transform.rotate(angle: pi, child: this);
}
