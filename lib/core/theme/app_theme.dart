import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// App theme configuration for StepPulse
/// Nature-inspired earthy palette
class AppTheme {
  AppTheme._();

  // ========== EARTHY PALETTE ==========
  // Background — deepest dark green
  static const Color bgDark = Color(0xFF1B211A);

  // Card / surface — slightly lifted from bg
  static const Color cardSurface = Color(0xFF2A332A);

  // Primary accent — sage green
  static const Color accentGreen = Color(0xFF8BAE66);

  // Secondary accent — deeper olive
  static const Color accentOlive = Color(0xFF628141);

  // Warm cream — for primary text & highlights
  static const Color cream = Color(0xFFEBD5AB);

  // Muted sage — for secondary text
  static const Color mutedSage = Color(0xFFA0A890);

  // ========== LIGHT PALETTE ==========
  static const Color bgLight = Color(0xFFF5F2EC); // warm off-white
  static const Color cardLight = Color(0xFFFFFFFF); // pure white cards
  static const Color textDark = Color(0xFF2C3E2D); // dark olive for text
  static const Color textSecondaryLight = Color(0xFF5A6B52); // muted olive

  // ── Legacy aliases (kept so existing references still compile) ──
  static const Color mintBackground = bgDark;
  static const Color mintBackgroundDark = bgDark;
  static const Color cardWhite = cardSurface;
  static const Color cardDark = cardSurface;
  static const Color accentBlack = accentGreen;
  static const Color accentWhite = accentGreen;
  static const Color textPrimary = cream;
  static const Color textSecondary = mutedSage;
  static const Color textLight = cream;
  static const Color textSecondaryDark = mutedSage;

  // Soft accent tones (for badges, tags, category chips)
  static const Color softPink = Color(0xFF3A2E24); // warm brown
  static const Color softMint = Color(0xFF253024); // muted forest
  static const Color softBlue = Color(0xFF242D26); // gray-green

  static const Color softPinkDark = softPink;
  static const Color softMintDark = softMint;
  static const Color softBlueDark = softBlue;

  // ========== THEME-AWARE HELPERS ==========
  // With a single dark palette these always return the same value,
  // but we keep the API so every screen file compiles unchanged.

  /// Whether current context is dark mode
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Background color (scaffold)
  static Color bg(BuildContext context) => isDark(context) ? bgDark : bgLight;

  /// Card/surface color
  static Color cardColor(BuildContext context) =>
      isDark(context) ? cardSurface : cardLight;

  /// Accent color (buttons, icons, active elements)
  static Color accent(BuildContext context) =>
      isDark(context) ? accentGreen : accentOlive;

  /// Primary text color
  static Color textPrimaryC(BuildContext context) =>
      isDark(context) ? cream : textDark;

  /// Secondary text color
  static Color textSecondaryC(BuildContext context) =>
      isDark(context) ? mutedSage : textSecondaryLight;

  /// Subdued background (chips, tags, subtle sections)
  static Color subtleBg(BuildContext context) =>
      isDark(context) ? const Color(0xFF232B22) : const Color(0xFFECEAE4);

  /// Divider / border color
  static Color dividerColor(BuildContext context) => isDark(context)
      ? cream.withValues(alpha: 0.10)
      : textDark.withValues(alpha: 0.10);

  /// Grey shades for locked badges, disabled states
  static Color grey100(BuildContext context) =>
      isDark(context) ? const Color(0xFF222A21) : const Color(0xFFE8E6E0);
  static Color grey200(BuildContext context) =>
      isDark(context) ? const Color(0xFF2A332A) : const Color(0xFFD9D7D1);
  static Color grey300(BuildContext context) =>
      isDark(context) ? const Color(0xFF3A4539) : const Color(0xFFC0BEB8);
  static Color grey400(BuildContext context) =>
      isDark(context) ? const Color(0xFF5A6858) : const Color(0xFF9A9890);

  /// Card decoration (theme-aware)
  static BoxDecoration cardDecorationOf(BuildContext context) => BoxDecoration(
    color: isDark(context) ? cardSurface : cardLight,
    borderRadius: BorderRadius.circular(24),
    boxShadow: [
      BoxShadow(
        color: isDark(context)
            ? Colors.black.withValues(alpha: 0.35)
            : Colors.black.withValues(alpha: 0.06),
        blurRadius: isDark(context) ? 14 : 10,
        offset: const Offset(0, 4),
      ),
    ],
  );

