import 'package:flutter_test/flutter_test.dart';
import 'package:arrows_game/level_generator.dart';
import 'package:arrows_game/models.dart';

/// Guards the _packFill direction-rebalance pass: regular L100+ and daily
/// boards must not be dominated by one direction (the engine's raw output
/// leaned 40-55% DOWN before rebalancing).
void main() {
  test('no direction dominates regular L100+ / daily boards', () {
    final gen = LevelGenerator();
    double maxFracOf(int lvl, {bool daily = false}) {
      final l = gen.genLevel(lvl, daily: daily);
      final cnt = {for (final d in Direction.values) d: 0};
      var tot = 0;
      for (final a in l.arrows) {
        cnt[a.dir] = cnt[a.dir]! + a.pts.length;
        tot += a.pts.length;
      }
      final maxFrac =
          cnt.values.map((v) => v / tot).reduce((a, b) => a > b ? a : b);
      // ignore: avoid_print
      print('${daily ? "daily" : "reg"} L$lvl ${l.cols}x${l.rows}: '
          'u=${(cnt[Direction.up]! / tot * 100).round()}% '
          'd=${(cnt[Direction.down]! / tot * 100).round()}% '
          'l=${(cnt[Direction.left]! / tot * 100).round()}% '
          'r=${(cnt[Direction.right]! / tot * 100).round()}%');
      return maxFrac;
    }

    for (final lv in [105, 110, 130, 150, 170]) {
      expect(maxFracOf(lv), lessThan(0.42), reason: 'reg L$lv too skewed');
    }
    for (final lv in [40, 43, 55, 61, 76, 90]) {
      expect(maxFracOf(lv, daily: true), lessThan(0.42),
          reason: 'daily L$lv too skewed');
    }
  });
}
