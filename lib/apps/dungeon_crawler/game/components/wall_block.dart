import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

/// One invisible static collision tile, built from a non-empty cell in the
/// Tiled map's "Walls" layer. `DungeonGame` creates one of these per
/// wall tile when the map loads — see `_buildWallCollisions()`.
class WallBlock extends PositionComponent with CollisionCallbacks {
  WallBlock({required Vector2 position, required Vector2 size})
      : super(position: position, size: size);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox(collisionType: CollisionType.passive));
  }
}
