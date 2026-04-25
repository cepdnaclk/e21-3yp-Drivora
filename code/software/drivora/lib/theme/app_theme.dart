import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
<<<<<<< HEAD
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
=======
  // ── PREMIUM DARK AUTOMOTIVE PALETTE ──
  static const Color background    = Color(0xFF0A0A0F);   // Near-black cockpit
  static const Color surface       = Color(0xFF12121A);   // Card surface
  static const Color surfaceElevated = Color(0xFF1C1C28); // Raised panels
  static const Color panel         = Color(0xFF1A1A26);   // Main panels

  static const Color textPrimary   = Color(0xFFF0F0FF);
  static const Color textSecondary = Color(0xFF8888AA);
  static const Color textMuted     = Color(0xFF444466);

  // Accent palette – electric & warm
  static const Color accentBlue    = Color(0xFF2979FF);   // Electric blue
  static const Color accentCyan    = Color(0xFF00E5FF);   // HUD cyan
  static const Color accentGreen   = Color(0xFF00E676);   // Safe green
  static const Color accentAmber   = Color(0xFFFFAB00);   // Warning amber
  static const Color accentRed     = Color(0xFFFF1744);   // Danger red
  static const Color accentPurple  = Color(0xFF7C4DFF);   // Data purple

  // Glow colours (semi-transparent versions used for shadows)
  static Color get glowBlue    => accentBlue.withOpacity(0.35);
  static Color get glowCyan    => accentCyan.withOpacity(0.30);
  static Color get glowGreen   => accentGreen.withOpacity(0.30);
  static Color get glowAmber   => accentAmber.withOpacity(0.30);
  static Color get glowRed     => accentRed.withOpacity(0.35);

  // Borders
  static const Color border        = Color(0x22FFFFFF);
  static const Color borderStrong  = Color(0x44FFFFFF);

  // ── SHADOWS ──
  static List<BoxShadow> get shadow => [
    BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 4)),
    BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 6,  offset: const Offset(0, 1)),
  ];

  static List<BoxShadow> get shadowLg => [
    BoxShadow(color: Colors.black.withOpacity(0.7), blurRadius: 50, offset: const Offset(0, 12)),
    BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 3)),
  ];

  static List<BoxShadow> neonShadow(Color color, {double intensity = 1.0}) => [
    BoxShadow(color: color.withOpacity(0.5 * intensity), blurRadius: 20),
    BoxShadow(color: color.withOpacity(0.25 * intensity), blurRadius: 40),
  ];

  // ── GRADIENTS ──
  static LinearGradient get backgroundGradient => const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0D0D18), Color(0xFF080810)],
  );

  static LinearGradient cardGradient(Color accent) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      accent.withOpacity(0.08),
      Colors.transparent,
    ],
  );

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
        titleTextStyle: GoogleFonts.rajdhani(
          fontSize: 16,
          fontWeight: FontWeight.w700,
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)
          color: textPrimary,
          letterSpacing: 3,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      textTheme: TextTheme(
<<<<<<< HEAD
        displayLarge: GoogleFonts.orbitron(color: textPrimary, fontWeight: FontWeight.bold),
        headlineMedium: GoogleFonts.rajdhani(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 22),
        bodyLarge: GoogleFonts.rajdhani(color: textPrimary, fontSize: 16),
        bodyMedium: GoogleFonts.rajdhani(color: textSecondary, fontSize: 14),
        labelSmall: GoogleFonts.orbitron(color: textSecondary, fontSize: 9, letterSpacing: 2),
=======
        displayLarge: GoogleFonts.rajdhani(color: textPrimary, fontWeight: FontWeight.w700),
        headlineMedium: GoogleFonts.rajdhani(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 22),
        bodyLarge: GoogleFonts.rajdhani(color: textPrimary, fontSize: 16),
        bodyMedium: GoogleFonts.rajdhani(color: textSecondary, fontSize: 14),
        labelSmall: GoogleFonts.rajdhani(color: textSecondary, fontSize: 9, letterSpacing: 2),
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)
      ),
    );
  }

<<<<<<< HEAD
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
=======
  // ── COMPATIBILITY ALIASES (for legacy code) ──
  static const Color lightTechTheme_compat = background; // use darkTheme instead
  static ThemeData get lightTechTheme => darkTheme;

  static const Color primaryNeon    = accentCyan;
  static const Color secondaryBlue  = accentBlue;
  static const Color successGreen   = accentGreen;
  static const Color warningYellow  = accentAmber;
  static const Color dangerRed      = accentRed;
  static const Color darkBackground = background;
  static const Color darkSurface    = surface;
  static const Color cardBackground = panel;
}
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)
