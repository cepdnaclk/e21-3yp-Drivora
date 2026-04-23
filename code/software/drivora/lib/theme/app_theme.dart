import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Apple-style High-Tech Light Palette
  static const Color background = Color(0xFFF5F5F7);
  static const Color panel = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1D1D1F);
  static const Color textSecondary = Color(0xFF6E6E73);
  
  static const Color accentBlue = Color(0xFF0A84FF);
  static const Color accentGreen = Color(0xFF30D158);
  static const Color accentAmber = Color(0xFFFF9F0A);
  static const Color accentRed = Color(0xFFFF3B30);
  
  static const Color border = Color(0x14000000); 

  static List<BoxShadow> get shadow => [
    BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 2)),
    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 1)),
  ];

  static List<BoxShadow> get shadowLg => [
    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 40, offset: const Offset(0, 8)),
    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
  ];

  static LinearGradient get techGradient => LinearGradient(
    colors: [panel, background],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get lightTechTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      primaryColor: accentBlue,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accentBlue,
        background: background,
        surface: panel,
        onSurface: textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: panel,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.orbitron(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: textPrimary,
          letterSpacing: 3,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.orbitron(color: textPrimary, fontWeight: FontWeight.bold),
        headlineMedium: GoogleFonts.rajdhani(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 22),
        bodyLarge: GoogleFonts.rajdhani(color: textPrimary, fontSize: 16),
        bodyMedium: GoogleFonts.rajdhani(color: textSecondary, fontSize: 14),
        labelSmall: GoogleFonts.orbitron(color: textSecondary, fontSize: 9, letterSpacing: 2),
      ),
    );
  }

  // Maintaining aliases for compatibility
  static const Color primaryNeon = accentGreen;
  static const Color secondaryBlue = accentBlue;
  static const Color successGreen = accentGreen;
  static const Color warningYellow = accentAmber;
  static const Color dangerRed = accentRed;
  static const Color darkBackground = background;
  static const Color darkSurface = panel;
  static const Color cardBackground = panel;
  static ThemeData get darkTheme => lightTechTheme;
}
