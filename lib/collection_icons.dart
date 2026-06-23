import 'dart:math' as math;
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
    final featherShadow = Paint()
      ..color = const Color(0xFF7E84AE).withValues(alpha: 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);

    for (final right in const [true, false]) {
      double fx(double v) => (right ? v : 1 - v) * w;
      // draw bottom → top so each upper feather overlaps + shadows the one below
      for (int i = feathers.length - 1; i >= 0; i--) {
        final f = feathers[i];
        final base = Offset(fx(f[0]), y(f[1]));
        final tip = Offset(fx(f[2]), y(f[3]));
        final path = feather(base, tip, w * f[4]);
        // soft shadow cast onto the feather already drawn beneath
        if (i != feathers.length - 1) {
          c.save();
          c.translate(0, h * 0.024);
          c.drawPath(path, featherShadow);
          c.restore();
        }
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

// ───────────────────────── Star medallion (award) ─────────────────────────
class StarMedalPainter extends CustomPainter {
  final bool unlocked;
  StarMedalPainter({required this.unlocked});

  Path _star(Offset c, double outer, double inner) {
    final path = Path();
    for (int i = 0; i < 10; i++) {
      final r = i.isEven ? outer : inner;
      final a = -math.pi / 2 + i * math.pi / 5;
      final p = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final c = Offset(w / 2, h * 0.46);
    final R = math.min(w, h) * 0.44;

    // soft drop shadow under the coin
    canvas.drawCircle(
      c.translate(0, R * 0.10), R,
      Paint()
        ..color = const Color(0xFF9AA0C2).withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));

    // outer disc — domed coin
    canvas.drawCircle(c, R, Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.45),
        colors: const [Color(0xFFF1F2FB), Color(0xFFD2D7EA)],
      ).createShader(Rect.fromCircle(center: c, radius: R)));

    // raised rim ring
    canvas.drawCircle(c, R * 0.985, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = R * 0.05
      ..color = const Color(0xFFC6CBE2));

    // recessed inner dish (darker at top = shadow under rim)
    final inner = R * 0.74;
    canvas.drawCircle(c, inner, Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xFFCAD0E5), Color(0xFFE7EAF5)],
      ).createShader(Rect.fromCircle(center: c, radius: inner)));

    // ── star ──
    final starOuter = R * 0.56, starInner = R * 0.24;
    final star = _star(c, starOuter, starInner);

    final shader = unlocked
        ? const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF8FC8FF), Color(0xFF4A93EE), Color(0xFF2A6FD0)],
          ).createShader(star.getBounds())
        : const LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFFECEEF8), Color(0xFFCFD4E8)],
          ).createShader(star.getBounds());

    // single star: fill + round-join stroke to soften the points
    canvas.drawPath(star, Paint()..shader = shader);
    canvas.drawPath(star, Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = R * 0.07
      ..strokeJoin = StrokeJoin.round);

    // gloss highlight kept INSIDE the star (clipped) so it never reads as a 2nd star
    canvas.save();
    canvas.clipPath(star);
    canvas.drawOval(
      Rect.fromCenter(
        center: c.translate(-R * 0.06, -R * 0.20),
        width: R * 0.6, height: R * 0.34),
      Paint()
        ..color = Colors.white.withValues(alpha: unlocked ? 0.34 : 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant StarMedalPainter old) => old.unlocked != unlocked;
}

// ───────────────────── Target / dartboard hexagon (Perfect Play) ──────────
class TargetMedalPainter extends CustomPainter {
  final bool unlocked;
  TargetMedalPainter({required this.unlocked});

