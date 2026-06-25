import 'dart:async';
import 'package:flutter/material.dart';
import 'challenge.dart';
import 'collection_icons.dart';
import 'config.dart';
import 'level_legend.dart';
import 'main.dart' show navigateToChallenge, startDailyChallenge;
import 'perfect.dart';
import 'prefs.dart';
import 'records.dart';
import 'streak.dart';
import 'streak_screen.dart';
import 'ui_kit.dart';
import 'unstoppable.dart';

class CollectionScreen extends StatelessWidget {
  const CollectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bestStreak = StreakService.best;
    final winStreak = RecordsService.highestWinStreak;
    final mostWins = RecordsService.mostWins;
    // a record with a value but no stored date (set before date-tracking) falls
    // back to today so the card never shows a blank date
    final todayStr = _recordDate(_isoToday());
    String dateOr(String stored, int value) =>
        stored.isNotEmpty ? stored : (value > 0 ? todayStr : '');

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
                  value: '$bestStreak',
                  label: 'Longest Streak',
                  date: dateOr(_recordDate(Prefs.bestStreakDate), bestStreak),
                  onTap: bestStreak > 0
                      ? () => showRecordDetail(context,
                          iconWidget: const FlameOnPedestal(),
                          value: '$bestStreak',
                          date: dateOr(
                              _recordDate(Prefs.bestStreakDate), bestStreak),
                          text: 'You reached a $bestStreak day streak!',
                          primaryLabel: 'Current Streak',
                          onPrimary: () =>
                              showStreakDetail(context, StreakService.current))
                      : null,
                )),
                const SizedBox(width: 12),
                Expanded(child: _RecordCard(
                  painter: CrownPainter(),
                  value: '$winStreak',
                  label: 'Highest Win\nStreak',
                  date: dateOr(RecordsService.highestWinStreakDate, winStreak),
                  onTap: winStreak > 0
                      ? () => showRecordDetail(context,
                          painter: CrownPainter(),
                          value: '$winStreak',
                          date: dateOr(
                              RecordsService.highestWinStreakDate, winStreak),
                          text: 'You won $winStreak levels in a row!',
                          currentText:
                              "You're on ${RecordsService.currentWinStreak} "
                              'wins in a row.')
                      : null,
                )),
                const SizedBox(width: 12),
                Expanded(child: _RecordCard(
                  painter: WingArrowPainter(),
                  value: '$mostWins',
                  label: 'Most Wins',
                  date: dateOr(RecordsService.mostWinsDate, mostWins),
                  onTap: mostWins > 0
                      ? () => showRecordDetail(context,
                          painter: WingArrowPainter(),
                          value: '$mostWins',
                          date: dateOr(RecordsService.mostWinsDate, mostWins),
                          text: 'You won $mostWins levels in a day!',
                          currentText:
                              'You won ${RecordsService.winsToday} levels today.')
                      : null,
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

  // The app's first season — never show trophy years before this.
  static const _startYear = 2026;

  static List<Widget> _buildTrophyYears() {
    final played = Prefs.playedDays.toSet();
    final now = DateTime.now();
    final years = <int>{now.year};
    for (final d in played) {
      final y = int.tryParse(d.split('-').first);
      if (y != null && y >= _startYear) years.add(y);
    }
    final sorted = years.where((y) => y >= _startYear).toList()
      ..sort((a, b) => b.compareTo(a));

    final widgets = <Widget>[];
    for (final year in sorted) {
      widgets.add(const SizedBox(height: 10));
      widgets.add(Text('$year', style: poppins(18, FontWeight.w900, AppColors.ink)));
      widgets.add(const SizedBox(height: 12));
      widgets.add(_TrophyGrid(year: year, playedDays: played));
    }
    return widgets;
  }

  /// Formats an ISO date ("2026-04-12") as "Apr 12 2026", or '' if unset.
  static String _recordDate(String iso) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final p = iso.split('-');
    if (p.length != 3) return '';
    final m = int.tryParse(p[1]) ?? 1;
    return '${months[m - 1]} ${int.parse(p[2])} ${p[0]}';
  }

  static String _isoToday() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }
}

