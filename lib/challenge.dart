import 'prefs.dart';

/// Daily-challenge state: tracks whether today's challenge is done, how far
/// it's progressed, and the "unseen" red-dot badge on the Challenge nav.
class ChallengeService {
  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// True once the user has completed today's daily challenge.
  static bool get completedToday =>
      Prefs.lastChallengeDate == _fmt(DateTime.now());

  /// Fraction (0..1) of today's challenge already cleared (arrows fired).
  /// 0 when not started, 1 when complete.
  static double get todayProgress {
    if (completedToday) return 1.0;
    if (Prefs.challengeProgressDate != _fmt(DateTime.now())) return 0.0;
    return Prefs.challengeProgress.clamp(0.0, 1.0);
  }

  /// Records partial progress on today's challenge.
  static Future<void> setTodayProgress(double v) async {
    await Prefs.setChallengeProgressDate(_fmt(DateTime.now()));
    await Prefs.setChallengeProgress(v.clamp(0.0, 1.0));
  }

  /// Marks today's challenge complete (also clears the red dot).
  static Future<void> completeToday() async {
    await Prefs.setLastChallengeDate(_fmt(DateTime.now()));
    await markSeen();
  }

  // ── red-dot badge ──
  // The dot shows on every app open while today's challenge is unfinished,
  // and is cleared for the session once the user opens the Challenge tab.
  static bool _seenThisSession = false;

  static bool get hasUnseen => !completedToday && !_seenThisSession;

  static Future<void> markSeen() async {
    _seenThisSession = true;
  }
}
