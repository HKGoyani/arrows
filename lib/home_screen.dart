import 'package:flutter/material.dart';
import 'config.dart';
import 'prefs.dart';
import 'streak.dart';
import 'ui_kit.dart';
import 'widgets.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback onPlay;
  final VoidCallback onOpenStreak;
  const HomeScreen({super.key, required this.onPlay, required this.onOpenStreak});

  @override
  Widget build(BuildContext context) {
    final level = Prefs.level;
    final streak = StreakService.current;
    final best = StreakService.best;
    final solved = (level - 1).clamp(0, 9999);

    return Stack(
      children: [
        const Positioned.fill(child: CustomPaint(painter: DotGridPainter())),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Pressable(
                    onTap: onOpenStreak,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
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
                ),
                // centered hero block
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const ArrowsWordmark(),
                        const SizedBox(height: 8),
                        Text('Clear every arrow on the board',
                            style: poppins(13.5, FontWeight.w500, AppColors.muted)),
                        const SizedBox(height: 30),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppColors.navPill,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text('Level $level',
                              style: poppins(14, FontWeight.w700, AppColors.navInk)),
                        ),
                        const SizedBox(height: 16),
                        PrimaryButton(
                            label: 'Play',
                            icon: Icons.play_arrow_rounded,
                            onTap: onPlay,
                            width: 230),
                        const SizedBox(height: 10),
                        Text(level > 1 ? 'Continue your run' : 'Tap to begin',
                            style: poppins(13, FontWeight.w500, AppColors.muted)),
                      ],
                    ),
                  ),
                ),
                // stats
                Row(
                  children: [
                    Expanded(
                        child: StatCard(
                            icon: Icons.local_fire_department_rounded,
                            tint: AppColors.flame,
                            value: '$streak',
                            label: 'Day streak')),
                    const SizedBox(width: 10),
                    Expanded(
                        child: StatCard(
                            icon: Icons.emoji_events_rounded,
                            tint: AppColors.blue,
                            value: '$best',
                            label: 'Best')),
                    const SizedBox(width: 10),
                    Expanded(
                        child: StatCard(
                            icon: Icons.check_circle_rounded,
                            tint: AppColors.blueSoft,
                            value: '$solved',
                            label: 'Solved')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
