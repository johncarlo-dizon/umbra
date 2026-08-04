import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import 'enemy_base.dart';

/// A short-lived, invisible-ish hitbox spawned in front of the player on
/// attack. Deals [damage] once per enemy it overlaps, then removes itself
/// after [lifespan] seconds. Kept dumb on purpose — visual feedback (a
/// swing sprite/animation) can be layered on later without touching the
/// collision logic here.
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
    }
  }
}
