import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CyberTheme {
  // Deep Void Backgrounds
  static const Color bgDeep = Color(0xFF05090D);
  static const Color bgSlate = Color(0xFF0F172A);
  
  // Functional Palette
  static const Color neonSafe = Color(0xFF00F0FF); // Cyan
  static const Color neonWarn = Color(0xFFFFB800); // Amber
  static const Color neonCrit = Color(0xFFFF2A6D); // Radical Red
  static const Color textMain = Color(0xFFE2E8F0);
  static const Color textDim = Color(0xFF64748B);

  static ThemeData get theme => ThemeData.dark().copyWith(
    scaffoldBackgroundColor: bgDeep,
    textTheme: TextTheme(
      displayLarge: GoogleFonts.syne(
        fontSize: 56, 
        fontWeight: FontWeight.bold, 
        color: textMain,
        letterSpacing: -1.5,
      ),
      displayMedium: GoogleFonts.spaceGrotesk(
        fontSize: 32, 
        fontWeight: FontWeight.bold, 
        color: textMain
      ),
      bodyLarge: GoogleFonts.spaceGrotesk(
        fontSize: 16, 
        color: textMain
      ),
      bodyMedium: GoogleFonts.jetBrainsMono(
        fontSize: 14, 
        color: neonSafe
      ),
      labelSmall: GoogleFonts.jetBrainsMono(
        fontSize: 10, 
        color: textDim, 
        letterSpacing: 2.0
      ),
    ),
  );
}

// Reusable Glass Container
class CyberGlass extends StatelessWidget {
  final Widget child;
  final double opacity;
  final Color? tint;

  const CyberGlass({
    super.key, 
    required this.child, 
    this.opacity = 0.05,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: (tint ?? Colors.white).withValues(alpha: opacity),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1), 
              width: 1
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.1),
                Colors.white.withValues(alpha: 0.02),
              ],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}