import 'dart:math';
import 'difficulty.dart';
import 'hand_levels.dart';
import 'models.dart';
import 'rng.dart';

/// Procedural, deterministic, GUARANTEED-solvable level generator.
/// Ported 1:1 from the HTML build: long winding maze arrows, ~46% edge fill,
/// even coverage; densest solvable layout chosen, with a reverse-construction
/// fallback that can never dead-lock.
class LevelGenerator {
  int cols = 9, rows = 11, maxSeg = 4;

  bool _inB(int x, int y) => x >= 0 && x <= cols && y >= 0 && y <= rows;

  bool _touchesSelf(int nx, int ny, int fromX, int fromY, Set<String> body) {
    const adj = [
      [1, 0],
      [-1, 0],
      [0, 1],
      [0, -1]
    ];
    for (final d in adj) {
      final ax = nx + d[0], ay = ny + d[1];
      if (ax == fromX && ay == fromY) continue;
      if (body.contains(cellKey(ax, ay))) return true;
    }
    return false;
  }

  _Walk? _windPath(SeededRandom rng, Set<String> occ) {
    int cx = rng.nextInt(cols + 1), cy = rng.nextInt(rows + 1);
    if (occ.contains(cellKey(cx, cy))) return null;
    final targetLen = 3 + rng.nextInt(maxSeg * 2 + 3);
    final pts = <Point<int>>[Point(cx, cy)];
    final body = <String>{cellKey(cx, cy)};
    var dir = Direction.values[rng.nextInt(4)];
    var headDir = dir;
    for (var step = 0; step < targetLen; step++) {
      final cur = dir;
      final perp =
          Direction.values.where((d) => d.horizontal != cur.horizontal).toList();
      final List<Direction> order = rng.next() < 0.78
          ? [cur, perp[rng.nextInt(2)], perp[0], perp[1]]
          : [perp[rng.nextInt(2)], cur, perp[0], perp[1]];
      var moved = false;
      for (final d in order) {
        final nx = cx + d.dx, ny = cy + d.dy;
        final k = cellKey(nx, ny);
        if (_inB(nx, ny) &&
            !occ.contains(k) &&
            !body.contains(k) &&
            !_touchesSelf(nx, ny, cx, cy, body)) {
          cx = nx;
          cy = ny;
          pts.add(Point(cx, cy));
          body.add(k);
          dir = d;
          headDir = d;
          moved = true;
          break;
        }
      }
      if (!moved) break;
    }
    if (pts.length < 2) return null;
    return _Walk(pts, body, headDir, cx, cy);
  }

  /// Targeted walk starting from a specific open cell (used by the dense
  /// packer to fill gaps instead of picking random starts).
  _Walk? _windPathFrom(SeededRandom rng, Set<String> occ, int sx, int sy,
      {bool relaxAdj = false}) {
    if (occ.contains(cellKey(sx, sy))) return null;
    final targetLen = 2 + rng.nextInt(maxSeg + 2);
    final pts = <Point<int>>[Point(sx, sy)];
    final body = <String>{cellKey(sx, sy)};
    var cx = sx, cy = sy;
    var dir = Direction.values[rng.nextInt(4)];
    var headDir = dir;
    for (var step = 0; step < targetLen; step++) {
      final cur = dir;
      final perp =
          Direction.values.where((d) => d.horizontal != cur.horizontal).toList();
      final List<Direction> order = rng.next() < 0.65
          ? [cur, perp[rng.nextInt(2)], perp[0], perp[1]]
          : [perp[rng.nextInt(2)], cur, perp[0], perp[1]];
      var moved = false;
      for (final d in order) {
        final nx = cx + d.dx, ny = cy + d.dy;
        final k = cellKey(nx, ny);
        if (_inB(nx, ny) &&
            !occ.contains(k) &&
            !body.contains(k) &&
            (relaxAdj || !_touchesSelf(nx, ny, cx, cy, body))) {
          cx = nx;
          cy = ny;
          pts.add(Point(cx, cy));
          body.add(k);
          dir = d;
          headDir = d;
          moved = true;
          break;
        }
      }
      if (!moved) break;
    }
    if (pts.length < 2) return null;
    return _Walk(pts, body, headDir, cx, cy);
  }

  List<Arrow> _packArrows(int seed, int count) {
    final rng = SeededRandom(seed);
    final occ = <String>{};
    final arrows = <Arrow>[];
    var tries = 0;
    while (arrows.length < count && tries < count * 80) {
      tries++;
      final w = _windPath(rng, occ);
      if (w == null) continue;
      occ.addAll(w.body);
      arrows.add(Arrow(id: arrows.length, pts: w.pts, dir: w.headDir, cells: w.body));
    }
    return arrows;
  }

