import 'dart:math';
import 'package:flutter/foundation.dart';
import 'config.dart';
import 'models.dart';
import 'level_generator.dart';

enum GameStatus { playing, won, lost }

/// MVVM ViewModel: owns the game state + rules. Pure logic, no rendering.
/// Per-frame animations live in the View (GameScreen) and call back here.
class GameController extends ChangeNotifier {
  final LevelGenerator _gen = LevelGenerator();

  int level = 1;
  int cols = 9, rows = 11;
  List<Arrow> arrows = [];
  Map<String, int> occ = {};
  // Every cell any arrow occupies on the initial board. Dots are drawn only on
  // these "track" cells (revealed as arrows vacate them) — never in empty space.
  Set<String> trackCells = {};
  int hearts = 3;
  int total = 0;
  GameStatus status = GameStatus.playing;

  double get progress {
    if (total == 0) return 0;
    return (total - liveArrows.length) / total;
  }

  /// Arrows still on the board — excludes those mid-flight (already committed
  /// as fired). Used to snapshot/restore a daily challenge.
  List<Arrow> get liveArrows =>
      arrows.where((a) => a.state != ArrowState.leaving).toList();

  void loadLevel(int lvl, {bool daily = false}) {
    level = lvl;
    final g = _gen.genLevel(lvl, daily: daily);
    arrows = g.arrows;
    cols = g.cols;
    rows = g.rows;
    occ = {};
    trackCells = {};
    for (final a in arrows) {
      for (final c in a.cells) {
        occ[c] = a.id;
        trackCells.add(c);
      }
    }
    hearts = 3;
    total = arrows.length;
    status = GameStatus.playing;
    notifyListeners();
  }

  /// Restores a partly-played board: keeps only the [remainingIds] arrows
  /// (the rest are treated as already fired). [total] is left at the full
  /// count so the progress bar stays accurate. Call right after [loadLevel].
  void restoreState(Set<int> remainingIds, int savedHearts) {
    arrows.removeWhere((a) => !remainingIds.contains(a.id));
    occ = {};
    for (final a in arrows) {
      for (final c in a.cells) {
        occ[c] = a.id;
      }
    }
    hearts = savedHearts.clamp(1, 3);
    status = arrows.isEmpty ? GameStatus.won : GameStatus.playing;
    notifyListeners();
  }

  /// Is the arrow's forward path clear to the board edge?
  bool isClear(Arrow a) {
    var x = a.head.x, y = a.head.y;
    while (true) {
      x += a.dir.dx;
      y += a.dir.dy;
      if (x < 0 || x > cols || y < 0 || y > rows) return true;
      final o = occ[cellKey(x, y)];
      if (o != null && o != a.id) return false;
    }
  }

  /// Returns the first arrow blocking [a]'s exit path, or null.
  Arrow? findBlocker(Arrow a) {
    var x = a.head.x, y = a.head.y;
    while (true) {
      x += a.dir.dx;
      y += a.dir.dy;
      if (x < 0 || x > cols || y < 0 || y > rows) return null;
      final o = occ[cellKey(x, y)];
      if (o != null && o != a.id) {
        return arrows.where((ar) => ar.id == o).firstOrNull;
      }
    }
  }

  /// Hit-test in cell-unit coordinates (already divided by scale).
  Arrow? hitTest(double px, double py) {
    Arrow? best;
    var bestD = double.infinity;
    for (final a in arrows) {
      if (a.state == ArrowState.leaving) continue;
      final d = _distToPolyline(px, py, a.pts);
      if (d < bestD) {
        bestD = d;
        best = a;
      }
    }
    return (best != null && bestD <= Cfg.hitBand) ? best : null;
  }

  /// Fire: free the arrow's cells immediately so neighbours open up; the View
  /// animates it and calls [completeFire] when the snake has flown off.
  /// Multiple arrows may be in flight at once.
  void startFire(Arrow a) {
    a.state = ArrowState.leaving;
    for (final c in a.cells) {
      occ.remove(c);
    }
    notifyListeners();
  }

  void completeFire(Arrow a) {
    arrows.remove(a);
    if (arrows.isEmpty && status == GameStatus.playing) status = GameStatus.won;
    notifyListeners();
  }

  void addLife() {
    hearts = 1;
    status = GameStatus.playing;
    notifyListeners();
  }

  /// Clash: tapping a blocked arrow turns it red (stays red) and costs a life.
  void clash(Arrow a) {
    a.state = ArrowState.clashed;
    hearts = (hearts - 1).clamp(0, 3);
    if (hearts == 0) status = GameStatus.lost;
    notifyListeners();
  }
}

double _distToPolyline(double px, double py, List<Point<int>> pts) {
  double best = double.infinity;
  for (var i = 1; i < pts.length; i++) {
    final ax = Cfg.margin + pts[i - 1].x * Cfg.cell;
    final ay = Cfg.margin + pts[i - 1].y * Cfg.cell;
    final bx = Cfg.margin + pts[i].x * Cfg.cell;
    final by = Cfg.margin + pts[i].y * Cfg.cell;
    best = min(best, _distToSeg(px, py, ax, ay, bx, by));
  }
  return best;
}

double _distToSeg(double px, double py, double ax, double ay, double bx, double by) {
  final dx = bx - ax, dy = by - ay;
  final len2 = dx * dx + dy * dy;
  double t = len2 == 0 ? 0 : ((px - ax) * dx + (py - ay) * dy) / len2;
  t = t.clamp(0.0, 1.0);
  final cx = ax + t * dx, cy = ay + t * dy;
  return sqrt((px - cx) * (px - cx) + (py - cy) * (py - cy));
}
