import 'package:flutter/material.dart';

import '../models/pet_definition.dart';
import '../services/pet_progress_service.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('Pet Shop')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: FutureBuilder<PetProgress>(
            future: _future,
            builder: (context, snapshot) {
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              final progress = snapshot.data!;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.diamond, color: Colors.purpleAccent),
                        const SizedBox(width: 8),
                        Text(
                          '${progress.gems} gems',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: PetDefinition.all.length,
                      itemBuilder: (context, i) {
                        final pet = PetDefinition.all[i];
                        final owned = progress.unlockedPetIds.contains(pet.id);
                        final equipped = progress.equippedPetId == pet.id;
                        final canAfford = progress.gems >= pet.cost;

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          child: ListTile(
                            leading: CircleAvatar(child: Text(pet.name[0])),
                            title: Text(pet.name),
                            subtitle: Text(_describePet(pet)),
                            trailing: owned
                                ? (equipped
                                      ? const Chip(label: Text('Equipped'))
                                      : OutlinedButton(
                                          onPressed: () async {
                                            await PetProgressService.equipPet(
                                              pet.id,
                                            );
                                            _reload();
                                          },
                                          child: const Text('Equip'),
                                        ))
                                : FilledButton(
                                    onPressed: canAfford
                                        ? () async {
                                            final ok =
                                                await PetProgressService.purchasePet(
                                                  pet.id,
                                                );
                                            if (ok) _reload();
                                          }
                                        : null,
                                    child: Text('${pet.cost} gems'),
                                  ),
                          ),
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
  }

  String _describePet(PetDefinition p) {
    final parts = <String>[
      '${p.maxHp} HP',
      '${p.damage} dmg',
      '${p.cooldown}s cooldown',
    ];
    if (p.doubleAttackChance > 0)
      parts.add('${(p.doubleAttackChance * 100).round()}% double-hit');
    if (p.stunChance > 0) parts.add('${(p.stunChance * 100).round()}% stun');
    if (p.lifestealChance > 0)
      parts.add('${(p.lifestealChance * 100).round()}% lifesteal');
    return parts.join(' · ');
  }
}
