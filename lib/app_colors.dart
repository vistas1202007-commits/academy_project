import 'package:flutter/material.dart';

/// App ke saare colors ek jagah. Screens apne local colors nahi banayenge,
/// yahi file use karenge.
class AppColors {
  AppColors._();

  // ---------------- Brand (open screen / login ka aurora) ----------------

  /// Raat ka aasmaan, dark backgrounds
  static const Color night = Color(0xFF05141C);

  /// Aurora ki chamakti green line, dark bg par highlight
  static const Color aurora = Color(0xFF3EE0A0);

  /// Aurora ka gehra teal hissa
  static const Color teal = Color(0xFF14919B);

  // ---------------- App (andar ki screens) ----------------

  /// AppBar, primary buttons, headers
  static const Color appPrimary = Color(0xFF0B4F55);

  /// FAB, secondary highlights
  static const Color appAccent = Color(0xFF1FA383);

  /// Halka screen background, input fill
  static const Color appBackground = Color(0xFFF3F8F7);

  /// Card / sheet ka surface
  static const Color surface = Colors.white;

  static const Color textDark = Color(0xFF12292E);
  static const Color textMuted = Color(0xFF5F7B7A);
  static const Color border = Color(0xFFE1ECEA);

  // ---------------- Andar ki screens ka halka aurora ----------------

  /// Content ke upar wala aurora wash (neeche appBackground me ghulta hai)
  static const Color washTop = Color(0xFFD3EDE6);

  /// Stat card ke icon chip ka mint gradient
  static const Color mintChipStart = Color(0xFFE3F5EF);
  static const Color mintChipEnd = Color(0xFFC9EBDF);

  /// App bar / welcome card ki halki aurora ribbon
  static const Color ribbon = Color(0x2E3EE0A0);

  // ---------------- Semantic ----------------

  /// Paid, present, completed, selected
  static const Color success = Color(0xFF1FA383);

  /// Fees pending, low attendance jaisi cheezein. Status chips ke liye nahi.
  static const Color warning = Color(0xFFD99A2B);

  /// Dropped, absent, rejected, delete, errors
  static const Color danger = Color(0xFFB5524A);
}
