import 'dart:ui';
import 'config.dart';
import 'models.dart';

/// The fixed "track" an arrow snakes along when fired: its own polyline plus a
/// straight extension in the head direction (so it exits the screen). The shaft
/// drawn each frame is the slice of the track between tailArc..headArc.
class FlyOff {
  final Arrow arrow;
  final List<Offset> track; // cell-unit points
  final List<double> cum; // cumulative arc length
  final double arrowLen; // arc length of the head (front of snake)
  final double total;

  FlyOff._(this.arrow, this.track, this.cum, this.arrowLen, this.total);

  factory FlyOff.forArrow(Arrow a) {
    final pts = a.pts
        .map((p) => Offset(Cfg.margin + p.x * Cfg.cell, Cfg.margin + p.y * Cfg.cell))
        .toList();
    final ext = Offset(
      pts.last.dx + a.dir.dx * Cfg.flyDist,
      pts.last.dy + a.dir.dy * Cfg.flyDist,
    );
    final track = [...pts, ext];
    final cum = <double>[0];
    for (var i = 1; i < track.length; i++) {
      cum.add(cum[i - 1] + (track[i] - track[i - 1]).distance);
    }
    return FlyOff._(a, track, cum, cum[pts.length - 1], cum.last);
  }

  Offset pointAt(double s) {
    if (s <= 0) return track.first;
    if (s >= total) return track.last;
    for (var i = 1; i < cum.length; i++) {
      if (s <= cum[i]) {
        final t = (s - cum[i - 1]) / (cum[i] - cum[i - 1]);
        return Offset.lerp(track[i - 1], track[i], t)!;
      }
    }
    return track.last;
  }

  /// Shaft polyline between tail and head at the given advance — passes through
  /// every track vertex so it follows each bend (the "snake on rails").
  List<Offset> shaftPoints(double adv) {
    final tailArc = adv, headArc = arrowLen + adv;
    final out = <Offset>[pointAt(tailArc)];
    for (var i = 1; i < cum.length; i++) {
      if (cum[i] > tailArc && cum[i] < headArc) out.add(track[i]);
    }
    out.add(pointAt(headArc));
    return out;
  }
}
