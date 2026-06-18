/// Deterministic RNG — a Dart port of the JS `mulberry32` used in the HTML build,
/// so generated levels are reproducible. All math is masked to 32-bit to match JS.
class SeededRandom {
  int _a;
  SeededRandom(int seed) : _a = seed & 0xFFFFFFFF;

  /// 32-bit integer multiply (JS `Math.imul` equivalent, low 32 bits).
  static int _imul(int a, int b) {
    a &= 0xFFFFFFFF;
    b &= 0xFFFFFFFF;
    final aHi = (a >>> 16) & 0xFFFF;
    final aLo = a & 0xFFFF;
    return (aLo * b + (((aHi * b) & 0xFFFF) << 16)) & 0xFFFFFFFF;
  }

  double next() {
    _a = (_a + 0x6D2B79F5) & 0xFFFFFFFF;
    int t = _a;
    t = _imul(t ^ (t >>> 15), 1 | t) & 0xFFFFFFFF;
    t = ((t + _imul(t ^ (t >>> 7), 61 | t)) ^ t) & 0xFFFFFFFF;
    return ((t ^ (t >>> 14)) & 0xFFFFFFFF) / 4294967296.0;
  }

  int nextInt(int max) => (next() * max).floor();
}

/// Cubic-bezier easing as a function (Newton solve), ported from the HTML.
double Function(double) cubicBezier(double x1, double y1, double x2, double y2) {
  final cx = 3 * x1, bx = 3 * (x2 - x1) - cx, ax = 1 - cx - bx;
  final cy = 3 * y1, by = 3 * (y2 - y1) - cy, ay = 1 - cy - by;
  double fx(double t) => ((ax * t + bx) * t + cx) * t;
  double fy(double t) => ((ay * t + by) * t + cy) * t;
  return (double x) {
    double t = x;
    for (int i = 0; i < 8; i++) {
      final e = fx(t) - x;
      if (e.abs() < 1e-4) break;
      final d = (3 * ax * t + 2 * bx) * t + cx;
      if (d.abs() < 1e-6) break;
      t -= e / d;
    }
    return fy(t.clamp(0.0, 1.0));
  };
}

/// strong ease-in (accelerate) — measured from the source.
final flyEase = cubicBezier(0.19, 0.05, 0.50, 0.28);
