import 'package:flutter/material.dart';
import 'config.dart';
import 'prefs.dart';
import 'streak.dart';
import 'ui_kit.dart';

class CollectionScreen extends StatelessWidget {
  const CollectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final best = StreakService.best;
    final solved = (Prefs.level - 1).clamp(0, 9999);
    final current = StreakService.current;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 16),
              child: Text('Collection',
                  style: poppins(26, FontWeight.w800, AppColors.ink)),
            ),
            // Records
            _SectionHeader(title: 'Records'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _TrophyCard(
                    icon: Icons.local_fire_department_rounded,
                    tint: AppColors.flame,
                    value: '$current',
                    label: 'Longest Streak',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TrophyCard(
                    icon: Icons.emoji_events_rounded,
                    tint: AppColors.blue,
                    value: '$best',
                    label: 'Highest Win\nStreak',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TrophyCard(
                    icon: Icons.arrow_upward_rounded,
                    tint: AppColors.blueSoft,
                    value: '$solved',
                    label: 'Most Wins',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            // Awards
            _SectionHeader(title: 'Awards'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _AwardBadge(
                  label: 'Level Legend',
                  unlocked: solved >= 50,
                )),
                const SizedBox(width: 10),
                Expanded(child: _AwardBadge(
                  label: 'Perfect Play',
                  unlocked: false,
                )),
                const SizedBox(width: 10),
                Expanded(child: _AwardBadge(
                  label: 'Unstoppable',
                  unlocked: false,
                )),
              ],
            ),
            const SizedBox(height: 28),
            // Challenge Trophies
            _SectionHeader(title: 'Challenge Trophies'),
            const SizedBox(height: 4),
            Text('${DateTime.now().year}',
                style: poppins(14, FontWeight.w600, AppColors.muted)),
            const SizedBox(height: 12),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Column(
                children: [
                  Text('Win 3 Nightmare levels to earn\nthis award.',
                      textAlign: TextAlign.center,
                      style: poppins(14, FontWeight.w600, AppColors.ink, height: 1.4)),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: _monthTrophies(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _monthTrophies() {
    const months = ['January', 'February', 'March'];
    return months.map((m) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: const Icon(Icons.emoji_events_rounded,
                color: AppColors.lock, size: 28),
          ),
          const SizedBox(height: 8),
          Text(m, style: poppins(12, FontWeight.w600, AppColors.muted)),
          Text('0 of 31', style: poppins(11, FontWeight.w500, AppColors.lock)),
        ],
      );
    }).toList();
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: poppins(16, FontWeight.w700, AppColors.blue)),
        const SizedBox(width: 10),
        Expanded(
          child: Container(height: 1, color: AppColors.cardBorder),
        ),
      ],
    );
  }
}

class _TrophyCard extends StatelessWidget {
  final IconData icon;
  final Color tint;
  final String value;
  final String label;
  const _TrophyCard({
    required this.icon,
    required this.tint,
    required this.value,
    required this.label,
  });
  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: tint, size: 26),
          ),
          const SizedBox(height: 8),
          Text(value, style: poppins(20, FontWeight.w800, AppColors.ink)),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: poppins(11, FontWeight.w500, AppColors.muted)),
        ],
      ),
    );
  }
}

class _AwardBadge extends StatelessWidget {
  final String label;
  final bool unlocked;
  const _AwardBadge({required this.label, required this.unlocked});
  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: unlocked
                  ? AppColors.blue.withValues(alpha: 0.14)
                  : AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.shield_rounded,
              color: unlocked ? AppColors.blue : AppColors.lock,
              size: 30,
            ),
          ),
          const SizedBox(height: 8),
          Text(label,
              textAlign: TextAlign.center,
              style: poppins(12, FontWeight.w500,
                  unlocked ? AppColors.ink : AppColors.lock)),
        ],
      ),
    );
  }
}
