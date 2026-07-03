import 'package:flutter_test/flutter_test.dart';
import 'package:arrows_game/level_generator.dart';
import 'package:arrows_game/difficulty.dart';

void main() {
  test('daily gravity sweep: solvable, filled, fast', () {
    final gen = LevelGenerator();
    var worstMs = 0, maxHoles = 0, unsolvable = 0;
    final tierCount = <String, int>{};
    // dailyLevelFor maps date→ 40..99; sweep the whole 60-day cycle.
    for (var lv = 40; lv <= 99; lv++) {
      final tier = dailyTier(lv);
      tierCount[tier.name] = (tierCount[tier.name] ?? 0) + 1;
      final sw = Stopwatch()..start();
      final lvl = gen.genLevel(lv, daily: true);
      sw.stop();
      if (sw.elapsedMilliseconds > worstMs) worstMs = sw.elapsedMilliseconds;
      final cells = lvl.arrows.fold<int>(0, (s, a) => s + a.cells.length);
      final holes = (lvl.cols + 1) * (lvl.rows + 1) - cells;
      if (holes > maxHoles) maxHoles = holes;
      if (!gen.greedySolvable(lvl.arrows)) unsolvable++;
      for (final a in lvl.arrows) {
        final h = a.pts.last, p = a.pts[a.pts.length - 2];
        expect('${h.x - p.x},${h.y - p.y}', '${a.dir.dx},${a.dir.dy}',
            reason: 'daily lv$lv arrow head misaligned');
        expect(a.pts.length, greaterThanOrEqualTo(2));
      }
      if (lv <= 45 || lv >= 96) {
        // ignore: avoid_print
        print('lv$lv ${tier.name}: ${lvl.cols}x${lvl.rows} '
            'arrows=${lvl.arrows.length} holes=$holes ${sw.elapsedMilliseconds}ms');
      }
    }
    // ignore: avoid_print
    print('SWEEP: worst=${worstMs}ms maxHoles=$maxHoles unsolvable=$unsolvable '
        'tiers=$tierCount');
    expect(unsolvable, 0);
  });
}
