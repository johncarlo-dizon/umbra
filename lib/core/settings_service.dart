import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_settings_state.dart';

/// Reads/writes settings to on-device storage. Deliberately separate
/// from Supabase — these are device-local preferences, not synced
/// per-account, so they're never affected by sign-in/sign-out.
class SettingsService {
  SettingsService._();

  static const _darkModeKey = 'settings_dark_mode';
  static const _navStyleKey = 'settings_nav_style';

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final isDark = prefs.getBool(_darkModeKey) ?? false;
    AppSettingsState.themeMode.value = isDark
        ? ThemeMode.dark
        : ThemeMode.light;

    final styleName = prefs.getString(_navStyleKey);
    AppSettingsState.navBarStyle.value = NavBarStyle.values.firstWhere(
      (s) => s.name == styleName,
      orElse: () => NavBarStyle.standard,
    );
  }

  static Future<void> setDarkMode(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, isDark);
    AppSettingsState.themeMode.value = isDark
        ? ThemeMode.dark
        : ThemeMode.light;
  }

  static Future<void> setNavBarStyle(NavBarStyle style) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_navStyleKey, style.name);
    AppSettingsState.navBarStyle.value = style;
  }
}