  Path _hexagon(Offset c, double r) {
    // pointy-top hexagon: a corner sits at the top (not a flat edge)
    final v = <Offset>[
      for (var k = 0; k < 6; k++)
        Offset(
          c.dx + r * math.cos((-90 + 60 * k) * math.pi / 180),
          c.dy + r * math.sin((-90 + 60 * k) * math.pi / 180),
        ),
    ];
    final rad = r * 0.10; // rounded but crisp corners
    final path = Path();
    final n = v.length;
    for (var i = 0; i < n; i++) {
      final cur = v[i];
      final toPrev = v[(i - 1 + n) % n] - cur;
      final toNext = v[(i + 1) % n] - cur;
      final p1 = cur + toPrev / toPrev.distance * rad;
      final p2 = cur + toNext / toNext.distance * rad;
      i == 0 ? path.moveTo(p1.dx, p1.dy) : path.lineTo(p1.dx, p1.dy);
      path.quadraticBezierTo(cur.dx, cur.dy, p2.dx, p2.dy);
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final c = Offset(w / 2, h * 0.46);
    final R = math.min(w, h) * 0.42;

    // drop shadow
    canvas.drawPath(
      _hexagon(c.translate(0, R * 0.09), R),
      Paint()
        ..color = const Color(0xFF9AA0C2).withValues(alpha: 0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));

    // outer hexagon frame (corners already rounded in the path)
    final outer = _hexagon(c, R);
    final outerPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFFEAEDF7), Color(0xFFD3D8EC)],
      ).createShader(Rect.fromCircle(center: c, radius: R));
    canvas.drawPath(outer, outerPaint);

    // inner recessed hexagon
    final inner = _hexagon(c, R * 0.80);
    canvas.drawPath(inner, Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xFFCBD0E5), Color(0xFFE4E7F3)],
      ).createShader(Rect.fromCircle(center: c, radius: R * 0.80)));

    final tr = R * 0.46;
    _target(canvas, c, tr);
    _dart(canvas, c, tr);
  }

  void _target(Canvas canvas, Offset o, double r) {
    final red = unlocked ? const Color(0xFFEF5230) : const Color(0xFFCDD2E6);
    final white = unlocked ? Colors.white : const Color(0xFFE9ECF5);
    Paint p(Color col) => Paint()..color = col;
    canvas.drawCircle(o, r * 1.04, p(white));
    canvas.drawCircle(o, r * 1.00, p(red));
    canvas.drawCircle(o, r * 0.78, p(white));
    canvas.drawCircle(o, r * 0.58, p(red));
    canvas.drawCircle(o, r * 0.38, p(white));
    canvas.drawCircle(o, r * 0.18, p(red));
    // top gloss
    canvas.drawOval(
      Rect.fromCenter(
          center: o.translate(0, -r * 0.42), width: r * 1.2, height: r * 0.5),
      Paint()..color = Colors.white.withValues(alpha: 0.16));
  }

  void _dart(Canvas canvas, Offset center, double r) {
    final gLight = unlocked ? const Color(0xFF5BC65F) : const Color(0xFFCFD4E6);
    final gDark = unlocked ? const Color(0xFF34A03E) : const Color(0xFFB4B9CF);
    // unit vector from the bullseye toward the upper-right (where the tail sits)
    final u = const Offset(0.70, -0.71) / const Offset(0.70, -0.71).distance;
    final perp = Offset(-u.dy, u.dx);
    final back = center + u * (r * 1.16); // far (upper-right) end with flights

    // shaft: from just outside the bullseye to the back
    canvas.drawLine(center + u * (r * 0.10), back, Paint()
      ..color = gDark
      ..strokeWidth = r * 0.09
      ..strokeCap = StrokeCap.round);

    // flight: two facets folded along the spine for a 3D look
    final inner = back - u * (r * 0.55); // meets the shaft, toward center
    final backTip = back + u * (r * 0.18); // far point of the tail
    final wing = r * 0.30;
    final upper = back - perp * wing; // upper-left fin (catches light)
    final lower = back + perp * wing; // lower-right fin (in shadow)
    final facetUpper = Path()
      ..moveTo(inner.dx, inner.dy)
      ..lineTo(upper.dx, upper.dy)
      ..lineTo(backTip.dx, backTip.dy)
      ..close();
    final facetLower = Path()
      ..moveTo(inner.dx, inner.dy)
      ..lineTo(lower.dx, lower.dy)
      ..lineTo(backTip.dx, backTip.dy)
      ..close();
    canvas.drawPath(facetLower, Paint()..color = gDark);
    canvas.drawPath(facetUpper, Paint()..color = gLight);

    // sharp point planted in the bullseye (points down-left into center)
    final tipBase = center + u * (r * 0.16);
    final point = Path()
      ..moveTo(center.dx, center.dy)
      ..lineTo((tipBase + perp * (r * 0.05)).dx, (tipBase + perp * (r * 0.05)).dy)
      ..lineTo((tipBase - perp * (r * 0.05)).dx, (tipBase - perp * (r * 0.05)).dy)
      ..close();
    canvas.drawPath(point, Paint()..color = const Color(0xFF8A8FA6));
  }

  @override
  bool shouldRepaint(covariant TargetMedalPainter old) => old.unlocked != unlocked;
}

