import 'package:flutter/material.dart';

/// Theme scoped to the Dungeon Crawler sub-app only. Palette pulled from
/// the dungeon's own art: navy dungeon walls, orange HP, gold coins,
/// green potions, red hazards. Wrapped around dungeon-crawler routes in
/// `dungeon_crawler_routes.dart` — NOT wired at the shell root, since
/// other sub-apps (calculator, fitlog, etc.) use `core/theme.dart`.
class DungeonTheme {
  DungeonTheme._();

  static const dungeonWall = Color(0xFF2A2E52);
  static const dungeonFloor = Color(0xFF4A4A57);
  static const hpOrange = Color(0xFFFF9F1C);
  static const coinGold = Color(0xFFF4C430);
  static const potionGreen = Color(0xFF4CAF50);
  static const hazardRed = Color(0xFFE63950);
  static const voidBlack = Color(0xFF0D0D14);

  static final ColorScheme _scheme = ColorScheme.fromSeed(
    seedColor: hpOrange,
    brightness: Brightness.dark,
    primary: hpOrange,
    onPrimary: voidBlack,
    secondary: coinGold,
    onSecondary: voidBlack,
    tertiary: potionGreen,
    onTertiary: Colors.white,
    error: hazardRed,
    onError: Colors.white,
    surface: dungeonWall,
    onSurface: const Color(0xFFEDEDF2),
    surfaceContainerHighest: dungeonFloor,
    outline: dungeonFloor,
  );

  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: _scheme,
      scaffoldBackgroundColor: voidBlack,
      appBarTheme: AppBarTheme(
        backgroundColor: voidBlack,
        foregroundColor: _scheme.onSurface,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: _scheme.surface,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: dungeonFloor, width: 1),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _scheme.primary,
          foregroundColor: _scheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _scheme.secondary,
          side: BorderSide(color: _scheme.secondary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: _scheme.onSurface),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: _scheme.secondary,
        tileColor: dungeonWall.withValues(alpha: 0.4),
      ),
      textTheme: Typography.whiteMountainView.apply(
        bodyColor: _scheme.onSurface,
        displayColor: _scheme.onSurface,
      ),
    );
  }
}
