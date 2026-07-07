/// Core data model for the arrow escape puzzle.
///
/// Coordinate system: `row` increases downward, `col` increases rightward.
/// Cell (0,0) is the top-left corner.
library;

/// A single grid coordinate.
class Cell {
  final int row;
  final int col;

  const Cell(this.row, this.col);

  Cell step(Direction d) => Cell(row + d.dRow, col + d.dCol);

  @override
  bool operator ==(Object other) =>
      other is Cell && other.row == row && other.col == col;

  @override
  int get hashCode => row * 92821 + col;

  @override
  String toString() => '($row,$col)';
}

/// The four orthogonal directions. `dRow`/`dCol` give the unit step.
enum Direction {
  up(-1, 0),
  down(1, 0),
  left(0, -1),
  right(0, 1);

  final int dRow;
  final int dCol;
  const Direction(this.dRow, this.dCol);

  Direction get opposite => switch (this) {
        Direction.up => Direction.down,
        Direction.down => Direction.up,
        Direction.left => Direction.right,
        Direction.right => Direction.left,
      };

  static const List<Direction> all = [
    Direction.up,
    Direction.down,
    Direction.left,
    Direction.right,
  ];
}

/// A single continuous orthogonal path.
///
/// [cells] is ordered from tail (index 0) to head (last index). The arrowhead
/// sits on the head cell and points in [headDir] — the direction the path
/// "reels out" toward the board edge when removed.

class ArrowPath {
  final int id;
  final List<Cell> cells;
  final Direction headDir;

  const ArrowPath({
    required this.id,
    required this.cells,
    required this.headDir,
  });

  Cell get head => cells.last;
  Cell get tail => cells.first;
  int get length => cells.length;
}

/// A fully generated, solvable board.

class Board {
  final int rows;
  final int cols;
  final List<ArrowPath> paths;

  /// A valid order in which paths can be removed (by path id), from first to
  /// last. Produced by the solver.
  final List<int> solveOrder;

  const Board({
    required this.rows,
    required this.cols,
    required this.paths,
    required this.solveOrder,
  });

  int get occupiedCells =>
      paths.fold(0, (sum, p) => sum + p.cells.length);

  double get occupancy => occupiedCells / (rows * cols);
}
