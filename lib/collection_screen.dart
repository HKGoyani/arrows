import 'package:flutter/material.dart';
import 'collection_icons.dart';
import 'config.dart';
import 'level_legend.dart';
import 'main.dart' show navigateToChallenge;
import 'perfect.dart';
import 'prefs.dart';
import 'streak.dart';
import 'ui_kit.dart';
import 'unstoppable.dart';

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
                  showBadge: PerfectPlay.hasUnseen,
                  onTap: () => showPerfectPlayDetail(context),
                )),
                const SizedBox(width: 12),
                Expanded(child: _AwardCard(
                  icon: Icons.shield_rounded,
                  label: 'Unstoppable',
                  unlocked: Unstoppable.unlocked,
                  painter: SkullShieldPainter(unlocked: Unstoppable.unlocked),
                  value: Unstoppable.unlocked ? '${Unstoppable.reached}' : null,
                  sublabel: Unstoppable.unlocked
                      ? '${Unstoppable.tier} of ${Unstoppable.milestones.length}'
                      : null,
                  showBadge: Unstoppable.hasUnseen,
                  onTap: () => showUnstoppableDetail(context),
                )),
              ],
            ),
            const SizedBox(height: 28),
            _SectionHeader(title: 'Challenge Trophies'),
            ..._buildTrophyYears(),
          ],
        ),
      ),
    );
  }

  static List<Widget> _buildTrophyYears() {
    final played = Prefs.playedDays.toSet();
    final now = DateTime.now();
    final years = <int>{now.year};
    for (final d in played) {
      final y = int.tryParse(d.split('-').first);
      if (y != null) years.add(y);
    }
    final sorted = years.toList()..sort((a, b) => b.compareTo(a));

    final widgets = <Widget>[];
    for (final year in sorted) {
      widgets.add(const SizedBox(height: 10));
      widgets.add(Text('$year', style: poppins(18, FontWeight.w900, AppColors.ink)));
      widgets.add(const SizedBox(height: 12));
      widgets.add(_TrophyGrid(year: year, playedDays: played));
    }
    return widgets;
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
  final Set<String> playedDays;
  const _TrophyGrid({required this.year, required this.playedDays});

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static const _daysInMonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

  int _countPlayed(int month) {
    var count = 0;
    final prefix = '$year-${month.toString().padLeft(2, '0')}-';
    for (final d in playedDays) {
      if (d.startsWith(prefix)) count++;
    }
    return count;
  }

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
      itemCount: year == DateTime.now().year ? DateTime.now().month : 12,
      itemBuilder: (_, i) {
        final days = (i == 1 && year % 4 == 0 && (year % 100 != 0 || year % 400 == 0))
            ? 29 : _daysInMonth[i];
        final played = _countPlayed(i + 1);
        final completed = played >= days;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => showTrophyDetail(context, year: year, month: i + 1,
              played: played, totalDays: days, completed: completed),
          child: Column(
            children: [
              _IconBox(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: SizedBox.expand(
                    child: CustomPaint(
                      painter: TrophyPainter(unlocked: completed),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(_monthNames[i],
                  style: poppins(12, FontWeight.w800, AppColors.ink)),
              Text('$played of $days',
                  style: poppins(10.5, FontWeight.w700, AppColors.muted)),
            ],
          ),
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
    final factor = raw.clamp(0.0, 1.0).toDouble();
    final fs = showTarget ? 18.0 : 16.0;
    return Row(
      children: [
        Expanded(
          child: LayoutBuilder(builder: (context, cons) {
            final trackW = cons.maxWidth;
            const h = 36.0;
            final pillW = _pillWidth('$current', fs, h);
            final fillW = (factor * trackW).clamp(pillW, trackW);
            return SizedBox(
              height: h,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDEFF7),
                      borderRadius: BorderRadius.circular(h / 2),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: fillW,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF28E588),
                        borderRadius: BorderRadius.circular(h / 2),
                      ),
                      alignment: Alignment.center,
                      child: Text('$current',
                          style: poppins(fs, FontWeight.w900, Colors.white)),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
        if (showTarget) ...[
          const SizedBox(width: 10),
          Text('$target',
              style: poppins(16, FontWeight.w900, const Color(0xFFAFB4CC))),
        ],
      ],
    );
  }

  static double _pillWidth(String text, double fontSize, double height) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w900)),
      textDirection: TextDirection.ltr,
    )..layout();
    final w = tp.width + 24;
    return w < height ? height : w;
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
  PerfectPlay.markSeen();
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

// ───────────────────── Unstoppable detail (tap) ──────────────────────

void showUnstoppableDetail(BuildContext context) {
  Unstoppable.markSeen();
  showGeneralDialog(
    context: context,
    barrierLabel: 'Unstoppable',
    barrierColor: Colors.black.withValues(alpha: 0.0),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (_, __, ___) => const _UnstoppableDetailScreen(),
    transitionBuilder: (_, anim, __, child) => FadeTransition(
      opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
      child: child,
    ),
  );
}

class _UnstoppableDetailScreen extends StatelessWidget {
  const _UnstoppableDetailScreen();

  @override
  Widget build(BuildContext context) {
    final count = Unstoppable.count;
    final unlocked = Unstoppable.unlocked;
    final reached = Unstoppable.reached;
    final next = Unstoppable.next;

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
                          painter: SkullShieldPainter(unlocked: unlocked)),
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
                _DatePill(Unstoppable.earnedDateFor(reached) ?? _formatToday()),
                const SizedBox(height: 18),
                Text(
                  'You earned Unstoppable by\nwinning $reached Nightmare levels!',
                  textAlign: TextAlign.center,
                  style: poppins(20, FontWeight.w800, AppColors.ink),
                ),
              ] else
                Text(
                  'Win ${Unstoppable.milestones.first} Nightmare levels to earn '
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
                      target: Unstoppable.milestones.first),
                ),
              ],
              const Spacer(flex: 5),
              if (unlocked && next != null) ...[
                Text('Next award at $next levels',
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

// ───────────────── Trophy detail modal (tap trophy card) ─────────────────

void showTrophyDetail(BuildContext context, {
  required int year,
  required int month,
  required int played,
  required int totalDays,
  required bool completed,
}) {
  final monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  showGeneralDialog(
    context: context,
    barrierLabel: 'Trophy',
    barrierColor: Colors.black.withValues(alpha: 0.0),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (_, __, ___) => _TrophyDetailScreen(
      year: year,
      month: month,
      monthName: monthNames[month - 1],
      played: played,
      totalDays: totalDays,
      completed: completed,
    ),
    transitionBuilder: (_, anim, __, child) => FadeTransition(
      opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
      child: child,
    ),
  );
}

class _TrophyDetailScreen extends StatelessWidget {
  final int year, month, played, totalDays;
  final String monthName;
  final bool completed;

  const _TrophyDetailScreen({
    required this.year,
    required this.month,
    required this.monthName,
    required this.played,
    required this.totalDays,
    required this.completed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            children: [
              const Spacer(flex: 3),
              SizedBox(
                width: 200,
                height: 200,
                child: CustomPaint(
                  painter: TrophyPainter(unlocked: completed),
                ),
              ),
              const SizedBox(height: 24),
              Text('$monthName $year',
                  style: poppins(22, FontWeight.w900, AppColors.blue)),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _AwardProgress(
                    current: played, target: totalDays),
              ),
              const Spacer(flex: 5),
              GestureDetector(
                onTap: () {
                  navigateToChallenge(year, month);
                  Navigator.of(context).pop();
                },
                child: Container(
                  width: double.infinity,
                  height: 56,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: AppColors.blue,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  alignment: Alignment.center,
                  child: Text('Go to month',
                      style: poppins(18, FontWeight.w900, Colors.white)),
                ),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: double.infinity,
                  height: 56,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                        color: const Color(0xFFE4E6F1), width: 1.5),
                  ),
                  child: Text('Close',
                      style: poppins(18, FontWeight.w900, const Color(0xFF8C90A6))),
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

// ───────────────── Month detail screen (Challenge tab) ─────────────────

class MonthDetailScreen extends StatefulWidget {
  final int initialYear;
  final int initialMonth;
  const MonthDetailScreen({
    super.key,
    required this.initialYear,
    required this.initialMonth,
  });

  @override
  State<MonthDetailScreen> createState() => _MonthDetailScreenState();
}

class _MonthDetailScreenState extends State<MonthDetailScreen> {
  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    _year = widget.initialYear;
    _month = widget.initialMonth;
  }

  void _prev() {
    setState(() {
      _month--;
      if (_month < 1) { _month = 12; _year--; }
    });
  }

  void _next() {
    final now = DateTime.now();
    final nextM = _month + 1;
    final nextY = nextM > 12 ? _year + 1 : _year;
    final adjM = nextM > 12 ? 1 : nextM;
    if (nextY > now.year || (nextY == now.year && adjM > now.month)) return;
    setState(() {
      _month = adjM;
      _year = nextY;
    });
  }

  bool get _canGoNext {
    final now = DateTime.now();
    final nextM = _month + 1;
    final nextY = nextM > 12 ? _year + 1 : _year;
    final adjM = nextM > 12 ? 1 : nextM;
    return nextY < now.year || (nextY == now.year && adjM <= now.month);
  }

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static const _daysInMonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

  @override
  Widget build(BuildContext context) {
    final played = Prefs.playedDays.toSet();
    final now = DateTime.now();
    final isLeap = _month == 2 && _year % 4 == 0 &&
        (_year % 100 != 0 || _year % 400 == 0);
    final totalDays = isLeap ? 29 : _daysInMonth[_month - 1];

    var playedCount = 0;
    final prefix = '$_year-${_month.toString().padLeft(2, '0')}-';
    for (final d in played) {
      if (d.startsWith(prefix)) playedCount++;
    }
    final completed = playedCount >= totalDays;

    final firstWeekday = DateTime(_year, _month, 1).weekday; // 1=Mon
    final isCurrentMonth = _year == now.year && _month == now.month;

    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 16),
          // trophy + nav arrows
          Row(
            children: [
              const SizedBox(width: 8),
              _NavArrow(icon: Icons.arrow_back_ios_rounded, onTap: _prev),
              Expanded(
                child: SizedBox(
                  height: 140,
                  child: CustomPaint(
                    painter: TrophyPainter(unlocked: completed),
                  ),
                ),
              ),
              _canGoNext
                  ? _NavArrow(icon: Icons.arrow_forward_ios_rounded, onTap: _next)
                  : const SizedBox(width: 48),
              const SizedBox(width: 8),
            ],
          ),
          const SizedBox(height: 8),
          // progress bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 50),
            child: _AwardProgress(current: playedCount, target: totalDays),
          ),
          const SizedBox(height: 20),
          // month title
          Text('${_monthNames[_month - 1]} $_year',
              style: poppins(22, FontWeight.w800, AppColors.ink)),
          const SizedBox(height: 16),
          // weekday headers
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su']
                  .map((d) => Expanded(
                        child: Center(
                          child: Text(d,
                              style: poppins(13, FontWeight.w700, AppColors.muted)),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),
          // calendar grid
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _CalendarGrid(
                year: _year,
                month: _month,
                totalDays: totalDays,
                firstWeekday: firstWeekday,
                playedDays: played,
                isCurrentMonth: isCurrentMonth,
                today: now.day,
              ),
            ),
          ),
          // Play button
          Padding(
            padding: const EdgeInsets.fromLTRB(40, 8, 40, 16),
            child: GestureDetector(
              onTap: () {
                // TODO: navigate to daily challenge for this month
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: AppColors.blue,
                  borderRadius: BorderRadius.circular(30),
                ),
                alignment: Alignment.center,
                child: Text('Play',
                    style: poppins(18, FontWeight.w800, Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFE8EAF4),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: AppColors.ink),
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  final int year, month, totalDays, firstWeekday, today;
  final Set<String> playedDays;
  final bool isCurrentMonth;

  const _CalendarGrid({
    required this.year,
    required this.month,
    required this.totalDays,
    required this.firstWeekday,
    required this.playedDays,
    required this.isCurrentMonth,
    required this.today,
  });

  @override
  Widget build(BuildContext context) {
    final cells = <Widget>[];
    // empty cells before first day
    for (var i = 1; i < firstWeekday; i++) {
      cells.add(const SizedBox());
    }
    for (var d = 1; d <= totalDays; d++) {
      final dateStr =
          '$year-${month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
      final wasPlayed = playedDays.contains(dateStr);
      final isToday = isCurrentMonth && d == today;
      final isFuture = isCurrentMonth && d > today;

      cells.add(_DayCell(
        day: d,
        played: wasPlayed,
        isToday: isToday,
        isFuture: isFuture,
      ));
    }

    return GridView.count(
      crossAxisCount: 7,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 0,
      children: cells,
    );
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final bool played;
  final bool isToday;
  final bool isFuture;

  const _DayCell({
    required this.day,
    required this.played,
    required this.isToday,
    required this.isFuture,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color textColor;

    if (played && !isToday) {
      bg = const Color(0xFF28E588);
      textColor = Colors.white;
    } else if (isToday) {
      bg = AppColors.blue;
      textColor = Colors.white;
    } else if (isFuture) {
      bg = Colors.transparent;
      textColor = const Color(0xFFCDD2E4);
    } else {
      bg = const Color(0xFFEDEFF7);
      textColor = AppColors.ink;
    }

    return Center(
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text('$day',
            style: poppins(14, FontWeight.w800, textColor)),
      ),
    );
  }
}
