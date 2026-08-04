import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../dungeon_game.dart';
import '../../models/inventory.dart';
import 'player.dart';

/// A key, potion, or coin sitting on the map. [itemId] must be unique and
/// is what `LockedDoor.requiresKey` compares against for keys — it comes
/// straight from the `itemId` property on the Tiled object.
class ItemPickup extends PositionComponent
    with CollisionCallbacks, HasGameRef<DungeonGame> {
  ItemPickup({
    required Vector2 position,
    required this.itemId,
    required this.kind,
  }) : super(position: position, size: Vector2.all(18), anchor: Anchor.center);

  final String itemId;
  final ItemKind kind;

  Color get _color {
    switch (kind) {
      case ItemKind.key:
        return const Color(
          0xFF00E5FF,
        ); // was 0xFFFFD54F — too close to coin gold
      case ItemKind.potion:
        return const Color(0xFFE91E63);
      case ItemKind.coin:
        return const Color(0xFFFFC107);
    }
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox(collisionType: CollisionType.passive));
    add(
      TextComponent(
        text: kind.name.toUpperCase(),
        position: Vector2(size.x / 2, -10),
        anchor: Anchor.bottomCenter,
        textRenderer: TextPaint(
          style: const TextStyle(color: Colors.white, fontSize: 8),
        ),
      ),
    );
  }

  @override
  void render(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);
    if (kind == ItemKind.coin) {
      canvas.drawCircle(center, size.x / 2, Paint()..color = _color);
    } else {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()..color = _color,
      );
    }
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
