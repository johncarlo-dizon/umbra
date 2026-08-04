import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'enemy_base.dart';
import 'wall_block.dart';

/// A simple thrown projectile (alternative to `MeleeHitbox` for ranged
/// attacks). Travels in a straight line at [speed] px/sec along
/// [direction], deals [damage] to the first enemy it touches, and is
/// destroyed on wall contact or after [maxLifespan] seconds so stray shots
/// don't linger forever off-screen.
class Projectile extends PositionComponent with CollisionCallbacks {
  Projectile({
    required Vector2 position,
    required this.direction,
    this.speed = 260,
    this.damage = 15,
    this.maxLifespan = 2.0,
  }) : super(position: position, size: Vector2.all(10), anchor: Anchor.center);

  final Vector2 direction;
  final double speed;
  final int damage;
  final double maxLifespan;
  double _age = 0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox(collisionType: CollisionType.active));
  }

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      size.x / 2,
      Paint()
        ..color = const Color(
          0xFFFF7A1A,
        ), // Umbra orange — HUD/FX layer, not theme-bound
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.add(direction.normalized() * speed * dt);
    _age += dt;
    if (_age >= maxLifespan) {
      removeFromParent();
    }
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is EnemyBase) {
      other.takeDamage(damage);
      removeFromParent();
    } else if (other is WallBlock) {
      removeFromParent();
    }
  }
}
