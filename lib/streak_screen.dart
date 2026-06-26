import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'l10n.dart';
import 'prefs.dart';
import 'streak.dart';
import 'ui_kit.dart';

const _pendingBlue = Color(0xFFB8BFE0); // today, not-yet-earned circle
const _pendingLabel = Color(0xFF7A89FB); // today label (pending)

const _flameOrange = Color(0xFFFF9800);
const _flameGray = Color(0xFFBFC4D8);

/// Gradient used for the streak flame fill (matches the Longest Streak icon).
const _flameGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFFFFD15C), Color(0xFFFFA838), Color(0xFFF8842B)],
);

/// Streak Freezers ship in v2 — flip to true to re-enable the card.
const _showFreezers = false;

/// Material flame used across the streak UI. [active] = warm orange, else gray.
Widget streakFlame({double size = 140, bool active = true}) => Icon(
      Icons.local_fire_department_rounded,
      size: size,
      color: active ? _flameOrange : _flameGray,
    );

/// One day in the current-week streak row.
class _WeekDay {
  final String label;
  final bool done;
  final bool isToday;
  const _WeekDay(this.label, this.done, this.isToday);
}

List<_WeekDay> _currentWeek() {
  final labels = [Tr.get('mo'), Tr.get('tu'), Tr.get('we'), Tr.get('th'), Tr.get('fr'), Tr.get('sa'), Tr.get('su')];
  String fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final monday = today.subtract(Duration(days: now.weekday - 1));
  // derive played days from streak length (consecutive days)
  final streak = StreakService.current;
  final lastPlayed = Prefs.lastPlayed;
  final streakDays = <String>{};
  if (lastPlayed.isNotEmpty && streak > 0) {
    final base = lastPlayed == fmt(now)
        ? now
        : now.subtract(const Duration(days: 1));
    for (var i = 0; i < streak; i++) {
      streakDays.add(fmt(base.subtract(Duration(days: i))));
    }
  }
  final out = <_WeekDay>[];
  for (var i = 0; i < 7; i++) {
    final d = monday.add(Duration(days: i));
    out.add(_WeekDay(labels[i], streakDays.contains(fmt(d)), d == today));
  }
  return out;
}

/// Mo–Su row with check circles for completed days. When [todayPop] is given,
/// today's freshly-earned check scales in with it.
class StreakWeekRow extends StatelessWidget {
  final Animation<double>? todayPop;
  const StreakWeekRow({super.key, this.todayPop});

  static const _cell = 42.0; // column width (tighter than full-width)
  static const _circle = 34.0;

