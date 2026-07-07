import 'dart:math';
import 'package:flutter/material.dart';
import 'config.dart';
import 'prefs.dart';
import 'fly_off.dart';
import 'game_controller.dart';
import 'models.dart';

/// Draws the whole board in cell units, scaled to fit: dot grid (bottom),
/// tap ripple, idle/clashed arrows, and the animated leaving arrow on top.
class BoardPainter extends CustomPainter {
  final GameController c;
  final List<({FlyOff fly, double adv})> flights;
  final Offset? rippleCenter;
  final double rippleT;
  final Arrow? flashBlocker;
  final Arrow? lurchArrow;
  final double lurchT;
  final double lurchDist;
  final double clashTint;
  final bool showGrid;
  final Arrow? peekArrow; // long-press: show only this arrow's exit path
  final bool hideDots;
  final Arrow? hintArrow;
  final double hintPulse;
  final Set<int> hintedIds;
  final double heartT;

  BoardPainter({
    required this.c,
    this.flights = const [],
    this.rippleCenter,
    this.rippleT = 1,
    this.flashBlocker,
    this.lurchArrow,
    this.lurchT = 0,
    this.lurchDist = 0,
    this.clashTint = 0,
    this.showGrid = false,
    this.peekArrow,
    this.hideDots = false,
    this.hintArrow,
    this.hintPulse = 0,
    this.hintedIds = const {},
    this.heartT = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final vbW = c.cols * Cfg.cell + 2 * Cfg.margin;
    final scale = size.width / vbW;
    canvas.scale(scale);

    // dots are drawn only on arrow-track cells (revealed as arrows vacate
    // them) — never in empty space around the puzzle.
    if (hideDots) {
      // no dots
    } else if (heartT > 0) {
      _drawHeartDots(canvas);
    } else {
      final dotPaint = Paint()..color = AppColors.dot;
      for (final key in c.trackCells) {
        final ci = key.indexOf(',');
        final i = int.parse(key.substring(0, ci));
        final j = int.parse(key.substring(ci + 1));
        canvas.drawCircle(
          Offset(Cfg.margin + i * Cfg.cell, Cfg.margin + j * Cfg.cell),
          Cfg.dotR,
          dotPaint,
        );
      }
    }

    // grid lines — exit path from an arrow's head in its direction.
    //  • showGrid (# button toggle): show every arrow's path
    //  • peekArrow (long-press): show only the pressed arrow's path
    if (showGrid || peekArrow != null) {
      final far = vbW * 4;
      final normalPaint = Paint()
        ..color = Prefs.darkMode ? const Color(0xFF3A4060) : const Color(0xFFD0D3E8)
        ..strokeWidth = Cfg.stroke
        ..strokeCap = StrokeCap.round;
      final redPaint = Paint()
        ..color = AppColors.red.withValues(alpha: 0.4)
        ..strokeWidth = Cfg.stroke
        ..strokeCap = StrokeCap.round;
      final targets = showGrid ? c.arrows : <Arrow>[peekArrow!];
      for (final a in targets) {
        if (a.state == ArrowState.leaving) continue;
        final hx = Cfg.margin + a.head.x * Cfg.cell;
        final hy = Cfg.margin + a.head.y * Cfg.cell;
        final Offset end;
        if (a.dir == Direction.up) {
          end = Offset(hx, -far);
        } else if (a.dir == Direction.down) {
          end = Offset(hx, far);
        } else if (a.dir == Direction.left) {
          end = Offset(-far, hy);
        } else {
          end = Offset(far, hy);
        }
        canvas.drawLine(Offset(hx, hy), end,
            a.state == ArrowState.clashed ? redPaint : normalPaint);
      }
    }

    // tap ripple (above dots, below arrows)
    if (rippleCenter != null && rippleT < 1) {
      final p = Paint()..color = AppColors.ripple.withValues(alpha: 0.22 * (1 - rippleT));
      canvas.drawCircle(rippleCenter!, Cfg.rippleR * (0.18 + 0.82 * rippleT), p);
    }

    // idle / clashed arrows
    const maroon = Color(0xFF4A1B2E);
    for (final a in c.arrows) {
      if (a.state == ArrowState.leaving) continue;
      Color color;
      if (peekArrow != null && a.id == peekArrow!.id) {
        color = AppColors.arrowBlue; // long-press highlight
      } else if (hintedIds.contains(a.id)) {
        color = AppColors.arrowBlue;
      } else if (a.state == ArrowState.clashed) {
        color = AppColors.red;
      } else if (flashBlocker != null && a.id == flashBlocker!.id) {
        final blockerT = (clashTint * 1.8).clamp(0.0, 1.0);
        color = Color.lerp(AppColors.arrow, AppColors.red, blockerT)!;
      } else if (clashTint > 0) {
        color = Color.lerp(AppColors.arrow, maroon, clashTint)!;
      } else {
        color = AppColors.arrow;
      }
      var pts = _toOffsets(a);
      if (lurchArrow != null && a.id == lurchArrow!.id && lurchT > 0) {
        pts = _lurchAlongPath(pts, a.dir, lurchT);
      }
      if (hintArrow != null && a.id == hintArrow!.id && pts.length >= 2 && hintPulse > 0.01 && hintPulse < 0.99) {
        double glowSize;
        double glowAlpha;
        if (hintPulse < 0.50) {
          final t = Curves.easeOut.transform(hintPulse / 0.50);
          glowSize = t;
          glowAlpha = 1.0 - t;
        } else if (hintPulse < 0.60) {
          glowSize = 0.0;
          glowAlpha = 0.0;
        } else {
          final t = Curves.easeOut.transform((hintPulse - 0.60) / 0.40);
          glowSize = t;
          glowAlpha = 1.0 - t;
        }
        glowSize = glowSize.clamp(0.0, 1.0);
        glowAlpha = glowAlpha.clamp(0.0, 1.0);
        final glowScale = 1.5 + 1.5 * glowSize;
        final glowPath = Path()..moveTo(pts.first.dx, pts.first.dy);
        for (var i = 1; i < pts.length; i++) {
          glowPath.lineTo(pts[i].dx, pts[i].dy);
        }
        canvas.drawPath(glowPath, Paint()
          ..color = AppColors.arrowBlue.withValues(alpha: glowAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = Cfg.stroke * glowScale
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);
        final h = pts.last;
        final dx = a.dir.dx.toDouble(), dy = a.dir.dy.toDouble();
        final px = -dy, py = dx;
        final halfLen = Cfg.headLen / 2;
        final tip = Offset(h.dx + dx * halfLen, h.dy + dy * halfLen);
        final l = Offset(h.dx - dx * halfLen + px * Cfg.headHalf,
            h.dy - dy * halfLen + py * Cfg.headHalf);
        final r = Offset(h.dx - dx * halfLen - px * Cfg.headHalf,
            h.dy - dy * halfLen - py * Cfg.headHalf);
        final headPath = Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(l.dx, l.dy)
          ..lineTo(r.dx, r.dy)
          ..close();
        canvas.drawPath(headPath, Paint()
          ..color = AppColors.arrowBlue.withValues(alpha: glowAlpha)
          ..style = PaintingStyle.fill);
        canvas.drawPath(headPath, Paint()
          ..color = AppColors.arrowBlue.withValues(alpha: glowAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = Cfg.stroke * (glowScale - 0.5)
          ..strokeJoin = StrokeJoin.round);
      }
      _drawArrow(canvas, pts, a.dir, color);
    }

    // animated leaving arrows (snakes), drawn on top
    for (final f in flights) {
      _drawArrow(canvas, f.fly.shaftPoints(f.adv), f.fly.arrow.dir, AppColors.arrowBlue);
    }
  }

  void _drawHeartDots(Canvas canvas) {
    const waveColor = Color(0xFFA0A4D4);
    final t = heartT.clamp(0.0, 1.0);
    final cx = c.cols / 2.0;
    final cy = c.rows / 2.0;
    final maxDist = sqrt(cx * cx + cy * cy);
    final waveFront = t * (maxDist + 2.0);
    const waveWidth = 2.5;

    for (var i = 0; i <= c.cols; i++) {
      for (var j = 0; j <= c.rows; j++) {
        final dx = i - cx;
        final dy = j - cy;
        final dist = sqrt(dx * dx + dy * dy);
        final center = Offset(Cfg.margin + i * Cfg.cell, Cfg.margin + j * Cfg.cell);

        final distToWave = (dist - waveFront).abs();
        final inWave = distToWave < waveWidth;
        final behindWave = dist < waveFront - waveWidth;
        final aheadOfWave = dist > waveFront + waveWidth;

        double dotSize;
        double dotAlpha;

        if (inWave) {
          final waveT = 1.0 - (distToWave / waveWidth);
          dotSize = Cfg.dotR + Cfg.dotR * 1.0 * waveT;
          dotAlpha = 0.4 + 0.4 * waveT;
        } else if (behindWave) {
          dotSize = 0;
          dotAlpha = 0;
        } else {
          dotSize = Cfg.dotR;
          dotAlpha = 1.0 - t * 0.3;
        }

        if (dotAlpha < 0.01 || dotSize < 0.3) continue;
        canvas.drawCircle(
          center,
          dotSize,
          Paint()..color = inWave
              ? waveColor.withValues(alpha: dotAlpha)
              : AppColors.dot.withValues(alpha: dotAlpha),
        );
      }
    }
  }

  List<Offset> _lurchAlongPath(List<Offset> pts, Direction dir, double t) {
    final maxDist = lurchDist > 0 ? lurchDist : Cfg.cell * 0.7;
    final nudge = t < 0.3
        ? Curves.easeOut.transform(t / 0.3) * maxDist
        : maxDist * (1 - Curves.easeOut.transform((t - 0.3) / 0.7));
    if (nudge < 0.5) return pts;

    final ext = Offset(
      pts.last.dx + dir.dx * maxDist,
      pts.last.dy + dir.dy * maxDist,
    );
    final track = [...pts, ext];

    final cum = <double>[0];
    for (var i = 1; i < track.length; i++) {
      cum.add(cum[i - 1] + (track[i] - track[i - 1]).distance);
    }
    final totalLen = cum[pts.length - 1];

    Offset pointAt(double s) {
      if (s <= 0) return track.first;
      if (s >= cum.last) return track.last;
      for (var i = 1; i < cum.length; i++) {
        if (s <= cum[i]) {
          final frac = (s - cum[i - 1]) / (cum[i] - cum[i - 1]);
          return Offset.lerp(track[i - 1], track[i], frac)!;
        }
      }
      return track.last;
    }

    final tailArc = nudge;
    final headArc = totalLen + nudge;
    final out = <Offset>[pointAt(tailArc)];
    for (var i = 1; i < cum.length; i++) {
      if (cum[i] > tailArc && cum[i] < headArc) out.add(track[i]);
    }
    out.add(pointAt(headArc));
    return out;
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

    final h = pts.last;
    final dx = dir.dx.toDouble(), dy = dir.dy.toDouble();
    final px = -dy, py = dx;
    final halfLen = Cfg.headLen / 2;
    final tip = Offset(h.dx + dx * halfLen, h.dy + dy * halfLen);
    final l = Offset(h.dx - dx * halfLen + px * Cfg.headHalf,
        h.dy - dy * halfLen + py * Cfg.headHalf);
    final r = Offset(h.dx - dx * halfLen - px * Cfg.headHalf,
        h.dy - dy * halfLen - py * Cfg.headHalf);
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
          ..strokeWidth = 5
          ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(covariant BoardPainter old) => true;
}
