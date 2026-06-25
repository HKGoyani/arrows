import 'dart:math';
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

  /// True if (nx,ny) is orthogonally adjacent to an own-body cell other than the
  /// cell we stepped from — i.e. the path would fold back beside itself (a
  /// U-turn / hairpin). Banned so an arrow never doubles back parallel to itself.
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

  /// A long winding arrow: self-avoiding walk, prefers straight, turns ~22% or
  /// when blocked. Returns null if it couldn't grow to length >= 2.
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

  /// Greedy solver — true iff every arrow can be cleared (removing only frees
  /// cells ⇒ monotonic ⇒ greedy order is a valid solvability test).
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
    // Falls through to procedural generation if a board ever fails the solver.
    final hand = handLevel(level);
    if (hand != null && greedySolvable(hand.arrows)) {
      cols = hand.cols;
      rows = hand.rows;
      return GeneratedLevel(hand.arrows, hand.cols, hand.rows);
    }

    cols = min(2 + level, 13);
    rows = min(3 + level, 16);
    // Shorter arrows at higher tiers pack more pieces → denser, harder boards
    // (matches the reference's many-short-arrows Nightmare layouts).
    maxSeg = level < 6
        ? max(2, min(4, min(cols, rows) ~/ 2))
        : (level < 25 ? 3 : 2);
    // Target scales with level; the packer fills the grid and early-exits.
    final count = min(3 + level * 3, 60);
    final seed = (0x9E37 + level * 2654435761) & 0xFFFFFFFF;

    int score(List<Arrow> arr) {
      var s = 0;
      for (final a in arr) {
        s += a.cells.length;
      }
      return (arr.length >= count ? 1000000 : 0) + s;
    }

    // 1) densest fully-solvable winding packing (early-exit once a good one is found)
    List<Arrow>? best;
    var bestScore = -1;
    for (var att = 0; att < 60; att++) {
      final arr = _packArrows((seed + att * 7919) & 0xFFFFFFFF, count);
      if (!greedySolvable(arr)) continue;
      final sc = score(arr);
      if (sc > bestScore) {
        bestScore = sc;
        best = arr;
      }
      if (best != null && best.length >= count && att >= 18) break;
    }
    if (best != null && best.length >= count) return GeneratedLevel(best, cols, rows);

    // 2) guaranteed-solvable reverse-construction fallback
    List<Arrow>? rc;
    var rcScore = -1;
    for (var att = 0; att < 40; att++) {
      final arr = _packArrowsRC((seed + 101 + att * 7919) & 0xFFFFFFFF, count);
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