  /// Dense packer: random phase then gap-fill phase. Scans for open cells and
  /// starts arrows from them so we don't waste tries on occupied spots.
  List<Arrow> _packArrowsDense(int seed, int count) {
    final rng = SeededRandom(seed);
    final occ = <String>{};
    final arrows = <Arrow>[];

    // Phase 1: random starts (quick coverage)
    var tries = 0;
    final phase1Limit = count * 40;
    while (arrows.length < count && tries < phase1Limit) {
      tries++;
      final w = _windPath(rng, occ);
      if (w == null) continue;
      occ.addAll(w.body);
      arrows.add(Arrow(id: arrows.length, pts: w.pts, dir: w.headDir, cells: w.body));
    }
    if (arrows.length >= count) return arrows;

    // Phase 2: scan for open cells and try to start arrows from them
    for (var pass = 0; pass < 5 && arrows.length < count; pass++) {
      final relax = pass >= 2;
      for (var y = 0; y <= rows && arrows.length < count; y++) {
        for (var x = 0; x <= cols && arrows.length < count; x++) {
          if (occ.contains(cellKey(x, y))) continue;
          for (var r = 0; r < 6; r++) {
            final w = _windPathFrom(rng, occ, x, y, relaxAdj: relax);
            if (w == null) continue;
            occ.addAll(w.body);
            arrows.add(Arrow(id: arrows.length, pts: w.pts, dir: w.headDir, cells: w.body));
            break;
          }
        }
      }
    }
    return arrows;
  }

  /// Reverse-construction: each arrow's exit corridor must be clear of placed
  /// arrows ⇒ removing in reverse order is always valid ⇒ guaranteed solvable.
  List<Arrow> _packArrowsRC(int seed, int count) {
    final rng = SeededRandom(seed);
    final occ = <String>{};
    final arrows = <Arrow>[];
    var tries = 0;
    while (arrows.length < count && tries < count * 80) {
      tries++;
      final w = _windPath(rng, occ);
      if (w == null) continue;
      var fx = w.hx, fy = w.hy, ok = true;
      while (true) {
        fx += w.headDir.dx;
        fy += w.headDir.dy;
        if (!_inB(fx, fy)) break;
        final k = cellKey(fx, fy);
        if (occ.contains(k) || w.body.contains(k)) {
          ok = false;
          break;
        }
      }
      if (!ok) continue;
      occ.addAll(w.body);
      arrows.add(Arrow(id: arrows.length, pts: w.pts, dir: w.headDir, cells: w.body));
    }
    return arrows;
  }

  /// Dense reverse-construction with gap-fill.
  List<Arrow> _packArrowsRCDense(int seed, int count) {
    final rng = SeededRandom(seed);
    final occ = <String>{};
    final arrows = <Arrow>[];

    bool exitClear(_Walk w) {
      var fx = w.hx, fy = w.hy;
      while (true) {
        fx += w.headDir.dx;
        fy += w.headDir.dy;
        if (!_inB(fx, fy)) return true;
        final k = cellKey(fx, fy);
        if (occ.contains(k) || w.body.contains(k)) return false;
      }
    }

    // Phase 1: random starts
    var tries = 0;
    while (arrows.length < count && tries < count * 40) {
      tries++;
      final w = _windPath(rng, occ);
      if (w == null) continue;
      if (!exitClear(w)) continue;
      occ.addAll(w.body);
      arrows.add(Arrow(id: arrows.length, pts: w.pts, dir: w.headDir, cells: w.body));
    }
    if (arrows.length >= count) return arrows;

    // Phase 2: gap-fill from open cells
    for (var pass = 0; pass < 5 && arrows.length < count; pass++) {
      final relax = pass >= 2;
      for (var y = 0; y <= rows && arrows.length < count; y++) {
        for (var x = 0; x <= cols && arrows.length < count; x++) {
          if (occ.contains(cellKey(x, y))) continue;
          for (var r = 0; r < 6; r++) {
            final w = _windPathFrom(rng, occ, x, y, relaxAdj: relax);
            if (w == null) continue;
            if (!exitClear(w)) continue;
            occ.addAll(w.body);
            arrows.add(Arrow(id: arrows.length, pts: w.pts, dir: w.headDir, cells: w.body));
            break;
          }
        }
      }
    }
    return arrows;
  }

