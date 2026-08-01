/// The set of selectable Home tab wallpapers. Persisted preference lives in
/// AppSettingsState/SettingsService (device-local, same pattern as dark
/// mode / nav bar style) — this file only maps each option to its asset
/// path and display label, kept separate so settings logic doesn't need to
/// know about file paths.
enum HomeWallpaper { wallpaper1, wallpaper2, wallpaper3 }

extension HomeWallpaperAsset on HomeWallpaper {
  String get assetPath {
    switch (this) {
      case HomeWallpaper.wallpaper1:
        return 'assets/images/wallpaper_1.jpg';
      case HomeWallpaper.wallpaper2:
        return 'assets/images/wallpaper_2.jpg';
      case HomeWallpaper.wallpaper3:
        return 'assets/images/wallpaper_3.jpg';
    }
  }

  String get label {
    switch (this) {
      case HomeWallpaper.wallpaper1:
        return 'Coastal Cave';
      case HomeWallpaper.wallpaper2:
        return 'Wallpaper 2';
      case HomeWallpaper.wallpaper3:
        return 'Wallpaper 3';
    }
  }
}
