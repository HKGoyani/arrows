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

// ───────────────────────── Compact pedestal (cup at top → base at bottom) ──
class PedestalPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    Offset p(double x, double y) => Offset(x * w, y * h);

    // base bottom ellipse (depth)
    final baseOval = Rect.fromCenter(center: p(0.5, 0.92), width: w * 0.60, height: h * 0.16);
    c.drawOval(baseOval, Paint()..shader = const LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [_pedMid, _pedDark],
    ).createShader(baseOval));

    // base foot
    final baseFoot = Path()
      ..moveTo(w * 0.28, h * 0.78)
      ..lineTo(w * 0.72, h * 0.78)
      ..lineTo(w * 0.70, h * 0.92)
      ..lineTo(w * 0.30, h * 0.92)
      ..close();
    c.drawPath(baseFoot, Paint()..shader = const LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [_pedLight, _pedMid],
    ).createShader(baseFoot.getBounds()));
    final baseTop = Rect.fromCenter(center: p(0.5, 0.78), width: w * 0.50, height: h * 0.12);
    c.drawOval(baseTop, Paint()..color = _pedLight);

    // tapered neck
    final neck = Path()
      ..moveTo(w * 0.40, h * 0.40)
      ..lineTo(w * 0.60, h * 0.40)
      ..lineTo(w * 0.66, h * 0.78)
      ..lineTo(w * 0.34, h * 0.78)
      ..close();
    c.drawPath(neck, Paint()..shader = const LinearGradient(
      colors: [_pedLight, _pedMid],
    ).createShader(neck.getBounds()));

    // top cup
    final cup = Path()
      ..moveTo(w * 0.26, h * 0.16)
      ..lineTo(w * 0.74, h * 0.16)
      ..lineTo(w * 0.62, h * 0.42)
      ..lineTo(w * 0.38, h * 0.42)
      ..close();
    c.drawPath(cup, Paint()..shader = const LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [_pedLight, _pedMid],
    ).createShader(cup.getBounds()));

    // top rim ellipse (where the flame sits)
    final topRim = Rect.fromCenter(center: p(0.5, 0.16), width: w * 0.50, height: h * 0.14);
    c.drawOval(topRim, Paint()..color = _pedLight);
    c.drawOval(
      Rect.fromCenter(center: p(0.5, 0.14), width: w * 0.36, height: h * 0.09),
      Paint()..color = _pedHi);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Flame Material icon sitting in the trophy pedestal cup.
