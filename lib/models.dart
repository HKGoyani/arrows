import 'dart:math';

enum Direction {
  up(0, -1),
  down(0, 1),
  left(-1, 0),
  right(1, 0);

  final int dx, dy;
  const Direction(this.dx, this.dy);

  bool get horizontal => dx != 0;
}

enum ArrowState { idle, leaving, clashed }

class Arrow {
  final int id;
  final List<Point<int>> pts; // grid points the path passes through
  final Direction dir; // head direction (last segment)
  final Set<String> cells; // occupied cell keys "x,y"
  ArrowState state;

  Arrow({
    required this.id,
    required this.pts,
    required this.dir,
    required this.cells,
    this.state = ArrowState.idle,
  });

  Point<int> get head => pts.last;
}

class GeneratedLevel {
  final List<Arrow> arrows;
  final int cols, rows;
  const GeneratedLevel(this.arrows, this.cols, this.rows);
}

String cellKey(int x, int y) => '$x,$y';