/// Full-screen record detail: large icon + number, date, a line of text and a
/// Close button. Optionally a "Current …" line (Highest Win Streak, Most Wins)
/// or a primary action button (Longest Streak → Current Streak).
void showRecordDetail(
  BuildContext context, {
  CustomPainter? painter,
  Widget? iconWidget,
  required String value,
  required String date,
  required String text,
  String? currentText,
  String? primaryLabel,
  VoidCallback? onPrimary,
  double badgeAlign = 0.80,
  Color textColor = const Color(0xFF5E658B),
}) {
  showGeneralDialog(
    context: context,
    barrierLabel: 'Record',
    barrierColor: Colors.black.withValues(alpha: 0.0),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (_, __, ___) => _RecordDetailScreen(
        painter: painter, iconWidget: iconWidget, value: value, date: date,
        text: text, currentText: currentText, primaryLabel: primaryLabel,
        onPrimary: onPrimary, badgeAlign: badgeAlign, textColor: textColor),
    transitionBuilder: (_, anim, __, child) => FadeTransition(
      opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
      child: child,
    ),
  );
}

class _RecordDetailScreen extends StatelessWidget {
  final CustomPainter? painter;
  final Widget? iconWidget;
  final String value, date, text;
  final String? currentText;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final double badgeAlign;
  final Color textColor;
  const _RecordDetailScreen({
    this.painter,
    this.iconWidget,
    required this.value,
    required this.date,
    required this.text,
    this.currentText,
    this.primaryLabel,
    this.onPrimary,
    this.badgeAlign = 0.80,
    this.textColor = const Color(0xFF5E658B),
  });