  @override
  Widget build(BuildContext context) {
    final week = _currentWeek();
    final doneIdx = [for (var i = 0; i < 7; i++) if (week[i].done) i];

    return Center(
      child: Column(
        children: [
          // labels
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final d in week)
                SizedBox(
                  width: _cell,
                  child: Center(
                    child: Text(d.label,
                        style: poppins(13, FontWeight.w900,
                            d.done
                                ? _flameOrange
                                : d.isToday
                                    ? const Color(0xFF7A89FB)
                                    : const Color(0xFFC2C7DE))),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // circles, with a light-orange bar connecting the completed run
          SizedBox(
            width: _cell * 7,
            height: _circle,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                if (doneIdx.isNotEmpty)
                  Positioned(
                    // thin pill connecting the centres of the completed run
                    left: doneIdx.first * _cell + _cell / 2 - 6,
                    top: (_circle - 24) / 2,
                    child: Container(
                      width: (doneIdx.last - doneIdx.first) * _cell + 12,
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBE3C8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final d in week)
                      SizedBox(width: _cell, child: Center(child: _checkCircle(d))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _checkCircle(_WeekDay d) {
    final color = d.done
        ? _flameOrange
        : d.isToday
            ? const Color(0xFFB8BFE0)
            : const Color(0xFFEDEFF7);
    final circle = Container(
      width: _circle,
      height: _circle,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: d.done
          ? const SizedBox(
              width: 20, height: 20,
              child: CustomPaint(painter: _CheckPainter()))
          : null,
    );
    // animate today's newly-earned check popping in
    if (d.done && d.isToday && todayPop != null) {
      return ScaleTransition(scale: todayPop!, child: circle);
    }
    return circle;
  }
}

/// Streak celebration shown after winning a level that extends the streak.
/// Sequenced to match the reference:
///   1. cream progress bar extends from the existing run out to today
///   2. simultaneously — today's circle flips+zooms to an orange check,
///      the count rolls old→new, and the flame fills orange bottom→top
///   3. the Continue button slides up ~1s later
class StreakCelebration extends StatefulWidget {
  final int streak;
  final VoidCallback onContinue;
  const StreakCelebration(
      {super.key, required this.streak, required this.onContinue});

  @override
  State<StreakCelebration> createState() => _StreakCelebrationState();
}

class _StreakCelebrationState extends State<StreakCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _enter; // initial fade-in (resting state)
  late final Animation<double> _bar; // progress bar Mo→today
  late final Animation<double> _flip; // today circle flip+zoom
  late final Animation<double> _roll; // count roll old→new
  late final Animation<double> _fill; // flame orange fill bottom→top
  late final Animation<double> _button; // Continue slide-up

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2600));
    _enter = CurvedAnimation(
        parent: _c, curve: const Interval(0.0, 0.12, curve: Curves.easeOut));
    _bar = CurvedAnimation(
        parent: _c, curve: const Interval(0.16, 0.40, curve: Curves.easeInOut));
    // the three simultaneous beats, once the bar reaches today
    _flip = CurvedAnimation(
        parent: _c, curve: const Interval(0.40, 0.62, curve: Curves.easeOutBack));
    _roll = CurvedAnimation(
        parent: _c, curve: const Interval(0.40, 0.60, curve: Curves.easeOut));
    _fill = CurvedAnimation(
        parent: _c, curve: const Interval(0.40, 0.64, curve: Curves.easeInOut));
    _button = CurvedAnimation(
        parent: _c, curve: const Interval(0.82, 1.0, curve: Curves.easeOut));
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final oldStreak = widget.streak - 1;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            return Column(
              children: [
                const Spacer(flex: 3),
                Opacity(
                  opacity: _enter.value,
                  child: _FillFlame(size: 150, fill: _fill.value),
                ),
                const SizedBox(height: 18),
                Opacity(
                  opacity: _enter.value,
                  child: _RollingStreakText(
                    oldStreak: oldStreak,
                    newStreak: widget.streak,
                    t: _roll.value,
                  ),
                ),
                const SizedBox(height: 24),
                Opacity(
                  opacity: _enter.value,
                  child: _CelebrationWeekRow(
                    barExtend: _bar.value,
                    todayFlip: _flip.value,
                  ),
                ),
                const Spacer(flex: 4),
                Transform.translate(
                  offset: Offset(0, (1 - _button.value) * 80),
                  child: Opacity(
                    opacity: _button.value,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(40, 0, 40, 28),
                      child: PrimaryButton(
                          label: Tr.get('continueButton'),
                          onTap: widget.onContinue,
                          width: double.infinity),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Flame icon that fills orange from the bottom up over a gray base.
class _FillFlame extends StatelessWidget {
  final double size;
  final double fill; // 0 = all gray, 1 = all orange
  const _FillFlame({required this.size, required this.fill});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Icon(Icons.local_fire_department_rounded,
              size: size, color: _flameGray),
          ClipRect(
            clipper: _BottomReveal(fill.clamp(0.0, 1.0)),
            child: ShaderMask(
              shaderCallback: (b) => _flameGradient.createShader(b),
              blendMode: BlendMode.srcIn,
              child: Icon(Icons.local_fire_department_rounded,
                  size: size, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomReveal extends CustomClipper<Rect> {
  final double fill;
  _BottomReveal(this.fill);
  @override
  Rect getClip(Size s) =>
      Rect.fromLTRB(0, s.height * (1 - fill), s.width, s.height);
  @override
  bool shouldReclip(covariant _BottomReveal old) => old.fill != fill;
}

/// "N day streak" where the leading number rolls old→new (old slides down and
/// out, new slides in from the top).
class _RollingStreakText extends StatelessWidget {
  final int oldStreak;
  final int newStreak;
  final double t; // 0 = old, 1 = new
  const _RollingStreakText(
      {required this.oldStreak, required this.newStreak, required this.t});

  @override
  Widget build(BuildContext context) {
    final style = poppins(25, FontWeight.w900, const Color(0xFF535B83));
    const h = 34.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: h,
          child: ClipRect(
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Transform.translate(
                  offset: Offset(0, t * h),
                  child: Opacity(
                      opacity: (1 - t).clamp(0.0, 1.0),
                      child: Text('$oldStreak', style: style)),
                ),
                Transform.translate(
                  offset: Offset(0, (t - 1) * h),
                  child: Opacity(
                      opacity: t.clamp(0.0, 1.0),
                      child: Text('$newStreak', style: style)),
                ),
              ],
            ),
          ),
        ),
        Text(' ${Tr.get('dayStreakSuffix')}', style: style),
      ],
    );
  }
}

/// Mo–Su row for the celebration: the cream pill extends out to today
/// ([barExtend]) and today's circle flips+zooms to an orange check ([todayFlip]).
class _CelebrationWeekRow extends StatelessWidget {
  final double barExtend; // 0 = bar covers prior run, 1 = reaches today
  final double todayFlip; // 0 = pending blue, 1 = orange check
  const _CelebrationWeekRow(
      {required this.barExtend, required this.todayFlip});

  static const _cell = 42.0;
  static const _circle = 34.0;

  @override
  Widget build(BuildContext context) {
    final week = _currentWeek();
    final todayIdx = week.indexWhere((d) => d.isToday);
    final oldDone = [
      for (var i = 0; i < 7; i++)
        if (week[i].done && !week[i].isToday) i
    ];
    final firstIdx = oldDone.isEmpty ? todayIdx : oldDone.first;
    final oldLastIdx = oldDone.isEmpty ? todayIdx : oldDone.last;
    final barLastCenter =
        (oldLastIdx + (todayIdx - oldLastIdx) * barExtend) * _cell + _cell / 2;
    final barLeft = firstIdx * _cell + _cell / 2 - 6;

    return Center(
      child: Column(
        children: [
          // labels
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 7; i++)
                SizedBox(
                  width: _cell,
                  child: Center(child: _label(week[i], i == todayIdx)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: _cell * 7,
            height: _circle,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // connecting pill (extends Mo→today)
                Positioned(
                  left: barLeft,
                  top: (_circle - 24) / 2,
                  child: Container(
                    width: (barLastCenter - 6) - barLeft,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBE3C8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 7; i++)
                      SizedBox(
                          width: _cell,
                          child: Center(child: _circleFor(week[i], i == todayIdx))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(_WeekDay d, bool isToday) {
    final Color color;
    if (isToday) {
      color = Color.lerp(_pendingLabel, _flameOrange, todayFlip)!;
    } else if (d.done) {
      color = _flameOrange;
    } else {
      color = const Color(0xFFC2C7DE);
    }
    return Text(d.label, style: poppins(13, FontWeight.w900, color));
  }

  Widget _circleFor(_WeekDay d, bool isToday) {
    if (isToday) {
      // pending blue base, with the orange check flipping in over it
      final angle = (1 - todayFlip) * (math.pi / 2);
      return SizedBox(
        width: _circle,
        height: _circle,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (todayFlip < 1)
              Container(
                width: _circle,
                height: _circle,
                decoration: const BoxDecoration(
                    color: _pendingBlue, shape: BoxShape.circle),
              ),
            Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0015)
                ..rotateY(angle)
                ..scaleByDouble(
                    0.6 + 0.4 * todayFlip.clamp(0.0, 1.0),
                    0.6 + 0.4 * todayFlip.clamp(0.0, 1.0),
                    1.0,
                    1.0),
              child: Opacity(
                opacity: todayFlip.clamp(0.0, 1.0),
                child: _orangeCheck(),
              ),
            ),
          ],
        ),
      );
    }
    if (d.done) return _orangeCheck();
    return Container(
      width: _circle,
      height: _circle,
      decoration: const BoxDecoration(
          color: Color(0xFFEDEFF7), shape: BoxShape.circle),
    );
  }

  Widget _orangeCheck() => Container(
        width: _circle,
        height: _circle,
        decoration:
            const BoxDecoration(color: _flameOrange, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: const SizedBox(
            width: 20, height: 20, child: CustomPaint(painter: _CheckPainter())),
      );
}

/// Streak detail (from the home streak pill): adds the Freezers card + Close.
class StreakDetailSheet extends StatelessWidget {
  final int streak;
  const StreakDetailSheet({super.key, required this.streak});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 3),
            streakFlame(size: 180),
            const SizedBox(height: 18),
            Text(Tr.param('dayStreak', {'count': '$streak'}),
                style: poppins(25, FontWeight.w900, const Color(0xFF535B83))),
            const SizedBox(height: 24),
            const StreakWeekRow(),
            if (!StreakService.playedToday) ...[
              const SizedBox(height: 18),
              Text(Tr.get('extendStreakText'),
                  style: poppins(14, FontWeight.w800, const Color(0xFF5E658B))),
            ],
            const Spacer(flex: 2),
            // Streak Freezers card — hidden for now, ships in v2.
            if (_showFreezers) ...[
              Container(
                // match the week row width (StreakWeekRow: 42 × 7 = 294)
                width: 294,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE9EBF4)),
                ),
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                      child: Column(
                        children: [
                          Text(Tr.get('streakFreezers'),
                              style: poppins(17, FontWeight.w900,
                                  const Color(0xFF535B83))),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (var i = 0; i < 3; i++)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 11),
                                  child: const DottedCircle(
                                    size: 46,
                                    child: _ThickPlus(
                                        size: 21, color: Color(0xFFD8D8DC)),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(Tr.get('freezerStatus'),
                              style: poppins(13.5, FontWeight.w800,
                                  const Color(0xFF535B83))),
                        ],
                      ),
                    ),
                    const Positioned(
                      top: 12,
                      right: 12,
                      child: Icon(Icons.info_outline_rounded,
                          size: 17, color: Color(0xFFB4B9CF)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],
            Padding(
              padding: const EdgeInsets.only(bottom: 26),
              child: Pressable(
                onTap: () => Navigator.of(context).maybePop(),
                child: Container(
                  width: 250,
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    border:
                        Border.all(color: const Color(0xFFE4E6F1), width: 1.5),
                  ),
                  child: Text(Tr.get('close'),
                      style:
                          poppins(17, FontWeight.w900, const Color(0xFF8C90A6))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A bold white checkmark.
class _CheckPainter extends CustomPainter {
  const _CheckPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.17
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(w * 0.22, h * 0.52)
      ..lineTo(w * 0.42, h * 0.72)
      ..lineTo(w * 0.78, h * 0.30);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// A bold rounded plus (two capsules).
class _ThickPlus extends StatelessWidget {
  final double size;
  final Color color;
  const _ThickPlus({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    final bar = size * 0.26;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: bar,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(bar)),
          ),
          Container(
            width: bar,
            height: size,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(bar)),
          ),
        ],
      ),
    );
  }
}

/// A circle with a dashed border (freezer slot).
class DottedCircle extends StatelessWidget {
  final double size;
  final Widget child;
  const DottedCircle({super.key, required this.size, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DashedCirclePainter(),
        child: Center(child: child),
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD8D8DC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    final r = size.width / 2 - 2;
    final c = size.center(Offset.zero);
    const dashes = 12;
    const sweep = 6.2832 / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), i * sweep,
          sweep * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

void showStreakDetail(BuildContext context, int streak) {
  Navigator.of(context).push(PageRouteBuilder(
    opaque: false,
    pageBuilder: (_, __, ___) => StreakDetailSheet(streak: streak),
    transitionsBuilder: (_, anim, __, child) =>
        FadeTransition(opacity: anim, child: child),
    transitionDuration: const Duration(milliseconds: 250),
  ));
}
