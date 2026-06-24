import 'prefs.dart';

class DayInfo {
  final String label; // M T W T F S S
  final bool played;
  final bool isToday;
  const DayInfo(this.label, this.played, this.isToday);
}

/// Daily-streak logic: a "streak" is consecutive days the player launched a game.
class StreakService {
  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Call when the player starts playing today.
  static void registerPlayToday() {
    final now = DateTime.now();
    final today = _fmt(now);
    if (Prefs.lastPlayed == today) return; // already counted today
    final yesterday = _fmt(now.subtract(const Duration(days: 1)));
    var cur = Prefs.currentStreak;
    cur = (Prefs.lastPlayed == yesterday) ? cur + 1 : 1; // continue or restart
    final best = cur > Prefs.bestStreak ? cur : Prefs.bestStreak;
    Prefs.setCurrentStreak(cur);
    Prefs.setBestStreak(best);
    Prefs.setLastPlayed(today);
    final days = List<String>.from(Prefs.playedDays);
    if (!days.contains(today)) days.add(today);
    Prefs.setPlayedDays(days);
  }

  /// Live current streak — 0 if the chain is broken (missed yesterday & today).
  static int get current {
    if (Prefs.lastPlayed.isEmpty) return 0;
    final now = DateTime.now();
    final today = _fmt(now);
    final yesterday = _fmt(now.subtract(const Duration(days: 1)));
    if (Prefs.lastPlayed == today || Prefs.lastPlayed == yesterday) {
      return Prefs.currentStreak;
    }
    return 0;
  }

  static int get best => Prefs.bestStreak;
  static bool get playedToday => Prefs.lastPlayed == _fmt(DateTime.now());

  static const _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  /// The last 7 days (oldest→today) with played markers.
  static List<DayInfo> lastSevenDays() {
    final now = DateTime.now();
    final played = Prefs.playedDays.toSet();
    final out = <DayInfo>[];
    for (var i = 6; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      out.add(DayInfo(_labels[d.weekday - 1], played.contains(_fmt(d)), i == 0));
    }
    return out;
  }
}
