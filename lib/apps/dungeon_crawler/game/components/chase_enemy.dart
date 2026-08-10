import 'package:flame/components.dart';

import '../dungeon_game.dart';
import 'enemy_base.dart';
import '../../audio/dungeon_audio.dart';

class ChaseEnemy extends EnemyBase with HasGameRef<DungeonGame> {
  ChaseEnemy({required super.position, this.detectionRadius = 130})
    : super(
        size: Vector2.all(28),
        maxHp: 55,
        contactDamage: 15,
        spriteFile: 'sige.png',
        cellSize: Vector2(84, 742 / 9),
      );

  final double detectionRadius;
  late final double giveUpRadius = detectionRadius * 1.6;
  static const double speed = 95;
  bool _chasing = false;

  @override
  void updateAi(double dt) {
    if (isStunned) return;
    final target = _findNearestTarget();
    if (target == null) {
      setFacingFromVelocity(Vector2.zero());
      return;
    }

    final toTarget = target.position - position;
    final distance = toTarget.length;

    if (!_chasing && distance <= detectionRadius) {
      _chasing = true;
      DungeonAudio.chaseAggro();
    } else if (_chasing && distance > giveUpRadius) {
      _chasing = false;
    }

    if (_chasing && distance > 1) {
      final velocity = toTarget.normalized() * speed;
      position.add(velocity * dt);
      setFacingFromVelocity(velocity);
    } else {
      setFacingFromVelocity(Vector2.zero());
    }
  }

  PositionComponent? _findNearestTarget() {
    final player = gameRef.player;
    final pet = gameRef.pet;
    PositionComponent? nearest;
    double nearestDist = double.infinity;

    if (player != null) {
      final d = (player.position - position).length;
      if (d < nearestDist) {
        nearest = player;
        nearestDist = d;
      }
    }
    if (pet != null && !pet.isFainted) {
      final d = (pet.position - position).length;
      if (d < nearestDist) {
        nearest = pet;
        nearestDist = d;
      }
    }
    return nearest;
  }
}
