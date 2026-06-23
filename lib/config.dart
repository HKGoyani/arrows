import 'package:flutter/material.dart';

/// ===========================================================================
/// Design tokens & geometry — sampled 1:1 from the source video / HTML build.
/// ===========================================================================
class AppColors {
  static const bg = Color(0xFFFFFFFF); // screen + board background
  static const arrow = Color(0xFF11142E); // default arrow (navy)
  static const arrowBlue = Color(0xFF586FFE); // arrow while firing/leaving
  static const red = Color(0xFFF23A5C); // clashed arrow + filled heart
  static const ink = Color(0xFF2B2E4F); // logo + headings
  static const blue = Color(0xFF5B6AF9); // "Level N" + progress fill
  static const blueSoft = Color(0xFF0EADF0); // difficulty subtitle
  static const heartEmpty = Color(0xFFD7DAF5);
  static const btnBg = Color(0xFFD9DCF7); // round top-bar buttons
  static const btnInk = Color(0xFF4B5076);
  static const dot = Color(0xFFE7E8F3); // board grid dots
  static const navBg = Color(0xFFECEEF7);
  static const navPill = Color(0xFFCFD4F4);
  static const navInk = Color(0xFF44486B);
  static const lock = Color(0xFFC6C9D8);
  static const progressTrack = Color(0xFFE7E9F6);
  static final ripple = const Color(0xFF969AA8); // animated alpha applied in painter

  // UI chrome (home / settings / streak)
  static const muted = Color(0xFF8C90A6); // secondary text
  static const cardBorder = Color(0xFFEDEFF7); // soft card outline
  static const lavender = Color(0xFFAFB1FC); // soft accent (Play pill bg alt)
  static const flame = Color(0xFFFF8A3D); // streak flame
  static const surface = Color(0xFFF6F7FC); // tinted icon backings
}

/// Board is laid out in "cell units" then scaled to fit the screen.
class Cfg {
  static const double cell = 60; // grid pitch
  static const double margin = 42; // board margin (heads/caps don't clip)
  static const double stroke = 11; // arrow shaft width (~0.18*cell)
  static const double headLen = 27; // arrowhead length (along dir)
  static const double headHalf = 14; // arrowhead half-width (full 28)
  static const double headBase = 3; // base set back so it overlaps the shaft for a clean join
  static const double headStroke = 3; // soft head-corner rounding
  static const double dotR = 4; // grid dot radius
  static const double rippleR = 1.7 * 60; // tap ripple max radius
  static const double hitBand = 30; // tap tolerance (cell units ≈ half a cell — forgiving;
  // the hit-test still selects the NEAREST arrow, so it stays accurate)

  // fit-to-screen
  static const double targetCell = 40; // low levels render near this px/cell
  static const double widthFraction = 0.72; // board ≈ 72% of screen width
  static const double heightFraction = 0.95;

  // fly-off physics — slower, graceful exit (fly-offs run concurrently so play stays snappy)
  static const int flyHoldMs = 140;
  static const int flyDurMs = 820;
  static const double flyDist = 42 * 60; // straight-track extension (off-screen)
}
