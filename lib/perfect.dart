import 'prefs.dart';

/// "Perfect Play" tracking — counts levels cleared in a single valid run.
///
/// A completion counts only if, during that level's session, the player
/// neither lost all 3 hearts nor manually restarted. Validity is persisted,
/// so it survives the app being backgrounded or killed and resumed:
///   • Resuming the same level keeps the in-progress attempt's validity.
///   • A failure (all hearts lost) or a restart invalidates the attempt
///     permanently — it cannot be undone by killing/reopening the app.
class PerfectPlay {
  /// Award milestones (number of valid completions needed for each tier).
  static const milestones = <int>[10, 25, 50, 100, 200, 400, 800, 1600, 3200, 6400];

  /// Total valid completions so far.
  static int get count => Prefs.perfectCount;

  /// Whether the first milestone has been reached.
  static bool get unlocked => count >= milestones.first;

  /// Highest milestone reached (0 if none yet).
  static int get reached {
    var m = 0;
    for (final t in milestones) {
      if (count >= t) {
        m = t;
      } else {
        break;
      }
    }
    return m;
  }

  /// Next milestone to aim for (null once all are earned).
  static int? get next {
    for (final t in milestones) {
      if (count < t) return t;
    }
    return null;
  }

  /// How many milestones have been reached (the "X" in "X of 10").
  static int get tier {
    var n = 0;
    for (final t in milestones) {
      if (count >= t) {
        n++;
      } else {
        break;
      }
    }
    return n;
  }

  /// Call whenever a level's board is loaded fresh (entering or resuming).
  /// A genuinely new level resets validity to true; re-entering the same
  /// level (after background/kill) preserves the existing validity so an
  /// already-failed/restarted attempt stays invalid and a clean one stays
  /// countable.
  static void onLevelStart(int level) {
    if (Prefs.perfectLevel != level) {
      Prefs.setPerfectLevel(level);
      Prefs.setPerfectValid(true);
    }
  }

  /// Player lost all 3 hearts — invalidate this attempt permanently.
  static void onFail() => Prefs.setPerfectValid(false);

  /// Player manually restarted the level — invalidate this attempt.
  static void onRestart() => Prefs.setPerfectValid(false);

  static bool get hasUnseen => Prefs.perfectUnseen;

  static void markSeen() => Prefs.setPerfectUnseen(false);

  /// Whether the most recent win just crossed a milestone.
  static bool justUnlockedMilestone() => _lastMilestoneHit;
  static bool _lastMilestoneHit = false;

  /// Player cleared [level]. Counts toward Perfect Play only if the attempt
  /// was never invalidated. Marks the attempt spent to avoid double-counting,
  /// and stamps the earned-date when a milestone is freshly crossed.
  static void onWin(int level) {
    _lastMilestoneHit = false;
    if (Prefs.perfectValid && Prefs.perfectLevel == level) {
      final newCount = Prefs.perfectCount + 1;
      Prefs.setPerfectCount(newCount);
      final i = milestones.indexOf(newCount);
      if (i >= 0) {
        _stampMilestone(i);
        Prefs.setPerfectUnseen(true);
        _lastMilestoneHit = true;
      }
    }
    Prefs.setPerfectValid(false);
  }

  /// The date milestone [m] was earned (formatted), or null if not recorded.
  static String? earnedDateFor(int m) {
    final i = milestones.indexOf(m);
    if (i < 0) return null;
    final dates = Prefs.perfectDates;
    if (i >= dates.length || dates[i].isEmpty) return null;
    final p = dates[i].split('-');
    if (p.length != 3) return null;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final month = int.tryParse(p[1]) ?? 1;
    return '${months[month - 1]} ${int.parse(p[2])} ${p[0]}';
  }

  static void _stampMilestone(int index) {
    final dates = List<String>.from(Prefs.perfectDates);
    while (dates.length < milestones.length) {
      dates.add('');
    }
    if (dates[index].isEmpty) {
      final d = DateTime.now();
      dates[index] = '${d.year}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
      Prefs.setPerfectDates(dates);
    }
  }
}
