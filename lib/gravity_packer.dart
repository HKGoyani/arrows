import 'dart:math';
import 'models.dart';
import 'rng.dart';

/// Gravity-fill level packer used by the L100+ shaped levels.
///
/// A fundamentally different strategy from the RC/walker packing in
/// [LevelGenerator]: split the board into directional regions whose exit
/// rays only cross later-cleared regions, then fill each region like
/// falling sand — columns fill contiguously from the bottom (in
/// exit-rotated space), so every arrow's head has a clear straight ray off
/// the board AT PLACEMENT TIME and clearing in reverse placement order
/// always works: solvable BY CONSTRUCTION at 100% mask fill, in
/// single-digit milliseconds. Post passes weld snakes into long winding
/// arrows and flip-mix directions (greedy-verified) for the classic look.
class GravityPacker {
  GravityPacker({
    required this.cols,
    required this.rows,
    required this.inMask,
    required this.solvable,
  });

  /// Grid extents (inclusive: cells span 0..cols × 0..rows).
  final int cols, rows;

  /// Whether a cell is playable (inside the shape mask / grid rectangle).
  final bool Function(int x, int y) inMask;

  /// Full-board solvability check (LevelGenerator.greedySolvable).
  final bool Function(List<Arrow> arrows) solvable;

  // ── Gravity packer (used by the newer shaped levels) ──
  //
  // A fundamentally different strategy from RC packing: split the board into
  // 1/2/4 directional regions whose exit rays reach the grid edge without
  // crossing each other, then fill each region like falling sand — columns
  // fill contiguously from the bottom (in exit-rotated space), so every
  // arrow's head has a clear straight ray off the board AT PLACEMENT TIME
  // and arrows placed later always sit closer to the exit edge. Clearing in
  // reverse placement order therefore always works: solvable BY CONSTRUCTION
  // with zero retries and zero solver calls, at 100% mask fill. Runs in
  // single-digit milliseconds even on Nightmare-size masks.

  /// Arrow-length weights for gravity snakes (index 0 → length 2, ... last →
  /// length 12). Biased mid-length with a long tail for winding arrows.
  static const _gravityLenW = <double>[
    0.06, 0.14, 0.18, 0.17, 0.13, 0.10, 0.08, 0.06, 0.04, 0.03, 0.01,
  ];

  /// Cells left unfilled by [pack] (dropped orphan singletons).
  /// Zero on almost every seed; genLevel retries when non-zero.
  int holes = 0;

  List<Arrow> pack(int seed) {
    holes = 0;
    final rng = SeededRandom(seed);
    // Collect the playable cells (whole rect if no mask).
    final mask = <String>{};
    for (var y = 0; y <= rows; y++) {
      for (var x = 0; x <= cols; x++) {
        if (inMask(x, y)) mask.add(cellKey(x, y));
      }
    }
    final arrows = <Arrow>[];
    for (final region in _gravityRegions(rng, mask)) {
      _gravityFillRegion(rng, region.$1, region.$2, arrows);
    }
    return arrows;
  }

