import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame_tiled/flame_tiled.dart';
import 'package:flame/input.dart';
import '../models/dungeon_game_state.dart';
import '../models/inventory.dart';
import 'components/chase_enemy.dart';
import 'components/exit_trigger.dart';
import 'components/item_pickup.dart';
import 'components/locked_door.dart';
import 'components/patrol_enemy.dart';
import 'components/player.dart';
import 'components/wall_block.dart';
import 'package:flame/cache.dart';
import '../audio/dungeon_audio.dart';

/// Root Flame game for the dungeon crawler sub-app. Owns the shared
/// `DungeonGameState` (HP/win-lose) and `Inventory`, both handed in from
/// `DungeonCrawlerScreen` so the surrounding Flutter overlays
/// (`ValueListenableBuilder`s) can read the same instances the game
/// components mutate.
///
/// Map data: `assets/tiles/dungeon.tmx` + `assets/tiles/tileset.png`,
/// authored as a placeholder 3-room layout (start room -> locked-door
/// corridor -> key room -> exit room), see the Objects layer for entity
/// spawn points and their Tiled "Type"/properties.
class DungeonGame extends FlameGame
    with HasCollisionDetection, HasKeyboardHandlerComponents {
  DungeonGame({required this.gameState, required this.inventory});

  static const double tileSize = 32;

  final DungeonGameState gameState;
  final Inventory inventory;

  Player? player;
  late final World gameWorld;
  late final CameraComponent gameCamera;
  @override
  void update(double dt) {
    super.update(dt);
    DungeonAudio.tick(dt);
  }

  @override
  Future<void> onLoad() async {
    await DungeonAudio.preload();
    await super.onLoad();

    final tiledMap = await TiledComponent.load(
      'dungeon.tmx',
      Vector2.all(tileSize),
      images: Images(prefix: 'assets/tiles/'),
    );

    gameWorld = World();
    gameCamera = CameraComponent(world: gameWorld)..viewfinder.zoom = 2.5;
    addAll([gameWorld, gameCamera]);

    gameWorld.add(tiledMap);

    _buildWallCollisions(tiledMap);
    _spawnFromObjects(tiledMap);

    if (player != null) {
      gameCamera.follow(player!, snap: true);
    }
  }

  /// One `WallBlock` per non-empty cell in the "Walls" tile layer. Not the
  /// most efficient approach for a large map (no run-length merging of
  /// adjacent wall tiles into bigger rects) but the placeholder map is
  /// small (22x15) and this keeps the collision logic easy to follow —
  /// revisit with merged rects if a much bigger map is added later.
  void _buildWallCollisions(TiledComponent tiledMap) {
    final layer = tiledMap.tileMap.getLayer<TileLayer>('Walls');
    if (layer == null) return;

    for (var y = 0; y < layer.height; y++) {
      for (var x = 0; x < layer.width; x++) {
        final gid = layer.data?[y * layer.width + x] ?? 0;
        if (gid == 0) continue;
        gameWorld.add(
          WallBlock(
            position: Vector2(x * tileSize, y * tileSize),
            size: Vector2.all(tileSize),
          ),
        );
      }
    }
  }

  void _spawnFromObjects(TiledComponent tiledMap) {
    final objects =
        tiledMap.tileMap.getLayer<ObjectGroup>('Objects')?.objects ??
        <TiledObject>[];

    for (final obj in objects) {
      final topLeft = Vector2(obj.x, obj.y);
      final center = topLeft + Vector2(obj.width / 2, obj.height / 2);

      switch (obj.type) {
        case 'PlayerSpawn':
          player = Player(position: center);
          gameWorld.add(player!);
          break;

        case 'PatrolEnemy':
          final raw = obj.properties.getValue<String>('pathPoints') ?? '';
          final waypoints = raw
              .split(';')
              .where((s) => s.trim().isNotEmpty)
              .map((pair) {
                final parts = pair.split(',');
                final gx = double.parse(parts[0].trim());
                final gy = double.parse(parts[1].trim());
                // stored as tile-grid coords in the map -> pixel-center them
                return Vector2(
                  gx * tileSize + tileSize / 2,
                  gy * tileSize + tileSize / 2,
                );
              })
              .toList();
          gameWorld.add(PatrolEnemy(position: center, waypoints: waypoints));
          break;

        case 'ChaseEnemy':
          final radius = obj.properties.getValue<int>('detectionRadius') ?? 130;
          gameWorld.add(
            ChaseEnemy(position: center, detectionRadius: radius.toDouble()),
          );
          break;

        case 'Item':
          final itemType =
              obj.properties.getValue<String>('itemType') ?? 'coin';
          final itemId = obj.properties.getValue<String>('itemId') ?? obj.name;
          gameWorld.add(
            ItemPickup(
              position: center,
              itemId: itemId,
              kind: _kindFromString(itemType),
            ),
          );
          break;

        case 'LockedDoor':
          final requiresKey =
              obj.properties.getValue<String>('requiresKey') ?? '';
          gameWorld.add(
            LockedDoor(
              position: topLeft,
              size: Vector2(obj.width, obj.height),
              requiresKey: requiresKey,
            ),
          );
          break;

        case 'Exit':
          gameWorld.add(
            ExitTrigger(
              position: topLeft,
              size: Vector2(obj.width, obj.height),
            ),
          );
          break;
      }
    }
  }

  ItemKind _kindFromString(String s) {
    switch (s) {
      case 'key':
        return ItemKind.key;
      case 'potion':
        return ItemKind.potion;
      default:
        return ItemKind.coin;
    }
  }

  /// Small convenience so components (e.g. `Player.attack()`) can add a
  /// short-lived effect component to the world without reaching for
  /// `gameWorld` directly everywhere.
  void addComponentToWorld(Component c) => gameWorld.add(c);
}
