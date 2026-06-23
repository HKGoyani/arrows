import 'prefs.dart';

class Unstoppable {
  static const milestones = <int>[3, 6, 10, 30, 50, 75, 100, 250, 500];

  static const nightmareFrom = 35;

  static bool isNightmare(int level) => level >= nightmareFrom;

  static int get count => Prefs.unstoppableCount;

  static bool get unlocked => count >= milestones.first;

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

  static int? get next {
    for (final t in milestones) {
      if (count < t) return t;
    }
    return null;
  }

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

  static bool get hasUnseen => Prefs.unstoppableUnseen;

  static void markSeen() => Prefs.setUnstoppableUnseen(false);

  static void onWin(int level) {
    if (!isNightmare(level)) return;
    final newCount = Prefs.unstoppableCount + 1;
    Prefs.setUnstoppableCount(newCount);
    final i = milestones.indexOf(newCount);
    if (i >= 0) {
      _stampMilestone(i);
      Prefs.setUnstoppableUnseen(true);
    }
  }

  static String? earnedDateFor(int m) {
    final i = milestones.indexOf(m);
    if (i < 0) return null;
    final dates = Prefs.unstoppableDates;
    if (i >= dates.length || dates[i].isEmpty) return null;
    final p = dates[i].split('-');
    if (p.length != 3) return null;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final month = int.tryParse(p[1]) ?? 1;
    return '${months[month - 1]} ${int.parse(p[2])} ${p[0]}';
  }

  static void _stampMilestone(int index) {
    final dates = List<String>.from(Prefs.unstoppableDates);
    while (dates.length < milestones.length) {
      dates.add('');
    }
    if (dates[index].isEmpty) {
      final d = DateTime.now();
      dates[index] = '${d.year}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
      Prefs.setUnstoppableDates(dates);
    }
  }
}