  /// Splits the mask into directional regions that mix all four directions
  /// across the whole board:
  ///
  ///   • a band along each of two opposite edges, split outward two ways
  ///     (e.g. top band: left half exits left, right half exits right), and
  ///   • strips filling the middle, each cut at a random point into two
  ///     outward parts (e.g. vertical strip: upper part exits up, lower
  ///     exits down). Strip widths and cut points vary, so up/down (or
  ///     left/right) alternate in a mosaic rather than one block each.
  ///
  /// The orientation flips per seed. Soundness: a strip's exit ray stays in
  /// its own columns and crosses only the edge bands, so placing ALL strips
  /// first and the bands last means everything an arrow must fly through is
  /// placed later (= cleared earlier). Band rays run within their own rows
  /// toward the board edge and cross nothing but themselves.
  List<(Set<String>, Direction)> _gravityRegions(
      SeededRandom rng, Set<String> mask) {
    final vertical = rng.next() < 0.5; // strips run vertically?
    // Work in (a, b) coords: a = strip axis position, b = along-strip axis.
    // vertical: a=x (0..cols), b=y (0..rows); horizontal: a=y, b=x.
    final aMax = vertical ? cols : rows;
    final bMax = vertical ? rows : cols;
    final nearDir = vertical ? Direction.up : Direction.left;
    final farDir = vertical ? Direction.down : Direction.right;
    final bandNearDir = vertical ? Direction.left : Direction.up;
    final bandFarDir = vertical ? Direction.right : Direction.down;

    final nearBand = 4 + rng.nextInt(4); // band thickness 4-7
    final farBand = 4 + rng.nextInt(4);

    // Strip layout across the a-axis.
    final stripOf = List<int>.filled(aMax + 1, 0);
    final cuts = <int>[];
    {
      var a = 0, s = 0;
      while (a <= aMax) {
        final w = 4 + rng.nextInt(4); // strip width 4-7
        for (var i = 0; i < w && a <= aMax; i++, a++) {
          stripOf[a] = s;
        }
        // Cut point somewhere in the middle 30-70% of the strip run.
        final lo = nearBand + ((bMax - nearBand - farBand) * 0.3).round();
        final hi = nearBand + ((bMax - nearBand - farBand) * 0.7).round();
        cuts.add(lo + rng.nextInt(max(1, hi - lo + 1)));
        s++;
      }
    }
    final bandNearSplit = aMax ~/ 2 + rng.nextInt(5) - 2;
    final bandFarSplit = aMax ~/ 2 + rng.nextInt(5) - 2;

    final stripNear = <int, Set<String>>{};
    final stripFar = <int, Set<String>>{};
    final bandCells = {
      (true, true): <String>{}, // near band, near side
      (true, false): <String>{},
      (false, true): <String>{},
      (false, false): <String>{},
    };

    for (final k in mask) {
      final p = k.split(',');
      final x = int.parse(p[0]), y = int.parse(p[1]);
      final a = vertical ? x : y, b = vertical ? y : x;
      if (b < nearBand) {
        bandCells[(true, a < bandNearSplit)]!.add(k);
      } else if (b > bMax - farBand) {
        bandCells[(false, a < bandFarSplit)]!.add(k);
      } else {
        final s = stripOf[a];
        ((b < cuts[s]) ? stripNear : stripFar)
            .putIfAbsent(s, () => <String>{})
            .add(k);
      }
    }

    return [
      // All strips first (their rays cross only the bands, placed later).
      for (final c in stripNear.values)
        if (c.isNotEmpty) (c, nearDir),
      for (final c in stripFar.values)
        if (c.isNotEmpty) (c, farDir),
      // Bands last: their rays exit sideways within their own rows.
      if (bandCells[(true, true)]!.isNotEmpty)
        (bandCells[(true, true)]!, bandNearDir),
      if (bandCells[(true, false)]!.isNotEmpty)
        (bandCells[(true, false)]!, bandFarDir),
      if (bandCells[(false, true)]!.isNotEmpty)
        (bandCells[(false, true)]!, bandNearDir),
      if (bandCells[(false, false)]!.isNotEmpty)
        (bandCells[(false, false)]!, bandFarDir),
    ];
  }

  /// Rotates [mask] so [exitDir] becomes "up", gravity-fills it with snakes,
  /// and appends the resulting arrows (rotated back) to [out].
  void _gravityFillRegion(SeededRandom rng, Set<String> mask,
      Direction exitDir, List<Arrow> out) {
    if (mask.isEmpty) return;
    final w = cols + 1, h = rows + 1;
    late int lw, lh;
    late Point<int> Function(int, int) toLocal, toOrig;
    switch (exitDir) {
      case Direction.up:
        lw = w; lh = h;
        toLocal = (x, y) => Point(x, y);
        toOrig = (x, y) => Point(x, y);
      case Direction.down:
        lw = w; lh = h;
        toLocal = (x, y) => Point(x, h - 1 - y);
        toOrig = (x, y) => Point(x, h - 1 - y);
      case Direction.left:
        lw = h; lh = w;
        toLocal = (x, y) => Point(y, x);
        toOrig = (x, y) => Point(y, x);
      case Direction.right:
        lw = h; lh = w;
        toLocal = (x, y) => Point(y, w - 1 - x);
        toOrig = (x, y) => Point(w - 1 - y, x);
    }

    final lmask = <String>{};
    for (final k in mask) {
      final p = k.split(',');
      final q = toLocal(int.parse(p[0]), int.parse(p[1]));
      lmask.add(cellKey(q.x, q.y));
    }

    for (final snake in _gravityUp(rng, lw, lh, lmask)) {
      final pts = <Point<int>>[];
      final body = <String>{};
      for (final c in snake) {
        final q = toOrig(c.x, c.y);
        pts.add(q);
        body.add(cellKey(q.x, q.y));
      }
      out.add(Arrow(id: out.length, pts: pts, dir: exitDir, cells: body));
    }
  }

