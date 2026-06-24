import 'package:shared_preferences/shared_preferences.dart';

/// Persists level, settings and streak until the app is uninstalled.
/// Null-safe: sensible defaults if [init] was not called (e.g. tests).
class Prefs {
  static SharedPreferences? _p;

  static Future<void> init() async {
    _p = await SharedPreferences.getInstance();
  }

  // --- progress ---
  static int get level => _p?.getInt('level') ?? 1;
  static Future<void> setLevel(int v) async => _p?.setInt('level', v);

  // --- settings ---
  static bool get sound => _p?.getBool('sound') ?? true;
  static Future<void> setSound(bool v) async => _p?.setBool('sound', v);
  static bool get music => _p?.getBool('music') ?? true;
  static Future<void> setMusic(bool v) async => _p?.setBool('music', v);
  static bool get vibration => _p?.getBool('vibration') ?? true;
  static Future<void> setVibration(bool v) async => _p?.setBool('vibration', v);

  // --- streak ---
  static String get lastPlayed => _p?.getString('lastPlayed') ?? '';
  static Future<void> setLastPlayed(String v) async => _p?.setString('lastPlayed', v);
  static int get currentStreak => _p?.getInt('curStreak') ?? 0;
  static Future<void> setCurrentStreak(int v) async => _p?.setInt('curStreak', v);
  static int get bestStreak => _p?.getInt('bestStreak') ?? 0;
  static Future<void> setBestStreak(int v) async => _p?.setInt('bestStreak', v);
  static List<String> get playedDays => _p?.getStringList('playedDays') ?? const [];
  static Future<void> setPlayedDays(List<String> v) async =>
      _p?.setStringList('playedDays', v);

  // --- language ---
  static String get language => _p?.getString('language') ?? 'English';
  static Future<void> setLanguage(String v) async => _p?.setString('language', v);

  // --- settings placeholders ---
  static bool get darkMode => _p?.getBool('darkMode') ?? false;
  static Future<void> setDarkMode(bool v) async => _p?.setBool('darkMode', v);
  static bool get accountConnection => _p?.getBool('accountConn') ?? false;
  static Future<void> setAccountConnection(bool v) async => _p?.setBool('accountConn', v);
  static bool get removeAds => _p?.getBool('removeAds') ?? false;
  static Future<void> setRemoveAds(bool v) async => _p?.setBool('removeAds', v);

  // --- free life tracking ---
  static bool get usedFreeLife => _p?.getBool('usedFreeLife') ?? false;
  static Future<void> setUsedFreeLife() async => _p?.setBool('usedFreeLife', true);

  // --- level legend (milestone dates + unseen badge) ---
  static List<String> get legendDates => _p?.getStringList('legendDates') ?? const [];
  static Future<void> setLegendDates(List<String> v) async =>
      _p?.setStringList('legendDates', v);
  static bool get legendUnseen => _p?.getBool('legendUnseen') ?? false;
  static Future<void> setLegendUnseen(bool v) async => _p?.setBool('legendUnseen', v);

  // --- unstoppable (nightmare level wins) ---
  static int get unstoppableCount => _p?.getInt('unstoppableCount') ?? 0;
  static Future<void> setUnstoppableCount(int v) async => _p?.setInt('unstoppableCount', v);
  static List<String> get unstoppableDates => _p?.getStringList('unstoppableDates') ?? const [];
  static Future<void> setUnstoppableDates(List<String> v) async =>
      _p?.setStringList('unstoppableDates', v);
  static bool get unstoppableUnseen => _p?.getBool('unstoppableUnseen') ?? false;
  static Future<void> setUnstoppableUnseen(bool v) async => _p?.setBool('unstoppableUnseen', v);

  // --- daily challenge ---
  static String get lastChallengeDate => _p?.getString('lastChallengeDate') ?? '';
  static Future<void> setLastChallengeDate(String v) async =>
      _p?.setString('lastChallengeDate', v);
  static String get challengeProgressDate => _p?.getString('challengeProgressDate') ?? '';
  static Future<void> setChallengeProgressDate(String v) async =>
      _p?.setString('challengeProgressDate', v);
  static double get challengeProgress => _p?.getDouble('challengeProgress') ?? 0.0;
  static Future<void> setChallengeProgress(double v) async =>
      _p?.setDouble('challengeProgress', v);

  // --- perfect play unseen badge ---
  static bool get perfectUnseen => _p?.getBool('perfectUnseen') ?? false;
  static Future<void> setPerfectUnseen(bool v) async => _p?.setBool('perfectUnseen', v);

  // --- perfect play (valid, uninterrupted level completions) ---
  static int get perfectCount => _p?.getInt('perfectCount') ?? 0;
  static Future<void> setPerfectCount(int v) async => _p?.setInt('perfectCount', v);
  // the level the current attempt-validity refers to
  static int get perfectLevel => _p?.getInt('perfectLevel') ?? 0;
  static Future<void> setPerfectLevel(int v) async => _p?.setInt('perfectLevel', v);
  // is the current level's attempt still valid (no loss / no restart)?
  static bool get perfectValid => _p?.getBool('perfectValid') ?? false;
  static Future<void> setPerfectValid(bool v) async => _p?.setBool('perfectValid', v);
  // ISO date each milestone was earned (index-aligned to PerfectPlay.milestones)
  static List<String> get perfectDates => _p?.getStringList('perfectDates') ?? const [];
  static Future<void> setPerfectDates(List<String> v) async =>
      _p?.setStringList('perfectDates', v);

  static Future<void> resetProgress() async {
    await _p?.remove('level');
    await _p?.remove('curStreak');
    await _p?.remove('bestStreak');
    await _p?.remove('lastPlayed');
    await _p?.remove('playedDays');
    await _p?.remove('legendDates');
    await _p?.remove('unstoppableCount');
    await _p?.remove('unstoppableDates');
    await _p?.remove('unstoppableUnseen');
    await _p?.remove('legendUnseen');
    await _p?.remove('lastChallengeDate');
    await _p?.remove('challengeProgressDate');
    await _p?.remove('challengeProgress');
    await _p?.remove('perfectUnseen');
    await _p?.remove('perfectCount');
    await _p?.remove('perfectLevel');
    await _p?.remove('perfectValid');
    await _p?.remove('perfectDates');
  }
}
