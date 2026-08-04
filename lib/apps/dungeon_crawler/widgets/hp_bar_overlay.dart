import 'package:flutter/material.dart';

import '../models/dungeon_game_state.dart';

/// Top-left HP bar, rendered as a Flutter overlay above the `GameWidget`
/// (not inside Flame) so it can use ordinary widgets. Fixed colors here
/// are intentional — like `AppTile`'s label in the Home tab, this sits on
/// the game canvas rather than a theme-following surface, so it needs to
/// read clearly against arbitrary in-game backgrounds rather than adapt
/// to light/dark mode.
class HpBarOverlay extends StatelessWidget {
  const HpBarOverlay({super.key, required this.gameState});

  final DungeonGameState gameState;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 16,
      left: 16,
      child: ValueListenableBuilder<int>(
        valueListenable: gameState.hp,
        builder: (context, hp, _) {
          final fraction = hp / gameState.maxHp;
          return Container(
            width: 180,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'HP',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Stack(
                    children: [
                      Container(height: 14, color: Colors.white12),
                      FractionallySizedBox(
                        widthFactor: fraction.clamp(0.0, 1.0),
                        child: Container(
                          height: 14,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: fraction > 0.3
                                  ? [const Color(0xFFFF7A1A), const Color(0xFFFFB74D)]
                                  : [Colors.red.shade900, Colors.red.shade400],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$hp / ${gameState.maxHp}',
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
