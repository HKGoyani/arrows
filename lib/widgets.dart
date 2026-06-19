import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'config.dart';
import 'game_controller.dart';
import 'ui_kit.dart';

/// "Arrows" wordmark — a filled triangle "A" + "rrows".
class ArrowsWordmark extends StatelessWidget {
  const ArrowsWordmark({super.key});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 3, right: 1),
          child: CustomPaint(size: const Size(31, 35), painter: _TrianglePainter()),
        ),
        Text(
          'rrows',
          style: GoogleFonts.poppins(
            fontSize: 40,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
            letterSpacing: -1,
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
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: const BoxDecoration(color: AppColors.btnBg, shape: BoxShape.circle),
        child: Center(child: child),
      ),
    );
  }
}

class HeartsRow extends StatelessWidget {
  final int hearts;
  const HeartsRow({super.key, required this.hearts});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final filled = i < hearts;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.5),
          child: AnimatedScale(
            scale: filled ? 1 : 0.92,
            duration: const Duration(milliseconds: 200),
            child: Icon(Icons.favorite,
                size: 24, color: filled ? AppColors.red : AppColors.heartEmpty),
          ),
        );
      }),
    );
  }
}

class ProgressBar extends StatelessWidget {
  final double progress; // 0..1
  const ProgressBar({super.key, required this.progress});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 2, 24, 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: SizedBox(
          height: 5,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: AppColors.progressTrack),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut,
                builder: (context, value, _) => FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: value,
                  child: const ColoredBox(color: AppColors.blue),
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

  String get _difficulty {
    final lvl = c.level;
    if (lvl < 4) return 'Easy';
    if (lvl < 6) return 'Medium';
    if (lvl < 9) return 'Hard';
    return 'Super Hard';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 8),
      child: Row(
        children: [
          CircleButton(
            onTap: onBack,
            child: const Icon(Icons.play_arrow, color: AppColors.btnInk, size: 24)
                .rotated(),
          ),
          const SizedBox(width: 14),
          CircleButton(
            onTap: onRestart,
            child: const Icon(Icons.refresh, color: AppColors.btnInk, size: 24),
          ),
          Expanded(
            child: Column(
              children: [
                Text(_difficulty,
                    style: poppins(14, FontWeight.w700, AppColors.blueSoft)),
                const SizedBox(height: 4),
                HeartsRow(hearts: c.hearts),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension _RotatedIcon on Icon {
  Widget rotated() => Transform.rotate(angle: pi, child: this);
}
