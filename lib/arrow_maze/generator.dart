/// Procedural generator for arrow escape boards.
///
/// Strategy — "reverse peel" (generate from the solution):
///
///   Paths are placed one at a time. When a path is added, its head cell and
///   arrow direction are chosen so the runway from the head to the border is
///   *currently* empty. The path's tail is then grown backward with a winding,
///   self-avoiding walk that never re-enters its own runway.
///
///   Because each path's runway is clear of every *earlier-placed* path, and a
///   path only needs its runway clear of paths removed *after* it, the order
///   "reverse of placement" is always a valid solution. Every board is therefore
///   solvable by construction; [Solver] independently confirms it.
///
///   The winding growth (Warnsdorff-biased so it fills tight pockets and rarely
///   strands holes) produces maze-like corridors of varied length and heavy
///   turning — matching the reference look — rather than rigid parallel lanes.
///   Every path is at least two cells long, so every arrowhead has a visible
///   stem (no lone floating heads).
library;

import 'dart:math';

import 'model.dart';
import 'solver.dart';

class GenConfig {
  final int rows;
  final int cols;

  const GenConfig({required this.rows, required this.cols});
}

class PuzzleGenerator {
  final GenConfig config;

  PuzzleGenerator(this.config);

  int get rows => config.rows;
  int get cols => config.cols;

  bool _inBounds(int r, int c) => r >= 0 && r < rows && c >= 0 && c < cols;

  /// Generates a solvable board deterministically from [seed].
  Board generate(int seed) {
    for (var attempt = 0; attempt < 8; attempt++) {
      final rng = Random(seed + attempt * 1000003);
      final paths = _buildOnce(rng);
      final result = Solver(rows: rows, cols: cols).solve(paths);
      if (result.solved) {
        return Board(
          rows: rows,
          cols: cols,
          paths: paths,
          solveOrder: result.order,
        );
      }
    }
    throw StateError('Failed to generate a solvable board for seed $seed');
  }

  List<ArrowPath> _buildOnce(Random rng) {
    final occupied = List.generate(rows, (_) => List.filled(cols, false));
    final paths = <ArrowPath>[];

    // Alternate two moves until neither makes progress:
    //   • place new winding corridors wherever a head still has a clear runway
    //     (the maze-like reference variety), and
    //   • extend existing tails into leftover cells (densification).
    // Extending frees up fresh pockets that a later placement pass can seed,
    // and vice-versa, so iterating squeezes out more occupancy than one pass.
    // Running tally of how many arrowheads point each way, so new heads can
    // prefer under-used directions and avoid a board where one direction
    // dominates or is missing (common on small boards).
    final dirCount = List.filled(4, 0);

    while (true) {
      var placedAny = false;
      while (true) {
        final path = _tryPlacePath(rng, occupied, paths.length, dirCount);
        if (path == null) break;
        _commit(occupied, paths, path);
        dirCount[path.headDir.index]++;
        placedAny = true;
      }
      final extendedAny = _extendTails(rng, occupied, paths);
      if (!placedAny && !extendedAny) break;
    }

    // Final densification: grow heads (toward the edge / into runway pockets)
    // and tails into any remaining blank cell, as long as the solver still
    // clears the board. This goes beyond the fast id rule by letting the solver
    // discover *any* working order. Only heads/tails grow, so every arrowhead
    // stays a collinear cap on its own corridor.
    _densifyVerified(rng, occupied, paths);

    // Absorb the enclosed pockets that extension can't reach by detouring a
    // path through them, then densify once more over anything newly exposed.
    _reroutePockets(occupied, paths);
    _densifyVerified(rng, occupied, paths);
    return paths;
  }

