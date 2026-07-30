import 'package:flutter/material.dart';

/// A single sub-app tile shown in the Umbra shell's "Your apps" section.
/// Used for both live apps (MangaHub) and the "coming soon" placeholder.
class AppTile extends StatelessWidget {
  final IconData icon;
  final String name;
  final String description;
  final VoidCallback? onTap;
  final bool isPlaceholder;
  final Color? color;

  const AppTile({
    super.key,
    required this.icon,
    required this.name,
    required this.description,
    this.onTap,
    this.isPlaceholder = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (isPlaceholder) {
      return DottedBorderCard(
        child: _TileContent(
          icon: icon,
          name: name,
          description: description,
          iconColor: colorScheme.outline,
          textColor: colorScheme.outline,
        ),
      );
    }

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _TileContent(
                  icon: icon,
                  name: name,
                  description: description,
                  iconColor: colorScheme.primary,
                  textColor: colorScheme.onSurface,
                ),
              ),
              Icon(Icons.chevron_right, color: colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _TileContent extends StatelessWidget {
  final IconData icon;
  final String name;
  final String description;
  final Color iconColor;
  final Color textColor;

  const _TileContent({
    required this.icon,
    required this.name,
    required this.description,
    required this.iconColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 32, color: iconColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: textColor),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: textColor.withValues(alpha: 0.7),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Simple dashed-border wrapper for the "coming soon" placeholder tile.
class DottedBorderCard extends StatelessWidget {
  final Widget child;

  const DottedBorderCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1.5,
        ),
      ),
      child: child,
    );
  }
}
