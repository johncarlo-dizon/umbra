import 'package:flutter/material.dart';

/// Full-screen modal shown when `RunStatus` flips to `lost`. Unlike the
/// HUD overlays, this is a genuine app-chrome surface (a card floating
/// over a dimmed backdrop, not drawn against arbitrary game art), so it
/// follows the normal `Theme.of(context)` rule rather than the HUD's
/// fixed-color exception.
class GameOverOverlay extends StatelessWidget {
  const GameOverOverlay({
    super.key,
    required this.onRetry,
    required this.onExit,
  });

  final VoidCallback onRetry;
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
                  Icons.dangerous_outlined,
                  size: 48,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 12),
                Text('You Died', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  'The dungeon claims another adventurer.',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
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
