import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:arrows_game/level_generator.dart';
import 'package:arrows_game/models.dart';
import 'package:arrows_game/main.dart';

void main() {
  final gen = LevelGenerator();

  testWidgets('boots to home with Play button and bottom nav', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.pumpWidget(const ArrowsApp());
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

  test('no arrow folds back on itself (no U-turn / hairpin arrows)', () {
    for (var lvl = 1; lvl <= 30; lvl++) {
      for (final a in gen.genLevel(lvl).arrows) {
        for (var i = 0; i < a.pts.length; i++) {
          for (var j = i + 2; j < a.pts.length; j++) {
            final manhattan =
                (a.pts[i].x - a.pts[j].x).abs() + (a.pts[i].y - a.pts[j].y).abs();
            expect(manhattan == 1, isFalse,
                reason: 'level $lvl arrow ${a.id} folds back on itself');
          }
        }
      }
    }
  });

  test('grid grows with level toward 11x13', () {
    expect(gen.genLevel(1).cols, lessThan(gen.genLevel(8).cols));
    final hi = gen.genLevel(20);
    expect(hi.cols, 11);
    expect(hi.rows, 13);
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
