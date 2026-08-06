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

import '../audio/dungeon_audio.dart';

/// Root Flame game for the dungeon crawler sub-app.
///
/// Supports multiple levels: [levels] is loaded in order, and reaching a
/// non-final `Exit` (see `isFinalExit` on the Tiled object) calls
/// [loadNextLevel] instead of ending the run. The same `Player` instance,
/// `DungeonGameState` (HP), and `Inventory` persist across the
/// transition — only the map, walls, enemies, items, and doors are torn
/// down and rebuilt; the player is repositioned to the new level's
/// `PlayerSpawn` rather than recreated.
class DungeonGame extends FlameGame
    with HasCollisionDetection, HasKeyboardHandlerComponents {
  DungeonGame({required this.gameState, required this.inventory});

  static const double tileSize = 32;

  static const List<String> levels = [
    'dungeon_level1.tmx',
    'dungeon_level2.tmx',
  ];
  int currentLevelIndex = 0;

  final DungeonGameState gameState;
  final Inventory inventory;

  Player? player;
  late final World gameWorld;
  late final CameraComponent gameCamera;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await DungeonAudio.preload();

    gameWorld = World();
    gameCamera = CameraComponent(world: gameWorld)..viewfinder.zoom = 2.5;
    addAll([gameWorld, gameCamera]);

    await _loadLevel(levels[currentLevelIndex]);
  }

  @override
  void update(double dt) {
    super.update(dt);
    DungeonAudio.tick(dt);
  }

  Future<void> loadNextLevel() async {
    currentLevelIndex++;
    if (currentLevelIndex >= levels.length) {
      // shouldn't normally happen — the last level's Exit should be
      // marked isFinalExit=true — but guard against a map authoring
      // mistake rather than crash.
      gameState.reachExit();
      return;
    }
    gameState.showBanner('Level ${currentLevelIndex + 1}');
    await _loadLevel(levels[currentLevelIndex]);
  }

  Future<void> _loadLevel(String fileName) async {
    _clearLevelEntities();

    final tiledMap = await TiledComponent.load(fileName, Vector2.all(tileSize));
    gameWorld.add(tiledMap);

    _buildWallCollisions(tiledMap);
    _spawnFromObjects(tiledMap);

    if (player != null) {
      gameCamera.follow(player!, snap: true);
    }
  }

  /// Removes everything from the previous level (map, walls, enemies,
  /// items, doors, exit, any lingering hitboxes/projectiles) but keeps
  /// the `Player` component itself — it gets repositioned by the next
  /// level's `PlayerSpawn` object instead of being recreated, so HP and
  /// facing/animation state carry over naturally.
  void _clearLevelEntities() {
    for (final child in gameWorld.children.toList()) {
      if (child == player) continue;
      child.removeFromParent();
    }
  }

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
        tiledMap.tileMap.getLayer<ObjectGroup>('Objects')?.objects ?? [];

    for (final obj in objects) {
      final topLeft = Vector2(obj.x, obj.y);
      final center = topLeft + Vector2(obj.width / 2, obj.height / 2);

      switch (obj.type) {
        case 'PlayerSpawn':
          if (player == null) {
            player = Player(position: center);
            gameWorld.add(player!);
          } else {
            player!.position = center;
          }
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
          final isFinalExit =
              obj.properties.getValue<bool>('isFinalExit') ?? false;
          gameWorld.add(
            ExitTrigger(
              position: topLeft,
              size: Vector2(obj.width, obj.height),
              isFinalExit: isFinalExit,
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

  void addComponentToWorld(Component c) => gameWorld.add(c);
}
