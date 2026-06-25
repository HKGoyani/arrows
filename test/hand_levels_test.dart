import 'package:flutter_test/flutter_test.dart';
import 'package:arrows_game/hand_levels.dart';
import 'package:arrows_game/level_generator.dart';

void main() {
  final gen = LevelGenerator();

  test('hand-authored levels 1-5 have no overlaps and are solvable', () {
    for (var lvl = 1; lvl <= 5; lvl++) {
      final h = handLevel(lvl)!;
      final occ = <String, int>{};
      for (final a in h.arrows) {
        for (final c in a.cells) {
          expect(occ.containsKey(c), isFalse,
              reason: 'L$lvl cell $c overlaps');
          occ[c] = a.id;
        }
      }
      expect(gen.greedySolvable(h.arrows), isTrue, reason: 'L$lvl unsolvable');
    }
  });

  test('procedural levels stay solvable across the ramp', () {
    for (final lvl in [6, 8, 10, 15, 20, 35, 50]) {
      final g = gen.genLevel(lvl);
      expect(g.arrows, isNotEmpty, reason: 'L$lvl empty');
      expect(gen.greedySolvable(g.arrows), isTrue, reason: 'L$lvl unsolvable');
    }
  });
}
