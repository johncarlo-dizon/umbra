import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_settings_state.dart';
import 'wallpapers.dart';

/// Reads/writes settings to on-device storage. Deliberately separate
/// from Supabase — these are device-local preferences, not synced
/// per-account, so they're never affected by sign-in/sign-out.
class SettingsService {
  SettingsService._();

  static const _darkModeKey = 'settings_dark_mode';
  static const _wallpaperKey = 'settings_home_wallpaper';
  static const _recentUnitCategoriesKey = 'settings_recent_unit_categories';

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final isDark = prefs.getBool(_darkModeKey) ?? false;
    AppSettingsState.themeMode.value = isDark
        ? ThemeMode.dark
        : ThemeMode.light;

    final wallpaperName = prefs.getString(_wallpaperKey);
    AppSettingsState.homeWallpaper.value = HomeWallpaper.values.firstWhere(
      (w) => w.name == wallpaperName,
      orElse: () => HomeWallpaper.wallpaper1,
    );

    AppSettingsState.recentUnitCategoryIds.value =
        prefs.getStringList(_recentUnitCategoriesKey) ?? [];
  }

  static Future<void> setDarkMode(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, isDark);
    AppSettingsState.themeMode.value = isDark
        ? ThemeMode.dark
        : ThemeMode.light;
  }

  static Future<void> setHomeWallpaper(HomeWallpaper wallpaper) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_wallpaperKey, wallpaper.name);
    AppSettingsState.homeWallpaper.value = wallpaper;
  }

  static Future<void> setRecentUnitCategoryIds(List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentUnitCategoriesKey, ids);
  }
}