  @override
  Widget build(BuildContext context) {
    // The bottom section (Current line, or the primary button) lives in a
    // fixed-height, bottom-aligned slot so the icon/date/text up top and the
    // Close button at the bottom sit at identical positions on all 3 screens.
    final bottomSlot = SizedBox(
      height: 84,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (currentText != null) ...[
            const _DatePill('Current'),
            const SizedBox(height: 10),
            Text(currentText!,
                textAlign: TextAlign.center,
                style: poppins(16, FontWeight.w800, const Color(0xFF7A809C))),
          ],
          if (primaryLabel != null)
            Pressable(
              onTap: onPrimary ?? () {},
              child: Container(
                width: 250,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.blue,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Text(primaryLabel!,
                    style: poppins(17, FontWeight.w900, Colors.white)),
              ),
            ),
        ],
      ),
    );

    return Material(
      color: Colors.white,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            children: [
              const Spacer(flex: 3),
              SizedBox(
                width: 215,
                height: 215,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: iconWidget ?? CustomPaint(painter: painter),
                      ),
                    ),
                    Align(
                      alignment: Alignment(0, badgeAlign),
                      child: _NumberBadge(value, fontSize: 34),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (date.isNotEmpty) _DatePill(date),
              const SizedBox(height: 18),
              Text(text,
                  textAlign: TextAlign.center,
                  style: poppins(18, FontWeight.w900, textColor)),
              const Spacer(flex: 4),
              bottomSlot,
              const SizedBox(height: 14),
              Pressable(
                onTap: () => Navigator.of(context).maybePop(),
                child: Container(
                  width: 250,
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: const Color(0xFFE4E6F1), width: 1.5),
                  ),
                  child: Text('Close',
                      style: poppins(17, FontWeight.w900, const Color(0xFF8C90A6))),
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
  final VoidCallback? onTap;
  const _RecordCard({
    this.painter,
    this.iconWidget,
    required this.value,
    required this.label,
    required this.date,
    this.onTap,
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
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
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F2F8),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(text, style: poppins(13, FontWeight.w800, const Color(0xFF535B83))),
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
              _PressButton(
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
              _PressButton(
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

class _MonthDetailScreenState extends State<MonthDetailScreen>
    with TickerProviderStateMixin {
  late int _year;
  late int _month;
  int? _selectedDay; // user-tapped selection; null = use default
  Timer? _tick;

  // ── completion animation state ──
  AnimationController? _animCtrl;
  bool _animating = false;
  int _animDay = 0; // the day whose dot flies up
  int _animOldCount = 0; // played count before this completion
  Offset? _dotStart; // calendar-cell position (in Stack coords)
  Offset? _dotEnd; // progress-bar landing position
  final _progressKey = GlobalKey();
  final _calendarKey = GlobalKey();
  final _stackKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _year = widget.initialYear;
    _month = widget.initialMonth;
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _animCtrl?.dispose();
    super.dispose();
  }

  /// Time remaining until midnight, formatted "Xh Ym".
  String _untilMidnight() {
    final now = DateTime.now();
    final next = DateTime(now.year, now.month, now.day + 1);
    final d = next.difference(now);
    return '${d.inHours}h ${d.inMinutes % 60}m';
  }

  void _prev() {
    if (!_canGoPrev) return;
    setState(() {
      _month--;
      if (_month < 1) { _month = 12; _year--; }
      _selectedDay = null; // reset selection on month change
    });
  }

  static const _startYear = 2026;
  bool get _canGoPrev =>
      _year > _startYear || (_year == _startYear && _month > 1);

  void _next() {
    final now = DateTime.now();
    final nextM = _month + 1;
    final nextY = nextM > 12 ? _year + 1 : _year;
    final adjM = nextM > 12 ? 1 : nextM;
    if (nextY > now.year || (nextY == now.year && adjM > now.month)) return;
    setState(() {
      _month = adjM;
      _year = nextY;
      _selectedDay = null;
    });
  }

  bool get _canGoNext {
    final now = DateTime.now();
    final nextM = _month + 1;
    final nextY = nextM > 12 ? _year + 1 : _year;
    final adjM = nextM > 12 ? 1 : nextM;
    return nextY < now.year || (nextY == now.year && adjM <= now.month);
  }

  /// Compute the center of a calendar day cell in global coordinates.
  Offset? _dayCellCenter(int day) {
    final calBox = _calendarKey.currentContext?.findRenderObject() as RenderBox?;
    if (calBox == null) return null;
    final firstWeekday = DateTime(_year, _month, 1).weekday;
    final idx = firstWeekday - 1 + day - 1; // 0-based index in grid
    final col = idx % 7;
    final row = idx ~/ 7;
    // _calendarKey is on the Padding(horizontal:30), so inner grid
    // starts at x=30 with width = calBox.width - 60
    const pad = 30.0;
    final gridW = calBox.size.width - pad * 2;
    final cellW = gridW / 7;
    // GridView.count with aspectRatio 1.0: cell height = cell width
    // mainAxisSpacing = 2
    const spacing = 2.0;
    final cellH = cellW;
    final x = pad + col * cellW + cellW / 2;
    final y = row * (cellH + spacing) + cellH / 2;
    return calBox.localToGlobal(Offset(x, y));
  }

  /// Progress-bar green pill center-left in global coordinates.
  Offset? _progressBarLeft() {
    final box = _progressKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    // _progressKey is on the Padding(horizontal:70), inner bar starts at x=70
    return box.localToGlobal(Offset(70 + 18, box.size.height / 2));
  }

  void _startCompletionAnim(int day, int oldCount) {
    _animDay = day;
    _animOldCount = oldCount;
    _animCtrl?.dispose();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _animating = true;
    _animCtrl!.addListener(() => setState(() {}));
    _animCtrl!.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        setState(() => _animating = false);
      }
    });
    // rebuild first so the calendar renders the day, then read positions
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dotStart = _dayCellCenter(day);
      _dotEnd = _progressBarLeft();
      if (_dotStart == null || _dotEnd == null) {
        _animating = false;
        setState(() {});
        return;
      }
      _animCtrl!.forward();
    });
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

    String dayStr(int d) =>
        '$_year-${_month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
    final todayDone = isCurrentMonth && played.contains(dayStr(now.day));

    // default selection:
    //  - current month with today still pending/in-progress → today
    //  - otherwise → lowest day with progress, else lowest un-played day
    int defaultDay;
    if (isCurrentMonth && !todayDone) {
      defaultDay = now.day;
    } else {
      defaultDay = isCurrentMonth ? now.day : 1;
      // lowest pending (un-played, not future) day
      final maxDay = isCurrentMonth ? now.day : totalDays;
      for (var d = 1; d <= maxDay; d++) {
        if (!played.contains(dayStr(d))) {
          defaultDay = d;
          break;
        }
      }
      // lowest day with saved progress takes priority
      for (var d = 1; d <= totalDays; d++) {
        if (ChallengeService.hasProgress(DateTime(_year, _month, d))) {
          defaultDay = d;
          break;
        }
      }
    }
    // current month with every day up to today already completed → there's
    // nothing to play; show the countdown and select nothing by default.
    var allCaughtUp = isCurrentMonth;
    if (allCaughtUp) {
      for (var d = 1; d <= now.day; d++) {
        if (!played.contains(dayStr(d))) {
          allCaughtUp = false;
          break;
        }
      }
    }
    final noSelection = allCaughtUp && _selectedDay == null;

    final activeDay = _selectedDay ?? defaultDay;
    final activeDate = DateTime(_year, _month, activeDay);
    final selectedPlayed =
        played.contains('$_year-${_month.toString().padLeft(2, '0')}'
            '-${activeDay.toString().padLeft(2, '0')}');
    // an active in-progress attempt on the selected day (first play or replay)
    final inProgress = ChallengeService.hasProgress(activeDate);
    // completed day → Replay (or Continue if a replay is mid-way);
    // un-played day → Play (or Continue if mid-way)
    final btnLabel = inProgress
        ? 'Continue'
        : (selectedPlayed ? 'Replay' : 'Play');

    // ── animation phases ──
    // 0.0-0.20: day shows as blue selected, overlay transitions blue→green
    // 0.20-0.62: green dot flies up in a curve to progress bar
    // 0.62-0.72: dot merges, count increments
    // 0.78-0.95: button slides up
    final double aT = _animCtrl?.value ?? 0;
    final colorT = _animating ? Curves.easeOut.transform(
        ((aT - 0.0) / 0.20).clamp(0.0, 1.0)) : 0.0;
    final flyT = _animating ? Curves.easeInOut.transform(
        ((aT - 0.20) / 0.42).clamp(0.0, 1.0)) : 0.0;
    final countLanded = _animating && flyT >= 1.0;
    final btnT = _animating ? Curves.easeOut.transform(
        ((aT - 0.78) / 0.17).clamp(0.0, 1.0)) : 0.0;

    // During animation:
    // - Before color done: remove from played, overlay draws blue→green on top
    // - After color done: ADD to played (green stays on cell), copy flies up
    final Set<String> effectivePlayed;
    if (_animating && _animDay > 0) {
      final key = dayStr(_animDay);
      if (colorT >= 1.0) {
        // day stays green in the calendar; a copy flies
        effectivePlayed = Set<String>.from(played)..add(key);
      } else {
        // day shows as gray underneath; overlay draws the blue→green dot
        effectivePlayed = Set<String>.from(played)..remove(key);
      }
    } else {
      effectivePlayed = played;
    }
    // progress bar: show old count until dot lands, then new count
    final displayCount = _animating
        ? (countLanded ? _animOldCount + 1 : _animOldCount)
        : playedCount;
    // in-place overlay: only during color phase (before fly starts)
    // flying copy: during fly phase
    final showInPlaceDot = _animating && colorT < 1.0;
    final showFlyingCopy = _animating && colorT >= 1.0 && flyT > 0 && flyT < 1.0;

    // button visibility
    final showButton = !_animating || aT >= 0.78;
    final buttonSlide = _animating ? (1 - btnT) * 80 : 0.0;

    return SafeArea(
      child: Stack(
        key: _stackKey,
        children: [
          Column(
            children: [
              const SizedBox(height: 12),
              Row(
                children: [
                  const SizedBox(width: 16),
                  _canGoPrev
                      ? _NavArrow(pointLeft: true, onTap: _prev)
                      : const SizedBox(width: 44),
                  Expanded(
                    child: Center(
                      child: SizedBox(
                        width: 128,
                        height: 128,
                        child: CustomPaint(
                          painter: TrophyPainter(unlocked: completed),
                        ),
                      ),
                    ),
                  ),
                  _canGoNext
                      ? _NavArrow(pointLeft: false, onTap: _next)
                      : const SizedBox(width: 44),
                  const SizedBox(width: 16),
                ],
              ),
              const SizedBox(height: 6),
              Padding(
                key: _progressKey,
                padding: const EdgeInsets.symmetric(horizontal: 70),
                child: _AwardProgress(
                  current: displayCount,
                  target: totalDays,
                ),
              ),
              const SizedBox(height: 16),
              Text('${_monthNames[_month - 1]} $_year',
                  style: poppins(22, FontWeight.w900, AppColors.blue)),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Row(
                  children: ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su']
                      .map((d) => Expanded(
                            child: Center(
                              child: Text(d,
                                  style: poppins(15, FontWeight.w900,
                                      const Color(0xFFB4B9CF))),
                            ),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                key: _calendarKey,
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: _CalendarGrid(
                  year: _year,
                  month: _month,
                  totalDays: totalDays,
                  firstWeekday: firstWeekday,
                  playedDays: effectivePlayed,
                  isCurrentMonth: isCurrentMonth,
                  today: now.day,
                  selectedDay: noSelection ? -1 : activeDay,
                  onSelect: _animating ? null : (d) => setState(() => _selectedDay = d),
                ),
              ),
              const Expanded(child: SizedBox()),
              if (showButton)
                Transform.translate(
                  offset: Offset(0, buttonSlide),
                  child: Opacity(
                    opacity: _animating ? btnT : 1.0,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(40, 0, 40, 28),
                      child: noSelection
                          ? Container(
                              width: double.infinity,
                              height: 62,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F2F8),
                                borderRadius: BorderRadius.circular(31),
                              ),
                              child: Text('New level in ${_untilMidnight()}',
                                  style: poppins(
                                      18, FontWeight.w900, AppColors.blue)),
                            )
                          : _PressButton(
                              onTap: () async {
                                final wasPlayed =
                                    played.contains(dayStr(activeDay));
                                final oldCount = playedCount;
                                await startDailyChallenge(context, activeDate);
                                if (!context.mounted) return;
                                final nowPlayed = Prefs.playedDays.toSet()
                                    .contains(dayStr(activeDay));
                                if (!wasPlayed && nowPlayed) {
                                  _selectedDay = null;
                                  _startCompletionAnim(activeDay, oldCount);
                                } else {
                                  setState(() => _selectedDay = null);
                                }
                              },
                              child: Container(
                                width: double.infinity,
                                height: 62,
                                decoration: BoxDecoration(
                                  color: AppColors.blue,
                                  borderRadius: BorderRadius.circular(31),
                                ),
                                alignment: Alignment.center,
                                child: Text(btnLabel,
                                    style: poppins(
                                        23, FontWeight.w900, Colors.white)),
                              ),
                            ),
                    ),
                  ),
                ),
              if (!showButton) const SizedBox(height: 90),
            ],
          ),
          // in-place blue→green overlay (before fly)
          if (showInPlaceDot && _dotStart != null)
            _buildInPlaceDot(colorT),
          // flying green copy (during fly)
          if (showFlyingCopy && _dotStart != null && _dotEnd != null)
            _buildFlyingCopy(flyT),
        ],
      ),
    );
  }

  /// In-place overlay: blue→green transition sitting on the calendar cell.
  Widget _buildInPlaceDot(double colorT) {
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null) return const SizedBox();
    final s = stackBox.globalToLocal(_dotStart!);
    const dotSize = 34.0;
    final color = Color.lerp(AppColors.blue, const Color(0xFF28E588), colorT)!;
    return Positioned(
      left: s.dx - dotSize / 2,
      top: s.dy - dotSize / 2,
      child: Container(
        width: dotSize,
        height: dotSize,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }

  /// Flying green copy: lifts off the day cell and curves up to progress bar.
  Widget _buildFlyingCopy(double flyT) {
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null) return const SizedBox();
    final s = stackBox.globalToLocal(_dotStart!);
    final e = stackBox.globalToLocal(_dotEnd!);
    const dotSize = 34.0;
    final ctrl = Offset(
      s.dx + (e.dx - s.dx) * 0.4,
      e.dy + (s.dy - e.dy) * 0.15,
    );
    final pos = _quadBezier(s, ctrl, e, flyT);
    final opacity = flyT > 0.85 ? (1 - flyT) / 0.15 : 1.0;
    return Positioned(
      left: pos.dx - dotSize / 2,
      top: pos.dy - dotSize / 2,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: const SizedBox(
          width: dotSize,
          height: dotSize,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xFF28E588),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }

  static Offset _quadBezier(Offset a, Offset ctrl, Offset b, double t) {
    final u = 1 - t;
    return Offset(
      u * u * a.dx + 2 * u * t * ctrl.dx + t * t * b.dx,
      u * u * a.dy + 2 * u * t * ctrl.dy + t * t * b.dy,
    );
  }
}

