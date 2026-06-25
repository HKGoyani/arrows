import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'prefs.dart';

enum Haptic { light, medium, heavy }

/// Sound effects, looping music and haptics. Each is independently toggleable
/// and observable (so Settings + the in-game button reflect state live).
class AudioService {
  static final AudioPlayer _sfx = AudioPlayer(playerId: 'arrows_sfx');
  static final AudioPlayer _bgm = AudioPlayer(playerId: 'arrows_bgm');

  static final ValueNotifier<bool> soundOn = ValueNotifier(true);
  static final ValueNotifier<bool> musicOn = ValueNotifier(true);
  static final ValueNotifier<bool> vibrationOn = ValueNotifier(true);

  static Future<void> init() async {
    soundOn.value = Prefs.sound;
    musicOn.value = Prefs.music;
    vibrationOn.value = Prefs.vibration;
    try {
      await _sfx.setReleaseMode(ReleaseMode.stop);
      await _bgm.setReleaseMode(ReleaseMode.loop);
      await _bgm.setVolume(0.45);
      if (musicOn.value) await _bgm.play(AssetSource('audio/bgm.mp3'));
    } catch (_) {/* audio is non-critical */}
  }

  static Future<void> _play(String file, double vol) async {
    if (!soundOn.value) return;
    try {
      await _sfx.play(AssetSource('audio/$file'), volume: vol);
    } catch (_) {}
  }

  static void tap() => _play('tap.wav', 0.7);
  static void clash() => _play('clash.wav', 0.85);
  static void win() => _play('win.wav', 0.9);

  static void vibrate(Haptic h) {
    if (!vibrationOn.value) return;
    switch (h) {
      case Haptic.light:
        HapticFeedback.lightImpact();
        break;
      case Haptic.medium:
        HapticFeedback.mediumImpact();
        break;
      case Haptic.heavy:
        // double-buzz for wrong moves: heavy + delayed medium
        HapticFeedback.heavyImpact();
        Future.delayed(const Duration(milliseconds: 100), () {
          if (vibrationOn.value) HapticFeedback.mediumImpact();
        });
        break;
    }
  }

  static Future<void> setSound(bool v) async {
    soundOn.value = v;
    await Prefs.setSound(v);
  }

  static Future<void> setVibration(bool v) async {
    vibrationOn.value = v;
    await Prefs.setVibration(v);
  }

  static Future<void> setMusic(bool v) async {
    musicOn.value = v;
    await Prefs.setMusic(v);
    try {
      if (v) {
        await _bgm.resume();
        if (_bgm.state != PlayerState.playing) {
          await _bgm.play(AssetSource('audio/bgm.mp3'));
        }
      } else {
        await _bgm.pause();
      }
    } catch (_) {}
  }

  static void onAppPause() {
    try {
      _bgm.pause();
    } catch (_) {}
  }

  static void onAppResume() {
    if (!musicOn.value) return;
    try {
      _bgm.resume();
    } catch (_) {}
  }
}
