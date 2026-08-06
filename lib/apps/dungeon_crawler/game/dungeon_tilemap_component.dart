// dungeon_tilemap_component.dart
//
// Renders the floor/wall tiles for a procedurally generated DungeonLevel.
// This replaces the *visual* role that TiledComponent used to play. Wall
// *collision* is still handled separately by WallBlock in dungeon_game.dart,
// same as before — this component is visuals only.
//
// Place at: lib/game/dungeon_tilemap_component.dart

import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'dungeon_generator.dart';

class DungeonTilemapComponent extends PositionComponent with HasGameReference {
  final DungeonLevel level;
  final double tileSize;

  DungeonTilemapComponent({required this.level, required this.tileSize});

  @override
  Future<void> onLoad() async {
    // Same tileset.png your .tmx files referenced: 160x32, 5 tiles of 32x32.
    // Lives at assets/images/tileset.png, and Flame's default image cache
    // prefix is 'assets/images/', so just the bare filename is correct here.
    final image = await game.images.load('tileset.png');
    final sheet = SpriteSheet(image: image, srcSize: Vector2(32, 32));

    final floorSprite = sheet.getSprite(0, 0); // tile gid 1 -> index 0
    final wallSprite = sheet.getSprite(0, 1); // tile gid 2 -> index 1

    for (var y = 0; y < level.ground.length; y++) {
      for (var x = 0; x < level.ground[y].length; x++) {
        if (level.ground[y][x] == 1) {
          add(
            SpriteComponent(
              sprite: floorSprite,
              position: Vector2(x * tileSize, y * tileSize),
              size: Vector2.all(tileSize),
            ),
          );
        } else if (level.walls[y][x] == 2) {
          add(
            SpriteComponent(
              sprite: wallSprite,
              position: Vector2(x * tileSize, y * tileSize),
              size: Vector2.all(tileSize),
            ),
          );
        }
      }
    }
  }
}