  /// Fills [mask] (local space, exit = up) with winding snakes. Columns fill
  /// contiguously from the bottom: a snake grows either UP within its column
  /// or SIDEWAYS onto an equal-height neighbour column (a bend), so each
  /// snake's topmost cell — its head — always has a clear upward ray when
  /// placed. Returns snakes as cell lists, tail→head. Pocket-free, 100% fill.
  List<List<Point<int>>> _gravityUp(
      SeededRandom rng, int lw, int lh, Set<String> mask) {
    final filled = <String>{};
    final out = <List<Point<int>>>[];
    const pStraight = 0.34; // low = windier snakes
    const jogBias = 0.72; // prefer a real sideways bend when turning

    int surfaceOf(int x) {
      for (var y = lh - 1; y >= 0; y--) {
        final k = cellKey(x, y);
        if (mask.contains(k) && !filled.contains(k)) return y;
      }
      return -1;
    }

    final surface = List.generate(lw, surfaceOf);
    var remaining = mask.length;

    while (remaining > 0) {
      // Start at the globally bottom-most open surface — keeps neighbouring
      // column heights even, which is what makes sideways jogs possible.
      var maxY = -1;
      for (var x = 0; x < lw; x++) {
        if (surface[x] > maxY) maxY = surface[x];
      }
      final starts = [
        for (var x = 0; x < lw; x++)
          if (surface[x] == maxY) x
      ];
      final x0 = starts[rng.nextInt(starts.length)];

      final snake = <Point<int>>[Point(x0, maxY)];
      filled.add(cellKey(x0, maxY));
      remaining--;
      surface[x0] = surfaceOf(x0);

      final targetLen =
          2 + _weightedIndex(rng, _gravityLenW).clamp(0, lh - 1);
      var cx = x0, cy = maxY;
      var growDir = Direction.up;

      while (snake.length < targetLen) {
        // Valid moves: up within the column, or sideways to an equal-height
        // surface neighbour (keeps every column contiguous from the bottom).
        Point<int>? upCell;
        if (cy - 1 >= 0 &&
            mask.contains(cellKey(cx, cy - 1)) &&
            !filled.contains(cellKey(cx, cy - 1))) {
          upCell = Point(cx, cy - 1);
        }
        final sides = <(Direction, Point<int>)>[];
        for (final d in const [Direction.left, Direction.right]) {
          final nx = cx + d.dx;
          if (nx < 0 || nx >= lw) continue;
          final k = cellKey(nx, cy);
          if (!mask.contains(k) || filled.contains(k) || surface[nx] != cy) {
            continue;
          }
          // Only jog onto a cell whose own up-cell is still free — a jog
          // onto a column's TOP cell would strand that column's head slot
          // (the snake can't end there pointing up), creating orphan holes.
          final upK = cellKey(nx, cy - 1);
          if (cy - 1 < 0 || !mask.contains(upK) || filled.contains(upK)) {
            continue;
          }
          sides.add((d, Point(nx, cy)));
        }
        if (upCell == null && sides.isEmpty) break;

        Direction ndir;
        Point<int> ncell;
        final canContinue = (growDir == Direction.up && upCell != null) ||
            (growDir != Direction.up && sides.any((s) => s.$1 == growDir));
        if (canContinue && rng.next() < pStraight) {
          if (growDir == Direction.up) {
            ndir = Direction.up;
            ncell = upCell!;
          } else {
            final s = sides.firstWhere((s) => s.$1 == growDir);
            ndir = s.$1;
            ncell = s.$2;
          }
        } else {
          // Turn: favour a sideways jog (a real bend) when one exists.
          final pool = <(Direction, Point<int>)>[
            if (upCell != null) (Direction.up, upCell),
            ...sides,
          ];
          final jogs = [
            for (final p in pool)
              if (p.$1 != Direction.up) p
          ];
          final choice = (jogs.isNotEmpty && rng.next() < jogBias)
              ? jogs[rng.nextInt(jogs.length)]
              : pool[rng.nextInt(pool.length)];
          ndir = choice.$1;
          ncell = choice.$2;
        }

        cx = ncell.x;
        cy = ncell.y;
        snake.add(ncell);
        filled.add(cellKey(cx, cy));
        remaining--;
        surface[cx] = surfaceOf(cx);
        growDir = ndir;
      }

      // Head alignment: the arrow fires along the exit direction (local up),
      // so the shaft must END with an upward step — otherwise the rendered
      // head sits rotated 90° against its own body. Extend one cell up when
      // possible; otherwise trim the trailing sideways cells back into the
      // pool (they're at the top of their columns, so later snakes take them).
      if (snake.length >= 2 && snake.last.y == snake[snake.length - 2].y) {
        final ux = snake.last.x, uy = snake.last.y - 1;
        final uk = cellKey(ux, uy);
        if (uy >= 0 && mask.contains(uk) && !filled.contains(uk)) {
          snake.add(Point(ux, uy));
          filled.add(uk);
          remaining--;
          surface[ux] = surfaceOf(ux);
        } else {
          while (snake.length >= 2 &&
              snake.last.y == snake[snake.length - 2].y) {
            final c = snake.removeLast();
            filled.remove(cellKey(c.x, c.y));
            remaining++;
            surface[c.x] = surfaceOf(c.x);
          }
        }
      }

      // y is non-increasing along the snake, so snake.last is the topmost
      // cell: tail→head order with the head's upward ray clear.
      out.add(snake);
    }
    _mergeLocalSingletons(out);
    _joinLocalSnakes(rng, out);
    return out;
  }

