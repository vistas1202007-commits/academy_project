import 'package:flutter/material.dart';

/// All app colors in one place. Screens should not define their own local
/// colors; they use this file.
class AppColors {
  AppColors._();

  // ---------------- Brand (open screen / login aurora) ----------------

  /// Night sky, dark backgrounds
  static const Color night = Color(0xFF05141C);

  /// Aurora's bright green line, highlight on dark backgrounds
  static const Color aurora = Color(0xFF3EE0A0);

  /// Aurora's deep teal part
  static const Color teal = Color(0xFF14919B);

  // ---------------- App (inner screens) ----------------

  /// AppBar, primary buttons, headers
  static const Color appPrimary = Color(0xFF0B4F55);

  /// FAB, secondary highlights
  static const Color appAccent = Color(0xFF1FA383);

  /// Light screen background, input fill
  static const Color appBackground = Color(0xFFF3F8F7);

  /// Card / sheet surface
  static const Color surface = Colors.white;

  static const Color textDark = Color(0xFF12292E);
  static const Color textMuted = Color(0xFF5F7B7A);
  static const Color border = Color(0xFFE1ECEA);

  // ---------------- Soft aurora for inner screens ----------------

  /// Aurora wash above the content (fades into appBackground below)
  static const Color washTop = Color(0xFFD3EDE6);

  /// Mint gradient for the stat card icon chip
  static const Color mintChipStart = Color(0xFFE3F5EF);
  static const Color mintChipEnd = Color(0xFFC9EBDF);

  /// Faint aurora ribbon for the app bar / welcome card
  static const Color ribbon = Color(0x2E3EE0A0);

  // ---------------- Semantic ----------------

  /// Paid, present, completed, selected
  static const Color success = Color(0xFF1FA383);

  /// Things like fees pending, low attendance. Not for status chips.
  static const Color warning = Color(0xFFD99A2B);

  /// Dropped, absent, rejected, delete, errors
  static const Color danger = Color(0xFFB5524A);
}
