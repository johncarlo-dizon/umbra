import 'package:flutter/material.dart';
import '../app_settings_state.dart';
import '../settings_service.dart';
import '../wallpapers.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Settings',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              _SectionCard(
                title: 'Appearance',
                child: ValueListenableBuilder<ThemeMode>(
                  valueListenable: AppSettingsState.themeMode,
                  builder: (context, mode, _) {
                    return SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Dark mode'),
                      subtitle: const Text('Applies across all apps'),
                      value: mode == ThemeMode.dark,
                      onChanged: (value) => SettingsService.setDarkMode(value),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Wallpaper',
                child: ValueListenableBuilder<HomeWallpaper>(
                  valueListenable: AppSettingsState.homeWallpaper,
                  builder: (context, selected, _) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Shown behind your app icons on Home',
                          style: TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: HomeWallpaper.values
                              .map(
                                (wallpaper) => Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: _WallpaperThumb(
                                    wallpaper: wallpaper,
                                    isSelected: wallpaper == selected,
                                    onTap: () =>
                                        SettingsService.setHomeWallpaper(
                                          wallpaper,
                                        ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WallpaperThumb extends StatelessWidget {
  final HomeWallpaper wallpaper;
  final bool isSelected;
  final VoidCallback onTap;

  const _WallpaperThumb({
    required this.wallpaper,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? scheme.primary : Colors.transparent,
            width: 3,
          ),
        ),
        padding: const EdgeInsets.all(2),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Image.asset(
            wallpaper.assetPath,
            fit: BoxFit.cover,
            // Slots 2 and 3 may not have an image added yet — fall back to
            // a plain placeholder instead of crashing the settings screen.
            errorBuilder: (context, error, stackTrace) => Container(
              color: scheme.surfaceContainerHighest,
              alignment: Alignment.center,
              child: Icon(
                Icons.image_not_supported_outlined,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          // ListTile-family widgets (SwitchListTile, RadioListTile, etc.)
          // need their own Material ancestor for ink/ripple effects — sitting
          // directly inside this Container's colored background (a
          // DecoratedBox) hides that layer, which Flutter flags as a debug
          // assertion and aborts the build for this whole card. Wrapping in
          // a transparent Material gives them that ancestor without
          // changing how anything looks.
          Material(type: MaterialType.transparency, child: child),
        ],
      ),
    );
  }
}
