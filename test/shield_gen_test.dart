import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:arrows_game/level_generator.dart';
import 'package:arrows_game/models.dart';

const _gravityLevels = {
  104: 'shield',
  112: 'teardrop',
  120: 'kite',
  128: 'house',
  136: 'egg',
  144: 'dome',
  152: 'arrow',
  160: 'crown',
  168: 'tree',
};

void main() {
  test('L100+ gravity shapes: solvable, aligned heads, fast', () {
    final gen = LevelGenerator();

    for (final entry in _gravityLevels.entries) {
      final level = entry.key, shape = entry.value;
      final sw = Stopwatch()..start();
      final lvl = gen.genLevel(level);
      sw.stop();

      final cells = lvl.arrows.fold<int>(0, (s, a) => s + a.cells.length);
      var minLen = 999, maxLen = 0, totLen = 0, bent = 0;
      final dirs = <Direction, int>{};
      for (final a in lvl.arrows) {
        minLen = min(minLen, a.pts.length);
        maxLen = max(maxLen, a.pts.length);
        totLen += a.pts.length;
        dirs[a.dir] = (dirs[a.dir] ?? 0) + 1;
        for (var i = 2; i < a.pts.length; i++) {
          if (a.pts[i].x - a.pts[i - 1].x != a.pts[i - 1].x - a.pts[i - 2].x ||
              a.pts[i].y - a.pts[i - 1].y != a.pts[i - 1].y - a.pts[i - 2].y) {
            bent++;
            break;
          }
        }
      }

      // ignore: avoid_print
      print('L$level $shape: ${lvl.cols}x${lvl.rows} '
          'arrows=${lvl.arrows.length} cells=$cells '
          'len $minLen-$maxLen avg=${(totLen / lvl.arrows.length).toStringAsFixed(1)} '
          'bent=${(bent / lvl.arrows.length * 100).round()}% '
          'dirs={u:${dirs[Direction.up] ?? 0} d:${dirs[Direction.down] ?? 0} '
          'l:${dirs[Direction.left] ?? 0} r:${dirs[Direction.right] ?? 0}} '
          'time=${sw.elapsedMilliseconds}ms');
      // ignore: avoid_print
      print(_ascii(lvl));

      expect(gen.greedySolvable(lvl.arrows), isTrue,
          reason: 'L$level $shape not solvable');
      expect(minLen, greaterThanOrEqualTo(2),
          reason: 'L$level $shape has a 1-cell arrow');
      // Every arrow's final shaft segment must run in its fire direction —
      // the head may never sit rotated against its own body.
      for (final a in lvl.arrows) {
        final h = a.pts.last, p = a.pts[a.pts.length - 2];
        expect('${h.x - p.x},${h.y - p.y}', '${a.dir.dx},${a.dir.dy}',
            reason: 'L$level $shape arrow ${a.id} last segment != dir');
      }
      // All four directions must be present (mixed-direction requirement).
      for (final d in Direction.values) {
        expect(dirs[d] ?? 0, greaterThan(0),
            reason: 'L$level $shape has no ${d.name} arrows');
      }
    }
  });
}

String _ascii(GeneratedLevel lvl) {
  final g = List.generate(lvl.rows + 1, (_) => List.filled(lvl.cols + 1, ' '));
  const heads = {
    Direction.up: '^',
    Direction.down: 'v',
    Direction.left: '<',
    Direction.right: '>'
  };
  for (final a in lvl.arrows) {
    for (var i = 0; i < a.pts.length; i++) {
      final p = a.pts[i];
      g[p.y][p.x] = i == a.pts.length - 1 ? heads[a.dir]! : '#';
    }
  }
  return g.map((r) => r.join()).join('\n');
}