  /// Welds snakes head→tail into LONG winding arrows (the classic 8-40 cell
  /// look): when a snake's head cell touches a later-placed snake's tail
  /// cell, the two become one train that exits along the later snake's head.
  ///
  /// Soundness: a chain clears at its LAST member's reverse-placement slot.
  /// The last member has the highest placement index of the chain, so the
  /// chain clears no later than any member would have on its own — every
  /// arrow waiting on a member's cells still finds them gone in time, and
  /// the chain's own head ray only crosses cells placed after the last
  /// member (cleared even earlier) or its own body (never blocks itself).
  /// Chains are built strictly in ascending placement order.
  void _joinLocalSnakes(SeededRandom rng, List<List<Point<int>>> snakes) {
    final tailAt = <String, int>{};
    for (var j = 0; j < snakes.length; j++) {
      tailAt[cellKey(snakes[j].first.x, snakes[j].first.y)] = j;
    }
    final consumed = List<bool>.filled(snakes.length, false);
    final out = <List<Point<int>>>[];
    for (var i = 0; i < snakes.length; i++) {
      if (consumed[i]) continue;
      consumed[i] = true;
      final chain = List<Point<int>>.from(snakes[i]);
      var lastIdx = i;
      final cap = _joinMin + rng.nextInt(_joinMax - _joinMin + 1);
      while (chain.length < cap) {
        final h = chain.last;
        int? next;
        for (final d in Direction.values) {
          final j = tailAt[cellKey(h.x + d.dx, h.y + d.dy)];
          if (j != null && !consumed[j] && j > lastIdx) {
            next = j;
            break;
          }
        }
        if (next == null) break;
        consumed[next] = true;
        chain.addAll(snakes[next]);
        lastIdx = next;
      }
      out.add(chain);
    }
    snakes
      ..clear()
      ..addAll(out);
  }

  /// Target length band for joined gravity arrows (classic long-arrow look).
  static const _joinMin = 8, _joinMax = 40;