  /// Greedy solver — true iff every arrow can be cleared.
  bool greedySolvable(List<Arrow> arrows) {
    final occ = <String, int>{};
    for (final a in arrows) {
      for (final c in a.cells) {
        occ[c] = a.id;
      }
    }
    bool clear(Arrow a) {
      var x = a.head.x, y = a.head.y;
      while (true) {
        x += a.dir.dx;
        y += a.dir.dy;
        if (!_inB(x, y)) return true;
        final o = occ[cellKey(x, y)];
        if (o != null && o != a.id) return false;
      }
    }

    final list = List<Arrow>.from(arrows);
    var guard = 0;
    while (list.isNotEmpty && guard < 9000) {
      guard++;
      final i = list.indexWhere(clear);
      if (i < 0) break;
      for (final c in list[i].cells) {
        occ.remove(c);
      }
      list.removeAt(i);
    }
    return list.isEmpty;
  }

  GeneratedLevel genLevel(int level) {
    // Hand-authored onboarding levels (1–5), validated for solvability.
    final hand = handLevel(level);
    if (hand != null && greedySolvable(hand.arrows)) {
      cols = hand.cols;
      rows = hand.rows;
      return GeneratedLevel(hand.arrows, hand.cols, hand.rows);
    }

    final tier = tierForLevel(level);

    // Grid and arrow parameters driven by the tier assigned to this level.
    switch (tier) {
      case Tier.normal:
        cols = min(2 + level, 9);
        rows = min(3 + level, 11);
        maxSeg = max(2, min(4, min(cols, rows) ~/ 2));
      case Tier.hard:
        cols = min(5 + level ~/ 2, 12);
        rows = min(6 + level ~/ 2, 15);
        maxSeg = 3;
      case Tier.superHard:
        cols = min(10 + (level - 15).clamp(0, 20) ~/ 3, 15);
        rows = min(12 + (level - 15).clamp(0, 20) ~/ 3, 19);
        maxSeg = 2;
      case Tier.nightmare:
        cols = min(14 + (level - 35).clamp(0, 50) ~/ 5, 16);
        rows = min(17 + (level - 35).clamp(0, 50) ~/ 4, 20);
        maxSeg = 1;
    }

    final gridArea = (cols + 1) * (rows + 1);
    final int count;
    switch (tier) {
      case Tier.normal:
        count = 3 + level * 3;
      case Tier.hard:
        count = min(15 + (level - 6).clamp(0, 50) * 3, gridArea ~/ 4);
      case Tier.superHard:
        count = min(30 + (level - 15).clamp(0, 50) * 2, gridArea ~/ 3);
      case Tier.nightmare:
        count = min(50 + (level - 35).clamp(0, 100), gridArea ~/ 3);
    }

    final seed = (0x9E37 + level * 2654435761) & 0xFFFFFFFF;
    final useDense = tier != Tier.normal;

    int score(List<Arrow> arr) {
      var s = 0;
      for (final a in arr) {
        s += a.cells.length;
      }
      return (arr.length >= count ? 1000000 : 0) + s;
    }

    // 1) densest fully-solvable packing
    List<Arrow>? best;
    var bestScore = -1;
    final attempts1 = useDense ? 40 : 60;
    for (var att = 0; att < attempts1; att++) {
      final s = (seed + att * 7919) & 0xFFFFFFFF;
      final arr = useDense ? _packArrowsDense(s, count) : _packArrows(s, count);
      if (!greedySolvable(arr)) continue;
      final sc = score(arr);
      if (sc > bestScore) {
        bestScore = sc;
        best = arr;
      }
      if (best != null && best.length >= count && att >= 12) break;
    }
    if (best != null && best.length >= count) return GeneratedLevel(best, cols, rows);

    // 2) guaranteed-solvable reverse-construction fallback
    List<Arrow>? rc;
    var rcScore = -1;
    final attempts2 = useDense ? 30 : 40;
    for (var att = 0; att < attempts2; att++) {
      final s = (seed + 101 + att * 7919) & 0xFFFFFFFF;
      final arr = useDense ? _packArrowsRCDense(s, count) : _packArrowsRC(s, count);
      final sc = score(arr);
      if (sc > rcScore) {
        rcScore = sc;
        rc = arr;
      }
      if (rc != null && rc.length >= count) break;
    }
    final chosen = (rc != null && rcScore > bestScore) ? rc : (best ?? rc ?? <Arrow>[]);
    return GeneratedLevel(chosen, cols, rows);
  }
}

class _Walk {
  final List<Point<int>> pts;
  final Set<String> body;
  final Direction headDir;
  final int hx, hy;
  _Walk(this.pts, this.body, this.headDir, this.hx, this.hy);
}