// ───────────────────── Skull shield (Unstoppable) ─────────────────────
class SkullShieldPainter extends CustomPainter {
  final bool unlocked;
  SkullShieldPainter({required this.unlocked});

  Path _shield(Offset c, double w, double h) {
    final top = c.dy - h * 0.50;
    final bot = c.dy + h * 0.50;
    final left = c.dx - w * 0.50;
    final right = c.dx + w * 0.50;
    final shoulderY = top + h * 0.10;
    final midY = c.dy + h * 0.12;
    return Path()
      ..moveTo(c.dx, top)
      ..lineTo(left + w * 0.03, shoulderY)
      ..quadraticBezierTo(left, shoulderY + h * 0.01, left, shoulderY + h * 0.05)
      ..lineTo(left, midY)
      ..quadraticBezierTo(left + w * 0.01, bot - h * 0.14, c.dx, bot)
      ..quadraticBezierTo(right - w * 0.01, bot - h * 0.14, right, midY)
      ..lineTo(right, shoulderY + h * 0.05)
      ..quadraticBezierTo(right, shoulderY + h * 0.01, right - w * 0.03, shoulderY)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final c = Offset(w / 2, h * 0.48);
    final sw = w * 0.90, sh = h * 0.98;

    // drop shadow
    canvas.drawPath(
      _shield(c.translate(0, sh * 0.03), sw, sh),
      Paint()
        ..color = const Color(0xFF9AA0C2).withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));

    // outer shield
    final outer = _shield(c, sw, sh);
    canvas.drawPath(outer, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: unlocked
            ? const [Color(0xFFE0E5F5), Color(0xFFC5CCEB)]
            : const [Color(0xFFEAEDF7), Color(0xFFD3D8EC)],
      ).createShader(outer.getBounds()));

    // inner recessed shield
    final inner = _shield(c.translate(0, sh * 0.01), sw * 0.76, sh * 0.74);
    canvas.drawPath(inner, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: unlocked
            ? const [Color(0xFFC6CCE5), Color(0xFFDFE3F2)]
            : const [Color(0xFFCBD0E5), Color(0xFFE4E7F3)],
      ).createShader(inner.getBounds()));

    // skull centered in the inner shield area
    _skull(canvas, c.translate(0, -sh * 0.02), sw * 0.28);
  }

  void _skull(Canvas canvas, Offset c, double r) {
    final bone1 = unlocked ? const Color(0xFFF7F2EC) : const Color(0xFFE0E3EE);
    final bone2 = unlocked ? const Color(0xFFEBE0D4) : const Color(0xFFD0D5E6);
    final socket = unlocked ? const Color(0xFFCBBDA8) : const Color(0xFFB5BAD0);

    // cranium — large round dome
    final crC = c.translate(0, -r * 0.20);
    canvas.drawOval(
      Rect.fromCenter(center: crC, width: r * 2.2, height: r * 2.0),
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.2, -0.4),
          radius: 0.85,
          colors: [bone1, bone2],
        ).createShader(Rect.fromCenter(center: crC, width: r * 2.2, height: r * 2.0)));

    // jaw — connected below
    canvas.drawOval(
      Rect.fromCenter(center: c.translate(0, r * 0.45), width: r * 1.3, height: r * 0.7),
      Paint()..color = bone2);
    canvas.drawRect(
      Rect.fromCenter(center: c.translate(0, r * 0.15), width: r * 1.3, height: r * 0.5),
      Paint()..color = bone2);

    // eye sockets — two round dark circles
    final eyeY = c.dy - r * 0.02;
    for (final dx in [-r * 0.38, r * 0.38]) {
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(c.dx + dx, eyeY),
            width: r * 0.58, height: r * 0.52),
        Paint()..color = socket);
    }

    // nose — small inverted triangle
    final ny = c.dy + r * 0.35;
    final nose = Path()
      ..moveTo(c.dx - r * 0.10, ny + r * 0.10)
      ..lineTo(c.dx + r * 0.10, ny + r * 0.10)
      ..lineTo(c.dx, ny - r * 0.02)
      ..close();
    canvas.drawPath(nose, Paint()..color = socket);

    // cranium highlight
    canvas.drawOval(
      Rect.fromCenter(
          center: crC.translate(0, -r * 0.36), width: r * 1.0, height: r * 0.45),
      Paint()..color = Colors.white.withValues(alpha: unlocked ? 0.38 : 0.42)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
  }

  @override
  bool shouldRepaint(covariant SkullShieldPainter old) => old.unlocked != unlocked;
}
