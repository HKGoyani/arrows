import 'package:flutter/material.dart';
import 'collection_icons.dart';
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
    final now = DateTime.now();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(title: 'Records'),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _RecordCard(
                  iconWidget: const FlameOnPedestal(),
                  value: '$current',
                  label: 'Longest Streak',
                  date: _formatDate(now),
                )),
                const SizedBox(width: 12),
                Expanded(child: _RecordCard(
                  painter: CrownPainter(),
                  value: '$best',
                  label: 'Highest Win\nStreak',
                  date: _formatDate(now),
                )),
                const SizedBox(width: 12),
                Expanded(child: _RecordCard(
                  painter: WingArrowPainter(),
                  value: '$solved',
                  label: 'Most Wins',
                  date: _formatDate(now),
                )),
              ],
            ),
            const SizedBox(height: 28),
            _SectionHeader(title: 'Awards'),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _AwardCard(
                  icon: Icons.star_rounded,
                  label: 'Level Legend',
                  unlocked: solved >= 50,
                )),
                const SizedBox(width: 12),
                Expanded(child: _AwardCard(
                  icon: Icons.hexagon_rounded,
                  label: 'Perfect Play',
                  unlocked: false,
                )),
                const SizedBox(width: 12),
                Expanded(child: _AwardCard(
                  icon: Icons.shield_rounded,
                  label: 'Unstoppable',
                  unlocked: false,
                )),
              ],
            ),
            const SizedBox(height: 28),
            _SectionHeader(title: 'Challenge Trophies'),
            const SizedBox(height: 8),
            Text('${now.year}',
                style: poppins(18, FontWeight.w900, AppColors.ink)),
            const SizedBox(height: 16),
            _TrophyGrid(year: now.year),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day} ${d.year}';
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: poppins(18, FontWeight.w900, AppColors.blue)),
        const SizedBox(width: 12),
        Expanded(
          child: Container(height: 1.5, color: AppColors.cardBorder),
        ),
      ],
    );
  }
}

/// Soft rounded square that contains only the icon art.
class _IconBox extends StatelessWidget {
  final Widget child;
  const _IconBox({required this.child});
  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: child,
      ),
    );
  }
}

/// White pill badge that shows a record number.
class _NumberBadge extends StatelessWidget {
  final String value;
  const _NumberBadge(this.value);
  @override
  Widget build(BuildContext context) {
    final base = poppins(20, FontWeight.w900, Colors.white);
    return Stack(
      alignment: Alignment.center,
      children: [
        // gray outline
        Text(value, style: base.copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6
            ..strokeJoin = StrokeJoin.round
            ..color = const Color(0xFF6F7596),
        )),
        // white fill
        Text(value, style: base),
      ],
    );
  }
}

class _RecordCard extends StatelessWidget {
  final CustomPainter? painter;
  final Widget? iconWidget;
  final String value;
  final String label;
  final String date;
  const _RecordCard({
    this.painter,
    this.iconWidget,
    required this.value,
    required this.label,
    required this.date,
  });
  @override
  Widget build(BuildContext context) {
    final iconContent = iconWidget != null
        ? Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 14),
              child: iconWidget!,
            ),
          )
        : Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
              child: CustomPaint(painter: painter),
            ),
          );
    return Column(
      children: [
        _IconBox(
          child: Stack(
            children: [
              iconContent,
              Align(
                alignment: const Alignment(0, 0.6),
                child: _NumberBadge(value),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: poppins(12, FontWeight.w800, AppColors.ink)),
        const SizedBox(height: 2),
        Text(date,
            style: poppins(10.5, FontWeight.w700, AppColors.muted)),
      ],
    );
  }
}

class _AwardCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool unlocked;
  const _AwardCard({
    required this.icon,
    required this.label,
    required this.unlocked,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _IconBox(
          child: Center(
            child: Icon(icon,
                color: unlocked ? AppColors.blue : AppColors.lock,
                size: 50),
          ),
        ),
        const SizedBox(height: 10),
        Text(label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: poppins(12, FontWeight.w800,
                unlocked ? AppColors.ink : AppColors.muted)),
      ],
    );
  }
}

class _TrophyGrid extends StatelessWidget {
  final int year;
  const _TrophyGrid({required this.year});

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static const _daysInMonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 18,
        crossAxisSpacing: 12,
        childAspectRatio: 0.70,
      ),
      itemCount: 12,
      itemBuilder: (_, i) {
        final days = (i == 1 && year % 4 == 0 && (year % 100 != 0 || year % 400 == 0))
            ? 29 : _daysInMonth[i];
        return Column(
          children: [
            _IconBox(
              child: Center(
                child: Icon(Icons.emoji_events_rounded,
                    color: AppColors.lock, size: 46),
              ),
            ),
            const SizedBox(height: 8),
            Text(_monthNames[i],
                style: poppins(12, FontWeight.w800, AppColors.ink)),
            Text('0 of $days',
                style: poppins(10.5, FontWeight.w700, AppColors.muted)),
          ],
        );
      },
    );
  }
}
