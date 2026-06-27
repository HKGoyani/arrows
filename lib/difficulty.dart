import 'package:flutter/material.dart';
import 'l10n.dart';

enum Tier {
  normal('normal', Color(0xFF27C281)),
  hard('hard', Color(0xFF38ADF2)),
  superHard('superHard', Color(0xFFDE63FB)),
  nightmare('nightmare', Color(0xFFE53935));

  final String _key;
  final Color color;
  const Tier(this._key, this.color);

  String get label => Tr.get(_key);
}

/// Deterministic tier LABEL for a level. Matches the reference game where the
/// label is mostly cosmetic — Normal dominates at every level, and the harder
/// tiers are sprinkled in with a ceiling that rises by level. Real difficulty
/// is driven by board size + arrow density (see LevelGenerator), not the label.
///
/// Reference observations: Hard first appears ~L6, Super Hard ~L26,
/// Nightmare ~L100. Normal stays the dominant label throughout.
Tier tierForLevel(int level) {
  if (level < 6) return Tier.normal;

  final hash = ((level * 2654435761) & 0xFFFFFFFF) / 4294967296.0;

  if (level < 26) {
    // L6-25: ~70% Normal, ~30% Hard
    return hash < 0.70 ? Tier.normal : Tier.hard;
  }
  if (level < 100) {
    // L26-99: ~65% Normal, ~22% Hard, ~13% Super Hard
    if (hash < 0.65) return Tier.normal;
    if (hash < 0.87) return Tier.hard;
    return Tier.superHard;
  }
  // L100+: ~55% Normal, ~22% Hard, ~13% Super Hard, ~10% Nightmare
  if (hash < 0.55) return Tier.normal;
  if (hash < 0.77) return Tier.hard;
  if (hash < 0.90) return Tier.superHard;
  return Tier.nightmare;
}

/// Tier for a daily challenge — always Hard or above (never Normal), cycling
/// through the harder tiers as the reference daily challenges do.
Tier dailyTier(int ordinal) {
  // Reference daily sequence cycles H / SH / NM, weighted toward Super Hard.
  switch (ordinal % 7) {
    case 0:
    case 3:
      return Tier.hard;
    case 1:
    case 4:
    case 6:
      return Tier.superHard;
    default:
      return Tier.nightmare;
  }
}
