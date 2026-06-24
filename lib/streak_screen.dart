import 'package:flutter/material.dart';
import 'config.dart';
import 'prefs.dart';
import 'ui_kit.dart';

const _flameOrange = Color(0xFFF7941D);
const _flameLight = Color(0xFFFFC24B);
const _flameDeep = Color(0xFFEC7C12);

/// One day in the current-week streak row.
class _WeekDay {
  final String label;
  final bool done;
  const _WeekDay(this.label, this.done);
}

List<_WeekDay> _currentWeek() {
  const labels = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
  String fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  final now = DateTime.now();
  final monday = DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: now.weekday - 1));
  final played = Prefs.playedDays.toSet();
  final out = <_WeekDay>[];
  for (var i = 0; i < 7; i++) {
    final d = monday.add(Duration(days: i));
    out.add(_WeekDay(labels[i], played.contains(fmt(d))));
  }
  return out;
}

/// 3D-style flame illustration. [active] gives the warm orange flame; otherwise
/// a muted gray (disabled streak).
class FlamePainter extends CustomPainter {
  final bool active;
  const FlamePainter({this.active = true});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cx = w / 2;

    final outer = active ? _flameOrange : const Color(0xFFBFC4D8);
    final outerDeep = active ? _flameDeep : const Color(0xFFAEB4CC);
    final inner = active ? _flameLight : const Color(0xFFD7DBEA);

    // soft shadow
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, h * 0.92), width: w * 0.55, height: h * 0.06),
      Paint()
        ..color = const Color(0xFF9AA0C2).withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));

    // main flame body
    final body = Path()
      ..moveTo(cx + w * 0.02, h * 0.06)
      ..cubicTo(cx + w * 0.10, h * 0.20, cx + w * 0.30, h * 0.24, cx + w * 0.30, h * 0.30)
      ..cubicTo(cx + w * 0.40, h * 0.24, cx + w * 0.42, h * 0.34, cx + w * 0.40, h * 0.40)
      ..cubicTo(cx + w * 0.50, h * 0.50, cx + w * 0.48, h * 0.66, cx + w * 0.30, h * 0.78)
      ..cubicTo(cx + w * 0.12, h * 0.90, cx - w * 0.12, h * 0.90, cx - w * 0.30, h * 0.78)
      ..cubicTo(cx - w * 0.50, h * 0.64, cx - w * 0.46, h * 0.42, cx - w * 0.30, h * 0.30)
      ..cubicTo(cx - w * 0.16, h * 0.20, cx - w * 0.08, h * 0.18, cx - w * 0.02, h * 0.10)
      ..cubicTo(cx - w * 0.01, h * 0.07, cx, h * 0.06, cx + w * 0.02, h * 0.06)
      ..close();
    canvas.drawPath(body, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [outer, outerDeep],
      ).createShader(body.getBounds()));

    // inner teardrop highlight
    final drop = Path()
      ..moveTo(cx, h * 0.34)
      ..cubicTo(cx + w * 0.16, h * 0.44, cx + w * 0.18, h * 0.62, cx, h * 0.70)
      ..cubicTo(cx - w * 0.18, h * 0.62, cx - w * 0.16, h * 0.44, cx, h * 0.34)
      ..close();
    canvas.drawPath(drop, Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, 0.2),
        colors: [inner, active ? _flameOrange : const Color(0xFFCBD0E2)],
      ).createShader(drop.getBounds()));
  }

  @override
  bool shouldRepaint(covariant FlamePainter old) => old.active != active;
}

/// Mo–Su row with check circles for completed days.
class StreakWeekRow extends StatelessWidget {
  const StreakWeekRow({super.key});

  @override
  Widget build(BuildContext context) {
    final week = _currentWeek();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final d in week)
            Column(
              children: [
                Text(d.label,
                    style: poppins(13, FontWeight.w800,
                        d.done ? _flameOrange : const Color(0xFFC2C7DE))),
                const SizedBox(height: 8),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: d.done ? _flameOrange : const Color(0xFFEDEFF7),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: d.done
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 20)
                      : null,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Streak celebration shown after completing today's challenge ("Continue").
class StreakCelebration extends StatelessWidget {
  final int streak;
  final VoidCallback onContinue;
  const StreakCelebration(
      {super.key, required this.streak, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 3),
            const SizedBox(
                width: 200, height: 200,
                child: CustomPaint(painter: FlamePainter())),
            const SizedBox(height: 18),
            Text('$streak day streak',
                style: poppins(28, FontWeight.w900, AppColors.ink)),
            const SizedBox(height: 24),
            const StreakWeekRow(),
            const Spacer(flex: 4),
            Padding(
              padding: const EdgeInsets.fromLTRB(40, 0, 40, 28),
              child: PrimaryButton(
                  label: 'Continue', onTap: onContinue, width: double.infinity),
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
            const SizedBox(
                width: 190, height: 190,
                child: CustomPaint(painter: FlamePainter())),
            const SizedBox(height: 16),
            Text('$streak day streak',
                style: poppins(26, FontWeight.w900, AppColors.ink)),
            const SizedBox(height: 22),
            const StreakWeekRow(),
            const Spacer(flex: 2),
            // Streak Freezers card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 30),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE9EBF4)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Streak Freezers',
                          style: poppins(17, FontWeight.w900, AppColors.ink)),
                      const SizedBox(width: 6),
                      const Icon(Icons.info_outline_rounded,
                          size: 16, color: Color(0xFFB4B9CF)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < 3; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: DottedCircle(
                            size: 52,
                            child: const Icon(Icons.add_rounded,
                                color: Color(0xFFB4B9CF), size: 26),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('0/3 Equipped',
                      style: poppins(14, FontWeight.w800, AppColors.muted)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.fromLTRB(40, 0, 40, 28),
              child: GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: Container(
                  width: double.infinity,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border:
                        Border.all(color: const Color(0xFFE4E6F1), width: 1.5),
                  ),
                  child: Text('Close',
                      style:
                          poppins(18, FontWeight.w900, const Color(0xFF8C90A6))),
                ),
              ),
            ),
          ],
        ),
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
      ..color = const Color(0xFFC8CCDD)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final r = size.width / 2 - 1;
    final c = size.center(Offset.zero);
    const dashes = 22;
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
