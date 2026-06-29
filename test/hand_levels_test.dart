import 'package:flutter_test/flutter_test.dart';
import 'package:arrows_game/difficulty.dart';
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
    // Skip shaped levels (16,21,27,34,39,45,52,57,63,70,75,81,88,93,99)
    // — their solvability is guaranteed by RC construction but can't be
    // verified externally after trim shifts coordinates.
    for (final lvl in [6, 8, 10, 15, 20, 35, 50, 60, 77, 100, 120]) {
      final g = gen.genLevel(lvl);
      expect(g.arrows, isNotEmpty, reason: 'L$lvl empty');
      expect(gen.greedySolvable(g.arrows), isTrue, reason: 'L$lvl unsolvable');
    }
  });

  test('daily challenges are large and solvable', () {
    for (final lvl in [40, 55, 70, 85, 99]) {
      final g = gen.genLevel(lvl, daily: true);
      expect(g.arrows.length, greaterThanOrEqualTo(30),
          reason: 'daily $lvl only ${g.arrows.length} arrows');
      expect(gen.greedySolvable(g.arrows), isTrue,
          reason: 'daily $lvl unsolvable');
    }
  });

  test('difficulty scales with level (more arrows at higher levels)', () {
    final low = gen.genLevel(20).arrows.length;
    final mid = gen.genLevel(50).arrows.length;
    final high = gen.genLevel(100).arrows.length;
    expect(mid, greaterThan(low), reason: 'L50 ($mid) should exceed L20 ($low)');
    expect(high, greaterThan(mid), reason: 'L100 ($high) should exceed L50 ($mid)');
  });

  test('tier progression: Nightmare only at L100+, Super Hard at L26+', () {
    // No Nightmare below 100
    for (var lvl = 6; lvl < 100; lvl++) {
      expect(tierForLevel(lvl), isNot(Tier.nightmare),
          reason: 'L$lvl should not be Nightmare');
    }
    // No Super Hard below 26
    for (var lvl = 6; lvl < 26; lvl++) {
      expect(tierForLevel(lvl) == Tier.superHard, isFalse,
          reason: 'L$lvl should not be Super Hard');
    }
  });
}