  /// Absorbs enclosed blank pockets by "bumping" a path's middle edge out into
  /// an adjacent pair of blank cells: a segment u→v is rerouted
  /// u→u+perp→v+perp→v, swallowing the two blank cells. Only the *middle* of a
  /// path changes (never the head edge or the tail), so the single collinear
  /// arrowhead is preserved. Every bump is solver-verified. Runs to a fixpoint.
  void _reroutePockets(List<List<bool>> occupied, List<ArrowPath> paths) {
    final solver = Solver(rows: rows, cols: cols);
    var changed = true;
    while (changed) {
      changed = false;
      for (final p in paths) {
        // Stop before the final edge (into the head) to keep the arrow collinear.
        var i = 0;
        while (i + 2 < p.cells.length) {
          final u = p.cells[i], v = p.cells[i + 1];
          final dr = v.row - u.row, dc = v.col - u.col;
          var bumped = false;
          for (final (pr, pc) in [(-dc, dr), (dc, -dr)]) {
            final up = Cell(u.row + pr, u.col + pc);
            final vp = Cell(v.row + pr, v.col + pc);
            if (!_inBounds(up.row, up.col) || occupied[up.row][up.col]) continue;
            if (!_inBounds(vp.row, vp.col) || occupied[vp.row][vp.col]) continue;
            p.cells.insertAll(i + 1, [up, vp]);
            occupied[up.row][up.col] = true;
            occupied[vp.row][vp.col] = true;
            if (solver.solve(paths).solved) {
              changed = true;
              bumped = true;
              break;
            }
            p.cells.removeRange(i + 1, i + 3);
            occupied[up.row][up.col] = false;
            occupied[vp.row][vp.col] = false;
          }
          // Advance past this (possibly newly inserted) segment.
          i += bumped ? 3 : 1;
        }
      }
    }
  }

  /// Repeatedly grows every path's tail into an adjacent empty cell until none
  /// can grow, filling shadowed pockets and reserved lanes as densely as the
  /// solvability guarantee allows.
  ///
  /// A path Q may extend into cell X only if every path whose *current clear
  /// runway* covers X is removed after Q — i.e. has a smaller id (ids follow
  /// placement order; removal order is its reverse). Then, by the time such a
  /// path needs its runway, Q is already gone and X is free again. This only
  /// ever adds "Q removed before R" constraints that the existing reverse-
  /// placement order already satisfies, so the board stays solvable without any
  /// re-solve. Warnsdorff-biased to clear tight spots first.
  bool _extendTails(
      Random rng, List<List<bool>> occupied, List<ArrowPath> paths) {
    // Head lookup (heads never move while only tails grow).
    final headId = List.generate(rows, (_) => List.filled(cols, -1));
    final headDir =
        List.generate(rows, (_) => List<Direction?>.filled(cols, null));
    for (final p in paths) {
      headId[p.head.row][p.head.col] = p.id;
      headDir[p.head.row][p.head.col] = p.headDir;
    }

    // Max id of a path whose clear runway currently covers X, or -1 if none.
    int maxRunwayOwner(Cell x) {
      var m = -1;
      for (final d in Direction.all) {
        var r = x.row + d.dRow;
        var c = x.col + d.dCol;
        while (_inBounds(r, c) && !occupied[r][c]) {
          r += d.dRow;
          c += d.dCol;
        }
        if (_inBounds(r, c) &&
            headId[r][c] != -1 &&
            headDir[r][c] == d.opposite) {
          if (headId[r][c] > m) m = headId[r][c];
        }
      }
      return m;
    }

    bool safeFor(int id, Cell c) =>
        _inBounds(c.row, c.col) &&
        !occupied[c.row][c.col] &&
        maxRunwayOwner(c) < id;

    var addedAny = false;
    var progressed = true;
    while (progressed) {
      progressed = false;
      for (final p in paths) {
        final tail = p.cells.first;
        final opts = [
          for (final d in Direction.all)
            if (safeFor(p.id, tail.step(d))) tail.step(d),
        ];
        if (opts.isEmpty) continue;

        // Prefer the neighbour with the fewest onward empty cells (fill pockets
        // first, avoid stranding).
        opts.shuffle(rng);
        var best = opts.first;
        var bestOnward = 1 << 30;
        for (final nc in opts) {
          final onward = Direction.all
              .where((d) => _inBounds(nc.step(d).row, nc.step(d).col))
              .where((d) => !occupied[nc.step(d).row][nc.step(d).col])
              .length;
          if (onward < bestOnward) {
            bestOnward = onward;
            best = nc;
          }
        }
        p.cells.insert(0, best);
        occupied[best.row][best.col] = true;
        progressed = true;
        addedAny = true;
      }
    }
    return addedAny;
  }

