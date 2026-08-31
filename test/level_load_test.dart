import 'package:flutter_test/flutter_test.dart';
import 'package:arrows_game/game_controller.dart';
import 'package:arrows_game/models.dart';
import 'package:arrows_game/level_generator.dart';

String sig(List<Arrow> a) => a
    .map((x) => '${x.id}|${x.dir}|${x.pts.map((p) => "${p.x},${p.y}").join(">")}')
    .join(';');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('async load matches direct generation (board unchanged by the fix)',
      () async {
    for (final lvl in [1, 30, 57, 93, 150]) {
      final c = GameController();
      await c.loadLevelAsync(lvl, daily: false);
      final direct = LevelGenerator().genLevel(lvl, daily: false);
      expect(sig(c.arrows), sig(direct.arrows), reason: 'level $lvl differs');
    }
  });

  test('restart from cache reproduces the identical board', () async {
    for (final lvl in [30, 57, 93]) {
      final c = GameController();
      await c.loadLevelAsync(lvl, daily: false);
      final before = sig(c.arrows);
      // Play the board: mutate + remove arrows the way a real session does.
      for (final a in c.arrows) {
        a.state = ArrowState.leaving;
      }
      c.arrows.removeWhere((a) => a.id.isEven);
      expect(c.reloadFromCache(lvl, daily: false), isTrue);
      expect(sig(c.arrows), before, reason: 'level $lvl restart differs');
      expect(c.arrows.every((a) => a.state == ArrowState.idle), isTrue,
          reason: 'level $lvl restart kept stale arrow state');
      expect(c.total, c.arrows.length);
    }
  });

  test('cache misses correctly for a different level or mode', () async {
    final c = GameController();
    await c.loadLevelAsync(30, daily: false);
    expect(c.reloadFromCache(31, daily: false), isFalse);
    expect(c.reloadFromCache(30, daily: true), isFalse);
    expect(c.reloadFromCache(30, daily: false), isTrue);
  });

  test('fresh controller has no cache to reload', () {
    expect(GameController().reloadFromCache(5, daily: false), isFalse);
  });
}
