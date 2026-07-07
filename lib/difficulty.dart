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
  // L100+ gravity-packed shapes: 100% fill at reference scale, so tiers are
  // graded by real board weight (>1000 cells → Nightmare, else Super Hard).
  104: Tier.nightmare, // shield — 34×43, ~1240 cells, ~147 arrows
  112: Tier.superHard, // teardrop — 32×45, ~930 cells
  120: Tier.superHard, // kite — 28×45, ~715 cells
  128: Tier.superHard, // house — 31×42, ~980 cells
  136: Tier.nightmare, // egg — 32×46, ~1150 cells
  144: Tier.nightmare, // dome — 44×30, ~1120 cells
  152: Tier.superHard, // arrow — 31×45, ~710 cells
  160: Tier.nightmare, // crown — 38×33, ~1010 cells
  168: Tier.superHard, // tree — 30×47, ~660 cells
};

/// Deterministic tier for a level. Escalating Normal→Hard→Super Hard mix,
/// with **Nightmare introduced only at L100** (never before). The board's
/// real difficulty is driven by the grid size (which grows monotonically with
/// the level number, see LevelGenerator); the tier is a label that rides that
/// ramp with a deterministic per-level mix so consecutive levels vary.
Tier tierForLevel(int level) {
  if (_shapedLevelTiers.containsKey(level)) return _shapedLevelTiers[level]!;
  if (level < 6) return Tier.normal;
  if (level == 100) return Tier.nightmare; // Nightmare debut

  final hash = ((level * 2654435761 + level * 7919 + 0x1337) & 0xFFFFFFFF) /
      4294967296.0;

  if (level < 100) {
    // L6-99: escalating N/H/SH mix — NO Nightmare before L100.
    if (level <= 20) {
      // Normal-lean with Hard sprinkled in.
      return hash < 0.70 ? Tier.normal : Tier.hard;
    }
    if (level <= 40) {
      // Hard-heavy, Super Hard introduced.
      if (hash < 0.45) return Tier.normal;
      if (hash < 0.85) return Tier.hard;
      return Tier.superHard;
    }
    if (level <= 65) {
      // Hard / Super Hard mix, Normal fading.
      if (hash < 0.25) return Tier.normal;
      if (hash < 0.70) return Tier.hard;
      return Tier.superHard;
    }
    // L66-99: Super Hard dominant, some Hard, rare Normal.
    if (hash < 0.10) return Tier.normal;
    if (hash < 0.55) return Tier.hard;
    return Tier.superHard;
  }
  // L101+: Nightmare now in the mix and its share grows with level.
  if (level < 151) {
    // ~15% Hard, ~45% SH, ~40% Nightmare
    if (hash < 0.15) return Tier.hard;
    if (hash < 0.60) return Tier.superHard;
    return Tier.nightmare;
  }
  if (level < 251) {
    // ~10% Hard, ~35% SH, ~55% Nightmare
    if (hash < 0.10) return Tier.hard;
    if (hash < 0.45) return Tier.superHard;
    return Tier.nightmare;
  }
  // L251+: plateau — ~8% Hard, ~27% SH, ~65% Nightmare
  if (hash < 0.08) return Tier.hard;
  if (hash < 0.35) return Tier.superHard;
  return Tier.nightmare;
}

/// Tier for a daily challenge — always Hard or above (never Normal). Daily
/// challenges lean harder than the main progression, so the 7-day cycle is
/// Nightmare-weighted: 2 Hard / 2 Super Hard / 3 Nightmare.
Tier dailyTier(int ordinal) {
  switch (ordinal % 7) {
    case 0:
    case 3:
      return Tier.hard;
    case 1:
    case 4:
      return Tier.superHard;
    default: // 2, 5, 6
      return Tier.nightmare;
  }
}