class FlameOnPedestal extends StatelessWidget {
  const FlameOnPedestal({super.key});
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, cons) {
        final s = cons.biggest.shortestSide;
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // pedestal: taller/narrower stand, cup rim near its own top
            Positioned(
              bottom: 0,
              left: s * 0.12,
              right: s * 0.12,
              height: s * 0.62,
              child: CustomPaint(painter: PedestalPainter()),
            ),
            // flame: base dips well into the cup
            Positioned(
              top: s * 0.10,
              left: 0,
              right: 0,
              child: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFD15C), Color(0xFFFFA838), Color(0xFFF8842B)],
                ).createShader(bounds),
                blendMode: BlendMode.srcIn,
                child: Icon(
                  Icons.local_fire_department_rounded,
                  size: s * 0.64,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ───────────────────────── Crown on pillow ─────────────────────────
class CrownPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    double x(double v) => v * w;
    double y(double v) => v * h;

    // ── saucer (rakabi) ──
    // bottom ellipse (shadow/depth)
    final saucerBottom = Rect.fromCenter(
      center: Offset(x(0.5), y(0.76)), width: w * 0.82, height: h * 0.16);
    c.drawOval(saucerBottom, Paint()..shader = const LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [_pedMid, _pedDark],
    ).createShader(saucerBottom));

    // side/rim (thin trapezoid connecting top and bottom ellipses)
    final rim = Path()
      ..moveTo(x(0.09), y(0.72))
      ..quadraticBezierTo(x(0.5), y(0.88), x(0.91), y(0.72))
      ..quadraticBezierTo(x(0.5), y(0.82), x(0.09), y(0.72))
      ..close();
    c.drawPath(rim, Paint()..shader = const LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [_pedMid, _pedDark],
    ).createShader(rim.getBounds()));

    // top surface ellipse (flat plate face)
    final saucerTop = Rect.fromCenter(
      center: Offset(x(0.5), y(0.72)), width: w * 0.82, height: h * 0.16);
    c.drawOval(saucerTop, Paint()..shader = const LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [_pedHi, _pedLight],
    ).createShader(saucerTop));

    // highlight on top surface
    final highlight = Rect.fromCenter(
      center: Offset(x(0.5), y(0.70)), width: w * 0.50, height: h * 0.07);
    c.drawOval(highlight, Paint()..color = Colors.white.withValues(alpha: 0.45));

    // ── bottom band / rim ──
    final band = RRect.fromRectAndRadius(
      Rect.fromLTWH(x(0.18), y(0.52), w * 0.64, h * 0.14),
      Radius.circular(w * 0.04));
    c.drawRRect(band, Paint()..shader = const LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [_goldMid, _goldDark],
    ).createShader(band.outerRect));

    // ── crown peaks rising from the band ──
    final crown = Path()
      ..moveTo(x(0.18), y(0.56))
      ..lineTo(x(0.23), y(0.30))
      ..lineTo(x(0.30), y(0.46))
      ..lineTo(x(0.37), y(0.33))
      ..lineTo(x(0.435), y(0.47))
      ..lineTo(x(0.50), y(0.22))
      ..lineTo(x(0.565), y(0.47))
      ..lineTo(x(0.63), y(0.33))
      ..lineTo(x(0.70), y(0.46))
      ..lineTo(x(0.77), y(0.30))
      ..lineTo(x(0.82), y(0.56))
      ..close();
    final crownShader = const LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [_goldHi, _goldMid, _goldDark],
    ).createShader(Rect.fromLTWH(x(0.18), y(0.22), w * 0.64, h * 0.36));
    c.drawPath(crown, Paint()..shader = crownShader);
    c.drawPath(crown, Paint()
      ..shader = crownShader
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.05
      ..strokeJoin = StrokeJoin.round);

    // ── ball tips on each peak ──
    const peaks = [
      [0.23, 0.28], [0.37, 0.31], [0.50, 0.20], [0.63, 0.31], [0.77, 0.28],
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

    // ── layered feather wings ──
    // a single feather: pointed leaf bulging out from base to tip
    Path feather(Offset base, Offset tip, double bulge) {
      final dir = tip - base;
      final len = dir.distance == 0 ? 1.0 : dir.distance;
      final perp = Offset(-dir.dy, dir.dx) / len;
      final mid = base + dir * 0.5;
      final c1 = mid + perp * bulge;
      final c2 = mid - perp * bulge;
      return Path()
        ..moveTo(base.dx, base.dy)
        ..quadraticBezierTo(c1.dx, c1.dy, tip.dx, tip.dy)
        ..quadraticBezierTo(c2.dx, c2.dy, base.dx, base.dy)
        ..close();
    }

    // feathers per wing: [baseX, baseY, tipX, tipY, bulge] (right side)
    const feathers = [
      [0.50, 0.55, 0.93, 0.39, 0.055], // top, longest
      [0.50, 0.57, 0.91, 0.50, 0.060],
      [0.49, 0.59, 0.84, 0.60, 0.055],
      [0.48, 0.61, 0.74, 0.67, 0.048], // bottom, shortest
    ];

    final wingFill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [_pedHi, _pedMid],
      ).createShader(Rect.fromLTWH(0, h * 0.38, w, h * 0.32))
      ..style = PaintingStyle.fill;
    final wingEdge = Paint()
      ..color = _pedDark.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.012
      ..strokeJoin = StrokeJoin.round;

    for (final right in const [true, false]) {
      double fx(double v) => (right ? v : 1 - v) * w;
      // draw back (longest) → front (shortest) so they overlap like real feathers
      for (final f in feathers) {
        final base = Offset(fx(f[0]), y(f[1]));
        final tip = Offset(fx(f[2]), y(f[3]));
        final path = feather(base, tip, w * f[4]);
        c.drawPath(path, wingFill);
        c.drawPath(path, wingEdge);
      }
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
