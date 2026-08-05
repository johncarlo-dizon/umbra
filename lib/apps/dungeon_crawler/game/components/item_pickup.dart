import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';

import '../dungeon_game.dart';
import '../../models/inventory.dart';
import 'player.dart';

/// A key, potion, or coin sitting on the map. [itemId] must be unique and
/// is what `LockedDoor.requiresKey` compares against for keys — it comes
/// straight from the `itemId` property on the Tiled object.
///
/// Potions and coins use real looping sprite animations
/// (`potion_spritesheet.png` / `coin_spritesheet.png`, both in
/// `assets/images/`). Keys still use a flat-color placeholder square —
/// no key art was generated yet.
class ItemPickup extends PositionComponent
    with CollisionCallbacks, HasGameRef<DungeonGame> {
  ItemPickup({
    required Vector2 position,
    required this.itemId,
    required this.kind,
  }) : super(position: position, size: Vector2.all(20), anchor: Anchor.center);

  final String itemId;
  final ItemKind kind;

  SpriteAnimationComponent? _animComponent;

  Color get _keyColor => const Color(0xFF00E5FF);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox(collisionType: CollisionType.passive));

    switch (kind) {
      case ItemKind.potion:
        final image = await gameRef.images.load('potion_spritesheet.png');
        final sheet = SpriteSheet(image: image, srcSize: Vector2(106, 157));
        final anim = sheet.createAnimation(
          row: 0,
          stepTime: 0.2,
          to: 4,
          loop: true,
        );
        _animComponent = SpriteAnimationComponent(
          animation: anim,
          size: Vector2(18, 26),
          anchor: Anchor.center,
          position: size / 2,
        );
        add(_animComponent!);
        break;
      case ItemKind.coin:
        final image = await gameRef.images.load('coin_spritesheet.png');
        final sheet = SpriteSheet(image: image, srcSize: Vector2(103, 100));
        final anim = sheet.createAnimation(
          row: 0,
          stepTime: 0.12,
          to: 6,
          loop: true,
        );
        _animComponent = SpriteAnimationComponent(
          animation: anim,
          size: Vector2(16, 16),
          anchor: Anchor.center,
          position: size / 2,
        );
        add(_animComponent!);
        break;
      case ItemKind.key:
        // no art yet — flat placeholder, drawn in render() below
        break;
    }
  }

  @override
  void render(Canvas canvas) {
    if (kind == ItemKind.key) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()..color = _keyColor,
      );
    }
    // potion/coin render themselves via their SpriteAnimationComponent child
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Player) {
      gameRef.inventory.addItem(itemId, kind);
      removeFromParent();
    }
  }
}
