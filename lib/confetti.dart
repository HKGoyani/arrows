import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

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
  double _elapsed = 0;
  Size _size = Size.zero;
  int _leftBursts = 0;
  int _rightBursts = 0;

  static const _colors = [
    Color(0xFF6C7EFA),
    Color(0xFFAEBCF9),
    Color(0xFF455176),
    Color(0xFFE5E5E5),
    Color(0xFF5B6AF9),
    Color(0xFF3A4DBF),
  ];
  static const _gravity = 1200.0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  void _burst(bool fromLeft) {
    for (var i = 0; i < 15; i++) {
      final w = 6 + _rnd.nextDouble() * 9;
      final baseAngle = fromLeft ? -80.0 : -100.0;
      final angle = (baseAngle + (_rnd.nextDouble() - 0.5) * 24) * pi / 180;
      final speed = 650 + _rnd.nextDouble() * 600;
      _pieces.add(_Piece(
        x: fromLeft ? _size.width * 0.005 : _size.width * 0.995,
        y: _size.height * 0.98,
        vx: cos(angle) * speed,
        vy: sin(angle) * speed,
        rot: _rnd.nextDouble() * pi * 2,
        vr: (_rnd.nextDouble() - 0.5) * 10,
        w: w,
        h: w * (0.3 + _rnd.nextDouble() * 0.35),
        color: _colors[_rnd.nextInt(_colors.length)],
        curve: (_rnd.nextDouble() - 0.5) * 0.4,
      ));
    }
  }

  void _tick(Duration elapsed) {
    if (_size == Size.zero) return;
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.032);
    _last = elapsed;
    _elapsed += dt;

    if (_leftBursts < 3 && _elapsed >= _leftBursts * 0.15) {
      _burst(true);
      _leftBursts++;
    }
    if (_rightBursts < 3 && _elapsed >= _rightBursts * 0.15) {
      _burst(false);
      _rightBursts++;
    }

    for (final p in _pieces) {
      p.life += dt;
      p.vy += _gravity * dt;
      p.vx *= 0.994;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.rot += p.vr * dt;
      if (p.life > 1.5) {
        final t = ((p.life - 1.5) / 1.2).clamp(0.0, 1.0);
        p.opacity = 1 - t;
        p.scale = 1 - t * 0.6;
      }
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
      if (_size == Size.zero) {
        _size = constraints.biggest;
      }
      return CustomPaint(size: constraints.biggest, painter: _ConfettiPainter(_pieces));
    });
  }
}

class _Piece {
  double x, y, vx, vy, rot, vr, w, h, life = 0, opacity = 1, scale = 1;
  final double curve;
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
    required this.curve,
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
      final paint = Paint()
        ..color = p.color.withValues(alpha: p.opacity)
        ..style = PaintingStyle.fill;
      final hw = p.w * p.scale / 2;
      final hh = p.h * p.scale / 2;
      final bend = p.w * p.curve;
      final path = Path()
        ..moveTo(-hw, -hh)
        ..quadraticBezierTo(-hw + bend, 0, -hw, hh)
        ..lineTo(hw, hh)
        ..quadraticBezierTo(hw + bend, 0, hw, -hh)
        ..close();
      canvas.drawPath(path, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => true;
}
