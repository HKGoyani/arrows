import 'package:flutter/material.dart';

/// Hand-built 3D-style illustrations for the Collection screen.
/// Drawn with gradients + highlights so flat Flutter canvas reads as 3D.

const _pedLight = Color(0xFFE3E6F6);
const _pedMid = Color(0xFFC4CAEC);
const _pedDark = Color(0xFFADB4E2);
const _pedHi = Color(0xFFF3F4FC);

const _goldHi = Color(0xFFFFD968);
const _goldMid = Color(0xFFFBB23E);
const _goldDark = Color(0xFFEF9A2E);

const _flameHi = Color(0xFFFFD15C);
const _flameMid = Color(0xFFFFA838);
const _flameDark = Color(0xFFF8842B);

class Icon3D extends StatelessWidget {
  final CustomPainter painter;
  final double size;
  const Icon3D(this.painter, {super.key, this.size = 64});
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(size, size), painter: painter);
}

// ───────────────────────── Flame on pedestal ─────────────────────────
class FlamePainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    Offset p(double x, double y) => Offset(x * w, y * h);

    // pedestal foot
    final foot = Rect.fromCenter(center: p(0.5, 0.93), width: w * 0.5, height: h * 0.12);
    c.drawOval(foot, Paint()..shader = const LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [_pedMid, _pedDark],
    ).createShader(foot));

    // stem
    final stem = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.43, h * 0.74, w * 0.14, h * 0.16),
      Radius.circular(w * 0.04));
    c.drawRRect(stem, Paint()..shader = LinearGradient(
      colors: [_pedLight, _pedMid],
    ).createShader(stem.outerRect));

    // cup bowl
    final bowl = Path()
      ..moveTo(w * 0.27, h * 0.62)
      ..quadraticBezierTo(w * 0.5, h * 0.86, w * 0.73, h * 0.62)
      ..quadraticBezierTo(w * 0.5, h * 0.74, w * 0.27, h * 0.62)
      ..close();
    c.drawPath(bowl, Paint()..shader = LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: const [_pedLight, _pedMid],
    ).createShader(bowl.getBounds()));
    // rim ellipse
    final rim = Rect.fromCenter(center: p(0.5, 0.62), width: w * 0.46, height: h * 0.12);
    c.drawOval(rim, Paint()..color = _pedLight);
    c.drawOval(
      Rect.fromCenter(center: p(0.5, 0.61), width: w * 0.34, height: h * 0.07),
      Paint()..color = _pedHi);

    // flame outer
    final flame = Path()
      ..moveTo(w * 0.5, h * 0.10)
      ..cubicTo(w * 0.42, h * 0.26, w * 0.72, h * 0.34, w * 0.70, h * 0.50)
      ..cubicTo(w * 0.69, h * 0.62, w * 0.59, h * 0.66, w * 0.5, h * 0.66)
      ..cubicTo(w * 0.41, h * 0.66, w * 0.31, h * 0.62, w * 0.30, h * 0.50)
      ..cubicTo(w * 0.29, h * 0.38, w * 0.40, h * 0.34, w * 0.42, h * 0.24)
      ..cubicTo(w * 0.44, h * 0.18, w * 0.47, h * 0.14, w * 0.5, h * 0.10)
      ..close();
    c.drawPath(flame, Paint()..shader = LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: const [_flameHi, _flameMid, _flameDark],
    ).createShader(flame.getBounds()));

    // inner droplet highlight
    final drop = Path()
      ..moveTo(w * 0.5, h * 0.34)
      ..cubicTo(w * 0.44, h * 0.42, w * 0.42, h * 0.50, w * 0.5, h * 0.58)
      ..cubicTo(w * 0.58, h * 0.50, w * 0.56, h * 0.42, w * 0.5, h * 0.34)
      ..close();
    c.drawPath(drop, Paint()..color = _flameHi.withValues(alpha: 0.9));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ───────────────────────── Crown on pillow ─────────────────────────
class CrownPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    double x(double v) => v * w;
    double y(double v) => v * h;

    // ── puffy cushion ──
    final pillow = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(x(0.5), y(0.80)), width: w * 0.74, height: h * 0.30),
      Radius.circular(w * 0.16));
    c.drawRRect(pillow, Paint()..shader = const LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [_pedLight, _pedMid],
    ).createShader(pillow.outerRect));
    // top highlight
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x(0.5), y(0.72)), width: w * 0.52, height: h * 0.09),
        Radius.circular(w * 0.1)),
      Paint()..color = _pedHi.withValues(alpha: 0.65));

    // ── crown body (sharp peaks, softened by round-join stroke + balls) ──
    final crown = Path()
      ..moveTo(x(0.21), y(0.52))
      ..lineTo(x(0.23), y(0.30))
      ..lineTo(x(0.30), y(0.45))
      ..lineTo(x(0.37), y(0.35))
      ..lineTo(x(0.435), y(0.46))
      ..lineTo(x(0.50), y(0.22))
      ..lineTo(x(0.565), y(0.46))
      ..lineTo(x(0.63), y(0.35))
      ..lineTo(x(0.70), y(0.45))
      ..lineTo(x(0.77), y(0.30))
      ..lineTo(x(0.79), y(0.52))
      ..quadraticBezierTo(x(0.50), y(0.63), x(0.21), y(0.52))
      ..close();
    final crownShader = const LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [_goldHi, _goldMid, _goldDark],
    ).createShader(Rect.fromLTWH(x(0.21), y(0.22), w * 0.58, h * 0.41));
    c.drawPath(crown, Paint()..shader = crownShader);
    c.drawPath(crown, Paint()
      ..shader = crownShader
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.05
      ..strokeJoin = StrokeJoin.round);

    // ── ball tips on each peak ──
    const peaks = [
      [0.23, 0.28], [0.37, 0.33], [0.50, 0.20], [0.63, 0.33], [0.77, 0.28],
    ];
    for (final p in peaks) {
      final cx = x(p[0]), cy = y(p[1]);
      c.drawCircle(Offset(cx, cy), w * 0.062, Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.5),
          colors: const [_goldHi, _goldMid, _goldDark],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: w * 0.062)));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ───────────────────────── Winged arrow ─────────────────────────
class WingArrowPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    double y(double v) => v * h;

    // ── feathered wing (right side; mirrored for left) ──
    Path wing(bool right) {
      double x(double v) => (right ? v : 1 - v) * w;
      return Path()
        ..moveTo(x(0.52), y(0.56))
        ..cubicTo(x(0.66), y(0.47), x(0.80), y(0.45), x(0.91), y(0.50))
        ..quadraticBezierTo(x(0.955), y(0.515), x(0.905), y(0.565))
        ..quadraticBezierTo(x(0.85), y(0.63), x(0.80), y(0.585))
        ..quadraticBezierTo(x(0.745), y(0.66), x(0.685), y(0.605))
        ..quadraticBezierTo(x(0.62), y(0.665), x(0.555), y(0.61))
        ..close();
    }

    final wingPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [_pedLight, _pedMid],
      ).createShader(Rect.fromLTWH(0, h * 0.44, w, h * 0.24))
      ..style = PaintingStyle.fill;
    final wingEdge = Paint()
      ..shader = wingPaint.shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.02
      ..strokeJoin = StrokeJoin.round;
    for (final right in const [true, false]) {
      c.drawPath(wing(right), wingPaint);
      c.drawPath(wing(right), wingEdge);
    }

    // ── chunky upward arrow ──
    final arrow = Path()
      ..moveTo(w * 0.5, y(0.15))
      ..lineTo(w * 0.70, y(0.43))
      ..lineTo(w * 0.59, y(0.43))
      ..lineTo(w * 0.59, y(0.80))
      ..lineTo(w * 0.41, y(0.80))
      ..lineTo(w * 0.41, y(0.43))
      ..lineTo(w * 0.30, y(0.43))
      ..close();
    final arrowShader = const LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [_flameHi, _flameMid, _flameDark],
    ).createShader(Rect.fromLTWH(w * 0.30, y(0.15), w * 0.40, h * 0.65));
    // fill + round-join stroke to soften corners
    c.drawPath(arrow, Paint()..shader = arrowShader);
    c.drawPath(arrow, Paint()
      ..shader = arrowShader
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.055
      ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
