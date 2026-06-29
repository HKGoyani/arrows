import 'package:flutter/material.dart';
import 'prefs.dart';

/// ===========================================================================
/// Design tokens & geometry. Colors switch between light/dark based on
/// Prefs.darkMode — every getter re-reads the pref so toggling is instant.
/// ===========================================================================
class AppColors {
  static bool get _d => Prefs.darkMode;

  static Color get bg => _d ? const Color(0xFF1A1D2E) : const Color(0xFFFFFFFF);
  static Color get arrow => _d ? const Color(0xFFE0E4F0) : const Color(0xFF11142E);
  static const arrowBlue = Color(0xFF586FFE);
  static const red = Color(0xFFF23A5C);
  static const heart = Color(0xFFFD4A5C);
  static Color get ink => _d ? const Color(0xFFAEB6E1) : const Color(0xFF2B2E4F);
  static const blue = Color(0xFF667CFF);
  static const blueSoft = Color(0xFF0EADF0);
  static Color get heartEmpty => _d ? const Color(0xFF3A3F5E) : const Color(0xFFD7DAF5);
  static Color get btnBg => _d ? const Color(0xFF2A2E45) : const Color(0xFFD9DCF7);
  static Color get btnInk => _d ? const Color(0xFFA0A8C8) : const Color(0xFF4B5076);
  static Color get dot => _d ? const Color(0xFF2A2E45) : const Color(0xFFE7E8F3);
  static Color get navBg => _d ? const Color(0xFF2A2F4A) : const Color(0xFFECEEF7);
  static Color get navPill => _d ? const Color(0xFF3A3F5E) : const Color(0xFFCFD4F4);
  static Color get navInk => _d ? const Color(0xFFAEB6E1) : const Color(0xFF44486B);
  static Color get lock => _d ? const Color(0xFF4A4F68) : const Color(0xFFC6C9D8);
  static Color get progressTrack => _d ? const Color(0xFF2A2E45) : const Color(0xFFE7E9F6);
  static Color get ripple => _d ? const Color(0xFF606888) : const Color(0xFF969AA8);

  // UI chrome
  static Color get muted => _d ? const Color(0xFFAEB6E1) : const Color(0xFF8C90A6);
  static Color get cardBorder => _d ? const Color(0xFF2A2F4A) : const Color(0xFFEDEFF7);
  static Color get lavender => _d ? const Color(0xFF6568A0) : const Color(0xFFAFB1FC);
  static const flame = Color(0xFFFF8A3D);
  static Color get surface => _d ? const Color(0xFF2A2F4A) : const Color(0xFFECEEF7);
}

/// Board is laid out in "cell units" then scaled to fit the screen.
class Cfg {
  static const double cell = 60;
  static const double margin = 42;
  static const double stroke = 11;
  static const double headLen = 27;
  static const double headHalf = 14;
  static const double headBase = 3;
  static const double headStroke = 3;
  static const double dotR = 4;
  static const double rippleR = 1.7 * 60;
  static const double hitBand = 30;

  static const double targetCell = 40;
  static const double widthFraction = 0.72;
  static const double heightFraction = 0.95;

  static const int flyHoldMs = 140;
  static const int flyDurMs = 820;
  static const double flyDist = 42 * 60;
}

