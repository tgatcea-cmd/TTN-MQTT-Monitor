import 'package:flutter/material.dart';

class AppTheme {
  // ---------------------------------------------------------------------------
  // 1. Color Palette (The "Swiss Spa" System)
  // ---------------------------------------------------------------------------
  
  // Base Tones
  static const Color background = Color(0xFFFBFBF9); // Warm Alabaster
  static const Color surface = Color(0xFFFFFFFF);    // Pure White
  static const Color surfaceSubtle = Color(0xFFF4F4F5); // Very light grey for hover/inputs
  
  // Text & Content Tones
  static const Color primary = Color(0xFF18181B);    // Deep Charcoal (Zinc 950)
  static const Color secondary = Color(0xFF71717A);  // Muted Grey (Zinc 500)
  static const Color tertiary = Color(0xFFA1A1AA);   // Light Grey (Zinc 400)
  static const Color border = Color(0xFFE4E4E7);     // Subtle Border (Zinc 200)

  // Functional Palette (Refined)
  // We avoid "Traffic Light" colors. We use sophisticated, slightly desaturated tones.
  static const Color accent = Color(0xFF0F766E);     // Deep Teal (Calm, Professional)
  static const Color error = Color(0xFFBE123C);      // Rose (Not bright red)
  static const Color success = Color(0xFF047857);    // Emerald (Natural green)
  static const Color warning = Color(0xFFB45309);    // Amber (Earthy orange)

  // ---------------------------------------------------------------------------
  // 2. Theme Definition
  // ---------------------------------------------------------------------------
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter', 
      
      // Global Color Scheme
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      dividerColor: border,
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

      // AppBar: Minimalist, "Floating" feel implies logic elsewhere, 
      // but here we set the base transparent/flat style.
      appBarTheme: const AppBarTheme(
        backgroundColor: background, // Blends with scaffold
        foregroundColor: primary,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          color: primary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5, // Tight editorial spacing
        ),
        iconTheme: IconThemeData(color: primary, size: 20),
      ),

      // Card: Flat, bordered, clean. No default shadows.
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16), // Consistent 16px radius
          side: const BorderSide(color: border, width: 1),
        ),
      ),

      // Buttons: Sophisticated geometry
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 14,
            letterSpacing: 0.2,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          backgroundColor: Colors.transparent,
          elevation: 0,
          side: const BorderSide(color: border),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 14,
            letterSpacing: 0.2,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: secondary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),

      // Inputs: Clean, spacious, minimal borders
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.all(16),
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
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        labelStyle: const TextStyle(color: secondary, fontSize: 13),
        hintStyle: const TextStyle(color: tertiary, fontSize: 13),
        floatingLabelStyle: const TextStyle(color: accent, fontWeight: FontWeight.w500),
      ),

      // Tooltip: Dark, high contrast, refined
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: primary,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),

      // Dividers
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Typography Styles (Helpers for consistent usage)
  // ---------------------------------------------------------------------------
  
  static const TextStyle headingLarge = TextStyle(
    fontFamily: 'Inter',
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: primary,
    letterSpacing: -0.8,
    height: 1.2,
  );

  static const TextStyle headingMedium = TextStyle(
    fontFamily: 'Inter',
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: primary,
    letterSpacing: -0.5,
    height: 1.3,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: 'Inter',
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: secondary,
    letterSpacing: 0.5, // Wide spacing for uppercase labels
    height: 1.4,
  );

  static const TextStyle valueLarge = TextStyle(
    fontFamily: 'Inter', // Or a monospaced variant if available like 'JetBrains Mono'
    fontSize: 32,
    fontWeight: FontWeight.w400, // Light weight for elegance
    color: primary,
    letterSpacing: -1.0,
  );
}