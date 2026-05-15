import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── DRIVORA PREMIUM DARK AUTOMOTIVE PALETTE ──
  static const Color background       = Color(0xFF080B12);   // Deep cockpit black
  static const Color surface          = Color(0xFF0D1018);   // Card surface
  static const Color surfaceElevated  = Color(0xFF131A25);   // Raised panels
  static const Color panel            = Color(0xFF101520);   // Main panels

  // Typography
  static const Color textPrimary      = Color(0xFFF0F4FF);
  static const Color textSecondary    = Color(0xFF6B7A99);
  static const Color textMuted        = Color(0xFF2E3850);

  // ── DRIVORA ACCENT PALETTE ──
  static const Color accentBlue       = Color(0xFF2979FF);   // Primary electric blue
  static const Color accentBlueLight  = Color(0xFF4D9FFF);   // Lighter blue for text
  static const Color accentCyan       = Color(0xFF00E5FF);   // HUD cyan
  static const Color accentGreen      = Color(0xFF00E676);   // Safe / online green
  static const Color accentAmber      = Color(0xFFFFAB00);   // Warning amber
  static const Color accentRed        = Color(0xFFFF1744);   // Danger red
  static const Color accentPurple     = Color(0xFF7C4DFF);   // Analytics purple

  // ── GLOW COLOURS ──
  static Color get glowBlue    => accentBlue.withOpacity(0.30);
  static Color get glowCyan    => accentCyan.withOpacity(0.25);
  static Color get glowGreen   => accentGreen.withOpacity(0.25);
  static Color get glowAmber   => accentAmber.withOpacity(0.28);
  static Color get glowRed     => accentRed.withOpacity(0.32);

  // ── BORDERS ──
  static const Color border        = Color(0x1AFFFFFF);
  static const Color borderStrong  = Color(0x33FFFFFF);
  static const Color borderBlue    = Color(0x332979FF);

  // ── SHADOWS ──
  static List<BoxShadow> get shadow => [
    BoxShadow(color: Colors.black.withOpacity(0.55), blurRadius: 24, offset: const Offset(0, 6)),
    BoxShadow(color: Colors.black.withOpacity(0.3),  blurRadius: 6,  offset: const Offset(0, 2)),
  ];

  static List<BoxShadow> get shadowLg => [
    BoxShadow(color: Colors.black.withOpacity(0.75), blurRadius: 56, offset: const Offset(0, 14)),
    BoxShadow(color: Colors.black.withOpacity(0.4),  blurRadius: 12, offset: const Offset(0, 4)),
  ];

  static List<BoxShadow> neonShadow(Color color, {double intensity = 1.0}) => [
    BoxShadow(color: color.withOpacity(0.45 * intensity), blurRadius: 20),
    BoxShadow(color: color.withOpacity(0.20 * intensity), blurRadius: 40),
  ];

  static List<BoxShadow> cardShadow(Color accentColor) => [
    BoxShadow(color: accentColor.withOpacity(0.08), blurRadius: 24, offset: const Offset(0, 4)),
    BoxShadow(color: Colors.black.withOpacity(0.5),  blurRadius: 16, offset: const Offset(0, 4)),
  ];

  // ── GRADIENTS ──
  static LinearGradient get backgroundGradient => const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF080B12), Color(0xFF060810)],
  );

  static LinearGradient get headerGradient => const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0D1018), Color(0xFF0A0E18)],
  );

  static LinearGradient get blueGradient => const LinearGradient(
    colors: [Color(0xFF2979FF), Color(0xFF1565C0)],
  );

  static LinearGradient get redGradient => const LinearGradient(
    colors: [Color(0xFFFF1744), Color(0xFFD50000)],
  );

  static LinearGradient get greenGradient => const LinearGradient(
    colors: [Color(0xFF00E676), Color(0xFF00BFA5)],
  );

  static LinearGradient cardGradient(Color accent) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      accent.withOpacity(0.06),
      Colors.transparent,
    ],
  );

  // ── STATUS COLORS ──
  static Color statusColor(int level) {
    switch (level) {
      case 2:  return accentRed;
      case 1:  return accentAmber;
      default: return accentGreen;
    }
  }

  // ── THEME ──
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: accentBlue,
      colorScheme: ColorScheme.fromSeed(
        brightness: Brightness.dark,
        seedColor: accentBlue,
        background: background,
        surface: surface,
        onSurface: textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.orbitron(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: textPrimary,
          letterSpacing: 2.5,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.orbitron(color: textPrimary, fontWeight: FontWeight.w800),
        displayMedium: GoogleFonts.rajdhani(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 28),
        headlineLarge: GoogleFonts.orbitron(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 20),
        headlineMedium: GoogleFonts.rajdhani(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 20),
        headlineSmall: GoogleFonts.rajdhani(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
        bodyLarge: GoogleFonts.rajdhani(color: textPrimary, fontSize: 16),
        bodyMedium: GoogleFonts.rajdhani(color: textSecondary, fontSize: 14),
        labelSmall: GoogleFonts.rajdhani(
          color: textSecondary,
          fontSize: 8,
          letterSpacing: 1.8,
          fontWeight: FontWeight.w700,
        ),
      ),
      dividerColor: const Color(0xFF1A2030),
      cardColor: surface,
    );
  }

  // ── COMPATIBILITY ALIASES ──
  static ThemeData get lightTechTheme => darkTheme;
  static const Color lightTechTheme_compat = background;

  static const Color primaryNeon    = accentCyan;
  static const Color secondaryBlue  = accentBlue;
  static const Color successGreen   = accentGreen;
  static const Color warningYellow  = accentAmber;
  static const Color dangerRed      = accentRed;
  static const Color darkBackground = background;
  static const Color darkSurface    = surface;
  static const Color cardBackground = panel;
}