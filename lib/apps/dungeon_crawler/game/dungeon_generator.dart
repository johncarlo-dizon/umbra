// dungeon_generator.dart
//
// Runtime procedural dungeon generator for a Flutter/Flame project.
// This produces a `DungeonLevel` in memory -- no .tmx file, no asset
// loading step. Call `DungeonGenerator(level: n).generate()` from your
// game code whenever you need a new level (e.g. when the player advances),
// and feed the result straight into your rendering/spawn logic.
//
// Drop this in e.g. lib/game/dungeon_generator.dart

import 'dart:math';

const int mapW = 30;
const int mapH = 20;

const int slotCols = 3;
const int slotRows = 2;
const int slotW = 8;
const int slotH = 8;
const int border = 1;
const int gap = 1;

/// One spawnable/interactive object in the level. Mirrors the fields your
/// TMX objects had (name/type/x/y/w/h/properties) so your existing
/// "switch on type, read properties" spawn logic needs minimal changes --
/// just swap the source list from TiledObject to LevelObject.
class LevelObject {
  final String name;
  final String
  type; // "PlayerSpawn" | "ChaseEnemy" | "PatrolEnemy" | "Item" | "LockedDoor" | "Exit"
  final double x, y, width, height;
  final Map<String, dynamic> properties;

  LevelObject({
    required this.name,
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.properties = const {},
  });
}

class DungeonLevel {
  final int level;
  final List<List<int>> ground; // [row][col], 1 = floor, 0 = void
  final List<List<int>> walls; // [row][col], 2 = wall, 0 = open
  final List<LevelObject> objects;

  DungeonLevel({
    required this.level,
    required this.ground,
    required this.walls,
    required this.objects,
  });

  LevelObject get playerSpawn =>
      objects.firstWhere((o) => o.type == 'PlayerSpawn');
  LevelObject get exit => objects.firstWhere((o) => o.type == 'Exit');
  Iterable<LevelObject> get chaseEnemies =>
      objects.where((o) => o.type == 'ChaseEnemy');
  Iterable<LevelObject> get patrolEnemies =>
      objects.where((o) => o.type == 'PatrolEnemy');
  Iterable<LevelObject> get items => objects.where((o) => o.type == 'Item');
  Iterable<LevelObject> get lockedDoors =>
      objects.where((o) => o.type == 'LockedDoor');
}

class _Room {
  final int x0, y0, x1, y1;
  _Room(this.x0, this.y0, this.x1, this.y1);
  int get cx => (x0 + x1) ~/ 2;
  int get cy => (y0 + y1) ~/ 2;
}

class _Corridor {
  final bool horizontal;
  final int fixedCoord; // y if horizontal, x if vertical
  final int lo, hi; // range along the other axis
  _Corridor(this.horizontal, this.fixedCoord, this.lo, this.hi);
}

class DungeonGenerator {
  final int level;
  final Random rng;

  /// Whether this level's Exit should be marked `isFinalExit: true`.
  /// Decide this in your game code (e.g. `levelNumber >= maxLevel`) rather
  /// than hardcoding an ending into the generator itself.
  final bool isFinalLevel;

  DungeonGenerator({required this.level, int? seed, this.isFinalLevel = false})
    : rng = Random(seed);

  int _slotId(int col, int row) => row * slotCols + col;
  List<int> _slotCoord(int sid) => [sid % slotCols, sid ~/ slotCols];
  List<int> _slotOrigin(int col, int row) => [
    border + col * (slotW + gap),
    border + row * (slotH + gap),
  ];

  Map<String, dynamic> _params() {
    return {
      'extraLoops': min(2, level ~/ 3),
      'chaseEnemies': min(8, 2 + level ~/ 2),
      'patrolEnemies': min(5, 1 + level ~/ 3),
      'detectionRadius': min(220, 110 + level * 6),
      'lockedDoors': min(3, level ~/ 2),
      'potions': max(1, 4 - level ~/ 3),
      'coins': 3 + level,
      'roomShrinkMax': min(2, level ~/ 4),
    };
  }

