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

// Manual overrides for shaped levels whose hash tier doesn't match actual
// difficulty (shaped levels fill only a fraction of the full grid, so the
// hash-assigned tier can be misleading).
const _shapedLevelTiers = <int, Tier>{
  16: Tier.normal,   // circle — small grid, light fill
  21: Tier.hard,     // heart
  27: Tier.normal,   // diamond
  34: Tier.normal,   // triangle
  39: Tier.normal,   // star
  45: Tier.hard,     // cross
  52: Tier.normal,   // hexagon
  57: Tier.normal,   // pentagon
  63: Tier.hard,     // crescent — 32×32 partial fill, Hard is appropriate
  70: Tier.hard,     // clover — 34×34, four lobes, Hard
  75: Tier.hard,     // bolt — 44×50 lightning zigzag, Hard
  81: Tier.normal,   // octagon
  88: Tier.normal,   // circle
  93: Tier.hard,     // flower — 40×40, five petals + hollow center, Hard
  99: Tier.normal,   // peach
};

/// Deterministic tier for a level. Calibrated from 99 reference levels (L4-102):
///   L4-102: 70% Normal, 20% Hard, 9% SH, 1% NM (L100 hardcoded)
///   L103+:  Normal gradually gives way; Nightmare grows to 40% by L1000+
///
/// Hard first at L6, Super Hard at L26, Nightmare at L100.
Tier tierForLevel(int level) {
  if (_shapedLevelTiers.containsKey(level)) return _shapedLevelTiers[level]!;
  if (level < 6) return Tier.normal;
  if (level == 100) return Tier.nightmare;

  final hash = ((level * 2654435761 + level * 7919 + 0x1337) & 0xFFFFFFFF) /
      4294967296.0;

  if (level < 26) {
    // ~70% Normal, ~30% Hard
    return hash < 0.70 ? Tier.normal : Tier.hard;
  }
  if (level < 100) {
    // ~70% Normal, ~20% Hard, ~10% Super Hard
    if (hash < 0.70) return Tier.normal;
    if (hash < 0.90) return Tier.hard;
    return Tier.superHard;
  }
  if (level < 151) {
    // ~55% Normal, ~18% Hard, ~18% SH, ~8% NM
    if (hash < 0.55) return Tier.normal;
    if (hash < 0.73) return Tier.hard;
    if (hash < 0.92) return Tier.superHard;
    return Tier.nightmare;
  }
  if (level < 251) {
    // ~40% Normal, ~22% Hard, ~22% SH, ~16% NM
    if (hash < 0.40) return Tier.normal;
    if (hash < 0.62) return Tier.hard;
    if (hash < 0.84) return Tier.superHard;
    return Tier.nightmare;
  }
  if (level < 501) {
    // ~25% Normal, ~20% Hard, ~27% SH, ~28% NM
    if (hash < 0.25) return Tier.normal;
    if (hash < 0.45) return Tier.hard;
    if (hash < 0.72) return Tier.superHard;
    return Tier.nightmare;
  }
  if (level < 1001) {
    // ~15% Normal, ~20% Hard, ~30% SH, ~35% NM
    if (hash < 0.15) return Tier.normal;
    if (hash < 0.35) return Tier.hard;
    if (hash < 0.65) return Tier.superHard;
    return Tier.nightmare;
  }
  // L1000+: plateau — ~10% Normal, ~18% Hard, ~32% SH, ~40% NM
  if (hash < 0.10) return Tier.normal;
  if (hash < 0.28) return Tier.hard;
  if (hash < 0.60) return Tier.superHard;
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
