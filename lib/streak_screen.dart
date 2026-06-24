import 'package:flutter/material.dart';
import 'config.dart';
import 'prefs.dart';
import 'ui_kit.dart';

const _flameOrange = Color(0xFFF7941D);
const _flameGray = Color(0xFFBFC4D8);

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
  const labels = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
  String fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final monday = today.subtract(Duration(days: now.weekday - 1));
  final played = Prefs.playedDays.toSet();
  final out = <_WeekDay>[];
  for (var i = 0; i < 7; i++) {
    final d = monday.add(Duration(days: i));
    out.add(_WeekDay(labels[i], played.contains(fmt(d)), d == today));
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
                            d.done ? _flameOrange : const Color(0xFFC2C7DE))),
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
    final circle = Container(
      width: _circle,
      height: _circle,
      decoration: BoxDecoration(
        color: d.done ? _flameOrange : const Color(0xFFEDEFF7),
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

/// Streak celebration shown after completing today's challenge. The flame
/// scales in, the streak number pops up, and today's check animates in.
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
  late final Animation<double> _flame; // scale + fade
  late final Animation<double> _number; // pop
  late final Animation<double> _check; // today's check pop
  late final Animation<double> _button;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    _flame = CurvedAnimation(
        parent: _c, curve: const Interval(0.0, 0.45, curve: Curves.elasticOut));
    _number = CurvedAnimation(
        parent: _c, curve: const Interval(0.35, 0.6, curve: Curves.easeOutBack));
    _check = CurvedAnimation(
        parent: _c, curve: const Interval(0.55, 0.8, curve: Curves.elasticOut));
    _button = CurvedAnimation(
        parent: _c, curve: const Interval(0.75, 1.0, curve: Curves.easeOut));
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 3),
            ScaleTransition(
              scale: _flame,
              child: FadeTransition(
                opacity: _c.drive(CurveTween(curve: const Interval(0, 0.3))),
                child: streakFlame(size: 150),
              ),
            ),
            const SizedBox(height: 18),
            ScaleTransition(
              scale: Tween(begin: 0.6, end: 1.0).animate(_number),
              child: FadeTransition(
                opacity: _number,
                child: Text('${widget.streak} day streak',
                    style: poppins(28, FontWeight.w900, AppColors.ink)),
              ),
            ),
            const SizedBox(height: 24),
            StreakWeekRow(todayPop: _check),
            const Spacer(flex: 4),
            FadeTransition(
              opacity: _button,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(40, 0, 40, 28),
                child: PrimaryButton(
                    label: 'Continue',
                    onTap: widget.onContinue,
                    width: double.infinity),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
            Text('$streak day streak',
                style: poppins(25, FontWeight.w900, const Color(0xFF535B83))),
            const SizedBox(height: 24),
            const StreakWeekRow(),
            const Spacer(flex: 2),
            // Streak Freezers card — title centred, (i) in the top-right corner
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
                        Text('Streak Freezers',
                            style: poppins(17, FontWeight.w900,
                                const Color(0xFF535B83))),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < 3; i++)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 11),
                                child: const DottedCircle(
                                  size: 46,
                                  child: _ThickPlus(
                                      size: 21, color: Color(0xFFD8D8DC)),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text('0/3 Equipped',
                            style: poppins(
                                13.5, FontWeight.w800, const Color(0xFF535B83))),
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
                  child: Text('Close',
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
