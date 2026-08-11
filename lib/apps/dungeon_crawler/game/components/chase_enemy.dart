import 'package:flame/components.dart';

import '../dungeon_game.dart';
import 'battle_companion_pet.dart';
import 'enemy_base.dart';
import '../../audio/dungeon_audio.dart';

class ChaseEnemy extends EnemyBase with HasGameRef<DungeonGame> {
  ChaseEnemy({required super.position, this.detectionRadius = 130})
    : super(
        size: Vector2.all(28),
        maxHp: 100,
        contactDamage: 15,
        spriteFile: 'sige.png',
        cellSize: Vector2(84, 742 / 9),
      );

  final double detectionRadius;
  late final double giveUpRadius = detectionRadius * 1.6;
  static const double speed = 95;

  /// How close the enemy is willing to close the gap to. Stopping short
  /// instead of driving distance to ~0 avoids getting visually "glued" to
  /// the target and avoids `toTarget.normalized()` degenerating to NaN.
  static const double meleeRange = 22;

  bool _chasing = false;

  @override
  BattleCompanionPet? get guardPet => gameRef.pet;

  @override
  void updateAi(double dt) {
    if (isStunned) return;
    final target = _findTarget();
    if (target == null) {
      _chasing = false;
      setFacingFromVelocity(Vector2.zero());
      return;
    }

    final toTarget = target.position - position;
    final distance = toTarget.length;

    // Walls block both sight and sound — an enemy standing on the other
    // side of a wall block should neither notice the target nor keep
    // tracking it once a wall slides between them mid-chase.
    final canSee = gameRef.hasLineOfSight(position, target.position);

    if (!_chasing && distance <= detectionRadius && canSee) {
      _chasing = true;
      DungeonAudio.chaseAggro();
    } else if (_chasing && (distance > giveUpRadius || !canSee)) {
      _chasing = false;
    }

    if (_chasing && distance > meleeRange) {
      final velocity = toTarget.normalized() * speed;
      position.add(velocity * dt);
      setFacingFromVelocity(velocity);
    } else {
      setFacingFromVelocity(Vector2.zero());
    }
  }

  /// Protector rule: the pet is the sole target as long as it's alive.
  /// The enemy only turns its attention to the player once the pet has
  /// fainted — it's a strict priority, not a "whichever is closer" pick.
  PositionComponent? _findTarget() {
    final pet = gameRef.pet;
    if (pet != null && !pet.isFainted) return pet;
    return gameRef.player;
  }
}
