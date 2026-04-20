import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Safety System Colors
  static const Color primaryNeon = Color(0xFF00F5D4); // Cyan
  static const Color secondaryBlue = Color(0xFF4CC9F0);
  static const Color accentPurple = Color(0xFF7209B7);
  
  // Status Colors
  static const Color successGreen = Color(0xFF06D6A0); // All clear
  static const Color warningYellow = Color(0xFFFFBE0B); // Caution
  static const Color dangerRed = Color(0xFFFF595A); // Critical
  
  // Background Colors
  static const Color darkBackground = Color(0xFF0a0e27);
  static const Color darkSurface = Color(0xFF1a2332);
  static const Color cardBackground = Color(0xFF242d3d);
  
  // Text Colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF88A0B5);
  static const Color textTertiary = Color(0xFF5A6F82);
  static const Color dividerColor = Color(0xFF3a4555);

  // Material Theme
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      primaryColor: primaryNeon,
      appBarTheme: AppBarTheme(
        backgroundColor: darkSurface,
        elevation: 1,
        centerTitle: false,
        titleTextStyle: GoogleFonts.roboto(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        iconTheme: const IconThemeData(color: primaryNeon),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: darkSurface,
        selectedItemColor: primaryNeon,
        unselectedItemColor: textSecondary,
        elevation: 8,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.robotoMono(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        displayMedium: GoogleFonts.robotoMono(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        headlineLarge: GoogleFonts.roboto(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        headlineMedium: GoogleFonts.roboto(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        headlineSmall: GoogleFonts.roboto(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        titleLarge: GoogleFonts.roboto(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: GoogleFonts.roboto(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        bodyMedium: GoogleFonts.roboto(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: textSecondary,
        ),
        bodySmall: GoogleFonts.roboto(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: textTertiary,
        ),
        labelLarge: GoogleFonts.roboto(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        labelMedium: GoogleFonts.roboto(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textSecondary,
        ),
        labelSmall: GoogleFonts.roboto(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: textTertiary,
        ),
      ),
      cardTheme: CardTheme(
        color: cardBackground,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      iconTheme: const IconThemeData(
        color: primaryNeon,
        size: 24,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryNeon, width: 2),
        ),
      ),
    );
  }

  static const List<BoxShadow> softShadow = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 8,
      spreadRadius: 0,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> neonGlow = [
    BoxShadow(
      color: primaryNeon,
      blurRadius: 20,
      spreadRadius: 0,
      offset: Offset(0, 0),
    ),
  ];
}
