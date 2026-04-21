import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryNeon = Color(0xFF00F5D4);
  static const Color secondaryBlue = Color(0xFF4CC9F0);
  static const Color successGreen = Color(0xFF06D6A0);
  static const Color warningYellow = Color(0xFFFFBE0B);
  static const Color dangerRed = Color(0xFFFF595A);
  static const Color darkBackground = Color(0xFF050A10);
  static const Color darkSurface = Color(0xFF0A121D);
  static const Color cardBackground = Color(0xFF141D2B);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      primaryColor: primaryNeon,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryNeon,
        brightness: Brightness.dark,
        surface: darkSurface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: darkSurface,
        titleTextStyle: GoogleFonts.robotoMono(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      textTheme: TextTheme(
        headlineMedium: GoogleFonts.robotoMono(fontWeight: FontWeight.bold, color: Colors.white),
        bodyMedium: GoogleFonts.roboto(color: Colors.white70),
      ),
    );
  }
}
