class PetDefinition {
  final String id;
  final String name;
  final String spriteSheet;
  final int cost;
  final double cellWidth;
  final double cellHeight;
  final int maxHp;
  final int damage;
  final double cooldown;
  final double doubleAttackChance;
  final double stunChance;
  final double stunDuration;
  final double lifestealChance;
  final Map<String, int> attackFrameCounts; // per-pet, since these vary (3-5)

  const PetDefinition({
    required this.id,
    required this.name,
    required this.spriteSheet,
    required this.cost,
    required this.cellWidth,
    required this.cellHeight,
    required this.maxHp,
    required this.damage,
    required this.cooldown,
    required this.attackFrameCounts,
    this.doubleAttackChance = 0,
    this.stunChance = 0,
    this.stunDuration = 0,
    this.lifestealChance = 0,
  });

  static const List<PetDefinition> all = [
    PetDefinition(
      id: 'black_bird',
      name: 'Black Bird',
      spriteSheet: 'black_bird.png',
      cost: 40,
      cellWidth: 95,
      cellHeight: 86,
      maxHp: 80,
      damage: 7,
      cooldown: 2.0,
      attackFrameCounts: {'attack': 5},
    ),
    PetDefinition(
      id: 'phoenix',
      name: 'Phoenix',
      spriteSheet: 'phoenix.png',
      cost: 100,
      cellWidth: 147,
      cellHeight: 91,
      maxHp: 90,
      damage: 8,
      cooldown: 1.8,
      lifestealChance: 0.40, // fire/rebirth theme fits lifesteal
      attackFrameCounts: {'attack': 5},
    ),
    PetDefinition(
      id: 'griffin',
      name: 'Griffin',
      spriteSheet: 'griffin.png',
      cost: 150,
      cellWidth: 96,
      cellHeight: 81,
      maxHp: 100,
      damage: 9,
      cooldown: 1.6,
      doubleAttackChance: 0.30, // fast, fierce — double-strike theme
      attackFrameCounts: {'attack': 5},
    ),
    PetDefinition(
      // cat sound effect
      id: 'frost',
      name: 'Frost',
      spriteSheet: 'frost.png',
      cost: 180,
      cellWidth: 106,
      cellHeight: 72,
      maxHp: 120,
      damage: 9,
      cooldown: 1.6,
      stunChance: 0.40,
      stunDuration: 1.0, // ice/freeze theme fits stun
      attackFrameCounts: {'attack': 3},
    ),
    PetDefinition(
      id: 'dragon',
      name: 'Dragon',
      spriteSheet: 'dragon.png',
      cost: 200,
      cellWidth: 132,
      cellHeight: 86,
      maxHp: 130,
      damage: 11,
      cooldown: 1.4,
      doubleAttackChance: 0.40,
      stunChance: 0.10,
      stunDuration: 1.0,
      attackFrameCounts: {'attack': 5},
    ),
    PetDefinition(
      // cat sound effect
      id: 'void',
      name: 'Void',
      spriteSheet: 'void.png',
      cost: 250,
      cellWidth: 104,
      cellHeight: 78,
      maxHp: 150,
      damage: 15,
      cooldown: 1.3,
      doubleAttackChance: 0.20,
      lifestealChance: 0.40,
      stunChance: 0.10,
      stunDuration: 1.5,
      attackFrameCounts: {'attack': 4},
    ),
  ];

  static PetDefinition byId(String id) => all.firstWhere((p) => p.id == id);
}
