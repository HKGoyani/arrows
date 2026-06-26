import 'package:flutter/material.dart';

enum Tier {
  normal('Normal', Color(0xFF27C281)),
  hard('Hard', Color(0xFF38ADF2)),
  superHard('Super Hard', Color(0xFFDE63FB)),
  nightmare('Nightmare', Color(0xFFE53935));

  final String label;
  final Color color;
  const Tier(this.label, this.color);
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
