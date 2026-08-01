import 'package:flutter/material.dart';
import 'settings_service.dart';
import 'wallpapers.dart';

/// Holds the app's live settings as ValueNotifiers so any widget can
/// react instantly when they change, without threading state through
/// every screen. Values are loaded from disk once at boot by
/// SettingsService and written back whenever the user changes them.
class AppSettingsState {
  AppSettingsState._();

  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier(
    ThemeMode.light,
  );

  /// Selected Home tab wallpaper. Device-local, independent of account —
  /// same reasoning as theme mode.
  static final ValueNotifier<HomeWallpaper> homeWallpaper = ValueNotifier(
    HomeWallpaper.wallpaper1,
  );

  /// Most-recently-used Unit Converter category ids, most recent first.
  /// Capped at 4 so the "Recent" row never overflows on small screens.
  static final ValueNotifier<List<String>> recentUnitCategoryIds =
      ValueNotifier(<String>[]);

  static void markUnitCategoryUsed(String categoryId) {
    final updated = [
      categoryId,
      ...recentUnitCategoryIds.value.where((id) => id != categoryId),
    ].take(4).toList();
    recentUnitCategoryIds.value = updated;
    SettingsService.setRecentUnitCategoryIds(updated);
  }
}
