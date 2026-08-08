import 'package:flutter/material.dart';

import '../models/dungeon_game_state.dart';
import '../models/inventory.dart';
import '../game/components/player.dart';

class ReviveOverlay extends StatelessWidget {
  const ReviveOverlay({
    super.key,
    required this.gameState,
    required this.inventory,
    required this.player,
    required this.onGiveUp,
  });

  final DungeonGameState gameState;
  final Inventory inventory;
  final Player? player;
  final VoidCallback onGiveUp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cost = gameState.reviveCost;
    final canAfford = inventory.coins >= cost;

    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.favorite_border,
                  size: 48,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 12),
                Text('You Fell...', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  canAfford
                      ? 'Revive for $cost coins?'
                      : 'Need $cost coins to revive (you have ${inventory.coins})',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: canAfford
                      ? () {
                          inventory.spendCoins(cost);
                          gameState.revive();
                          player?.reviveVisual();
                        }
                      : null,
                  icon: const Icon(Icons.favorite),
                  label: Text('Revive ($cost coins)'),
                ),
                const SizedBox(height: 8),
                TextButton(onPressed: onGiveUp, child: const Text('Give Up')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