  /// Grows paths into remaining blank cells, keeping each growth only if the
  /// solver confirms the whole board is still 100% clearable. Two moves:
  ///
  ///  • **Head extension** — push the arrowhead forward along its own direction
  ///    into its runway, so arrows reach the board edge (or fill runway pockets)
  ///    instead of stopping short. Stays collinear (same direction, head just
  ///    slides out).
  ///  • **Tail extension** — grow the tail into any blank neighbour.
  ///
  /// Both are solver-verified, so occupancy is pushed to the practical maximum
  /// without ever risking solvability. Runs to a fixpoint.
  bool _densifyVerified(
      Random rng, List<List<bool>> occupied, List<ArrowPath> paths) {
    final solver = Solver(rows: rows, cols: cols);
    var anyChange = false;
    var changed = true;
    while (changed) {
      changed = false;
      for (final p in paths) {
        // Head extension along the escape direction (reach the edge / fill the
        // runway). Repeats within the round while it keeps succeeding.
        while (true) {
          final hnext = p.head.step(p.headDir);
          if (!_inBounds(hnext.row, hnext.col) ||
              occupied[hnext.row][hnext.col]) {
            break;
          }
          p.cells.add(hnext);
          occupied[hnext.row][hnext.col] = true;
          if (solver.solve(paths).solved) {
            changed = true;
            anyChange = true;
          } else {
            p.cells.removeLast();
            occupied[hnext.row][hnext.col] = false;
            break;
          }
        }

        // Tail extension into any blank neighbour.
        final tail = p.cells.first;
        final neighbours = [for (final d in Direction.all) tail.step(d)]
          ..shuffle(rng);
        for (final nc in neighbours) {
          if (!_inBounds(nc.row, nc.col) || occupied[nc.row][nc.col]) continue;
          p.cells.insert(0, nc);
          occupied[nc.row][nc.col] = true;
          if (solver.solve(paths).solved) {
            changed = true;
            anyChange = true;
            break;
          }
          p.cells.removeAt(0);
          occupied[nc.row][nc.col] = false;
        }
      }
    }
    return anyChange;
  }

  void _commit(
      List<List<bool>> occupied, List<ArrowPath> paths, ArrowPath path) {
    for (final c in path.cells) {
      occupied[c.row][c.col] = true;
    }
    paths.add(path);
  }