  DungeonLevel generate() {
    final p = _params();
    final ground = List.generate(mapH, (_) => List.filled(mapW, 0));
    final rooms = <int, _Room>{};

    // 1. Carve rooms into each slot.
    for (var row = 0; row < slotRows; row++) {
      for (var col = 0; col < slotCols; col++) {
        final origin = _slotOrigin(col, row);
        final sx = rng.nextInt(p['roomShrinkMax'] + 1);
        final sy = rng.nextInt(p['roomShrinkMax'] + 1);
        final rx0 = origin[0] + sx, ry0 = origin[1] + sy;
        final rx1 = origin[0] + slotW - 1 - sx,
            ry1 = origin[1] + slotH - 1 - sy;
        for (var y = ry0; y <= ry1; y++) {
          for (var x = rx0; x <= rx1; x++) {
            ground[y][x] = 1;
          }
        }
        rooms[_slotId(col, row)] = _Room(rx0, ry0, rx1, ry1);
      }
    }

    // 2. Build a spanning-tree graph over the slot grid (+ a few loop edges).
    final allEdges = <List<int>>[];
    for (var row = 0; row < slotRows; row++) {
      for (var col = 0; col < slotCols; col++) {
        final a = _slotId(col, row);
        if (col + 1 < slotCols) allEdges.add([a, _slotId(col + 1, row)]);
        if (row + 1 < slotRows) allEdges.add([a, _slotId(col, row + 1)]);
      }
    }
    allEdges.shuffle(rng);

    final parent = <int, int>{
      for (var r = 0; r < slotRows; r++)
        for (var c = 0; c < slotCols; c++) _slotId(c, r): _slotId(c, r),
    };
    int find(int x) {
      while (parent[x] != x) {
        parent[x] = parent[parent[x]!]!;
        x = parent[x]!;
      }
      return x;
    }

    final mstEdges = <List<int>>[];
    final remainingEdges = <List<int>>[];
    for (final e in allEdges) {
      final ra = find(e[0]), rb = find(e[1]);
      if (ra != rb) {
        parent[ra] = rb;
        mstEdges.add(e);
      } else {
        remainingEdges.add(e);
      }
    }
    remainingEdges.shuffle(rng);
    final edges = [...mstEdges, ...remainingEdges.take(p['extraLoops'] as int)];

    // 3. Carve a corridor for every edge; remember its geometry for door placement.
    final corridors = <String, _Corridor>{};
    String edgeKey(int a, int b) {
      final lo = min(a, b), hi = max(a, b);
      return '$lo-$hi';
    }

    for (final e in edges) {
      final a = e[0], b = e[1];
      final ca = _slotCoord(a), cb = _slotCoord(b);
      final ra = rooms[a]!, rb = rooms[b]!;
      if (ca[1] == cb[1]) {
        // horizontal neighbors
        final yLo = max(ra.y0, rb.y0), yHi = min(ra.y1, rb.y1);
        final y = yLo <= yHi
            ? (yLo + rng.nextInt(yHi - yLo + 1))
            : ((ra.y0 + ra.y1) ~/ 2);
        final xs = ca[0] < cb[0] ? ra.x1 : rb.x1;
        final xe = ca[0] < cb[0] ? rb.x0 : ra.x0;
        for (var x = min(xs, xe); x <= max(xs, xe); x++) {
          ground[y][x] = 1;
        }
        corridors[edgeKey(a, b)] = _Corridor(true, y, min(xs, xe), max(xs, xe));
      } else {
        // vertical neighbors
        final xLo = max(ra.x0, rb.x0), xHi = min(ra.x1, rb.x1);
        final x = xLo <= xHi
            ? (xLo + rng.nextInt(xHi - xLo + 1))
            : ((ra.x0 + ra.x1) ~/ 2);
        final ys = ca[1] < cb[1] ? ra.y1 : rb.y1;
        final ye = ca[1] < cb[1] ? rb.y0 : ra.y0;
        for (var y = min(ys, ye); y <= max(ys, ye); y++) {
          ground[y][x] = 1;
        }
        corridors[edgeKey(a, b)] = _Corridor(
          false,
          x,
          min(ys, ye),
          max(ys, ye),
        );
      }
    }

    // 4. Walls = inverse of ground.
    final walls = List.generate(
      mapH,
      (y) => List.generate(mapW, (x) => ground[y][x] == 0 ? 2 : 0),
    );

    // 5. BFS over the slot graph from the start slot to find play order + exit.
    final adj = <int, List<int>>{
      for (var i = 0; i < slotRows * slotCols; i++) i: [],
    };
    for (final e in edges) {
      adj[e[0]]!.add(e[1]);
      adj[e[1]]!.add(e[0]);
    }
    const start = 0;
    final dist = <int, int>{start: 0};
    final parentSlot = <int, int?>{start: null};
    final order = <int>[start];
    final queue = <int>[start];
    while (queue.isNotEmpty) {
      final cur = queue.removeAt(0);
      for (final nxt in adj[cur]!) {
        if (!dist.containsKey(nxt)) {
          dist[nxt] = dist[cur]! + 1;
          parentSlot[nxt] = cur;
          order.add(nxt);
          queue.add(nxt);
        }
      }
    }
    final exitSlot = order.reduce((a, b) => dist[a]! >= dist[b]! ? a : b);
    final path = <int>[exitSlot];
    while (parentSlot[path.last] != null) {
      path.add(parentSlot[path.last]!);
    }
    final orderedPath = path.reversed.toList(); // start .. exit

    // 6. Spawn objects.
    final objects = <LevelObject>[];
    final usedTiles = <int, Set<String>>{
      for (var i = 0; i < slotRows * slotCols; i++) i: {},
    };

    List<double> randomTileIn(int sid) {
      final r = rooms[sid]!;
      for (var i = 0; i < 50; i++) {
        final tx = r.x0 + rng.nextInt(r.x1 - r.x0 + 1);
        final ty = r.y0 + rng.nextInt(r.y1 - r.y0 + 1);
        final key = '$tx,$ty';
        if (!usedTiles[sid]!.contains(key)) {
          usedTiles[sid]!.add(key);
          return [tx * 32.0, ty * 32.0];
        }
      }
      return [r.x0 * 32.0, r.y0 * 32.0];
    }

    final spawnPos = randomTileIn(start);
    objects.add(
      LevelObject(
        name: 'PlayerSpawn',
        type: 'PlayerSpawn',
        x: spawnPos[0],
        y: spawnPos[1],
        width: 32,
        height: 32,
      ),
    );

    final exitPos = randomTileIn(exitSlot);
    objects.add(
      LevelObject(
        name: 'Exit',
        type: 'Exit',
        x: exitPos[0],
        y: exitPos[1],
        width: 32,
        height: 32,
        properties: {'isFinalExit': isFinalLevel},
      ),
    );

    // Locked doors + keys, placed along the main path so it's always solvable:
    // key i is always in a room strictly before door i.
    final nDoors = min(p['lockedDoors'] as int, max(0, orderedPath.length - 2));
    final doorPositions = <int>[];
    if (nDoors > 0) {
      final candidates = List.generate(orderedPath.length - 1, (i) => i + 1)
        ..shuffle(rng);
      doorPositions.addAll(candidates.take(nDoors));
      doorPositions.sort();
    }
    const keyNames = ['bronze_key', 'silver_key', 'gold_key', 'obsidian_key'];
    for (var i = 0; i < doorPositions.length; i++) {
      final pos = doorPositions[i];
      final roomBefore = orderedPath[pos - 1];
      final roomAfter = orderedPath[pos];
      final keyId = keyNames[i % keyNames.length];
      final corridor = corridors[edgeKey(roomBefore, roomAfter)];
      if (corridor == null) continue;
      final mid = (corridor.lo + corridor.hi) ~/ 2;
      double dx, dy, dw, dh;
      if (corridor.horizontal) {
        dx = mid * 32.0;
        dy = corridor.fixedCoord * 32.0;
        dw = 64;
        dh = 32;
      } else {
        dx = corridor.fixedCoord * 32.0;
        dy = mid * 32.0;
        dw = 32;
        dh = 64;
      }
      objects.add(
        LevelObject(
          name: 'LockedDoor${i + 1}',
          type: 'LockedDoor',
          x: dx,
          y: dy,
          width: dw,
          height: dh,
          properties: {'requiresKey': keyId},
        ),
      );
      final keyPos = randomTileIn(roomBefore);
      objects.add(
        LevelObject(
          name: keyId,
          type: 'Item',
          x: keyPos[0],
          y: keyPos[1],
          width: 32,
          height: 32,
          properties: {'itemType': 'key', 'itemId': keyId},
        ),
      );
    }

    // Enemies.
    final chaseCount = p['chaseEnemies'] as int;
    for (var i = 0; i < chaseCount; i++) {
      final sid = order[i % order.length];
      final pos = randomTileIn(sid);
      final radius = (p['detectionRadius'] as int) + rng.nextInt(21) - 10;
      objects.add(
        LevelObject(
          name: 'ChaseEnemy${i + 1}',
          type: 'ChaseEnemy',
          x: pos[0],
          y: pos[1],
          width: 32,
          height: 32,
          properties: {'detectionRadius': radius},
        ),
      );
    }

    final patrolCount = min(p['patrolEnemies'] as int, slotRows * slotCols);
    final patrolRooms = List.generate(slotRows * slotCols, (i) => i)
      ..shuffle(rng);
    for (var i = 0; i < patrolCount; i++) {
      final sid = patrolRooms[i];
      final r = rooms[sid]!;
      final pathPoints =
          '${r.x0},${r.y0};${r.x1},${r.y0};${r.x1},${r.y1};${r.x0},${r.y1}';
      objects.add(
        LevelObject(
          name: 'PatrolEnemy${i + 1}',
          type: 'PatrolEnemy',
          x: r.x0 * 32.0,
          y: r.y0 * 32.0,
          width: 32,
          height: 32,
          properties: {'pathPoints': pathPoints},
        ),
      );
    }

    // Loot.
    final potionCount = p['potions'] as int;
    for (var i = 0; i < potionCount; i++) {
      final sid = order[rng.nextInt(order.length)];
      final pos = randomTileIn(sid);
      objects.add(
        LevelObject(
          name: 'Potion${i + 1}',
          type: 'Item',
          x: pos[0],
          y: pos[1],
          width: 32,
          height: 32,
          properties: {
            'itemType': 'potion',
            'itemId': 'potion_l${level}_${i + 1}',
          },
        ),
      );
    }

    final coinCount = p['coins'] as int;
    for (var i = 0; i < coinCount; i++) {
      final sid = order[rng.nextInt(order.length)];
      final pos = randomTileIn(sid);
      objects.add(
        LevelObject(
          name: 'Coin${i + 1}',
          type: 'Item',
          x: pos[0],
          y: pos[1],
          width: 32,
          height: 32,
          properties: {'itemType': 'coin', 'itemId': 'coin_l${level}_${i + 1}'},
        ),
      );
    }

    return DungeonLevel(
      level: level,
      ground: ground,
      walls: walls,
      objects: objects,
    );
  }
}
