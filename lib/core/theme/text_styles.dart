import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'color_scheme.dart';

class SkorioTextStyles {
  static TextStyle displayLg = GoogleFonts.outfit(
    fontSize: 48,
    fontWeight: FontWeight.w800,
    height: 56 / 48,
    letterSpacing: -1.92,
    color: SkorioColors.onSurface,
  );

  static TextStyle headlineLg = GoogleFonts.outfit(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 40 / 32,
    letterSpacing: -0.64,
    color: SkorioColors.onSurface,
  );

  static TextStyle headlineMd = GoogleFonts.outfit(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 32 / 24,
    color: SkorioColors.onSurface,
  );

  static TextStyle bodyLg = GoogleFonts.outfit(
    fontSize: 18,
    fontWeight: FontWeight.w400,
    height: 28 / 18,
    color: SkorioColors.onSurfaceVariant,
  );

  static TextStyle bodyMd = GoogleFonts.outfit(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 24 / 16,
    color: SkorioColors.onSurfaceVariant,
  );

  static TextStyle labelMd = GoogleFonts.outfit(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 20 / 14,
    letterSpacing: 0.28,
    color: SkorioColors.onSurface,
  );

  static TextStyle labelSm = GoogleFonts.outfit(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 16 / 12,
    color: SkorioColors.outline,
  );
}
