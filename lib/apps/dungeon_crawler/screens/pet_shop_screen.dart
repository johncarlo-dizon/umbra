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
      child: Scaffold(
        appBar: AppBar(title: const Text('Pet Shop')),
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
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    Text(
                      'Spend gems on companions to fight by your side.',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Center(child: _GemBalance(gems: progress.gems)),
                    const SizedBox(height: 20),
                    ...PetDefinition.all.map((pet) {
                      final owned = progress.unlockedPetIds.contains(pet.id);
                      final equipped = progress.equippedPetId == pet.id;
                      final canAfford = progress.gems >= pet.cost;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _PetRow(
                          pet: pet,
                          owned: owned,
                          equipped: equipped,
                          canAfford: canAfford,
                          onEquip: () async {
                            await PetProgressService.equipPet(pet.id);
                            _reload();
                          },
                          onPurchase: () async {
                            final ok = await PetProgressService.purchasePet(
                              pet.id,
                            );
                            if (ok) _reload();
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
            );
          },
        ),
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

/// One flat row per pet -- same skeleton as the leaderboard's rank rows:
/// avatar, name + a single stat line, one action on the right. Replaces
/// the old elevated Card + multi-line chip Wrap, but keeps every color
/// the original screen already used.
class _PetRow extends StatelessWidget {
  const _PetRow({
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
      margin: EdgeInsets.zero,
      elevation: equipped ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: equipped ? DungeonTheme.hpOrange : DungeonTheme.dungeonFloor,
          width: equipped ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
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
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            ),
            const SizedBox(width: 12),
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
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(
                            Icons.check_circle,
                            size: 16,
                            color: DungeonTheme.hpOrange,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _StatLine(pet: pet),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _ActionSlot(
              pet: pet,
              owned: owned,
              equipped: equipped,
              canAfford: canAfford,
              onEquip: onEquip,
              onPurchase: onPurchase,
            ),
          ],
        ),
      ),
    );
  }
}

/// All stats on a single line instead of a wrapping chip cloud -- each
/// stat keeps the exact icon/color pairing the original chips used.
class _StatLine extends StatelessWidget {
  const _StatLine({required this.pet});

  final PetDefinition pet;

  @override
  Widget build(BuildContext context) {
    final special = _specialStat(pet);
    return Row(
      children: [
        _statItem(Icons.favorite, DungeonTheme.hpOrange, '${pet.maxHp}'),
        const SizedBox(width: 8),
        _statItem(Icons.bolt, DungeonTheme.hazardRed, '${pet.damage}'),
        const SizedBox(width: 8),
        _statItem(Icons.timer, DungeonTheme.potionGreen, '${pet.cooldown}s'),
        if (special != null) ...[
          const SizedBox(width: 8),
          Flexible(
            child: _statItem(special.icon, special.color, special.label),
          ),
        ],
      ],
    );
  }

  Widget _statItem(IconData icon, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// Only the strongest special stat is shown inline to keep the row to
  /// one line, using the same icon/color pairing the original chips had.
  ({IconData icon, Color color, String label})? _specialStat(PetDefinition p) {
    if (p.doubleAttackChance > 0) {
      return (
        icon: Icons.flash_on,
        color: DungeonTheme.coinGold,
        label: '${(p.doubleAttackChance * 100).round()}% double',
      );
    }
    if (p.stunChance > 0) {
      return (
        icon: Icons.blur_circular,
        color: DungeonTheme.dungeonFloor,
        label: '${(p.stunChance * 100).round()}% stun',
      );
    }
    if (p.lifestealChance > 0) {
      return (
        icon: Icons.opacity,
        color: DungeonTheme.hazardRed,
        label: '${(p.lifestealChance * 100).round()}% lifesteal',
      );
    }
    return null;
  }
}

class _ActionSlot extends StatelessWidget {
  const _ActionSlot({
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
    if (equipped) {
      return const SizedBox.shrink();
    }
    if (owned) {
      return OutlinedButton.icon(
        onPressed: onEquip,
        icon: const Icon(Icons.check_circle_outline, size: 18),
        label: const Text('Equip'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        FilledButton.icon(
          onPressed: canAfford ? onPurchase : null,
          icon: const Icon(Icons.diamond, size: 18),
          label: Text('${pet.cost}'),
        ),
        if (!canAfford)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Not enough',
              style: TextStyle(fontSize: 10, color: DungeonTheme.hazardRed),
            ),
          ),
      ],
    );
  }
}
