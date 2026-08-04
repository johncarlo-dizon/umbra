import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';

import 'player.dart';

enum EnemyFacing { up, down, left, right }

abstract class EnemyBase extends PositionComponent with CollisionCallbacks {
  EnemyBase({
    required Vector2 position,
    required Vector2 size,
    required this.maxHp,
    required this.contactDamage,
    required this.spriteFile,
    required this.cellSize,
  }) : hp = maxHp,
       super(position: position, size: size, anchor: Anchor.center);

  final int maxHp;
  final int contactDamage;
  final String spriteFile;
  final Vector2 cellSize;
  int hp;
  bool get isDead => hp <= 0;
  bool _isDying = false;
  bool _isAttacking = false;
  double _attackAnimCooldown = 0;
  static const double _attackAnimInterval = 0.8;

  EnemyFacing facing = EnemyFacing.down;

  late final SpriteAnimationComponent animComponent;
  late final Map<EnemyFacing, SpriteAnimation> _walkAnimations;
  late final SpriteAnimation _attackRight;
  late final SpriteAnimation _attackLeft;
  late final SpriteAnimation _deathAnim;
  late final SpriteAnimation _spawnAnim;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox(collisionType: CollisionType.active));

    final image = await Flame.images.load(spriteFile);
    final sheet = SpriteSheet(image: image, srcSize: cellSize);
    SpriteAnimation a(
      int row,
      int frames, {
      double stepTime = 0.15,
      bool loop = true,
    }) => sheet.createAnimation(
      row: row,
      stepTime: stepTime,
      to: frames,
      loop: loop,
    );

    _walkAnimations = {
      EnemyFacing.down: a(0, 4),
      EnemyFacing.up: a(1, 4),
      EnemyFacing.right: a(2, 4),
      EnemyFacing.left: a(3, 4),
    };
    _attackRight = a(4, 3, stepTime: 0.12, loop: false);
    _attackLeft = a(5, 3, stepTime: 0.12, loop: false);
    _deathAnim = a(6, 4, stepTime: 0.18, loop: false);
    _spawnAnim = a(7, 3, stepTime: 0.15, loop: false);

    animComponent = SpriteAnimationComponent(
      animation: _spawnAnim,
      size: Vector2(size.x * 1.8, size.y * 1.8),
      anchor: Anchor.bottomCenter,
      position: Vector2(size.x / 2, size.y),
      removeOnFinish: false,
    );
    add(animComponent);
    animComponent.animationTicker?.onComplete = () {
      animComponent.animation = _walkAnimations[facing];
    };
  }

  void setFacingFromVelocity(Vector2 velocity) {
    if (_isAttacking || _isDying) return;
    if (velocity.length2 < 0.0001) return;

    final previousFacing = facing;
    if (velocity.x.abs() > velocity.y.abs()) {
      facing = velocity.x > 0 ? EnemyFacing.right : EnemyFacing.left;
    } else {
      facing = velocity.y > 0 ? EnemyFacing.down : EnemyFacing.up;
    }
    if (facing != previousFacing ||
        animComponent.animation != _walkAnimations[facing]) {
      animComponent.animation = _walkAnimations[facing];
    }
  }

  void _playAttackAnimation() {
    if (_isDying) return;
    _isAttacking = true;
    animComponent.animation = (facing == EnemyFacing.left)
        ? _attackLeft
        : _attackRight;
    animComponent.animationTicker?.onComplete = () {
      _isAttacking = false;
      animComponent.animation = _walkAnimations[facing];
      animComponent.animationTicker?.onComplete = () {
        animComponent.animation = _walkAnimations[facing];
      };
    };
  }

  void takeDamage(int amount) {
    if (isDead) return;
    hp = (hp - amount).clamp(0, maxHp);
    if (isDead) onDeath();
  }

  void onDeath() {
    if (_isDying) return;
    _isDying = true;
    animComponent.animation = _deathAnim;
    animComponent.animationTicker?.onComplete = () => removeFromParent();
  }

  void updateAi(double dt);

  @override
  void update(double dt) {
    super.update(dt);
    if (_attackAnimCooldown > 0) _attackAnimCooldown -= dt;
    if (!isDead) updateAi(dt);
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is Player && !isDead && _attackAnimCooldown <= 0) {
      _attackAnimCooldown = _attackAnimInterval;
      _playAttackAnimation();
    }
  }

  @override
  void render(Canvas canvas) {
    if (isDead && !_isDying) return;
    final barWidth = size.x;
    const barHeight = 4.0;
    canvas.drawRect(
      Rect.fromLTWH(0, -8, barWidth, barHeight),
      Paint()..color = Colors.black54,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, -8, barWidth * (hp / maxHp), barHeight),
      Paint()..color = Colors.redAccent,
    );
  }
}
