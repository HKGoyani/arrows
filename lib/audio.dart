import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'prefs.dart';

enum Haptic { light, medium, heavy }

/// Sound effects, looping music and haptics. Each is independently toggleable
/// and observable (so Settings + the in-game button reflect state live).
class AudioService {
  static final AudioPlayer _bgm = AudioPlayer(playerId: 'arrows_bgm');

  /// Fallback player, used only until [_warmPools] finishes (and if it fails).
  /// Playing through this re-reads the asset and re-prepares the native player
  /// on every call — see [_play].
  static final AudioPlayer _sfx = AudioPlayer(playerId: 'arrows_sfx');

  // ── Pre-loaded SFX pools ──
  //
  // Each pool keeps its asset already loaded in its players, so playing is
  // just setVolume + resume. The previous approach called
  // play(AssetSource(...)) per sound, which on Android re-ran the whole
  // setDataSource → prepare → requestAudioFocus chain EVERY time, on the
  // platform main thread, for every arrow tap. Play vitals captured exactly
  // that: audioplayers' UrlSource.setForMediaPlayer and MediaPlayerWrapper
  // .setRate in ANR traces, plus ModernFocusManager.requestAudioFocus flagged
  // as a "Slow Binder call". In a game where taps come in fast bursts, that
  // flooded the main thread's message queue.
  static final Map<String, AudioPool> _pools = {};

  /// How many concurrent players each sound keeps. Only the swipe (fired on
  /// every arrow launch, and several can overlap) needs more than a couple.
  static const _poolSizes = <String, int>{
    'swipe.wav': 4,
    'tap.wav': 2,
    'clash.wav': 2,
    'win.wav': 1,
    'ui_tap.wav': 2,
  };

  static final ValueNotifier<bool> soundOn = ValueNotifier(true);
  static final ValueNotifier<bool> musicOn = ValueNotifier(true);
  static final ValueNotifier<bool> vibrationOn = ValueNotifier(true);

  static Future<void> init() async {
    soundOn.value = Prefs.sound;
    // Music toggle hidden in Settings for now — force off until re-enabled.
    musicOn.value = false;
    vibrationOn.value = Prefs.vibration;
    try {
      // Never take audio focus. mixWithOthers maps to AndroidAudioFocus.none,
      // so no requestAudioFocus binder call is made per sound — that call was
      // flagged as a slow binder call in the ANR traces. It is also the right
      // behaviour for a casual puzzle game: tapping an arrow should not
      // interrupt whatever the player is already listening to.
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers)
            .build(),
      );
      await _sfx.setReleaseMode(ReleaseMode.stop);
      await _bgm.setReleaseMode(ReleaseMode.loop);
      await _bgm.setVolume(0.45);
      if (musicOn.value) await _bgm.play(AssetSource('audio/bgm.mp3'));
    } catch (_) {/* audio is non-critical */}
    // Deliberately NOT awaited: this pre-loads every sound and would otherwise
    // add to the startup budget. Until it finishes, [_play] falls back to the
    // old single-player path, so early taps still make sound.
    unawaited(_warmPools());
  }

  static Future<void> _warmPools() async {
    for (final entry in _poolSizes.entries) {
      try {
        _pools[entry.key] = await AudioPool.createFromAsset(
          path: 'audio/${entry.key}',
          maxPlayers: entry.value,
        );
      } catch (_) {
        // Leave this sound on the fallback path rather than failing the rest.
      }
    }
  }

  /// Plays [file]. Overlapping calls are handled by the pool, which hands out
  /// a free player (or briefly creates one) instead of cutting the previous
  /// sound off.
  static void _play(String file, double vol) {
    if (!soundOn.value) return;
    final pool = _pools[file];
    if (pool != null) {
      // Fire and forget — awaiting would put the caller (a tap handler) on the
      // platform round trip. Errors are swallowed: audio is non-critical, and
      // an unhandled async error here would surface as a crash.
      pool.start(volume: vol).catchError((_) => () async {});
      return;
    }
    // Pools not warm yet (or this one failed to build).
    _sfx.play(AssetSource('audio/$file'), volume: vol).catchError((_) {});
  }

  static void tap() => _play('tap.wav', 0.7);
  static void clash() => _play('clash.wav', 0.85);
  static void win() => _play('win.wav', 0.9);
  static void uiTap() => _play('ui_tap.wav', 0.5);
  static void swipe() => _play('swipe.wav', 0.7);

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
