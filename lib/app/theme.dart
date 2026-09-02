// lib/app/theme.dart

import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // Brand colors
  static const Color _brandPrimary = Color(0xFF6366F1); // Indigo
  static const Color _brandSecondary = Color(0xFF22D3EE); // Cyan
  static const Color _brandTertiary = Color(0xFFF472B6); // Pink

  // Dark background palette
  static const Color _darkBackground = Color(0xFF0F172A);
  static const Color _darkSurface = Color(0xFF1E293B);
  static const Color _darkCard = Color(0xFF1E293B);
  static const Color _darkCardElevated = Color(0xFF273549);

  // Light background palette
  static const Color _lightBackground = Color(0xFFF8FAFC);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightCard = Color(0xFFFFFFFF);

  // Health metric accent colors
  static const Color heartColor = Color(0xFFEF4444);
  static const Color stepsColor = Color(0xFF6366F1);
  static const Color sleepColor = Color(0xFF8B5CF6);
  static const Color caloriesColor = Color(0xFFF97316);
  static const Color calorieColor = Color(0xFFF97316);
  static const Color distanceColor = Color(0xFF22D3EE);
  static const Color activeColor = Color(0xFF10B981);
  static const Color successColor = Color(0xFF10B981);
  static const Color warningColor = Color(0xFFF59E0B);

  // ---------------------------------------------------------------------------
  // Dark Theme
  // ---------------------------------------------------------------------------

  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _brandPrimary,
      brightness: Brightness.dark,
      surface: _darkSurface,
      surfaceContainerHighest: _darkCardElevated,
      primary: _brandPrimary,
      secondary: _brandSecondary,
      tertiary: _brandTertiary,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: _darkBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: _darkBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: _darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _darkSurface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: _brandPrimary.withValues(alpha: 0.2),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _brandPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _brandPrimary,
          side: const BorderSide(color: _brandPrimary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textTheme: _textTheme(Colors.white),
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.08),
        thickness: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _darkCardElevated,
        labelStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.white70,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Light Theme
  // ---------------------------------------------------------------------------

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _brandPrimary,
      brightness: Brightness.light,
      surface: _lightSurface,
      primary: _brandPrimary,
      secondary: _brandSecondary,
      tertiary: _brandTertiary,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: _lightBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: _lightBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFF0F172A),
        ),
      ),
      cardTheme: CardThemeData(
        color: _lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        margin: EdgeInsets.zero,
      ),
      textTheme: _textTheme(const Color(0xFF0F172A)),
    );
  }

  // ---------------------------------------------------------------------------
  // Shared Text Theme
  // ---------------------------------------------------------------------------

  static TextTheme _textTheme(Color baseColor) {
    return TextTheme(
      displayLarge: TextStyle(
        fontFamily: 'Inter',
        fontSize: 57,
        fontWeight: FontWeight.w700,
        color: baseColor,
      ),
      headlineLarge: TextStyle(
        fontFamily: 'Inter',
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: baseColor,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'Inter',
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      headlineSmall: TextStyle(
        fontFamily: 'Inter',
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      titleLarge: TextStyle(
        fontFamily: 'Inter',
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      titleMedium: TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: baseColor,
      ),
      titleSmall: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: baseColor,
      ),
      bodyLarge: TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: baseColor,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: baseColor,
      ),
      bodySmall: TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: baseColor.withValues(alpha: 0.7),
      ),
      labelLarge: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Gradient helpers
  // ---------------------------------------------------------------------------

  static LinearGradient get brandGradient => const LinearGradient(
        colors: [_brandPrimary, _brandSecondary],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient metricGradient(Color color) => LinearGradient(
        colors: [color, color.withValues(alpha: 0.7)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}
