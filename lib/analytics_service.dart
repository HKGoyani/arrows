import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';

/// Firebase Analytics wrapper. Call [init] once at app startup.
class AnalyticsService {
  static FirebaseAnalytics? _analytics;
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    try {
      await Firebase.initializeApp();
      _analytics = FirebaseAnalytics.instance;
      _initialized = true;
    } catch (_) {/* analytics is non-critical */}
  }

  static void logEvent(String name, [Map<String, Object>? params]) {
    _analytics?.logEvent(name: name, parameters: params);
  }

  static void levelStart(int level, {bool daily = false}) =>
      logEvent('level_start', {'level': level, 'daily': daily ? 1 : 0});

  static void levelWin(int level, {bool daily = false}) =>
      logEvent('level_win', {'level': level, 'daily': daily ? 1 : 0});

  static void levelLose(int level, {bool daily = false}) =>
      logEvent('level_lose', {'level': level, 'daily': daily ? 1 : 0});

  static void levelRestart(int level) =>
      logEvent('level_restart', {'level': level});

  static void levelSkip(int level) =>
      logEvent('level_skip', {'level': level});

  static void hintUsed(int level) => logEvent('hint_used', {'level': level});

  static void adShown(String type) => logEvent('ad_shown', {'type': type});

  /// GA4's canonical ad-revenue event, fed from AdMob's per-impression paid
  /// callback (see AdService). [valueMicros] is the estimated revenue in
  /// millionths of a currency unit, as the SDK reports it. Logged with
  /// value + currency so GA4 rolls it into its ad-revenue / ARPU metrics and
  /// it can be segmented per placement, per mediation source, and — via the
  /// level_start/level_win events around it — per level.
  static void adImpression({
    required String placement,
    required String format,
    required double valueMicros,
    required String currencyCode,
    String? adSource,
  }) {
    _analytics?.logAdImpression(
      adPlatform: 'AdMob',
      adSource: adSource ?? 'unknown',
      adFormat: format,
      adUnitName: placement,
      value: valueMicros / 1e6,
      currency: currencyCode,
    );
  }

  static void purchaseRemoveAds() => logEvent('purchase_remove_ads');

  static void dailyChallengeComplete() => logEvent('daily_challenge_complete');

  static void streakExtended(int streak) =>
      logEvent('streak_extended', {'streak': streak});
}
