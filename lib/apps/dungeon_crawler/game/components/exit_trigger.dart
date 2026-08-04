import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../dungeon_game.dart';
import 'player.dart';

/// The level exit. Purely a sensor — no solid hitbox — so the player can
/// simply walk onto it. Triggers `DungeonGameState.reachExit()` on
/// contact, which flips `RunStatus` to `won` and the screen swaps in the
/// victory overlay.
class ExitTrigger extends PositionComponent
    with CollisionCallbacks, HasGameRef<DungeonGame> {
  ExitTrigger({required Vector2 position, required Vector2 size})
    : super(position: position, size: size);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox(collisionType: CollisionType.passive));
    add(
      TextComponent(
        text: 'EXIT',
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
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()..color = const Color(0xFF1E8C6E),
    );
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Player) {
      debugPrint('ExitTrigger: player reached exit');
      other.playVictory();
      gameRef.gameState.reachExit();
    }
  }
}
