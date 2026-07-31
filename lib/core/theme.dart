import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const navy = Color(0xFF141B4D);
  static const navyLight = Color(0xFF1F2A6B);
  static const orange = Color(0xFFFF7A1A);
  static const orangeLight = Color(0xFFFFA45C);
  static const background = Color(0xFFF4F6FB);
  static const card = Color(0xFFFFFFFF);
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.orange,
      brightness: Brightness.light,
      primary: AppColors.orange,
      surface: AppColors.background,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.navy,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.card,
        indicatorColor: AppColors.orange.withValues(alpha: 0.15),
        surfaceTintColor: Colors.transparent,
        elevation: 2,
      ),
      cardTheme: CardThemeData(
        elevation: 4,
        shadowColor: AppColors.navy.withValues(alpha: 0.18),
        surfaceTintColor: Colors.transparent,
        color: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.orange,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.navy,
          side: const BorderSide(color: AppColors.navy, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.navy.withValues(alpha: 0.05),
        selectedColor: AppColors.orange,
        labelStyle: const TextStyle(color: AppColors.navy),
        secondaryLabelStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  static ThemeData get dark {
    const darkBackground = Color(0xFF12131C);
    const darkSurface = Color(0xFF1D1F2E);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.orange,
      brightness: Brightness.dark,
      primary: AppColors.orangeLight,
      surface: darkSurface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: darkBackground,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: darkBackground,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkSurface,
        indicatorColor: AppColors.orangeLight.withValues(alpha: 0.20),
        surfaceTintColor: Colors.transparent,
        elevation: 2,
      ),
      cardTheme: CardThemeData(
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.4),
        surfaceTintColor: Colors.transparent,
        color: darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.orangeLight,
          foregroundColor: darkBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white54, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.06),
        selectedColor: AppColors.orangeLight,
        labelStyle: const TextStyle(color: Colors.white),
        secondaryLabelStyle: TextStyle(color: darkBackground),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        hintStyle: const TextStyle(color: Colors.white38),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