  /// Salt-and-pepper direction mixing: reverses individual arrows
  /// (head↔tail) so extra directions appear inside each region instead of
  /// clean directional blocks. A reversed arrow fires along its old TAIL
  /// segment, so an arrow whose tail started with a sideways jog becomes a
  /// HORIZONTAL arrow inside a vertical strip (and vice versa) — that's
  /// what puts all four directions everywhere. Axis-changing flips are
  /// tried first. Every accepted state is verified with [solvable];
  /// flips that would deadlock the board are reverted. The check budget is
  /// a fixed count, keeping generation deterministic on every device.
  void mixByFlipping(SeededRandom rng, List<Arrow> arrows) {
    Direction? flipDirOf(Arrow a) {
      final p0 = a.pts.first, p1 = a.pts[1];
      for (final d in Direction.values) {
        if (d.dx == p0.x - p1.x && d.dy == p0.y - p1.y) return d;
      }
      return null;
    }

    final axisChanging = <int>[], sameAxis = <int>[];
    for (var i = 0; i < arrows.length; i++) {
      final a = arrows[i];
      if (a.pts.length < 2) continue;
      final fd = flipDirOf(a);
      if (fd == null) continue;
      (fd.horizontal != a.dir.horizontal ? axisChanging : sameAxis).add(i);
    }
    void shuffle(List<int> xs) {
      for (var i = xs.length - 1; i > 0; i--) {
        final j = rng.nextInt(i + 1);
        final t = xs[i];
        xs[i] = xs[j];
        xs[j] = t;
      }
    }

    shuffle(axisChanging);
    shuffle(sameAxis);
    final candidates = [...axisChanging, ...sameAxis];
    Arrow flip(Arrow a) => Arrow(
        id: a.id,
        pts: a.pts.reversed.toList(),
        dir: flipDirOf(a)!,
        cells: a.cells);
    var checks = 0;
    const maxChecks = 60, batchSize = 4;
    for (var s = 0;
        s < candidates.length && checks < maxChecks;
        s += batchSize) {
      final batch =
          candidates.sublist(s, min(s + batchSize, candidates.length));
      final saved = [for (final i in batch) arrows[i]];
      for (final i in batch) {
        arrows[i] = flip(arrows[i]);
      }
      checks++;
      if (!solvable(arrows)) {
        for (var b = 0; b < batch.length; b++) {
          arrows[batch[b]] = saved[b];
        }
        // Batch deadlocked — retry each member alone.
        for (var b = 0; b < batch.length && checks < maxChecks; b++) {
          final i = batch[b];
          arrows[i] = flip(arrows[i]);
          checks++;
          if (!solvable(arrows)) arrows[i] = saved[b];
        }
      }
    }
  }

  /// Jagged mask edges can strand 1-cell snakes, which the game can't render
  /// as arrows. Prepend each onto a LATER-placed snake whose tail is adjacent
  /// (usually the snake that started directly above it in the same column).
  /// Later-placed is what keeps the construction sound: any snake whose exit
  /// ray crosses the orphan cell was placed even earlier, so the merged snake
  /// still clears first in reverse-placement order. A merge onto an
  /// EARLIER-placed snake is tried as a fallback — it can in theory break the
  /// ordering, so genLevel re-verifies with greedySolvable and retries the
  /// seed if needed. An orphan with no adjacent tail at all is dropped,
  /// leaving a 1-cell hole (counted in [holes] → seed retry).
  void _mergeLocalSingletons(List<List<Point<int>>> snakes) {
    // Iterate to a fixpoint: each merged orphan becomes that snake's new
    // tail, which can make a neighbouring orphan mergeable in a later sweep
    // (orphans on jagged mask edges often come in chains).
    var changed = true;
    while (changed) {
      changed = false;
      for (var i = snakes.length - 1; i >= 0; i--) {
        if (snakes[i].length >= 2) continue;
        final c = snakes[i].first;
        var merged = false;
        for (var pass = 0; pass < 2 && !merged; pass++) {
          final lo = pass == 0 ? i + 1 : 0;
          final hi = pass == 0 ? snakes.length : i;
          for (var j = lo; j < hi; j++) {
            final t = snakes[j];
            // Orphan directly ABOVE a snake's head: append as the new head.
            // (Safe: any arrow whose ray passes through the orphan's cell
            // also passes through this snake's old head, so it already
            // waits for this snake — which now clears no later than before.)
            final head = t.last;
            if (t.length >= 2 && head.x == c.x && head.y == c.y + 1) {
              t.add(c);
              merged = true;
              break;
            }
            final tail = t.first;
            if ((tail.x - c.x).abs() + (tail.y - c.y).abs() != 1) continue;
            // Merging into another orphan builds a 2-cell arrow from
            // scratch: only allowed when the pair forms a valid upward
            // (exit-direction) shaft — never a shaft lying perpendicular
            // to its own head.
            if (t.length == 1 && !(tail.x == c.x && tail.y == c.y - 1)) {
              continue;
            }
            t.insert(0, c);
            merged = true;
            break;
          }
        }
        if (merged) {
          snakes.removeAt(i);
          changed = true;
        }
      }
    }
    // Whatever is still a singleton now is a permanent hole.
    for (var i = snakes.length - 1; i >= 0; i--) {
      if (snakes[i].length < 2) {
        snakes.removeAt(i);
        holes++;
      }
    }
  }

  int _weightedIndex(SeededRandom rng, List<double> w) {
    var total = 0.0;
    for (final v in w) {
      total += v;
    }
    var r = rng.next() * total;
    for (var i = 0; i < w.length; i++) {
      r -= w[i];
      if (r <= 0) return i;
    }
    return w.length - 1;
  }

}
