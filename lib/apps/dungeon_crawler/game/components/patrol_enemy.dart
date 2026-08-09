import 'package:flame/components.dart';

import 'enemy_base.dart';
import '../dungeon_game.dart';
import '../../audio/dungeon_audio.dart';

/// Walks a fixed loop of waypoints and never reacts to the player —
/// simplest of the two enemy archetypes. Waypoints come from the
/// `pathPoints` property on the Tiled object (tile-grid coordinates,
/// semicolon-separated, e.g. `"13,2;16,2;16,5;13,5"`), parsed in
/// `DungeonGame._spawnFromObjects()`.
class PatrolEnemy extends EnemyBase with HasGameRef<DungeonGame> {
  PatrolEnemy({required super.position, required this.waypoints})
    : super(
        size: Vector2.all(26),
        maxHp: 40,
        contactDamage: 10,
        spriteFile: 'boylisensya.png',
        cellSize: Vector2(84, 742 / 9),
      );

  final List<Vector2> waypoints;
  int _targetIndex = 0;
  static const double speed = 55;
  static const double arriveThreshold = 4;

  static const double _barkRadius = 64; // ~2 tiles at 32px/tile
  static const double _barkGiveUpRadius = 90;
  bool _playerNearby = false;

  @override
  void updateAi(double dt) {
    if (isStunned) return;
    _checkProximityBark();

    if (waypoints.isEmpty) {
      setFacingFromVelocity(Vector2.zero());
      return;
    }
    final target = waypoints[_targetIndex];
    final toTarget = target - position;
    if (toTarget.length <= arriveThreshold) {
      _targetIndex = (_targetIndex + 1) % waypoints.length;
      return;
    }
    final velocity = toTarget.normalized() * speed;
    position.add(velocity * dt);
    setFacingFromVelocity(velocity);
  }

  void _checkProximityBark() {
    final player = gameRef.player;
    if (player == null) return;
    final distance = (player.position - position).length;

    if (!_playerNearby && distance <= _barkRadius) {
      _playerNearby = true;
      DungeonAudio.patrolBark();
    } else if (_playerNearby && distance > _barkGiveUpRadius) {
      _playerNearby = false;
    }
  }
}
