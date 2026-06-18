import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Win confetti: two bottom-corner cannons fire up-and-inward, then the pieces
/// fall under gravity (spin + drift + fade) over ~2.4s — matches the HTML.
class ConfettiOverlay extends StatefulWidget {
  const ConfettiOverlay({super.key});
  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _rnd = Random();
  final List<_Piece> _pieces = [];
  Duration _last = Duration.zero;
  bool _spawned = false;

  static const _colors = [
    Color(0xFF6C7EFA),
    Color(0xFFAEBCF9),
    Color(0xFF455176),
    Color(0xFFE5E5E5),
    Color(0xFF5B6AF9),
  ];
  static const _gravity = 2600.0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  void _spawn(Size size) {
    for (var i = 0; i < 130; i++) {
      final fromLeft = i.isEven;
      final w = 6 + _rnd.nextDouble() * 12;
      _pieces.add(_Piece(
        x: fromLeft ? size.width * 0.05 : size.width * 0.95,
        y: size.height * 0.99,
        vx: (200 + _rnd.nextDouble() * 520) * (fromLeft ? 1 : -1),
        vy: -(1500 + _rnd.nextDouble() * 850),
        rot: _rnd.nextDouble() * pi * 2,
        vr: (_rnd.nextDouble() - 0.5) * 15,
        w: w,
        h: w * (0.5 + _rnd.nextDouble() * 0.6),
        color: _colors[i % _colors.length],
      ));
    }
    _spawned = true;
  }

  void _tick(Duration elapsed) {
    if (!_spawned) return;
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.032);
    _last = elapsed;
    for (final p in _pieces) {
      p.life += dt;
      p.vy += _gravity * dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.rot += p.vr * dt;
      p.opacity = p.life < 1.3 ? 1.0 : (1 - (p.life - 1.3) / 1.1).clamp(0.0, 1.0);
    }
    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      if (!_spawned) {
        WidgetsBinding.instance.addPostFrameCallback(
            (_) => _spawn(constraints.biggest));
      }
      return CustomPaint(size: constraints.biggest, painter: _ConfettiPainter(_pieces));
    });
  }
}

class _Piece {
  double x, y, vx, vy, rot, vr, w, h, life = 0, opacity = 1;
  final Color color;
  _Piece({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.rot,
    required this.vr,
    required this.w,
    required this.h,
    required this.color,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_Piece> pieces;
  _ConfettiPainter(this.pieces);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      if (p.opacity <= 0) continue;
      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rot);
      final paint = Paint()..color = p.color.withValues(alpha: p.opacity);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.w, height: p.h),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => true;
}
