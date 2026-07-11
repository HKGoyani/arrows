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

  // Set once the app's first-ever session ends (backgrounded/killed). Used to
  // skip showing an App Open ad on a brand-new user's very first launch —
  // Google's own guidance advises against that as a first impression.
  static bool get hasCompletedFirstSession =>
      _p?.getBool('hasCompletedFirstSession') ?? false;
  static Future<void> setHasCompletedFirstSession(bool v) async =>
      _p?.setBool('hasCompletedFirstSession', v);

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

  // --- records (highest win streak + most wins in a day) ---
  static String get bestStreakDate => _p?.getString('bestStreakDate') ?? '';
  static Future<void> setBestStreakDate(String v) async => _p?.setString('bestStreakDate', v);
  static int get winStreakCur => _p?.getInt('winStreakCur') ?? 0;
  static Future<void> setWinStreakCur(int v) async => _p?.setInt('winStreakCur', v);
  static int get winStreakBest => _p?.getInt('winStreakBest') ?? 0;
  static Future<void> setWinStreakBest(int v) async => _p?.setInt('winStreakBest', v);
  static String get winStreakBestDate => _p?.getString('winStreakBestDate') ?? '';
  static Future<void> setWinStreakBestDate(String v) async => _p?.setString('winStreakBestDate', v);
  static int get winsTodayCount => _p?.getInt('winsTodayCount') ?? 0;
  static Future<void> setWinsTodayCount(int v) async => _p?.setInt('winsTodayCount', v);
  static String get winsTodayDate => _p?.getString('winsTodayDate') ?? '';
  static Future<void> setWinsTodayDate(String v) async => _p?.setString('winsTodayDate', v);
  static int get mostWinsBest => _p?.getInt('mostWinsBest') ?? 0;
  static Future<void> setMostWinsBest(int v) async => _p?.setInt('mostWinsBest', v);
  static String get mostWinsBestDate => _p?.getString('mostWinsBestDate') ?? '';
  static Future<void> setMostWinsBestDate(String v) async => _p?.setString('mostWinsBestDate', v);

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

  // --- rate-us prompt (after-win) ---
  static int get ratePromptCount => _p?.getInt('ratePromptCount') ?? 0;
  static Future<void> setRatePromptCount(int v) async =>
      _p?.setInt('ratePromptCount', v);
  static int get ratePromptLastAtLevel => _p?.getInt('ratePromptLastLevel') ?? 0;
  static Future<void> setRatePromptLastAtLevel(int v) async =>
      _p?.setInt('ratePromptLastLevel', v);

  // --- hints ---
  static const int freeHints = 5;
  static int get hintsUsed => _p?.getInt('hintsUsed') ?? 0;
  static Future<void> setHintsUsed(int v) async => _p?.setInt('hintsUsed', v);
  static bool get hasFreeHint => hintsUsed < freeHints;
  static int get freeHintsLeft => (freeHints - hintsUsed).clamp(0, freeHints);

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
  // per-date in-progress challenge boards (JSON: date -> {r,h,p})
  static String get challengeStates => _p?.getString('challengeStates') ?? '';
  static Future<void> setChallengeStates(String v) async =>
      _p?.setString('challengeStates', v);

  // --- collection first-unlock badge ---
  static bool get collectionUnseen => _p?.getBool('collectionUnseen') ?? false;
  static Future<void> setCollectionUnseen(bool v) async => _p?.setBool('collectionUnseen', v);

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
    await _p?.remove('bestStreakDate');
    await _p?.remove('winStreakCur');
    await _p?.remove('winStreakBest');
    await _p?.remove('winStreakBestDate');
    await _p?.remove('winsTodayCount');
    await _p?.remove('winsTodayDate');
    await _p?.remove('mostWinsBest');
    await _p?.remove('mostWinsBestDate');
    await _p?.remove('legendDates');
    await _p?.remove('unstoppableCount');
    await _p?.remove('unstoppableDates');
    await _p?.remove('unstoppableUnseen');
    await _p?.remove('legendUnseen');
    await _p?.remove('lastChallengeDate');
    await _p?.remove('challengeStates');
    await _p?.remove('perfectUnseen');
    await _p?.remove('perfectCount');
    await _p?.remove('perfectLevel');
    await _p?.remove('perfectValid');
    await _p?.remove('perfectDates');
    await _p?.remove('hintsUsed');
  }
}
