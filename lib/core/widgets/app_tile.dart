import 'package:flutter/material.dart';

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
    final tileColor = color ?? colorScheme.primary;

    if (isPlaceholder) {
      return DottedBorderCard(
        child: _TileContent(
          icon: icon,
          name: name,
          description: description,
          iconColor: colorScheme.outline,
          textColor: colorScheme.outline,
          iconBgColor: Colors.transparent,
        ),
      );
    }

    return Card(
      elevation: 3,
      shadowColor: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.12),
      color: Theme.of(context).colorScheme.surface,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _TileContent(
                  icon: icon,
                  name: name,
                  description: description,
                  iconColor: tileColor,
                  textColor: colorScheme.onSurface,
                  iconBgColor: tileColor.withValues(alpha: 0.15),
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
  final Color iconBgColor;

  const _TileContent({
    required this.icon,
    required this.name,
    required this.description,
    required this.iconColor,
    required this.textColor,
    required this.iconBgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: iconBgColor,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(icon, size: 28, color: iconColor),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
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

class DottedBorderCard extends StatelessWidget {
  final Widget child;

  const DottedBorderCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1.5,
        ),
      ),
      child: child,
    );
  }
}