/// Wraps a tappable child with a quick scale-down press animation.
class _PressButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _PressButton({required this.child, required this.onTap});

  @override
  State<_PressButton> createState() => _PressButtonState();
}

class _PressButtonState extends State<_PressButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class _NavArrow extends StatelessWidget {
  final bool pointLeft;
  final VoidCallback onTap;
  const _NavArrow({required this.pointLeft, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _PressButton(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          color: Color(0xFFD5DAF6),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Transform.rotate(
          angle: pointLeft ? 3.14159 : 0,
          child: const Icon(Icons.play_arrow_rounded,
              size: 38, color: Color(0xFF555B83)),
        ),
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  final int year, month, totalDays, firstWeekday, today, selectedDay;
  final Set<String> playedDays;
  final bool isCurrentMonth;
  final ValueChanged<int>? onSelect;

  const _CalendarGrid({
    required this.year,
    required this.month,
    required this.totalDays,
    required this.firstWeekday,
    required this.playedDays,
    required this.isCurrentMonth,
    required this.today,
    required this.selectedDay,
    required this.onSelect,
  });

  String _dateStr(int d) =>
      '$year-${month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final cells = <Widget>[];
    // empty cells before first day
    for (var i = 1; i < firstWeekday; i++) {
      cells.add(const SizedBox());
    }
    for (var d = 1; d <= totalDays; d++) {
      final wasPlayed = playedDays.contains(_dateStr(d));
      // a completed day can carry a mid-way replay attempt too
      final progress = ChallengeService.progressFor(DateTime(year, month, d));
      final isFuture = isCurrentMonth && d > today;
      final selectable = !isFuture; // completed days are selectable (replay)

      cells.add(_DayCell(
        day: d,
        played: wasPlayed,
        isSelected: d == selectedDay && selectable,
        isFuture: isFuture,
        progress: progress,
        onTap: selectable && onSelect != null ? () => onSelect!(d) : null,
      ));
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 2,
      crossAxisSpacing: 0,
      children: cells,
    );
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final bool played;
  final bool isSelected;
  final bool isFuture;
  final double progress; // 0..1 arrows fired on this day
  final VoidCallback? onTap;

  const _DayCell({
    required this.day,
    required this.played,
    required this.isSelected,
    required this.isFuture,
    this.progress = 0.0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasRing = progress > 0 && progress < 1;
    // base circle colour
    final Color bg;
    final Color textColor;
    if (played) {
      bg = const Color(0xFF28E588); // green = completed
      textColor = Colors.white;
    } else if (isSelected) {
      bg = AppColors.blue;
      textColor = Colors.white;
    } else if (isFuture) {
      bg = Colors.transparent;
      textColor = const Color(0xFFCDD2E4);
    } else {
      bg = const Color(0xFFEDEFF7);
      textColor = const Color(0xFF5E658B);
    }

    // show the number only when selected, or for an un-played non-future day.
    // A completed day shows a bare dot unless it's the selected one.
    final showNumber = (!played && !isFuture) || isSelected;
    final size = isSelected ? 38.0 : 34.0;

    final circle = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: showNumber
          ? Transform.translate(
              offset: const Offset(0, 1),
              child: Text('$day',
                  style: poppins(isSelected ? 17 : 16, FontWeight.w900,
                      textColor, height: 1.0)),
            )
          : null,
    );

    Widget content = circle;
    if (hasRing) {
      // selected → white inner arc; not selected → blue arc around the circle
      content = SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            circle,
            Positioned.fill(
              child: CustomPaint(
                painter: _RingPainter(
                  progress,
                  color: isSelected ? Colors.white : AppColors.blue,
                  inset: isSelected ? 4 : 1,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(child: content),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double inset; // distance from the circle edge
  const _RingPainter(this.progress, {this.color = Colors.white, this.inset = 4});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - inset;
    final arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: c, radius: r),
        -1.5708, 6.2832 * progress.clamp(0.0, 1.0), false, arc);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.color != color || old.inset != inset;
}
