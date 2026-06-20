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

  static Future<void> resetProgress() async {
    await _p?.remove('level');
    await _p?.remove('curStreak');
    await _p?.remove('bestStreak');
    await _p?.remove('lastPlayed');
    await _p?.remove('playedDays');
  }
}
