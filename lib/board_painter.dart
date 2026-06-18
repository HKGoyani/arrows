import 'package:flutter/material.dart';
import 'config.dart';
import 'fly_off.dart';
import 'game_controller.dart';
import 'models.dart';

/// Draws the whole board in cell units, scaled to fit: dot grid (bottom),
/// tap ripple, idle/clashed arrows, and the animated leaving arrow on top.
class BoardPainter extends CustomPainter {
  final GameController c;
  final List<({FlyOff fly, double adv})> flights; // arrows currently snaking off
  final Offset? rippleCenter;
  final double rippleT; // 0..1, 1 = done

  BoardPainter({
    required this.c,
    this.flights = const [],
    this.rippleCenter,
    this.rippleT = 1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final vbW = c.cols * Cfg.cell + 2 * Cfg.margin;
    final scale = size.width / vbW;
    canvas.scale(scale);

    // dot grid (revealed in empty/cleared cells)
    final dotPaint = Paint()..color = AppColors.dot;
    for (var i = 0; i <= c.cols; i++) {
      for (var j = 0; j <= c.rows; j++) {
        canvas.drawCircle(
          Offset(Cfg.margin + i * Cfg.cell, Cfg.margin + j * Cfg.cell),
          Cfg.dotR,
          dotPaint,
        );
      }
    }

    // tap ripple (above dots, below arrows)
    if (rippleCenter != null && rippleT < 1) {
      final p = Paint()..color = AppColors.ripple.withValues(alpha: 0.22 * (1 - rippleT));
      canvas.drawCircle(rippleCenter!, Cfg.rippleR * (0.18 + 0.82 * rippleT), p);
    }

    // idle / clashed arrows
    for (final a in c.arrows) {
      if (a.state == ArrowState.leaving) continue;
      final color = a.state == ArrowState.clashed ? AppColors.red : AppColors.arrow;
      _drawArrow(canvas, _toOffsets(a), a.dir, color);
    }

    // animated leaving arrows (snakes), drawn on top
    for (final f in flights) {
      _drawArrow(canvas, f.fly.shaftPoints(f.adv), f.fly.arrow.dir, AppColors.arrowBlue);
    }
  }

  List<Offset> _toOffsets(Arrow a) => a.pts
      .map((p) => Offset(Cfg.margin + p.x * Cfg.cell, Cfg.margin + p.y * Cfg.cell))
      .toList();

  void _drawArrow(Canvas canvas, List<Offset> pts, Direction dir, Color color) {
    if (pts.length < 2) return;
    final shaft = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = Cfg.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(path, shaft);

    // chevron head at the front, oriented along dir
    final h = pts.last;
    final dx = dir.dx.toDouble(), dy = dir.dy.toDouble();
    final px = -dy, py = dx;
    final tip = Offset(h.dx + dx * Cfg.headLen, h.dy + dy * Cfg.headLen);
    final l = Offset(h.dx - dx * Cfg.headBase + px * Cfg.headHalf,
        h.dy - dy * Cfg.headBase + py * Cfg.headHalf);
    final r = Offset(h.dx - dx * Cfg.headBase - px * Cfg.headHalf,
        h.dy - dy * Cfg.headBase - py * Cfg.headHalf);
    final head = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(l.dx, l.dy)
      ..lineTo(r.dx, r.dy)
      ..close();
    canvas.drawPath(head, Paint()..color = color..style = PaintingStyle.fill);
    canvas.drawPath(
        head,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = Cfg.headStroke
          ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(covariant BoardPainter old) => true;
}
