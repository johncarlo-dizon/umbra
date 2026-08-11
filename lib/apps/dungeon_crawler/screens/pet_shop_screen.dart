import 'package:flutter/material.dart';

import '../models/pet_definition.dart';
import '../services/pet_progress_service.dart';
import '../theme/dungeon_theme.dart';

class PetShopScreen extends StatefulWidget {
  const PetShopScreen({super.key});

  @override
  State<PetShopScreen> createState() => _PetShopScreenState();
}

class _PetShopScreenState extends State<PetShopScreen> {
  late Future<PetProgress> _future;

  @override
  void initState() {
    super.initState();
    _future = PetProgressService.fetch();
  }

  void _reload() {
    final newFuture = PetProgressService.fetch();
    setState(() {
      _future = newFuture;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: DungeonTheme.theme,
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          return Scaffold(
            appBar: AppBar(title: const Text('Pet Shop')),
            body: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: FutureBuilder<PetProgress>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final progress = snapshot.data!;
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                          child: Column(
                            children: [
                              Icon(
                                Icons.pets,
                                size: 72,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Pet Shop',
                                style: theme.textTheme.headlineMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Spend gems on companions to fight by your side.',
                                style: theme.textTheme.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              _GemBalance(gems: progress.gems),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: PetDefinition.all.length,
                            itemBuilder: (context, i) {
                              final pet = PetDefinition.all[i];
                              final owned = progress.unlockedPetIds.contains(
                                pet.id,
                              );
                              final equipped = progress.equippedPetId == pet.id;
                              final canAfford = progress.gems >= pet.cost;
                              return _PetCard(
                                pet: pet,
                                owned: owned,
                                equipped: equipped,
                                canAfford: canAfford,
                                onEquip: () async {
                                  await PetProgressService.equipPet(pet.id);
                                  _reload();
                                },
                                onPurchase: () async {
                                  final ok =
                                      await PetProgressService.purchasePet(
                                        pet.id,
                                      );
                                  if (ok) _reload();
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GemBalance extends StatelessWidget {
  const _GemBalance({required this.gems});

  final int gems;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: DungeonTheme.dungeonWall,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DungeonTheme.coinGold, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.diamond, color: DungeonTheme.coinGold, size: 20),
          const SizedBox(width: 8),
          Text(
            '$gems gems',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: DungeonTheme.coinGold,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _PetCard extends StatelessWidget {
  const _PetCard({
    required this.pet,
    required this.owned,
    required this.equipped,
    required this.canAfford,
    required this.onEquip,
    required this.onPurchase,
  });

  final PetDefinition pet;
  final bool owned;
  final bool equipped;
  final bool canAfford;
  final VoidCallback onEquip;
  final VoidCallback onPurchase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: equipped ? DungeonTheme.hpOrange : DungeonTheme.dungeonFloor,
          width: equipped ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: DungeonTheme.dungeonFloor,
              foregroundColor: theme.colorScheme.onSurface,
              child: Text(
                pet.name[0],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          pet.name,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      if (equipped)
                        const Chip(
                          label: Text('Equipped'),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: _statChips(pet)),
                  const SizedBox(height: 12),
                  if (owned && !equipped)
                    OutlinedButton.icon(
                      onPressed: onEquip,
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Equip'),
                    )
                  else if (!owned)
                    FilledButton.icon(
                      onPressed: canAfford ? onPurchase : null,
                      icon: const Icon(Icons.diamond, size: 18),
                      label: Text('${pet.cost} gems'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _statChips(PetDefinition p) {
    final chips = <Widget>[
      _StatChip(
        icon: Icons.favorite,
        color: DungeonTheme.hpOrange,
        label: '${p.maxHp} HP',
      ),
      _StatChip(
        icon: Icons.bolt,
        color: DungeonTheme.hazardRed,
        label: '${p.damage} dmg',
      ),
      _StatChip(
        icon: Icons.timer,
        color: DungeonTheme.potionGreen,
        label: '${p.cooldown}s cd',
      ),
    ];
    if (p.doubleAttackChance > 0) {
      chips.add(
        _StatChip(
          icon: Icons.flash_on,
          color: DungeonTheme.coinGold,
          label: '${(p.doubleAttackChance * 100).round()}% double',
        ),
      );
    }
    if (p.stunChance > 0) {
      chips.add(
        _StatChip(
          icon: Icons.blur_circular,
          color: DungeonTheme.dungeonFloor,
          label: '${(p.stunChance * 100).round()}% stun',
        ),
      );
    }
    if (p.lifestealChance > 0) {
      chips.add(
        _StatChip(
          icon: Icons.opacity,
          color: DungeonTheme.hazardRed,
          label: '${(p.lifestealChance * 100).round()}% lifesteal',
        ),
      );
    }
    return chips;
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
