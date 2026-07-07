/// Solver / validator for arrow escape boards.
///
/// A path is removable when its "runway" — the straight line of cells from just
/// beyond the head, in the arrow direction, to the board edge — is free of every
/// other remaining path. Removing a path only frees cells, so it can never make
/// another path un-removable. That monotonicity means greedy peeling is
/// *complete*: the board is solvable iff repeatedly removing any removable path
/// clears the whole board. A stuck state with paths remaining is a genuine
/// deadlock.
library;

import 'model.dart';

class SolveResult {
  /// Path ids in a valid removal order (first to last), or the partial order
  /// reached before getting stuck.
  final List<int> order;

  /// True iff every path was removed.
  final bool solved;

  /// Ids of paths that could not be removed (empty when [solved]).
  final List<int> stuck;

  const SolveResult({
    required this.order,
    required this.solved,
    required this.stuck,
  });
}

class Solver {
  final int rows;
  final int cols;

  Solver({required this.rows, required this.cols});

  bool _inBounds(int r, int c) => r >= 0 && r < rows && c >= 0 && c < cols;

  /// Greedily peels paths until none are removable.
  SolveResult solve(List<ArrowPath> paths) {
    // grid[r][c] = id of the path occupying it, or -1.
    final grid = List.generate(rows, (_) => List.filled(cols, -1));
    final byId = <int, ArrowPath>{};
    for (final p in paths) {
      byId[p.id] = p;
      for (final cell in p.cells) {
        grid[cell.row][cell.col] = p.id;
      }
    }

    final removed = <int>{};
    final order = <int>[];

    bool runwayClear(ArrowPath p) {
      var r = p.head.row + p.headDir.dRow;
      var c = p.head.col + p.headDir.dCol;
      while (_inBounds(r, c)) {
        final occupant = grid[r][c];
        // Clear unless a *different* still-present path sits here.
        if (occupant != -1 && occupant != p.id && !removed.contains(occupant)) {
          return false;
        }
        r += p.headDir.dRow;
        c += p.headDir.dCol;
      }
      return true;
    }

    var progress = true;
    while (progress && removed.length < paths.length) {
      progress = false;
      for (final p in paths) {
        if (removed.contains(p.id)) continue;
        if (runwayClear(p)) {
          removed.add(p.id);
          order.add(p.id);
          for (final cell in p.cells) {
            grid[cell.row][cell.col] = -1;
          }
          progress = true;
        }
      }
    }

    final stuck = [
      for (final p in paths)
        if (!removed.contains(p.id)) p.id,
    ];
    return SolveResult(order: order, solved: stuck.isEmpty, stuck: stuck);
  }
}

/// Structural validation independent of the solver: checks the invariants in
/// the spec's validation checklist that don't require simulation.
class BoardValidation {
  final bool ok;
  final List<String> errors;
  const BoardValidation(this.ok, this.errors);
}

BoardValidation validateStructure(Board board) {
  final errors = <String>[];
  final owner = List.generate(board.rows, (_) => List.filled(board.cols, -1));

  for (final p in board.paths) {
    if (p.cells.isEmpty) {
      errors.add('Path ${p.id} is empty.');
      continue;
    }
    // Bounds + overlap.
    for (final c in p.cells) {
      if (c.row < 0 || c.row >= board.rows || c.col < 0 || c.col >= board.cols) {
        errors.add('Path ${p.id} leaves the board at $c.');
        continue;
      }
      if (owner[c.row][c.col] != -1) {
        errors.add(
            'Cell $c shared by paths ${owner[c.row][c.col]} and ${p.id}.');
      }
      owner[c.row][c.col] = p.id;
    }
    // Continuity + no immediate self-touch beyond the polyline order is
    // checked via adjacency and uniqueness.
    final seen = <Cell>{};
    for (var i = 0; i < p.cells.length; i++) {
      if (!seen.add(p.cells[i])) {
        errors.add('Path ${p.id} self-intersects at ${p.cells[i]}.');
      }
      if (i > 0) {
        final a = p.cells[i - 1];
        final b = p.cells[i];
        final manhattan = (a.row - b.row).abs() + (a.col - b.col).abs();
        if (manhattan != 1) {
          errors.add('Path ${p.id} is not continuous between $a and $b.');
        }
      }
    }
  }

  return BoardValidation(errors.isEmpty, errors);
}
