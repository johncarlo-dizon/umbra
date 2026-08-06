import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../dungeon_game.dart';
import '../../audio/dungeon_audio.dart';
import 'player.dart';

/// The level exit. If [isFinalExit] is true (last level's Exit object,
/// `isFinalExit` property set to true in Tiled), reaching it wins the
/// run. Otherwise it loads the next level via `DungeonGame.loadNextLevel()`.
class ExitTrigger extends PositionComponent
    with CollisionCallbacks, HasGameRef<DungeonGame> {
  ExitTrigger({
    required Vector2 position,
    required Vector2 size,
    required this.isFinalExit,
  }) : super(position: position, size: size);

  final bool isFinalExit;
  bool _triggered = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox(collisionType: CollisionType.passive));
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
    if (other is! Player || _triggered) return;
    _triggered = true;

    if (isFinalExit) {
      other.playVictory();
      gameRef.gameState.reachExit();
    } else {
      DungeonAudio.doorUnlock(); // reuse as a level-transition "chime" — swap for a dedicated sound later if you want one
      gameRef.loadNextLevel();
    }
  }
}
