import 'package:flutter_test/flutter_test.dart';
import 'package:arrows_game/level_generator.dart';
import 'package:arrows_game/models.dart';
import 'package:arrows_game/main.dart';

void main() {
  final gen = LevelGenerator();

  testWidgets('boots to home with Play button and bottom nav', (tester) async {
    await tester.pumpWidget(ArrowsApp());
    await tester.pump();
    expect(find.text('Play'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  test('every level 1..40 is non-empty and fully solvable', () {
    for (var lvl = 1; lvl <= 40; lvl++) {
      final level = gen.genLevel(lvl);
      expect(level.arrows, isNotEmpty, reason: 'level $lvl produced no arrows');
      expect(gen.greedySolvable(level.arrows), isTrue,
          reason: 'level $lvl is not solvable');
    }
  });

  // The generator used to be asserted never to fold an arrow back alongside
  // itself. It winds them deliberately now — hairpins occur in 47 of the first
  // 60 levels, from level 6 on — so that assertion described a design that no
  // longer exists and has been dropped. What actually matters is that a wound
  // arrow is still a legal, single-cell-per-step path, which is asserted here;
  // that it never fires through itself, which self_fire_test covers; and that
  // every level stays solvable, which the sweep covers.
  test('arrow paths are contiguous: every step moves exactly one cell', () {
    for (var lvl = 1; lvl <= 30; lvl++) {
      for (final a in gen.genLevel(lvl).arrows) {
        for (var i = 1; i < a.pts.length; i++) {
          final step = (a.pts[i].x - a.pts[i - 1].x).abs() +
              (a.pts[i].y - a.pts[i - 1].y).abs();
          expect(step, 1,
              reason: 'level $lvl arrow ${a.id} jumps between points '
                  '${a.pts[i - 1]} and ${a.pts[i]}');
        }
      }
    }
  });

  // This used to pin level 20 at exactly 11x13. The board outgrew that: 11x13
  // now arrives around level 12 and keeps expanding, reaching 40x49 by level
  // 120. Individual levels also vary a lot — levels 21-30 alone range from 13
  // to 29 columns — so per-level monotonic growth is the wrong shape to
  // assert. The trend is what holds: averaged over blocks of ten, boards grow
  // steadily (7.9 -> 11.7 -> 16.8 -> 23.6 -> 32.7 columns).
  test('grid grows with level and stays bounded', () {
    double avgCols(int from, int to) {
      var total = 0;
      for (var l = from; l <= to; l++) {
        total += gen.genLevel(l).cols;
      }
      return total / (to - from + 1);
    }

    final blocks = [
      avgCols(1, 10),
      avgCols(11, 20),
      avgCols(21, 30),
      avgCols(41, 50),
      avgCols(91, 100),
    ];
    for (var i = 1; i < blocks.length; i++) {
      expect(blocks[i], greaterThan(blocks[i - 1]),
          reason: 'average board stopped growing at block $i: $blocks');
    }

    expect(gen.genLevel(1).cols, lessThanOrEqualTo(8));
    expect(blocks.last, greaterThanOrEqualTo(25));

    for (var lvl = 1; lvl <= 120; lvl++) {
      final lv = gen.genLevel(lvl);
      expect(lv.cols, lessThanOrEqualTo(48), reason: 'level $lvl too wide');
      expect(lv.rows, lessThanOrEqualTo(60), reason: 'level $lvl too tall');
      expect(lv.cols, greaterThan(0));
      expect(lv.rows, greaterThan(0));
    }
  });

  test('arrows within a level never share a cell', () {
    final level = gen.genLevel(12);
    final seen = <String>{};
    for (final a in level.arrows) {
      for (final cell in a.cells) {
        expect(seen.contains(cell), isFalse, reason: 'cell $cell shared');
        seen.add(cell);
      }
    }
    expect(level.arrows.every((a) => a.state == ArrowState.idle), isTrue);
  });

  test('level generation is deterministic for a given level', () {
    final a = gen.genLevel(7);
    final b = gen.genLevel(7);
    expect(a.arrows.length, b.arrows.length);
  });
}
