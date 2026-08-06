import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'dart:math' as math;
import 'wall_block.dart';
import '../dungeon_game.dart';
import 'enemy_base.dart';
import 'melee_hitbox.dart';
import 'locked_door.dart';
import '../../audio/dungeon_audio.dart';

enum FacingDirection { up, down, left, right }

enum PlayerAnimState { walk, attack, heal, death, spawn, victory }

/// The player character.
///
/// Animation model: walk/heal/death/spawn/victory come from
/// `player_master_spritesheet.png` (10-row sheet, cell 197x232 — rows 4/5
/// "attack"/"attack_left" in that file are unused now, superseded by the
/// richer variant set below). Attacks come from a SEPARATE file,
/// `player_attack_variants_spritesheet.png` (9 rows, cell 341x204, right-
/// facing only) — each call to `attack()` cycles to the next variant, and
/// left-facing is achieved by flipping the sprite horizontally at runtime
/// (`_animComponent.scale.x = -1`) rather than needing mirrored art.
class Player extends PositionComponent
    with CollisionCallbacks, KeyboardHandler, HasGameRef<DungeonGame> {
  Player({required Vector2 position})
    : super(position: position, size: Vector2.all(28), anchor: Anchor.center);

  static const double speed = 130;
  static const int maxHp = 100;
  static const double attackCooldown = 0.45;
  static const int potionHealAmount = 35;

  final Vector2 _keyboardDirection = Vector2.zero();
  Vector2 joystickDirection = Vector2.zero();

  FacingDirection facing = FacingDirection.down;
  double _attackTimer = 0;
  bool _invulnerable = false;
  double _invulnTimer = 0;
  static const double invulnDuration = 0.6;
  bool _isDead = false;
  bool _isFlipped = false;

  late final SpriteAnimationComponent _animComponent;

  late final Map<FacingDirection, SpriteAnimation> _walkAnimations;
  late final SpriteAnimation _healAnimation;
  late final SpriteAnimation _deathAnimation;
  late final SpriteAnimation _spawnAnimation;
  late final SpriteAnimation _victoryAnimation;

  late final List<SpriteAnimation> _attackVariants;
  int _currentAttackVariant = 0;
  double _ambientMutterTimer = 3; // first mutter after ~12s of walking
  final math.Random _rng = math.Random();
  PlayerAnimState _state = PlayerAnimState.spawn;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox(collisionType: CollisionType.active));

    // --- main master sheet: walk / heal / death / spawn / victory ---
    final masterImage = await gameRef.images.load('maindiwa.png');
    final masterSheet = SpriteSheet(
      image: masterImage,
      srcSize: Vector2(73, 86),
    );
    SpriteAnimation m(
      int row,
      int frames, {
      double stepTime = 0.15,
      bool loop = true,
    }) => masterSheet.createAnimation(
      row: row,
      stepTime: stepTime,
      to: frames,
      loop: loop,
    );

    _walkAnimations = {
      FacingDirection.down: m(0, 4),
      FacingDirection.up: m(1, 4),
      FacingDirection.right: m(2, 4),
      FacingDirection.left: m(3, 4),
    };
    _healAnimation = m(6, 3, stepTime: 0.18, loop: false);
    _deathAnimation = m(7, 4, stepTime: 0.18, loop: false);
    _spawnAnimation = m(8, 3, stepTime: 0.15, loop: false);
    _victoryAnimation = m(9, 2, stepTime: 0.25, loop: true);

    // --- attack variants sheet: 9 right-facing attacks, mirrored at runtime ---
    final variantImage = await gameRef.images.load('diwattack.png');
    final variantSheet = SpriteSheet(
      image: variantImage,
      srcSize: Vector2(125, 75),
    );
    const variantFrameCounts = [3, 2, 3, 3, 3, 3, 3, 3, 3];
    _attackVariants = [
      for (int i = 0; i < variantFrameCounts.length; i++)
        variantSheet.createAnimation(
          row: i,
          stepTime: 0.1,
          to: variantFrameCounts[i],
          loop: false,
        ),
    ];

    _animComponent = SpriteAnimationComponent(
      animation: _spawnAnimation,
      size: Vector2(32, 40), // was Vector2(48, 64)
      anchor: Anchor.bottomCenter,
      position: Vector2(size.x / 2, size.y),
      removeOnFinish: false,
    );
    add(_animComponent);
    _state = PlayerAnimState.spawn;
    _animComponent.animationTicker?.onComplete = () =>
        _setState(PlayerAnimState.walk);
  }

  void _setState(PlayerAnimState newState) {
    _state = newState;
    switch (newState) {
      case PlayerAnimState.walk:
        _isFlipped = false;
        _animComponent.animation = _walkAnimations[facing];
        break;
      case PlayerAnimState.attack:
        _isFlipped = facing == FacingDirection.left;
        _animComponent.animation = _attackVariants[_currentAttackVariant];
        break;
      case PlayerAnimState.heal:
        _isFlipped = false;
        _animComponent.animation = _healAnimation;
        break;
      case PlayerAnimState.death:
        _isFlipped = false;
        _animComponent.animation = _deathAnimation;
        break;
      case PlayerAnimState.spawn:
        _isFlipped = false;
        _animComponent.animation = _spawnAnimation;
        break;
      case PlayerAnimState.victory:
        _isFlipped = false;
        _animComponent.animation = _victoryAnimation;
        break;
    }
    _animComponent.scale.x = _isFlipped ? -1 : 1;
    if (newState == PlayerAnimState.attack ||
        newState == PlayerAnimState.heal) {
      _animComponent.animationTicker?.onComplete = () =>
          _setState(PlayerAnimState.walk);
    }
  }

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    final up =
        keysPressed.contains(LogicalKeyboardKey.arrowUp) ||
        keysPressed.contains(LogicalKeyboardKey.keyW);
    final down =
        keysPressed.contains(LogicalKeyboardKey.arrowDown) ||
        keysPressed.contains(LogicalKeyboardKey.keyS);
    final left =
        keysPressed.contains(LogicalKeyboardKey.arrowLeft) ||
        keysPressed.contains(LogicalKeyboardKey.keyA);
    final right =
        keysPressed.contains(LogicalKeyboardKey.arrowRight) ||
        keysPressed.contains(LogicalKeyboardKey.keyD);

    _keyboardDirection
      ..x = (right ? 1 : 0) - (left ? 1 : 0)
      ..y = (down ? 1 : 0) - (up ? 1 : 0);

    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.space ||
            event.logicalKey == LogicalKeyboardKey.keyJ)) {
      attack();
    }
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.keyE) {
      usePotion();
    }
    return true;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_isDead) return;

    final combined = (_keyboardDirection + joystickDirection);
    if (combined.length > 1) combined.normalize();

    final isAttackingOrHealing =
        _state == PlayerAnimState.attack || _state == PlayerAnimState.heal;

    if (combined.length2 > 0.0001 && !isAttackingOrHealing) {
      final previousFacing = facing;
      if (combined.x.abs() > combined.y.abs()) {
        facing = combined.x > 0 ? FacingDirection.right : FacingDirection.left;
      } else {
        facing = combined.y > 0 ? FacingDirection.down : FacingDirection.up;
      }
      if (_state != PlayerAnimState.walk || facing != previousFacing) {
        _setState(PlayerAnimState.walk);
      }
      position.add(combined * speed * dt);
      _ambientMutterTimer -= dt;
      if (_ambientMutterTimer <= 0) {
        DungeonAudio.playerAmbientMutter();
        _ambientMutterTimer = 10 + _rng.nextDouble() * 15; // next one in 10–25s
      }
    }
    priority = position.y.toInt();
    if (_attackTimer > 0) _attackTimer -= dt;
    if (_invulnerable) {
      _invulnTimer -= dt;
      if (_invulnTimer <= 0) _invulnerable = false;
    }
  }

  void attack() {
    if (_attackTimer > 0 || _isDead) return;
    _attackTimer = attackCooldown;
    _currentAttackVariant =
        (_currentAttackVariant + 1) % _attackVariants.length;
    _setState(PlayerAnimState.attack);

    final hitboxSize = Vector2(30, 30);
    Vector2 offset;
    switch (facing) {
      case FacingDirection.up:
        offset = Vector2(0, -size.y);
        break;
      case FacingDirection.down:
        offset = Vector2(0, size.y);
        break;
      case FacingDirection.left:
        offset = Vector2(-size.x, 0);
        break;
      case FacingDirection.right:
        offset = Vector2(size.x, 0);
        break;
    }

    gameRef.addComponentToWorld(
      MeleeHitbox(
        position: position + offset - hitboxSize / 2,
        size: hitboxSize,
      ),
    );
  }

  void usePotion() {
    if (_isDead) return;
    final consumed = gameRef.inventory.consumePotion();
    if (consumed) {
      gameRef.gameState.heal(potionHealAmount);
      DungeonAudio.potionDrink();
      _setState(PlayerAnimState.heal);
      debugPrint('Player: used potion, healed $potionHealAmount HP');
    } else {
      debugPrint('Player: no potions to use');
    }
  }

  void playVictory() {
    DungeonAudio.playerWin();
    _setState(PlayerAnimState.victory);
  }

  void takeDamage(int amount) {
    if (_invulnerable || _isDead) return;
    _invulnerable = true;
    _invulnTimer = invulnDuration;
    gameRef.gameState.damage(amount);
    if (gameRef.gameState.hp.value <= 0) {
      _isDead = true;
      DungeonAudio.playerDeath();
      _setState(PlayerAnimState.death);
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is WallBlock) _pushOutOfSolid(other);
    if (other is LockedDoor && !other.isOpen) _pushOutOfSolid(other);
    if (other is EnemyBase) takeDamage(other.contactDamage);
  }

  void _pushOutOfSolid(PositionComponent other) {
    final playerRect = Rect.fromLTWH(
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
        math.min(playerRect.right, otherRect.right) -
        math.max(playerRect.left, otherRect.left);
    final overlapY =
        math.min(playerRect.bottom, otherRect.bottom) -
        math.max(playerRect.top, otherRect.top);
    if (overlapX <= 0 || overlapY <= 0) return;

    if (overlapX < overlapY) {
      position.x += playerRect.center.dx < otherRect.center.dx
          ? -overlapX
          : overlapX;
    } else {
      position.y += playerRect.center.dy < otherRect.center.dy
          ? -overlapY
          : overlapY;
    }
  }
}
