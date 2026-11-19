import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palette BeCoach: grafite con accento blu acciaio.
class BC {
  static const graphite = Color(0xFF334155); // grigio ardesia con nota blu
  static const ink = Color(0xFF16181D);
  static const steel = Color(0xFF3F5F7F);
  static const steelDark = Color(0xFF2E4862);
  static const steelTint = Color(0xFFE6ECF1);
  static const steelLight = Color(0xFFA3B4C5);
  static const muted = Color(0xFF5C6068);
  static const body = Color(0xFF3A3E45);
  static const ground = Color(0xFFF4F5F6);
  static const surface = Colors.white;
  static const border = Color(0xFFE2E4E7);
  static const subtle = Color(0xFFF7F8F9);
  static const avatar = Color(0xFFE9ECEF);
  static const disabled = Color(0xFF9A9DA3);
  static const warnFg = Color(0xFF8A4300);
  static const warnBg = Color(0xFFFBEEDD);
  static const danger = Color(0xFFB3261E);
}

ThemeData buildTheme() {
  final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
  final text = GoogleFonts.interTextTheme(base.textTheme)
      .apply(bodyColor: BC.ink, displayColor: BC.ink);
  final radius10 = BorderRadius.circular(10);

  return base.copyWith(
    colorScheme: const ColorScheme.light(
      primary: BC.graphite,
      onPrimary: Colors.white,
      secondary: BC.steel,
      onSecondary: Colors.white,
      surface: BC.surface,
      onSurface: BC.ink,
      error: BC.danger,
    ),
    scaffoldBackgroundColor: BC.ground,
    textTheme: text,
    dividerColor: BC.border,
    appBarTheme: AppBarTheme(
      backgroundColor: BC.ground,
      foregroundColor: BC.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.inter(
          fontSize: 20, fontWeight: FontWeight.w700, color: BC.ink),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: radius10,
          borderSide: const BorderSide(color: BC.border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: radius10,
          borderSide: const BorderSide(color: BC.border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: radius10,
          borderSide: const BorderSide(color: BC.steel, width: 1.5)),
      labelStyle: const TextStyle(color: BC.muted),
      hintStyle: const TextStyle(color: BC.disabled),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: BC.graphite,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: radius10),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: BC.ink,
        side: const BorderSide(color: BC.border),
        minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(borderRadius: radius10),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: BC.steel,
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: BC.graphite,
      foregroundColor: Colors.white,
      elevation: 1,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: BC.steelTint,
      elevation: 0,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final sel = states.contains(WidgetState.selected);
        return GoogleFonts.inter(
          fontSize: 11,
          fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
          color: sel ? BC.steel : BC.muted,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final sel = states.contains(WidgetState.selected);
        return IconThemeData(color: sel ? BC.steel : BC.muted, size: 24);
      }),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: BC.graphite,
      behavior: SnackBarBehavior.floating,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : null),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? BC.steel : null),
    ),
    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: BC.steel),
  );
}
