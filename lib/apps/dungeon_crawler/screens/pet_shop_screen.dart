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
            body: FutureBuilder<PetProgress>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final progress = snapshot.data!;
                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: CustomScrollView(
                      slivers: [
                        SliverAppBar(
                          pinned: true,
                          floating: true,
                          expandedHeight: 168,
                          title: const Text('Pet Shop'),
                          actions: [
                            Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: Center(
                                child: _GemBalance(gems: progress.gems),
                              ),
                            ),
                          ],
                          flexibleSpace: FlexibleSpaceBar(
                            centerTitle: false,
                            titlePadding: EdgeInsets.zero,
                            background: Container(
                              padding: const EdgeInsets.fromLTRB(
                                24,
                                56,
                                24,
                                16,
                              ),
                              alignment: Alignment.bottomLeft,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    theme.colorScheme.primary.withValues(
                                      alpha: 0.12,
                                    ),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Icon(
                                    Icons.pets,
                                    size: 48,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Spend gems on companions\nto fight by your side.',
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          sliver: SliverList.builder(
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
                    ),
                  ),
                );
              },
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: DungeonTheme.dungeonWall,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DungeonTheme.coinGold, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.diamond, color: DungeonTheme.coinGold, size: 16),
          const SizedBox(width: 6),
          Text(
            '$gems',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
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
      elevation: equipped ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: equipped ? DungeonTheme.hpOrange : DungeonTheme.dungeonFloor,
          width: equipped ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        theme.colorScheme.primary.withValues(alpha: 0.85),
                        DungeonTheme.dungeonFloor,
                      ],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    pet.name[0],
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimary,
                    ),
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
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (equipped)
                            const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Chip(
                                label: Text('Equipped'),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _statChips(pet),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerRight, child: _actionButton()),
          ],
        ),
      ),
    );
  }

  Widget _actionButton() {
    if (owned && !equipped) {
      return OutlinedButton.icon(
        onPressed: onEquip,
        icon: const Icon(Icons.check_circle_outline, size: 18),
        label: const Text('Equip'),
      );
    }
    if (!owned) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton.icon(
            onPressed: canAfford ? onPurchase : null,
            icon: const Icon(Icons.diamond, size: 18),
            label: Text('${pet.cost} gems'),
          ),
          if (!canAfford)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Not enough gems',
                style: TextStyle(fontSize: 11, color: DungeonTheme.hazardRed),
              ),
            ),
        ],
      );
    }
    return const SizedBox.shrink();
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