  /// Attempts to place one winding path (length >= 2). Returns null when no
  /// empty cell can host a valid head+stem anymore.
  ArrowPath? _tryPlacePath(
      Random rng, List<List<bool>> occupied, int id, List<int> dirCount) {
    final empties = <Cell>[];
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (!occupied[r][c]) empties.add(Cell(r, c));
      }
    }
    empties.shuffle(rng);

    for (final head in empties) {
      // Candidate clear-runway directions, ordered by (1) least-used direction
      // so far — to keep all four directions balanced — then (2) shortest lane,
      // which keeps reserved whitespace small. Density is recovered later by the
      // densify + re-route passes, so favouring balance here is safe.
      final candidates = <(Direction, Set<Cell>)>[];
      for (final dir in Direction.all) {
        final runway = _runwayCells(occupied, head.row, head.col, dir);
        if (runway != null) candidates.add((dir, runway));
      }
      candidates.shuffle(rng); // random tie-break
      candidates.sort((a, b) {
        final ca = dirCount[a.$1.index], cb = dirCount[b.$1.index];
        if (ca != cb) return ca.compareTo(cb); // prefer under-used direction
        return a.$2.length.compareTo(b.$2.length); // then shortest runway
      });

      for (final (dir, runway) in candidates) {
        final body = _growTail(
          rng: rng,
          occupied: occupied,
          head: head,
          headDir: dir,
          runway: runway,
          targetLen: _pickLength(rng),
        );
        if (body.length < 2) continue; // no stem — try another option
        return ArrowPath(id: id, cells: body.reversed.toList(), headDir: dir);
      }
    }
    return null;
  }

  /// Cells from just beyond the head to the border in [dir], or null if any is
  /// occupied. This set is the path's escape lane and is off-limits to its body.
  Set<Cell>? _runwayCells(
      List<List<bool>> occupied, int hr, int hc, Direction dir) {
    final cells = <Cell>{};
    var r = hr + dir.dRow;
    var c = hc + dir.dCol;
    while (_inBounds(r, c)) {
      if (occupied[r][c]) return null;
      cells.add(Cell(r, c));
      r += dir.dRow;
      c += dir.dCol;
    }
    return cells;
  }

  /// Grows the body backward from the head with a winding, self-avoiding walk.
  /// Returned head-first.
  ///
  /// The first body cell is forced to sit directly *behind* the head (opposite
  /// the escape direction), so the segment entering the head is collinear with
  /// the arrow — the corridor runs straight into the arrowhead, as in the
  /// reference art. If that cell is unavailable the path is rejected (returns a
  /// single cell) and the caller tries another head/direction.
  List<Cell> _growTail({
    required Random rng,
    required List<List<bool>> occupied,
    required Cell head,
    required Direction headDir,
    required Set<Cell> runway,
    required int targetLen,
  }) {
    final body = <Cell>[head];
    final inPath = <Cell>{head};

    bool usable(Cell c) =>
        _inBounds(c.row, c.col) &&
        !occupied[c.row][c.col] &&
        !inPath.contains(c) &&
        !runway.contains(c);

    int onwardCount(Cell from, Direction cameFrom) {
      var n = 0;
      for (final d in Direction.all) {
        if (d == cameFrom.opposite) continue;
        if (usable(from.step(d))) n++;
      }
      return n;
    }

    // Mandatory straight stub into the arrowhead.
    final behind = head.step(headDir.opposite);
    if (!usable(behind)) return body; // length 1 -> caller rejects
    body.add(behind);
    inPath.add(behind);
    Direction? lastDir = headDir.opposite;

    var cur = behind;
    while (body.length < targetLen) {
      final options = <Direction>[];
      for (final d in Direction.all) {
        if (lastDir != null && d == lastDir.opposite) continue;
        if (usable(cur.step(d))) options.add(d);
      }
      if (options.isEmpty) break;

      final chosen = _chooseGrowthDir(rng, cur, options, lastDir, onwardCount);
      cur = cur.step(chosen);
      body.add(cur);
      inPath.add(cur);
      lastDir = chosen;
    }
    return body;
  }

  Direction _chooseGrowthDir(
    Random rng,
    Cell cur,
    List<Direction> options,
    Direction? lastDir,
    int Function(Cell, Direction) onwardCount,
  ) {
    // Winding bias: keep going straight a bit more often than turning, so
    // corridors read as maze-like rather than jagged, but still turn plenty.
    double windWeight(Direction d) {
      if (lastDir == null) return 1.0;
      return d == lastDir ? 1.8 : 1.0;
    }

    // Compactness (Warnsdorff): prefer moves into cells with fewer onward
    // options, so tight pockets are cleared first and holes rarely strand.
    double compactWeight(Direction d) {
      final onward = onwardCount(cur.step(d), d);
      var w = 1.0;
      for (var i = 0; i < onward; i++) {
        w *= 0.28;
      }
      return w;
    }

    final weights = [for (final d in options) windWeight(d) * compactWeight(d)];
    final total = weights.fold(0.0, (a, b) => a + b);
    var pick = rng.nextDouble() * total;
    for (var i = 0; i < options.length; i++) {
      pick -= weights[i];
      if (pick <= 0) return options[i];
    }
    return options.last;
  }

  /// Target path length — a spread of short, medium and long corridors. Skewed
  /// enough toward longer winding paths that boards fill densely (long tails mop
  /// up shadowed pockets) while still producing many short/medium corridors.
  int _pickLength(Random rng) {
    final roll = rng.nextDouble();
    if (roll < 0.22) return 2 + rng.nextInt(3); // short 2..4
    if (roll < 0.52) return 5 + rng.nextInt(8); // medium 5..12
    if (roll < 0.80) return 13 + rng.nextInt(13); // long 13..25
    return 26 + rng.nextInt(25); // highway 26..50
  }
}
