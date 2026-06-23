import 'package:flutter/material.dart';
import 'config.dart';
import 'prefs.dart';
import 'streak.dart';
import 'ui_kit.dart';

class StreakScreen extends StatelessWidget {
  const StreakScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final current = StreakService.current;
    final best = StreakService.best;
    final days = StreakService.lastSevenDays();
    final solved = (Prefs.level - 1).clamp(0, 9999);
    final playedToday = StreakService.playedToday;

    final String message = playedToday
        ? "You've played today — streak safe! 🔥"
        : (current > 0
            ? 'Play a level today to extend your streak!'
            : 'Start a new streak — play today!');

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 16),
              child: Text('Streak', style: poppins(26, FontWeight.w800, AppColors.ink)),
            ),
            // hero
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.flame.withValues(alpha: 0.16),
                    AppColors.lavender.withValues(alpha: 0.16),
                  ],
                ),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                children: [
                  const Icon(Icons.local_fire_department_rounded,
                      color: AppColors.flame, size: 64),
                  const SizedBox(height: 6),
                  Text('$current', style: poppins(50, FontWeight.w800, AppColors.ink, height: 1)),
                  Text(current == 1 ? 'day streak' : 'day streak',
                      style: poppins(15, FontWeight.w800, AppColors.muted)),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(message,
                        textAlign: TextAlign.center,
                        style: poppins(13.5, FontWeight.w800, AppColors.ink)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const SectionLabel('This week'),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: days.map(_dayDot).toList(),
              ),
            ),
            const SizedBox(height: 22),
            const SectionLabel('Stats'),
            Row(
              children: [
                Expanded(
                    child: StatCard(
                        icon: Icons.emoji_events_rounded,
                        tint: AppColors.blue,
                        value: '$best',
                        label: 'Best streak')),
                const SizedBox(width: 12),
                Expanded(
                    child: StatCard(
                        icon: Icons.check_circle_rounded,
                        tint: AppColors.blueSoft,
                        value: '$solved',
                        label: 'Levels solved')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayDot(DayInfo d) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: d.played ? AppColors.flame : AppColors.surface,
            shape: BoxShape.circle,
            border: d.isToday
                ? Border.all(color: AppColors.blue, width: 2)
                : Border.all(color: AppColors.cardBorder),
          ),
          child: d.played
              ? const Icon(Icons.local_fire_department_rounded,
                  color: Colors.white, size: 18)
              : null,
        ),
        const SizedBox(height: 6),
        Text(d.label,
            style: poppins(12, d.isToday ? FontWeight.w800 : FontWeight.w800,
                d.isToday ? AppColors.ink : AppColors.muted)),
      ],
    );
  }
}
