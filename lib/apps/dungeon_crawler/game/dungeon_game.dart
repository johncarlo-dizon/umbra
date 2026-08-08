import 'package:flame/components.dart';
import 'package:flame/game.dart';
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
import 'dungeon_generator.dart';
import 'dungeon_tilemap_component.dart';

import '../audio/dungeon_audio.dart';

/// Root Flame game for the dungeon crawler sub-app.
///
/// Levels are now generated procedurally at runtime (see
/// `DungeonGenerator`) instead of loaded from `.tmx` assets. Reaching a
/// non-final `Exit` calls [loadNextLevel], which generates the next level
/// number on the fly. The same `Player` instance, `DungeonGameState` (HP),
/// and `Inventory` persist across the transition — only the tiles, walls,
/// enemies, items, and doors are torn down and rebuilt; the player is
/// repositioned to the new level's `PlayerSpawn` rather than recreated.
class DungeonGame extends FlameGame
    with HasCollisionDetection, HasKeyboardHandlerComponents {
  DungeonGame({required this.gameState, required this.inventory});

  static const double tileSize = 32;

  /// Set to a level number to give the crawler a defined ending (that
  /// level's Exit will be marked `isFinalExit: true`). Leave null for an
  /// endless run that just keeps generating harder levels.
  static const int? maxLevel = null;

  /// Optional fixed seed for reproducible runs (e.g. daily challenge /
  /// debugging). Leave null for a fresh random layout every time.
  static const int? runSeed = null;

  int currentLevelNumber = 1;

  final DungeonGameState gameState;
  final Inventory inventory;
  DungeonLevel? currentLevel;
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

    await _loadLevel(currentLevelNumber);
  }

  @override
  void update(double dt) {
    super.update(dt);
    DungeonAudio.tick(dt);
  }

  Future<void> loadNextLevel() async {
    currentLevelNumber++;
    if (maxLevel != null && currentLevelNumber > maxLevel!) {
      // shouldn't normally happen — the exit at maxLevel should already be
      // marked final — but guard rather than crash.
      gameState.reachExit();
      return;
    }
    gameState.showBanner('Level $currentLevelNumber');
    await _loadLevel(currentLevelNumber);
  }

  Future<void> _loadLevel(int levelNumber) async {
    _clearLevelEntities();

    final isFinal = maxLevel != null && levelNumber >= maxLevel!;
    final seed = runSeed == null ? null : runSeed! + levelNumber;
    final level = DungeonGenerator(
      level: levelNumber,
      seed: seed,
      isFinalLevel: isFinal,
    ).generate();
    currentLevel = level;
    gameWorld.add(DungeonTilemapComponent(level: level, tileSize: tileSize));

    _buildWallCollisions(level);
    _spawnFromObjects(level);

    if (player != null) {
      gameCamera.follow(player!, snap: true);
    }
    gameState.levelChangeCounter.value++;
  }

  /// Removes everything from the previous level (tiles, walls, enemies,
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

  void _buildWallCollisions(DungeonLevel level) {
    for (var y = 0; y < level.walls.length; y++) {
      for (var x = 0; x < level.walls[y].length; x++) {
        if (level.walls[y][x] != 2) continue;
        gameWorld.add(
          WallBlock(
            position: Vector2(x * tileSize, y * tileSize),
            size: Vector2.all(tileSize),
          ),
        );
      }
    }
  }

  void _spawnFromObjects(DungeonLevel level) {
    for (final obj in level.objects) {
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
          final raw = obj.properties['pathPoints'] as String? ?? '';
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
          final radius = obj.properties['detectionRadius'] as int? ?? 130;
          gameWorld.add(
            ChaseEnemy(position: center, detectionRadius: radius.toDouble()),
          );
          break;

        case 'Item':
          final itemType = obj.properties['itemType'] as String? ?? 'coin';
          final itemId = obj.properties['itemId'] as String? ?? obj.name;
          gameWorld.add(
            ItemPickup(
              position: center,
              itemId: itemId,
              kind: _kindFromString(itemType),
            ),
          );
          break;

        case 'LockedDoor':
          final requiresKey = obj.properties['requiresKey'] as String? ?? '';
          gameWorld.add(
            LockedDoor(
              position: topLeft,
              size: Vector2(obj.width, obj.height),
              requiresKey: requiresKey,
            ),
          );
          break;

        case 'Exit':
          final isFinalExit = obj.properties['isFinalExit'] as bool? ?? false;
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
