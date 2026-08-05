import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../../audio/dungeon_audio.dart';
import 'enemy_base.dart';

class MeleeHitbox extends PositionComponent with CollisionCallbacks {
  MeleeHitbox({
    required Vector2 position,
    required Vector2 size,
    this.damage = 20,
    this.lifespan = 0.15,
  }) : super(position: position, size: size);

  final int damage;
  final double lifespan;
  double _age = 0;
  final Set<EnemyBase> _alreadyHit = {};

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox(collisionType: CollisionType.active));
  }

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    if (_age >= lifespan) {
      if (_alreadyHit.isEmpty) {
        DungeonAudio.attackWhiff();
      }
      removeFromParent();
    }
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is EnemyBase && !_alreadyHit.contains(other)) {
      _alreadyHit.add(other);
      other.takeDamage(damage);
      DungeonAudio.attackHit();
    }
  }
}