  /// Bottom sheet / dialog background
  static Color sheetBg(BuildContext context) =>
      isDark(context) ? const Color(0xFF222B21) : const Color(0xFFF8F6F1);

  /// Navigation bar background
  static Color navBarBg(BuildContext context) =>
      isDark(context) ? const Color(0xFF151B14) : const Color(0xFFFFFFFF);

  /// Progress ring track color
  static Color ringTrack(BuildContext context) =>
      isDark(context) ? const Color(0xFF2E3A2D) : const Color(0xFFE0DDD6);

  // ========== THEME DATA ==========
  // Both light & dark produce the same earthy dark look.

  static ThemeData get _baseTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: accentGreen,
        secondary: accentOlive,
        surface: cardSurface,
        onSurface: cream,
        onPrimary: bgDark,
      ),
      scaffoldBackgroundColor: bgDark,
      cardTheme: CardThemeData(
        color: cardSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      textTheme: _buildTextTheme(),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: bgDark,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: cream,
        ),
        iconTheme: const IconThemeData(color: cream),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accentGreen,
        thumbColor: accentGreen,
        overlayColor: accentGreen.withValues(alpha: 0.15),
        inactiveTrackColor: accentOlive.withValues(alpha: 0.3),
        trackHeight: 6,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentGreen,
          foregroundColor: bgDark,
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
      iconTheme: const IconThemeData(color: cream, size: 24),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF151B14),
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: cream,
          ),
        ),
        iconTheme: WidgetStateProperty.all(
          const IconThemeData(color: cream, size: 22),
        ),
      ),
    );
  }

  /// Light theme — earthy light palette
  static ThemeData get lightTheme => _baseLightTheme;

  /// Dark theme — earthy dark palette
  static ThemeData get darkTheme => _baseTheme;

  static ThemeData get _baseLightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: accentOlive,
        secondary: accentGreen,
        surface: cardLight,
        onSurface: textDark,
        onPrimary: Colors.white,
      ),
      scaffoldBackgroundColor: bgLight,
      cardTheme: CardThemeData(
        color: cardLight,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      textTheme: _buildLightTextTheme(),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textDark,
        ),
        iconTheme: const IconThemeData(color: textDark),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accentOlive,
        thumbColor: accentOlive,
        overlayColor: accentOlive.withValues(alpha: 0.15),
        inactiveTrackColor: accentGreen.withValues(alpha: 0.2),
        trackHeight: 6,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentOlive,
          foregroundColor: Colors.white,
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
      iconTheme: const IconThemeData(color: textDark, size: 24),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: textDark,
          ),
        ),
        iconTheme: WidgetStateProperty.all(
          const IconThemeData(color: textDark, size: 22),
        ),
      ),
    );
  }

  /// Build text theme with Google Fonts - Inter
  static TextTheme _buildTextTheme() {
    const color = cream;
    const secondaryColor = mutedSage;

    return _textThemeWith(color, secondaryColor);
  }

  /// Build light text theme
  static TextTheme _buildLightTextTheme() {
    const color = textDark;
    const secondaryColor = textSecondaryLight;

    return _textThemeWith(color, secondaryColor);
  }

  static TextTheme _textThemeWith(Color color, Color secondaryColor) {
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

  /// Card decoration for floating cards
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: cardSurface,
    borderRadius: BorderRadius.circular(24),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.25),
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
    ],
  );

  /// Pill button decoration (for selected state)
  static BoxDecoration get pillButtonDecoration => BoxDecoration(
    color: accentGreen,
    borderRadius: BorderRadius.circular(14),
  );

  /// Soft colored card backgrounds
  static List<Color> get softColors => [softPink, softMint, softBlue];

  // ========== ANIMATION CONSTANTS ==========

  /// Standard page transition duration - slower for premium feel
  static const Duration pageTransitionDuration = Duration(milliseconds: 500);

  /// Content entrance animation duration
  static const Duration contentAnimationDuration = Duration(milliseconds: 600);

  /// Stagger delay between items
  static const Duration staggerDelay = Duration(milliseconds: 60);

  /// Standard animation curve - ease out expo for slow-to-fast premium feel
  static const Curve animationCurve = Curves.easeOutExpo;

  /// Simple page route without animations - instant transitions
  static PageRouteBuilder<T> smoothPageRoute<T>({
    required Widget page,
    RouteSettings? settings,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return child; // No animation at all
      },
    );
  }
}
