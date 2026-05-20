import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Color Palette
  static const Color primaryBlue = Color(0xFF6ECBF5);
  static const Color primaryGreen = Color(0xFF7EEECB);
  static const Color accentPurple = Color(0xFFB8A9FF);
  static const Color accentPink = Color(0xFFFFB8D9);

  static const Color darkBg = Color(0xFF0D0F14);
  static const Color darkSurface = Color(0xFF161B24);
  static const Color darkCard = Color(0xFF1E2533);
  static const Color darkBorder = Color(0xFF2A3344);

  static const Color lightBg = Color(0xFFF0F8FF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFF8FFFE);

  static const Color textPrimary = Color(0xFF1A1D2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);

  static const Color success = Color(0xFF4ADE80);
  static const Color error = Color(0xFFFF6B8A);
  static const Color warning = Color(0xFFFFD166);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryBlue, primaryGreen],
  );

  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1A1F2E), Color(0xFF0D0F14)],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.transparent, Color(0xCC000000)],
  );

  static const LinearGradient matchGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6ECBF5), Color(0xFF7EEECB)],
  );

  // Premium Aesthetics: Glassmorphism
  static BoxDecoration glassDecoration({required bool isDark}) {
    return BoxDecoration(
      color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
        width: 1.5,
      ),
    );
  }

  static BoxDecoration premiumCard({required bool isDark}) {
    return BoxDecoration(
      color: isDark ? darkCard.withOpacity(0.8) : Colors.white.withOpacity(0.9),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(
        color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
          blurRadius: 30,
          offset: const Offset(0, 15),
        ),
      ],
    );
  }


  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: primaryBlue,
        secondary: primaryGreen,
        tertiary: accentPurple,
        surface: lightSurface,
        onPrimary: Colors.white,
        onSecondary: textPrimary,
        error: error,
      ),
      scaffoldBackgroundColor: lightBg,
      textTheme: _buildTextTheme(isDark: false),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      cardTheme: CardTheme(
        color: lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      inputDecorationTheme: _buildInputTheme(isDark: false),
      elevatedButtonTheme: _buildElevatedButtonTheme(),
      navigationBarTheme: _buildNavBarTheme(isDark: false),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: primaryBlue,
        secondary: primaryGreen,
        tertiary: accentPurple,
        surface: darkSurface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        error: error,
      ),
      scaffoldBackgroundColor: darkBg,
      textTheme: _buildTextTheme(isDark: true),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: -0.5,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      cardTheme: CardTheme(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      inputDecorationTheme: _buildInputTheme(isDark: true),
      elevatedButtonTheme: _buildElevatedButtonTheme(),
      navigationBarTheme: _buildNavBarTheme(isDark: true),
    );
  }

  static TextTheme _buildTextTheme({required bool isDark}) {
    final color = isDark ? Colors.white : textPrimary;
    return TextTheme(
      displayLarge: GoogleFonts.outfit(
        fontSize: 48,
        fontWeight: FontWeight.w800,
        color: color,
        letterSpacing: -1.5,
      ),
      displayMedium: GoogleFonts.outfit(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: -1.0,
      ),
      displaySmall: GoogleFonts.outfit(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: -0.5,
      ),
      headlineLarge: GoogleFonts.outfit(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: -0.3,
      ),
      headlineMedium: GoogleFonts.outfit(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      headlineSmall: GoogleFonts.outfit(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      titleLarge: GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      titleMedium: GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: color,
      ),
      bodyLarge: GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: isDark ? Colors.white70 : textSecondary,
        height: 1.6,
      ),
      bodyMedium: GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: isDark ? Colors.white60 : textSecondary,
        height: 1.5,
      ),
      bodySmall: GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: isDark ? Colors.white38 : textTertiary,
      ),
      labelLarge: GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: 0.5,
      ),
    );
  }

  static InputDecorationTheme _buildInputTheme({required bool isDark}) {
    return InputDecorationTheme(
      filled: true,
      fillColor: isDark ? darkCard : const Color(0xFFF3F6FF),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isDark ? darkBorder : const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: primaryBlue, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      hintStyle: GoogleFonts.outfit(
        fontSize: 14,
        color: isDark ? Colors.white38 : textTertiary,
      ),
    );
  }

  static ElevatedButtonThemeData _buildElevatedButtonTheme() {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(50),
        ),
        elevation: 0,
        textStyle: GoogleFonts.outfit(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  static NavigationBarThemeData _buildNavBarTheme({required bool isDark}) {
    return NavigationBarThemeData(
      backgroundColor: isDark ? darkSurface : Colors.white,
      indicatorColor: primaryBlue.withOpacity(0.15),
      height: 70,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: primaryBlue,
          );
        }
        return GoogleFonts.outfit(
          fontSize: 11,
          color: isDark ? Colors.white38 : textTertiary,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: primaryBlue, size: 24);
        }
        return IconThemeData(
          color: isDark ? Colors.white38 : textTertiary,
          size: 24,
        );
      }),
    );
  }
}
