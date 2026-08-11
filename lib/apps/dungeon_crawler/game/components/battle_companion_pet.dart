import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import '../../models/pet_definition.dart';
import '../dungeon_game.dart';
import 'damage_number.dart';
import 'enemy_base.dart';
import 'dart:math' as math;
import 'wall_block.dart';
import 'locked_door.dart';
import '../../audio/dungeon_audio.dart';
import 'floating_label.dart';
import 'package:flame/particles.dart';

enum PetFacing { down, up, right, left }

class BattleCompanionPet extends PositionComponent
    with CollisionCallbacks, HasGameRef<DungeonGame> {
  BattleCompanionPet({required this.definition, required Vector2 position})
    : hp = definition.maxHp,
      super(position: position, size: Vector2.all(20), anchor: Anchor.center);

  final PetDefinition definition;
  int hp;
  bool get isFainted => hp <= 0;

  static const double followDistance = 28;
  static const double followSpeed = 160;
  static const double detectionRadius = 90;

  double _attackCooldown = 0;
  bool _isAttacking = false;
  PetFacing _facing = PetFacing.down;
  bool _isFlipped = false;
  final Random _rng = Random();
  double? _faintTimer;
  static const double faintDisplayDuration = 1.2;
  late final SpriteAnimationComponent _animComponent;
  late final Map<PetFacing, SpriteAnimation> _walkAnimations;
  late final SpriteAnimation _attackAnimation;
  late final SpriteAnimation _faintedAnimation;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox(collisionType: CollisionType.active));

    final image = await gameRef.images.load(definition.spriteSheet);
    final sheet = SpriteSheet(
      image: image,
      srcSize: Vector2(definition.cellWidth, definition.cellHeight),
    );
    final attackFrames = definition.attackFrameCounts['attack'] ?? 4;

    _walkAnimations = {
      PetFacing.down: sheet.createAnimation(row: 0, stepTime: 0.16, to: 5),
      PetFacing.up: sheet.createAnimation(row: 1, stepTime: 0.16, to: 5),
      PetFacing.right: sheet.createAnimation(row: 2, stepTime: 0.16, to: 5),
    };
    _attackAnimation = sheet.createAnimation(
      row: 3,
      stepTime: 0.1,
      to: attackFrames,
      loop: false,
    );
    _faintedAnimation = sheet.createAnimation(
      row: 4,
      stepTime: 0.3,
      to: 2,
      loop: true,
    );

    _animComponent = SpriteAnimationComponent(
      animation: _walkAnimations[PetFacing.down],
      size: Vector2(28, 28),
      anchor: Anchor.bottomCenter,
      position: Vector2(size.x / 2, size.y),
      removeOnFinish: false,
    );
    add(_animComponent);
    priority = position.y.toInt();
  }

  void fullHeal() {
    hp = definition.maxHp;
    _animComponent.children.whereType<Effect>().toList().forEach(
      (e) => e.removeFromParent(),
    );
    _animComponent.opacity = 1.0;
    _faintTimer = null;
    _isAttacking = false;
    _attackCooldown = 0;
    _animComponent.animationTicker?.onComplete = null;
    final safeFacing = _facing == PetFacing.left ? PetFacing.right : _facing;
    _animComponent.animation = _walkAnimations[safeFacing];
    priority = position.y.toInt();
  }

  void _pushOutOfSolid(PositionComponent other) {
    final selfRect = Rect.fromLTWH(
      position.x - size.x / 2,
      position.y - size.y / 2,
      size.x,
      size.y,
    );
    final otherRect = Rect.fromLTWH(
      other.position.x,
      other.position.y,
      other.size.x,
      other.size.y,
    );
    final overlapX =
        math.min(selfRect.right, otherRect.right) -
        math.max(selfRect.left, otherRect.left);
    final overlapY =
        math.min(selfRect.bottom, otherRect.bottom) -
        math.max(selfRect.top, otherRect.top);
    if (overlapX <= 0 || overlapY <= 0) return;
    if (overlapX < overlapY) {
      position.x += selfRect.center.dx < otherRect.center.dx
          ? -overlapX
          : overlapX;
    } else {
      position.y += selfRect.center.dy < otherRect.center.dy
          ? -overlapY
          : overlapY;
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is WallBlock) _pushOutOfSolid(other);
    if (other is LockedDoor && !other.isOpen) _pushOutOfSolid(other);
  }

  void takeDamage(int amount) {
    if (isFainted) return;
    hp = (hp - amount).clamp(0, definition.maxHp);
    _animComponent.add(
      ColorEffect(
        Colors.white,
        EffectController(duration: 0.08, alternate: true),
        opacityFrom: 0.0,
        opacityTo: 0.7,
      ),
    );
    gameRef.addComponentToWorld(
      DamageNumber(
        position: position.clone() + Vector2(0, -18),
        amount: amount,
        color: Colors.orangeAccent,
      ),
    );
    if (isFainted) {
      _animComponent.animation = _faintedAnimation;
      _faintTimer = faintDisplayDuration;
      DungeonAudio.petDie(definition.id);
    }
  }

  static const double meleeRange = 20;

  @override
  void update(double dt) {
    super.update(dt);
    priority = position.y.toInt();

    if (_faintTimer != null) {
      _faintTimer = _faintTimer! - dt;
      if (_faintTimer! <= 0) {
        _faintTimer = null;
        if (gameRef.pet == this) gameRef.pet = null;
        removeFromParent();
      }
      return;
    }

    if (_attackCooldown > 0) _attackCooldown -= dt;

    final player = gameRef.player;
    if (player == null) return;

    if (isFainted) {
      _followPlayer(player, dt);
      return;
    }

    if (_isAttacking) return;

    final target = _findNearestEnemy();
    if (target != null) {
      final distance = (target.position - position).length;
      if (distance <= meleeRange) {
        if (_attackCooldown <= 0) _attack(target);
      } else {
        _moveToward(target.position, dt);
      }
    } else {
      _followPlayer(player, dt);
    }
  }

  void _moveToward(Vector2 targetPos, double dt) {
    final toTarget = targetPos - position;
    if (toTarget.length > 2) {
      final velocity = toTarget.normalized() * followSpeed;
      position.add(velocity * dt);
      _setFacingFromVelocity(velocity);
    }
  }

  /// Only considers enemies within radius **and** in line of sight — a
  /// pet standing behind a wall from an enemy shouldn't suddenly beeline
  /// through it to attack.
  EnemyBase? _findNearestEnemy() {
    EnemyBase? nearest;
    double nearestDist = detectionRadius;
    for (final child in gameRef.gameWorld.children) {
      if (child is EnemyBase && !child.isDead) {
        final dist = (child.position - position).length;
        if (dist < nearestDist &&
            gameRef.hasLineOfSight(position, child.position)) {
          nearest = child;
          nearestDist = dist;
        }
      }
    }
    return nearest;
  }

  void _followPlayer(dynamic player, double dt) {
    final toPlayer = player.position - position;
    final distance = toPlayer.length;
    if (distance > followDistance) {
      final velocity = toPlayer.normalized() * followSpeed;
      position.add(velocity * dt);
      _setFacingFromVelocity(velocity);
    }
  }

  void _setFacingFromVelocity(Vector2 velocity) {
    if (velocity.length2 < 0.0001) return;
    final previous = _facing;
    if (velocity.x.abs() > velocity.y.abs()) {
      _facing = PetFacing.right;
      _isFlipped = velocity.x < 0;
    } else {
      _facing = velocity.y > 0 ? PetFacing.down : PetFacing.up;
      _isFlipped = false;
    }
    final anim = _facing == PetFacing.left
        ? _walkAnimations[PetFacing.right]
        : _walkAnimations[_facing];
    if (_facing != previous || _animComponent.animation != anim) {
      _animComponent.animation = anim;
    }
    _animComponent.scale.x = _isFlipped ? -1 : 1;
  }

  void _attack(EnemyBase target) {
    _isAttacking = true;
    _attackCooldown = definition.cooldown;
    _isFlipped = target.position.x < position.x;
    _animComponent.scale.x = _isFlipped ? -1 : 1;
    _animComponent.animation = _attackAnimation;
    DungeonAudio.petAttack(definition.id);

    var damage = definition.damage;
    final isDoubleHit = _rng.nextDouble() < definition.doubleAttackChance;
    if (isDoubleHit) damage *= 2;

    target.takeDamage(damage);
    gameRef.addComponentToWorld(
      DamageNumber(
        position: target.position.clone() + Vector2(0, -20),
        amount: damage,
        color: isDoubleHit ? Colors.amberAccent : Colors.lightGreenAccent,
      ),
    );
    if (isDoubleHit) {
      gameRef.addComponentToWorld(
        FloatingLabel(
          text: '2x!',
          position: target.position.clone() + Vector2(0, -34),
          color: Colors.amberAccent,
        ),
      );
      _playCritBurst(target.position.clone());
    }

    final didLifesteal = _rng.nextDouble() < definition.lifestealChance;
    if (didLifesteal) {
      final healed = damage ~/ 2;
      hp = (hp + healed).clamp(0, definition.maxHp);
      gameRef.addComponentToWorld(
        DamageNumber(
          position: position.clone() + Vector2(0, -20),
          amount: healed,
          color: Colors.pinkAccent, // heal number shown on the pet itself
        ),
      );
      _playLifestealBurst();
    }

    final didStun = _rng.nextDouble() < definition.stunChance;
    if (didStun) {
      target.applyStun(definition.stunDuration);
      gameRef.addComponentToWorld(
        FloatingLabel(
          text: 'STUN',
          position: target.position.clone() + Vector2(0, -34),
          color: Colors.lightBlueAccent,
        ),
      );
      // quick blue flicker on the enemy so the stun is visible even if
      // you miss the text popup
      target.animComponent.add(
        ColorEffect(
          Colors.lightBlueAccent,
          EffectController(duration: 0.15, alternate: true, repeatCount: 3),
          opacityFrom: 0.0,
          opacityTo: 0.5,
        ),
      );
    }

    _animComponent.animationTicker?.onComplete = () {
      _isAttacking = false;
      _animComponent.animation =
          _walkAnimations[_facing == PetFacing.left
              ? PetFacing.right
              : _facing];
    };
  }

  void _playLifestealBurst() {
    gameRef.addComponentToWorld(
      ParticleSystemComponent(
        position: position.clone(),
        particle: Particle.generate(
          count: 5,
          lifespan: 0.6,
          generator: (i) {
            final angle = (i / 5) * 2 * math.pi + _rng.nextDouble() * 0.6;
            return AcceleratedParticle(
              speed: Vector2(math.cos(angle), math.sin(angle)) * -18,
              acceleration: Vector2(0, -55), // hearts drift upward as they fade
              child: ComputedParticle(
                renderer: (canvas, particle) {
                  final progress = particle.progress;
                  final alpha = (1 - progress).clamp(0.0, 1.0);
                  final scale = 1.0 - progress * 0.25;
                  final paint = Paint()
                    ..color = Colors.pinkAccent.withValues(alpha: alpha)
                    ..style = PaintingStyle.fill;
                  canvas.save();
                  canvas.rotate((_rng.nextDouble() - 0.5) * 0.3);
                  _drawHeart(canvas, paint, scale);
                  canvas.restore();
                },
              ),
            );
          },
        ),
      ),
    );
    _animComponent.add(
      ColorEffect(
        Colors.pinkAccent,
        EffectController(duration: 0.12, alternate: true, repeatCount: 2),
        opacityFrom: 0.0,
        opacityTo: 0.6,
      ),
    );
  }

  void _drawHeart(Canvas canvas, Paint paint, double scale) {
    final s = scale * 3.0;
    final path = Path()
      ..moveTo(0, 1.2 * s)
      ..cubicTo(-2.4 * s, -1.0 * s, -1.2 * s, -2.6 * s, 0, -1.0 * s)
      ..cubicTo(1.2 * s, -2.6 * s, 2.4 * s, -1.0 * s, 0, 1.2 * s)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _playCritBurst(Vector2 at) {
    gameRef.addComponentToWorld(
      ParticleSystemComponent(
        position: at,
        particle: Particle.generate(
          count: 10,
          lifespan: 0.3,
          generator: (i) {
            final angle = (i / 10) * 2 * math.pi + _rng.nextDouble() * 0.3;
            final dir = Vector2(math.cos(angle), math.sin(angle));
            final length = 6.0 + _rng.nextDouble() * 4.0;
            return AcceleratedParticle(
              speed: dir * 140,
              acceleration: dir * -260, // sharp burst that decelerates fast
              child: ComputedParticle(
                renderer: (canvas, particle) {
                  final progress = particle.progress;
                  final alpha = (1 - progress).clamp(0.0, 1.0);
                  final paint = Paint()
                    ..color = Colors.redAccent.withValues(alpha: alpha)
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 1.8
                    ..strokeCap = StrokeCap.round;
                  canvas.save();
                  canvas.rotate(angle);
                  canvas.drawLine(
                    Offset.zero,
                    Offset(length * (1 - progress * 0.4), 0),
                    paint,
                  );
                  canvas.restore();
                },
              ),
            );
          },
        ),
      ),
    );

    // a quick expanding ring at the impact point sells the "crit" weight
    gameRef.addComponentToWorld(
      ParticleSystemComponent(
        position: at,
        particle: ComputedParticle(
          lifespan: 0.22,
          renderer: (canvas, particle) {
            final progress = particle.progress;
            final radius = 4 + progress * 10;
            final alpha = (1 - progress).clamp(0.0, 1.0);
            final paint = Paint()
              ..color = Colors.redAccent.withValues(alpha: alpha * 0.8)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2;
            canvas.drawCircle(Offset.zero, radius, paint);
          },
        ),
      ),
    );
  }

  @override
  void render(Canvas canvas) {
    if (isFainted) return;
    const barWidth = 22.0, barHeight = 3.0;
    canvas.drawRect(
      Rect.fromLTWH(-1, -6, barWidth, barHeight),
      Paint()..color = Colors.black54,
    );
    canvas.drawRect(
      Rect.fromLTWH(-1, -6, barWidth * (hp / definition.maxHp), barHeight),
      Paint()..color = Colors.tealAccent,
    );
  }
}
