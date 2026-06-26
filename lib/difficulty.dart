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

/// Deterministic tier for a given level. The distribution varies by range but
/// the result is stable per level (hash-based).
Tier tierForLevel(int level) {
  if (level < 6) return Tier.normal;

  final hash = ((level * 2654435761) & 0xFFFFFFFF) / 4294967296.0;

  if (level < 15) {
    // 30% Normal, 70% Hard
    if (hash < 0.30) return Tier.normal;
    return Tier.hard;
  }
  if (level < 35) {
    // 10% Normal, 25% Hard, 65% Super Hard
    if (hash < 0.10) return Tier.normal;
    if (hash < 0.35) return Tier.hard;
    return Tier.superHard;
  }
  // 35+: 25% Hard, 45% Super Hard, 30% Nightmare
  if (hash < 0.25) return Tier.hard;
  if (hash < 0.70) return Tier.superHard;
  return Tier.nightmare;
}
