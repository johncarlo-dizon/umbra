import 'package:flutter/material.dart';

/// A single home-screen icon tile: a colored rounded-square badge with the
/// icon, and the app name as a label underneath — styled to sit directly on
/// the Home tab's photo wallpaper rather than a card.
///
/// Label text and icon glyph color are intentionally hardcoded white with a
/// drop shadow here, breaking the normal "never hardcode colors" rule —
/// justified the same way the shell's navy hero header is: this tile's
/// background is a fixed photograph, not a theme-following `colorScheme`
/// surface, so it needs to stay legible against *any* wallpaper rather than
/// adapting to light/dark mode.
///
/// [description] is no longer printed inline (there's no card to put it
/// in) — it now surfaces as a hover tooltip, matching how real desktop
/// icons reveal their info on hover instead of always showing text.
///
/// Icons come from either [icon] (an [IconData] glyph, tinted white on a
/// colored badge — used for the placeholder tile) or [iconAsset] (a custom
/// PNG, shown at full color with no badge fill so the artwork isn't
/// muddied). Exactly one of the two should be provided.
class AppTile extends StatelessWidget {
  final IconData? icon;
  final String? iconAsset;
  final String name;
  final String description;
  final VoidCallback? onTap;
  final bool isPlaceholder;
  final Color? color;

  const AppTile({
    super.key,
    this.icon,
    this.iconAsset,
    required this.name,
    required this.description,
    this.onTap,
    this.isPlaceholder = false,
    this.color,
  }) : assert(
         icon != null || iconAsset != null,
         'Provide either icon or iconAsset',
       );

  @override
  Widget build(BuildContext context) {
    final tileColor = color ?? Theme.of(context).colorScheme.primary;
    final useImage = iconAsset != null;

    final tile = InkWell(
      onTap: isPlaceholder ? null : onTap,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: isPlaceholder
                    ? Colors.white.withValues(alpha: 0.14)
                    : (useImage ? Colors.transparent : tileColor),
                borderRadius: BorderRadius.circular(18),
                border: isPlaceholder
                    ? Border.all(
                        color: Colors.white.withValues(alpha: 0.55),
                        width: 1.5,
                      )
                    : null,
                boxShadow: isPlaceholder
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: useImage
                  ? Padding(
                      padding: const EdgeInsets.all(4),
                      child: Image.asset(iconAsset!, fit: BoxFit.contain),
                    )
                  : Icon(icon, size: 26, color: Colors.white),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 78,
              child: Text(
                name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black54,
                      blurRadius: 6,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Tooltip(
      message: description,
      waitDuration: const Duration(milliseconds: 500),
      child: tile,
    );
  }
}
