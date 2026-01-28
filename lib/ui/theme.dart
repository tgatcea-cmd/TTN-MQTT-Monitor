// ui/theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  // ---------------------------------------------------------------------------
  // 1. The "Swiss Spa" Color System (Zinc-based)
  // ---------------------------------------------------------------------------
  
  // Backgrounds
  static const Color background = Color(0xFFFAFAFA); // Zinc 50 (The canvas)
  static const Color surface = Color(0xFFFFFFFF);    // White (The cards)
  static const Color surfaceSubtle = Color(0xFFF4F4F5); // Zinc 100 (Inputs/Hovers)
  
  // Content
  static const Color primary = Color(0xFF18181B);    // Zinc 950 (High contrast text)
  static const Color secondary = Color(0xFF71717A);  // Zinc 500 (Supporting text)
  static const Color tertiary = Color(0xFFA1A1AA);   // Zinc 400 (Inactive/Hints)
  
  // Structure
  static const Color border = Color(0xFFE4E4E7);     // Zinc 200 (The defining line)
  static const Color divider = Color(0xFFEEEEF0);    // Subtle separation

  // Status & Accents (Desaturated, Professional)
  static const Color accent = Color(0xFF0D9488);     // Teal 600 (Primary Action)
  static const Color error = Color(0xFFBE123C);      // Rose 700
  static const Color success = Color(0xFF047857);    // Emerald 700
  static const Color warning = Color(0xFFB45309);    // Amber 700

  // ---------------------------------------------------------------------------
  // 2. The Spacing Grid (4pt system)
  // ---------------------------------------------------------------------------
  static const double spacing4 = 4.0;
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;
  static const double spacing48 = 48.0;

  // ---------------------------------------------------------------------------
  // 3. Theme Definition
  // ---------------------------------------------------------------------------
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      dividerColor: divider,
      
      // Color Scheme
      colorScheme: const ColorScheme.light(
        primary: primary,
        onPrimary: Colors.white,
        secondary: accent,
        onSecondary: Colors.white,
        surface: surface,
        onSurface: primary,
        error: error,
        onError: Colors.white,
        outline: border,
      ),

      // Typography (Editorial Style)
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32, fontWeight: FontWeight.w600, letterSpacing: -1.0, color: primary, height: 1.2
        ),
        headlineSmall: TextStyle(
          fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.5, color: primary, height: 1.3
        ),
        titleMedium: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: -0.2, color: primary, height: 1.4
        ),
        bodyMedium: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.0, color: secondary, height: 1.5
        ),
        labelSmall: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: secondary, height: 1.4
        ),
      ),

      // AppBar (Invisible Structure)
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: primary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          color: primary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: primary, size: 20),
      ),

      // Cards (Flat, Bordered, No Shadow)
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border, width: 1),
        ),
      ),

      // Buttons (Geometric, Tactile)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, fontFamily: 'Inter'),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: primary,
          elevation: 0,
          side: const BorderSide(color: border),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, fontFamily: 'Inter'),
        ),
      ),

      // Inputs (Architectural)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.all(16), // Spacious
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5), // Focus = Dark Zinc
        ),
        hintStyle: const TextStyle(color: tertiary, fontSize: 13),
        labelStyle: const TextStyle(color: secondary, fontSize: 13, fontWeight: FontWeight.w500),
      ),
      
      dividerTheme: const DividerThemeData(
        color: divider,
        thickness: 1,
        space: 1,
      ),
    );
  }
}