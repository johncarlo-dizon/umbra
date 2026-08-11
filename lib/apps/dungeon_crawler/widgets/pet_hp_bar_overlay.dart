import 'dart:async';
import 'package:flutter/material.dart';
import '../game/dungeon_game.dart';

/// Pet HP bar, positioned directly under HpBarOverlay. Polls
/// game.petComponent's plain hp/maxHp fields each frame (mirroring
/// EnemyBase, which BattleCompanionPet is expected to follow) rather
/// than listening to a ValueNotifier, since the pet doesn't expose one.
class PetHpBarOverlay extends StatefulWidget {
  const PetHpBarOverlay({super.key, required this.game});

  final DungeonGame game;

  @override
  State<PetHpBarOverlay> createState() => _PetHpBarOverlayState();
}

class _PetHpBarOverlayState extends State<PetHpBarOverlay> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pet = widget.game.pet;
    if (pet == null || pet.isFainted) return const SizedBox.shrink();

    final fraction = (pet.hp / pet.definition.maxHp).clamp(0.0, 1.0);
    return Positioned(
      top: 94,
      left: 16,
      child: Container(
        width: 140,
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
              'PET HP',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                children: [
                  Container(height: 10, color: Colors.white12),
                  FractionallySizedBox(
                    widthFactor: fraction,
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: fraction > 0.3
                              ? [Colors.teal.shade700, Colors.tealAccent]
                              : [Colors.red.shade900, Colors.red.shade400],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
