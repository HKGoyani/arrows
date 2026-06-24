import 'dart:convert';
import 'prefs.dart';

/// Daily-challenge state. Each calendar day can hold its own partly-played
/// board (remaining arrow ids + hearts + progress fraction), persisted to disk
/// so "Continue" resumes from the last state and the calendar ring survives an
/// app kill. The red-dot badge tracks whether *today's* challenge is done.
class ChallengeService {
  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ── per-date board store (date -> {r: [ids], h: hearts, p: progress}) ──
  static Map<String, dynamic> _all() {
    final raw = Prefs.challengeStates;
    if (raw.isEmpty) return {};
    try {
      final m = jsonDecode(raw);
      return m is Map<String, dynamic> ? m : {};
    } catch (_) {
      return {};
    }
  }

  static Future<void> _persist(Map<String, dynamic> m) =>
      Prefs.setChallengeStates(jsonEncode(m));

  static double progressFor(DateTime d) {
    final e = _all()[_fmt(d)];
    if (e is Map && e['p'] is num) {
      return (e['p'] as num).toDouble().clamp(0.0, 1.0);
    }
    return 0.0;
  }

  /// True when [d] has a partly-played board (ring should show).
  static bool hasProgress(DateTime d) {
    final p = progressFor(d);
    return p > 0 && p < 1;
  }

  static List<int>? remainingFor(DateTime d) {
    final e = _all()[_fmt(d)];
    if (e is Map && e['r'] is List) {
      return (e['r'] as List).map((x) => (x as num).toInt()).toList();
    }
    return null;
  }

  static int heartsFor(DateTime d) {
    final e = _all()[_fmt(d)];
    if (e is Map && e['h'] is num) return (e['h'] as num).toInt();
    return 3;
  }

  /// Saves [d]'s partly-played board. Awaited so it survives an app kill.
  static Future<void> saveFor(
    DateTime d, {
    required List<int> remainingIds,
    required int hearts,
    required double progress,
  }) async {
    final m = _all();
    m[_fmt(d)] = {
      'r': remainingIds,
      'h': hearts,
      'p': progress.clamp(0.0, 1.0),
    };
    await _persist(m);
  }

  /// Clears any saved board for [d] (e.g. after restart or completion).
  static Future<void> clearFor(DateTime d) async {
    final m = _all();
    if (m.remove(_fmt(d)) != null) await _persist(m);
  }

  // ── today / red-dot ──
  static bool get completedToday =>
      Prefs.lastChallengeDate == _fmt(DateTime.now());

  static double get todayProgress {
    if (completedToday) return 1.0;
    return progressFor(DateTime.now());
  }

  /// Marks today's challenge complete (clears the red dot).
  static Future<void> completeToday() async {
    _seenThisSession = true;
    await Prefs.setLastChallengeDate(_fmt(DateTime.now()));
  }

  // The dot shows on every app open while today's challenge is unfinished,
  // and is cleared for the session once the user opens the Challenge tab.
  static bool _seenThisSession = false;

  static bool get hasUnseen => !completedToday && !_seenThisSession;

  static void markSeen() => _seenThisSession = true;
}
