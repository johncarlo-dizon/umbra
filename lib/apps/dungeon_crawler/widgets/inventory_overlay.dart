import 'package:flutter/material.dart';

import '../models/inventory.dart';

/// Top-right inventory readout (keys held, potions, coins). Same
/// fixed-color rationale as `HpBarOverlay` — this is game-canvas chrome,
/// not app chrome.
class InventoryOverlay extends StatelessWidget {
  const InventoryOverlay({super.key, required this.inventory});

  final Inventory inventory;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 16,
      right: 16,
      child: ListenableBuilder(
        listenable: inventory,
        builder: (context, _) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Stat(icon: Icons.vpn_key, color: const Color(0xFFFFD54F), value: inventory.keys.length),
                const SizedBox(width: 12),
                _Stat(icon: Icons.local_drink, color: const Color(0xFFE91E63), value: inventory.potions),
                const SizedBox(width: 12),
                _Stat(icon: Icons.circle, color: const Color(0xFFFFC107), value: inventory.coins),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.color, required this.value});

  final IconData icon;
  final Color color;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text('$value', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
