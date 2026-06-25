import 'prefs.dart';

/// Tracks the Collection "Records": the longest run of consecutive level wins
/// (Highest Win Streak) and the most levels won in a single day (Most Wins),
/// each with the date the record was set. The longest *day* streak lives in
/// [Prefs.bestStreak] (see StreakService); its date is stamped here too.
class RecordsService {
  static String _today() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  /// Call on every main-progression level win.
  static void onWin() {
    // ── consecutive win streak ──
    final cur = Prefs.winStreakCur + 1;
    Prefs.setWinStreakCur(cur);
    if (cur > Prefs.winStreakBest) {
      Prefs.setWinStreakBest(cur);
      Prefs.setWinStreakBestDate(_today());
    }

    // ── most wins in a single day ──
    final today = _today();
    final todayCount =
        (Prefs.winsTodayDate == today ? Prefs.winsTodayCount : 0) + 1;
    Prefs.setWinsTodayDate(today);
    Prefs.setWinsTodayCount(todayCount);
    if (todayCount > Prefs.mostWinsBest) {
      Prefs.setMostWinsBest(todayCount);
      Prefs.setMostWinsBestDate(today);
    }
  }

  /// Call when the player loses (all hearts gone) — breaks the win streak.
  static void onLoss() => Prefs.setWinStreakCur(0);

  // ── record getters ──
  static int get currentWinStreak => Prefs.winStreakCur;
  static int get winsToday =>
      Prefs.winsTodayDate == _today() ? Prefs.winsTodayCount : 0;
  static int get highestWinStreak => Prefs.winStreakBest;
  static String get highestWinStreakDate => _fmt(Prefs.winStreakBestDate);
  static int get mostWins => Prefs.mostWinsBest;
  static String get mostWinsDate => _fmt(Prefs.mostWinsBestDate);

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// Formats an ISO date ("2026-04-12") as "Apr 12 2026", or '' if unset.
  static String _fmt(String iso) {
    final p = iso.split('-');
    if (p.length != 3) return '';
    final m = int.tryParse(p[1]) ?? 1;
    return '${_months[m - 1]} ${int.parse(p[2])} ${p[0]}';
  }
}
