import 'package:flutter_test/flutter_test.dart';
import 'package:arrows_game/level_generator.dart';
import 'package:arrows_game/models.dart';

void main() {
  test('L104 shield: gravity packer', () {
    final gen = LevelGenerator();

    for (var run = 0; run < 3; run++) {
      final sw = Stopwatch()..start();
      final lvl = gen.genLevel(104);
      sw.stop();
      final cells = lvl.arrows.fold<int>(0, (s, a) => s + a.cells.length);
      // ignore: avoid_print
      print('run $run: ${lvl.cols}x${lvl.rows} arrows=${lvl.arrows.length} '
          'cells=$cells solvable=${gen.greedySolvable(lvl.arrows)} '
          'time=${sw.elapsedMilliseconds}ms');
      expect(gen.greedySolvable(lvl.arrows), isTrue);
    }

    final lvl = gen.genLevel(104);
    final g =
        List.generate(lvl.rows + 1, (_) => List.filled(lvl.cols + 1, ' '));
    const heads = {
      Direction.up: '^',
      Direction.down: 'v',
      Direction.left: '<',
      Direction.right: '>'
    };
    var bent = 0, minLen = 999, maxLen = 0, totLen = 0;
    for (final a in lvl.arrows) {
      if (a.pts.length < minLen) minLen = a.pts.length;
      if (a.pts.length > maxLen) maxLen = a.pts.length;
      totLen = totLen + a.pts.length;
      var isBent = false;
      for (var i = 2; i < a.pts.length; i++) {
        if (a.pts[i].x - a.pts[i - 1].x != a.pts[i - 1].x - a.pts[i - 2].x ||
            a.pts[i].y - a.pts[i - 1].y != a.pts[i - 1].y - a.pts[i - 2].y) {
          isBent = true;
          break;
        }
      }
      if (isBent) bent++;
      for (var i = 0; i < a.pts.length; i++) {
        final p = a.pts[i];
        g[p.y][p.x] = i == a.pts.length - 1 ? heads[a.dir]! : '#';
      }
    }
    // ignore: avoid_print
    print('len min=$minLen max=$maxLen '
        'avg=${(totLen / lvl.arrows.length).toStringAsFixed(1)} '
        'bent=${(bent / lvl.arrows.length * 100).round()}%');
    for (final row in g) {
      // ignore: avoid_print
      print(row.join());
    }
    expect(minLen, greaterThanOrEqualTo(2));

    // Every arrow's final shaft segment must run in its fire direction —
    // the head may never sit rotated against its own body.
    for (final a in lvl.arrows) {
      final h = a.pts.last, p = a.pts[a.pts.length - 2];
      expect('${h.x - p.x},${h.y - p.y}', '${a.dir.dx},${a.dir.dy}',
          reason: 'arrow ${a.id} last segment != dir ${a.dir}');
    }
  });
}

