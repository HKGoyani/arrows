import 'package:flutter_test/flutter_test.dart';
import 'package:arrows_game/level_generator.dart';

/// An arrow fires by snaking along its own polyline plus a straight extension
/// from the head (see FlyOff.forArrow), so the head leaves in a straight line
/// while the body follows the bends behind it. That is only sound while the
/// body stays behind the head: if a wound arrow has its own cells sitting
/// ahead of the head on the exit ray, those cells clear via the long winding
/// route and the head visibly flies through its own tail.
///
/// greedySolvable deliberately ignores self-collision (`o != i`), which is
/// correct for solvability and silent about this. The invariant is not "no
/// hairpins" — most wound arrows are fine — it is that the straight exit ray
/// must never cross the arrow's own body.
///
/// Swept rather than sampled: this shipped broken in 140 of the first 250
/// levels, from level 38 on, and was caught by eye rather than by a test.
void main() {
  final gen = LevelGenerator();

  test('no arrow fires through its own body, levels 1..250', () {
    for (var lvl = 1; lvl <= 250; lvl++) {
      final level = gen.genLevel(lvl);
      for (final a in level.arrows) {
        expect(gen.selfRayClear(a), isTrue,
            reason: 'level $lvl arrow ${a.id} (${a.dir}) fires through its '
                'own body; head at ${a.head}');
      }
    }
  });

  test('daily boards 1..120 are solvable and never self-fire', () {
    for (var day = 1; day <= 120; day++) {
      final level = gen.genLevel(day, daily: true);
      expect(level.arrows, isNotEmpty, reason: 'daily $day produced no arrows');
      expect(gen.greedySolvable(level.arrows), isTrue,
          reason: 'daily $day is not solvable');
      for (final a in level.arrows) {
        expect(gen.selfRayClear(a), isTrue,
            reason: 'daily $day arrow ${a.id} fires through its own body');
      }
    }
  });
}
