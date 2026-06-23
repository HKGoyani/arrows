import 'package:flutter/material.dart';
import 'collection_icons.dart';
import 'config.dart';
import 'level_legend.dart';
import 'perfect.dart';
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
                  unlocked: LevelLegend.unlocked,
                  painter: StarMedalPainter(unlocked: LevelLegend.unlocked),
                  value: LevelLegend.unlocked ? '${LevelLegend.reached}' : null,
                  sublabel: LevelLegend.unlocked
                      ? '${LevelLegend.tier} of ${LevelLegend.milestones.length}'
                      : null,
                  showBadge: LevelLegend.hasUnseen,
                  onTap: () => showLevelLegendDetail(context),
                )),
                const SizedBox(width: 12),
                Expanded(child: _AwardCard(
                  icon: Icons.hexagon_rounded,
                  label: 'Perfect Play',
                  unlocked: PerfectPlay.unlocked,
                  painter: TargetMedalPainter(unlocked: PerfectPlay.unlocked),
                  value: PerfectPlay.unlocked ? '${PerfectPlay.reached}' : null,
                  sublabel: PerfectPlay.unlocked
                      ? '${PerfectPlay.tier} of ${PerfectPlay.milestones.length}'
                      : null,
                  onTap: () => showPerfectPlayDetail(context),
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
  final double fontSize;
  const _NumberBadge(this.value, {this.fontSize = 20});
  @override
  Widget build(BuildContext context) {
    final base = poppins(fontSize, FontWeight.w900, Colors.white);
    return Stack(
      alignment: Alignment.center,
      children: [
        // gray outline
        Text(value, style: base.copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = fontSize * 0.3
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
  final CustomPainter? painter;
  final String? value;
  final String? sublabel;
  final bool showBadge;
  final VoidCallback? onTap;
  const _AwardCard({
    required this.icon,
    required this.label,
    required this.unlocked,
    this.painter,
    this.value,
    this.sublabel,
    this.showBadge = false,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final column = Column(
      children: [
        _IconBox(
          child: painter != null
              ? Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: CustomPaint(painter: painter),
                      ),
                    ),
                    if (unlocked && value != null)
                      Align(
                        alignment: const Alignment(0, 0.86),
                        child: _NumberBadge(value!),
                      ),
                    if (showBadge)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: const BoxDecoration(
                            color: AppColors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                )
              : Center(
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
        if (sublabel != null) ...[
          const SizedBox(height: 2),
          Text(sublabel!,
              textAlign: TextAlign.center,
              style: poppins(10.5, FontWeight.w700, AppColors.muted)),
        ],
      ],
    );
    if (onTap == null) return column;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: column,
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

// ───────────────────────── Award detail (tap) ─────────────────────────

/// Full-screen modal shown when an award is tapped: large medallion,
/// requirement text, progress bar (current → target) and a Close button.
void showAwardDetail(
  BuildContext context, {
  required CustomPainter Function(bool unlocked) medal,
  required int current,
  required int target,
}) {
  showGeneralDialog(
    context: context,
    barrierLabel: 'Award',
    barrierColor: Colors.black.withValues(alpha: 0.0),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (_, __, ___) =>
        _AwardDetailScreen(medal: medal, current: current, target: target),
    transitionBuilder: (_, anim, __, child) => FadeTransition(
      opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
      child: child,
    ),
  );
}

class _AwardDetailScreen extends StatelessWidget {
  final CustomPainter Function(bool unlocked) medal;
  final int current;
  final int target;
  const _AwardDetailScreen({
    required this.medal,
    required this.current,
    required this.target,
  });

  @override
  Widget build(BuildContext context) {
    final unlocked = current >= target;
    return Material(
      color: Colors.white,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            children: [
              const Spacer(flex: 3),
              SizedBox(
                width: 220,
                height: 220,
                child: CustomPaint(painter: medal(unlocked)),
              ),
              const SizedBox(height: 36),
              Text(
                unlocked
                    ? 'Award earned!'
                    : 'Reach Level $target to earn this award.',
                textAlign: TextAlign.center,
                style: poppins(20, FontWeight.w800, AppColors.ink),
              ),
              const SizedBox(height: 26),
              _AwardProgress(current: current, target: target),
              const Spacer(flex: 4),
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 230,
                    height: 60,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                          color: const Color(0xFFE4E6F1), width: 1.5),
                    ),
                    child: Text('Close',
                        style: poppins(17, FontWeight.w800,
                            const Color(0xFF8C90A6))),
                  ),
                ),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pill progress bar: green fill with the current value, target at the end.
class _AwardProgress extends StatelessWidget {
  final int current;
  final int target;
  final int from;
  final bool showTarget;
  const _AwardProgress({
    required this.current,
    required this.target,
    this.from = 0,
    this.showTarget = true,
  });

  @override
  Widget build(BuildContext context) {
    final span = target - from;
    final raw = span <= 0 ? 1.0 : (current - from) / span;
    final factor = raw.clamp(0.12, 1.0).toDouble();
    return SizedBox(
      height: 36,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFEDEFF7),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          if (showTarget)
            Align(
              alignment: const Alignment(0.92, 0),
              child: Text('$target',
                  style: poppins(16, FontWeight.w900, const Color(0xFFAFB4CC))),
            ),
          FractionallySizedBox(
            widthFactor: factor,
            alignment: Alignment.centerLeft,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF28E588),
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 14),
              child: Text('$current',
                  style: poppins(showTarget ? 18 : 16, FontWeight.w900,
                      Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────── Level Legend detail (tap) ──────────────────────

void showLevelLegendDetail(BuildContext context) {
  LevelLegend.markSeen();
  showGeneralDialog(
    context: context,
    barrierLabel: 'Level Legend',
    barrierColor: Colors.black.withValues(alpha: 0.0),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (_, __, ___) => const _LevelLegendDetailScreen(),
    transitionBuilder: (_, anim, __, child) => FadeTransition(
      opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
      child: child,
    ),
  );
}

class _LevelLegendDetailScreen extends StatelessWidget {
  const _LevelLegendDetailScreen();

  @override
  Widget build(BuildContext context) {
    final count = LevelLegend.count;
    final unlocked = LevelLegend.unlocked;
    final reached = LevelLegend.reached;
    final next = LevelLegend.next;

    return Material(
      color: Colors.white,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            children: [
              const Spacer(flex: 3),
              SizedBox(
                width: 230,
                height: 230,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                          painter: StarMedalPainter(unlocked: unlocked)),
                    ),
                    if (unlocked)
                      Align(
                        alignment: const Alignment(0, 0.96),
                        child: _NumberBadge('$reached', fontSize: 40),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (unlocked) ...[
                _DatePill(LevelLegend.earnedDateFor(reached) ?? _formatToday()),
                const SizedBox(height: 18),
                Text(
                  'You earned Level Legend by\nreaching level $reached!',
                  textAlign: TextAlign.center,
                  style: poppins(20, FontWeight.w800, AppColors.ink),
                ),
              ] else
                Text(
                  'Reach Level ${LevelLegend.milestones.first} to earn '
                  'this award.',
                  textAlign: TextAlign.center,
                  style: poppins(20, FontWeight.w800, AppColors.ink),
                ),
              if (!unlocked) ...[
                const SizedBox(height: 26),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 26),
                  child: _AwardProgress(
                      current: count,
                      target: LevelLegend.milestones.first),
                ),
              ],
              const Spacer(flex: 5),
              if (unlocked && next != null) ...[
                Text('Next award at level $next',
                    style: poppins(
                        15, FontWeight.w700, const Color(0xFF7A7F9E))),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 26),
                  child: _AwardProgress(
                      current: count, target: next, from: reached,
                      showTarget: false),
                ),
                const SizedBox(height: 24),
              ],
              _CloseButton(onTap: () => Navigator.of(context).pop()),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatToday() {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final d = DateTime.now();
    return '${months[d.month - 1]} ${d.day} ${d.year}';
  }
}

// ───────────────────── Perfect Play detail (tap) ─────────────────────

/// Tiered award detail: hexagon dartboard medal, milestone badge, earned date,
/// and progress toward the next milestone.
void showPerfectPlayDetail(BuildContext context) {
  showGeneralDialog(
    context: context,
    barrierLabel: 'Perfect Play',
    barrierColor: Colors.black.withValues(alpha: 0.0),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (_, __, ___) => const _PerfectPlayDetailScreen(),
    transitionBuilder: (_, anim, __, child) => FadeTransition(
      opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
      child: child,
    ),
  );
}

class _PerfectPlayDetailScreen extends StatelessWidget {
  const _PerfectPlayDetailScreen();

  @override
  Widget build(BuildContext context) {
    final count = PerfectPlay.count;
    final unlocked = PerfectPlay.unlocked;
    final reached = PerfectPlay.reached;
    final next = PerfectPlay.next;

    return Material(
      color: Colors.white,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            children: [
              const Spacer(flex: 3),
              // hexagon medal + milestone badge
              SizedBox(
                width: 230,
                height: 230,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                          painter: TargetMedalPainter(unlocked: unlocked)),
                    ),
                    if (unlocked)
                      Align(
                        alignment: const Alignment(0, 0.96),
                        child: _NumberBadge('$reached', fontSize: 40),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (unlocked) ...[
                _DatePill(PerfectPlay.earnedDateFor(reached) ?? _formatToday()),
                const SizedBox(height: 18),
                Text(
                  'You earned Perfect Play by winning $reached '
                  'levels on your first attempt!',
                  textAlign: TextAlign.center,
                  style: poppins(20, FontWeight.w800, AppColors.ink),
                ),
              ] else
                Text(
                  'Win ${PerfectPlay.milestones.first} levels on your first '
                  'attempt to earn this award.',
                  textAlign: TextAlign.center,
                  style: poppins(20, FontWeight.w800, AppColors.ink),
                ),
              const Spacer(flex: 5),
              if (next != null) ...[
                if (unlocked) ...[
                  Text('Next award at $next levels',
                      style: poppins(15, FontWeight.w700, const Color(0xFF7A7F9E))),
                  const SizedBox(height: 14),
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 26),
                  child: _AwardProgress(
                      current: count, target: next, from: reached,
                      showTarget: false),
                ),
                const SizedBox(height: 24),
              ],
              _CloseButton(onTap: () => Navigator.of(context).pop()),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatToday() {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final d = DateTime.now();
    return '${months[d.month - 1]} ${d.day} ${d.year}';
  }
}

/// Small pill that shows a date (e.g. the day an award was earned).
class _DatePill extends StatelessWidget {
  final String text;
  const _DatePill(this.text);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F2F8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: poppins(13.5, FontWeight.w700, AppColors.muted)),
    );
  }
}

/// Shared outlined "Close" pill button used by award detail screens.
class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CloseButton({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 230,
        height: 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: const Color(0xFFE4E6F1), width: 1.5),
        ),
        child: Text('Close',
            style: poppins(17, FontWeight.w800, const Color(0xFF8C90A6))),
      ),
    );
  }
}
