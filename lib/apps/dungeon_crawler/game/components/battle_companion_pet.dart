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

enum PetFacing { down, up, right, left }

/// The player's equipped battle companion — follows at a short lag,
/// auto-attacks the nearest enemy in range on a cooldown, has its own HP
/// (can be damaged by enemies, faints at 0 rather than dying permanently),
/// and rolls its tier's special ability chance on every hit (double
/// attack / stun / lifesteal, per `PetDefinition`).
///
/// Row layout matches every pet sheet's fixed convention: 0=walk_down,
/// 1=walk_up, 2=walk_right, 3=attack, 4=fainted. There's no dedicated
/// left-facing art — same trick as the player's attack variants, `right`
/// is mirrored at runtime via `scale.x = -1`.
class BattleCompanionPet extends PositionComponent
    with CollisionCallbacks, HasGameRef<DungeonGame> {
  BattleCompanionPet({required this.definition, required Vector2 position})
    : hp = definition.maxHp,
      super(position: position, size: Vector2.all(20), anchor: Anchor.center);

  final PetDefinition definition;
  int hp;
  bool get isFainted => hp <= 0;

  static const double followDistance =
      28; // how far behind the player it trails
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

    // Match Player's depth-sorting so the pet renders correctly relative
    // to whatever floor/walls/enemies get built on later levels — see
    // fullHeal() and update() for why this matters across transitions.
    priority = position.y.toInt();
  }

  /// Called by `DungeonGame` on every level transition and player revive
  /// — "each floor/revive is a fresh start" for the pet, no partial-HP
  /// carry-over, per the design plan.
  ///
  /// Also fully resets any transient visual/animation state. The pet
  /// component itself survives level transitions (unlike tiles/walls/
  /// enemies, which are torn down and rebuilt — see
  /// `DungeonGame._clearLevelEntities`), so anything left dangling here
  /// — a mid-flash effect, a stuck attack animation, a stale render
  /// priority — carries over silently into the next floor instead of
  /// being naturally reset by recreation.
  void fullHeal() {
    hp = definition.maxHp;

    // Clear ANY lingering effect (not just ColorEffect) so a heal can
    // never leave a stuck opacity/tint mid-transition.
    _animComponent.children.whereType<Effect>().toList().forEach(
      (e) => e.removeFromParent(),
    );
    _animComponent.opacity = 1.0;

    // A faint that was mid-countdown when the floor changed must not be
    // allowed to fire afterward and rip a freshly-healed pet back out
    // of the world.
    _faintTimer = null;

    // Don't resume mid-attack into a new floor with a dangling
    // onComplete callback pointing at old state.
    _isAttacking = false;
    _attackCooldown = 0;
    _animComponent.animationTicker?.onComplete = null;

    final safeFacing = _facing == PetFacing.left ? PetFacing.right : _facing;
    _animComponent.animation = _walkAnimations[safeFacing];

    // Re-sync depth sort immediately — don't wait for the next update()
    // tick, since DungeonGame repositions the pet in the same frame the
    // new level's tiles/walls get appended after it in the child list.
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
    }
  }

  static const double meleeRange = 20;

  @override
  void update(double dt) {
    super.update(dt);

    // Keep depth-sorted against everything else every frame, same as
    // Player — not just at spawn/heal time.
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

    final target = _findNearestEnemy(player);
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

  EnemyBase? _findNearestEnemy(dynamic player) {
    EnemyBase? nearest;
    double nearestDist = detectionRadius;
    for (final child in gameRef.gameWorld.children) {
      if (child is EnemyBase && !child.isDead) {
        final dist = (child.position - position).length;
        if (dist < nearestDist) {
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

    var damage = definition.damage;
    final isDoubleHit = _rng.nextDouble() < definition.doubleAttackChance;
    if (isDoubleHit) damage *= 2;

    target.takeDamage(damage);
    gameRef.addComponentToWorld(
      DamageNumber(
        position: target.position.clone() + Vector2(0, -20),
        amount: damage,
        color: Colors.lightGreenAccent,
      ),
    );

    if (_rng.nextDouble() < definition.lifestealChance) {
      hp = (hp + (damage ~/ 2)).clamp(0, definition.maxHp);
    }
    if (_rng.nextDouble() < definition.stunChance) {
      target.applyStun(definition.stunDuration);
    }

    _animComponent.animationTicker?.onComplete = () {
      _isAttacking = false;
      _animComponent.animation =
          _walkAnimations[_facing == PetFacing.left
              ? PetFacing.right
              : _facing];
    };
  }

  @override
  void render(Canvas canvas) {
    if (isFainted)
      return; // no HP bar once fainted — the fainted pose already communicates it
    const barWidth = 22.0, barHeight = 3.0;
    canvas.drawRect(
      Rect.fromLTWH(-1, -6, barWidth, barHeight),
      Paint()..color = Colors.black54,
    );
    canvas.drawRect(
      Rect.fromLTWH(-1, -6, barWidth * (hp / definition.maxHp), barHeight),
      Paint()..color = Colors.lightGreenAccent,
    );
  }
}
