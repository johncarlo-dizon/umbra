import 'package:flutter/material.dart';

import '../models/inventory.dart';

/// Full-screen "level complete" modal shown when the player reaches the
/// exit. Regular themed app chrome, same as `GameOverOverlay`.
class VictoryOverlay extends StatelessWidget {
  const VictoryOverlay({
    super.key,
    required this.inventory,
    required this.onPlayAgain,
    required this.onExit,
  });

  final Inventory inventory;
  final VoidCallback onPlayAgain;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: Colors.black.withValues(alpha: 0.65),
      child: Center(
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.emoji_events_outlined,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text('Dungeon Cleared!', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.circle,
                      size: 16,
                      color: theme.colorScheme.secondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${inventory.coins} coins collected',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onPlayAgain,
                  icon: const Icon(Icons.replay),
                  label: const Text('Play Again'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: onExit,
                  child: const Text('Back to Menu'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
