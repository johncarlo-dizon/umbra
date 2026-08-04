import 'package:flame/components.dart';

import '../dungeon_game.dart';
import 'enemy_base.dart';

/// Sits still until the player comes within [detectionRadius], then
/// pursues directly. Gives up and returns to idling if the player breaks
/// line-of-range by [giveUpRadius] (kept larger than [detectionRadius] so
/// it doesn't flicker in and out of chase at the boundary).
class ChaseEnemy extends EnemyBase with HasGameRef<DungeonGame> {
  ChaseEnemy({required super.position, this.detectionRadius = 130})
    : super(
        size: Vector2.all(28),
        maxHp: 55,
        contactDamage: 15,
        spriteFile: 'aqua_master_spritesheet.png',
        cellSize: Vector2(164, 95),
      );

  final double detectionRadius;
  late final double giveUpRadius = detectionRadius * 1.6;
  static const double speed = 95;
  bool _chasing = false;

  @override
  void updateAi(double dt) {
    final player = gameRef.player;
    if (player == null) {
      setFacingFromVelocity(Vector2.zero());
      return;
    }

    final toPlayer = player.position - position;
    final distance = toPlayer.length;

    if (!_chasing && distance <= detectionRadius) {
      _chasing = true;
    } else if (_chasing && distance > giveUpRadius) {
      _chasing = false;
    }

    if (_chasing && distance > 1) {
      final velocity = toPlayer.normalized() * speed;
      position.add(velocity * dt);
      setFacingFromVelocity(velocity);
    } else {
      setFacingFromVelocity(Vector2.zero());
    }
  }
}
