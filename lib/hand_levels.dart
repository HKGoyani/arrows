import 'dart:math';
import 'models.dart';

/// Hand-authored levels for the onboarding stretch (1–5), matching the
/// reference game's gentle ramp. Level 1 is the tutorial board.
///
/// Each level lists arrows as cell-by-cell paths (tail → head); the head
/// points in [dir] and exits the grid that way. The generator validates
/// every board with its greedy solver and falls back to procedural
/// generation if (somehow) a board isn't solvable, so nothing broken ships.

/// Marks which level is the guided tutorial (shows "Tap to move").
const int tutorialLevel = 1;

class HandLevel {
  final int cols, rows;
  final List<Arrow> arrows;
  const HandLevel(this.cols, this.rows, this.arrows);
}

/// Builds a straight-line cell path between two cells (inclusive).
List<Point<int>> _line(int x0, int y0, int x1, int y1) {
  final pts = <Point<int>>[];
  final dx = (x1 - x0).sign;
  final dy = (y1 - y0).sign;
  var x = x0, y = y0;
  pts.add(Point(x, y));
  while (x != x1 || y != y1) {
    x += dx;
    y += dy;
    pts.add(Point(x, y));
  }
  return pts;
}

/// Joins several straight segments into one polyline path (shared corner
/// cells are de-duplicated). The last segment determines the head direction.
List<Point<int>> _path(List<List<int>> corners) {
  final pts = <Point<int>>[];
  for (var i = 0; i < corners.length - 1; i++) {
    final seg = _line(corners[i][0], corners[i][1],
        corners[i + 1][0], corners[i + 1][1]);
    for (final p in seg) {
      if (pts.isNotEmpty && pts.last == p) continue; // skip shared corner
      pts.add(p);
    }
  }
  return pts;
}

Arrow _arrow(int id, List<Point<int>> path, Direction dir) {
  return Arrow(
    id: id,
    pts: path,
    dir: dir,
    cells: {for (final p in path) cellKey(p.x, p.y)},
  );
}

/// Returns the hand-authored board for [level], or null if none.
HandLevel? handLevel(int level) {
  switch (level) {
    case 1:
      // Tutorial: three tall vertical up-arrows, evenly spaced. All can
      // exit immediately — the player just learns the tap-to-fire gesture.
      return HandLevel(6, 8, [
        _arrow(0, _line(1, 6, 1, 2), Direction.up),
        _arrow(1, _line(3, 6, 3, 2), Direction.up),
        _arrow(2, _line(5, 6, 5, 2), Direction.up),
      ]);

    case 2:
      // Three straights; clear the top → then the up-arrow can exit.
      return HandLevel(6, 7, [
        _arrow(0, _line(1, 1, 4, 1), Direction.right), // → top, exits right
        _arrow(1, _line(2, 5, 2, 3), Direction.up),    // ↑ blocked by row 1
        _arrow(2, _line(4, 3, 4, 5), Direction.down),  // ↓ exits down
      ]);

    case 3:
      return HandLevel(6, 8, [
        _arrow(0, _line(1, 1, 4, 1), Direction.right),       // → top
        _arrow(1, _line(0, 3, 0, 6), Direction.down),        // ↓ left edge
        _arrow(2, _path([[2, 3], [2, 5]]), Direction.down),  // ↓ mid
        _arrow(3, _path([[5, 4], [3, 4]]), Direction.left),  // ← right
      ]);

    case 4:
      return HandLevel(6, 9, [
        _arrow(0, _line(1, 1, 5, 1), Direction.right),       // → top
        _arrow(1, _path([[1, 3], [1, 2]]), Direction.up),    // ↑
        _arrow(2, _path([[3, 3], [3, 6]]), Direction.down),  // ↓
        _arrow(3, _path([[5, 4], [5, 3]]), Direction.up),    // ↑
        _arrow(4, _path([[2, 7], [5, 7]]), Direction.right), // → bottom
      ]);

    case 5:
      return HandLevel(7, 9, [
        _arrow(0, _line(1, 1, 6, 1), Direction.right),       // → top
        _arrow(1, _path([[0, 3], [0, 6]]), Direction.down),  // ↓ left edge
        _arrow(2, _path([[2, 3], [2, 2]]), Direction.up),    // ↑
        _arrow(3, _path([[4, 3], [4, 6]]), Direction.down),  // ↓
        _arrow(4, _path([[6, 4], [6, 3]]), Direction.up),    // ↑
        _arrow(5, _path([[2, 8], [6, 8]]), Direction.right), // → bottom
      ]);
  }
  return null;
}
