import 'package:flutter/material.dart';
import 'config.dart';
import 'prefs.dart';
import 'streak.dart';
import 'ui_kit.dart';
import 'widgets.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback onPlay;
  const HomeScreen({super.key, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    final level = Prefs.level;
    final streak = StreakService.current;

    return Stack(
      children: [
        const Positioned.fill(child: CustomPaint(painter: DotGridPainter())),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
            child: Column(
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.local_fire_department_rounded,
                          color: AppColors.flame, size: 19),
                      const SizedBox(width: 5),
                      Text('$streak', style: poppins(15, FontWeight.w700, AppColors.ink)),
                    ]),
                  ),
                ),
                const Spacer(flex: 3),
                const ArrowsWordmark(),
                const SizedBox(height: 8),
                Text('Clear every arrow on the board',
                    style: poppins(13.5, FontWeight.w500, AppColors.muted)),
                const SizedBox(height: 14),
                Text('Level $level',
                    style: poppins(22, FontWeight.w700, AppColors.blue)),
                const Spacer(flex: 4),
                PrimaryButton(
                    label: 'Play',
                    onTap: onPlay,
                    width: 280),
                const SizedBox(height: 12),
                Text(level > 1 ? 'Continue your run' : 'Tap to begin',
                    style: poppins(13, FontWeight.w500, AppColors.muted)),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
