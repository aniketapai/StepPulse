import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App theme configuration for StepPulse
/// Inspired by modern minimal fitness app design
class AppTheme {
  AppTheme._();

  // Primary mint/teal background color
  static const Color mintBackground = Color(0xFFD5E8E3);
  static const Color mintBackgroundDark = Color(0xFF1A2F2A);

  // Pure white for cards
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color cardDark = Color(0xFF1E2D29);

  // Black for accents and selected items
  static const Color accentBlack = Color(0xFF1A1A1A);
  static const Color accentWhite = Color(0xFFFFFFFF);

  // Soft colors from reference
  static const Color softPink = Color(0xFFF5D5D5);
  static const Color softMint = Color(0xFFD5E8E3);
  static const Color softBlue = Color(0xFFD5E0E8);

  // Text colors
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B7B76);
  static const Color textLight = Colors.white;

  /// Light theme configuration
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: accentBlack,
        secondary: mintBackground,
        surface: cardWhite,
        onSurface: textPrimary,
        onPrimary: textLight,
      ),
      scaffoldBackgroundColor: mintBackground,
      cardTheme: CardThemeData(
        color: cardWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        shadowColor: Colors.black.withValues(alpha: 0.08),
      ),
      textTheme: _buildTextTheme(Brightness.light),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accentBlack,
        thumbColor: accentBlack,
        overlayColor: accentBlack.withValues(alpha: 0.1),
        inactiveTrackColor: accentBlack.withValues(alpha: 0.2),
        trackHeight: 6,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentBlack,
          foregroundColor: textLight,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      iconTheme: const IconThemeData(color: textPrimary, size: 24),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: accentBlack,
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: textLight,
          ),
        ),
        iconTheme: WidgetStateProperty.all(
          const IconThemeData(color: textLight, size: 22),
        ),
      ),
    );
  }

  /// Dark theme configuration
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: accentWhite,
        secondary: mintBackgroundDark,
        surface: cardDark,
        onSurface: textLight,
        onPrimary: textPrimary,
      ),
      scaffoldBackgroundColor: mintBackgroundDark,
      cardTheme: CardThemeData(
        color: cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      textTheme: _buildTextTheme(Brightness.dark),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textLight,
        ),
        iconTheme: const IconThemeData(color: textLight),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accentWhite,
        thumbColor: accentWhite,
        overlayColor: accentWhite.withValues(alpha: 0.1),
        inactiveTrackColor: accentWhite.withValues(alpha: 0.2),
        trackHeight: 6,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentWhite,
          foregroundColor: textPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      iconTheme: const IconThemeData(color: textLight, size: 24),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: accentWhite,
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: textPrimary,
          ),
        ),
        iconTheme: WidgetStateProperty.all(
          const IconThemeData(color: textPrimary, size: 22),
        ),
      ),
    );
  }

  /// Build text theme with Google Fonts - Inter
  static TextTheme _buildTextTheme(Brightness brightness) {
    final color = brightness == Brightness.light ? textPrimary : textLight;
    final secondaryColor = brightness == Brightness.light
        ? textSecondary
        : textLight.withValues(alpha: 0.7);

    return TextTheme(
      // Large display numbers (step count)
      displayLarge: GoogleFonts.inter(
        fontSize: 64,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: -2,
        height: 1,
      ),
      displayMedium: GoogleFonts.inter(
        fontSize: 48,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: -1.5,
      ),
      displaySmall: GoogleFonts.inter(
        fontSize: 36,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: -1,
      ),
      // Headlines
      headlineLarge: GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      // Titles
      titleLarge: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      // Body text
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: color,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: secondaryColor,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: secondaryColor,
      ),
      // Labels
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: color,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: secondaryColor,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: secondaryColor,
        letterSpacing: 0.5,
      ),
    );
  }

  /// Card decoration for floating white cards
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: cardWhite,
    borderRadius: BorderRadius.circular(24),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.06),
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
    ],
  );

  /// Pill button decoration (for selected state)
  static BoxDecoration get pillButtonDecoration => BoxDecoration(
    color: accentBlack,
    borderRadius: BorderRadius.circular(14),
  );

  /// Soft colored card backgrounds
  static List<Color> get softColors => [softPink, softMint, softBlue];
}
