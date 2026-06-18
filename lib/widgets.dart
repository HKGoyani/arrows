import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'audio.dart';
import 'config.dart';
import 'game_controller.dart';

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
      padding: const EdgeInsets.fromLTRB(24, 2, 24, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          height: 9,
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
          const SizedBox(width: 14),
          HeartsRow(hearts: c.hearts),
          const Spacer(),
          ValueListenableBuilder<bool>(
            valueListenable: AudioService.musicOn,
            builder: (_, on, __) => GestureDetector(
              onTap: () => AudioService.setMusic(!on),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                    on ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                    color: AppColors.btnInk,
                    size: 24),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension _RotatedIcon on Icon {
  Widget rotated() => Transform.rotate(angle: 3.14159, child: this);
}
