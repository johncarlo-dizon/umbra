import 'package:flutter/material.dart';

import '../game/dungeon_game.dart';
import '../models/dungeon_game_state.dart';

/// Top-right corner minimap. Shows the FULL generated level layout (not
/// fog-of-war — the whole map is already known at generation time, no
/// reason to hide it) plus a live player dot, the exit, and locked door
/// markers. Redraws its static layer only when `levelChangeCounter`
/// ticks (i.e. on level transitions), and repaints the player dot every
/// frame via `Player.positionNotifier`.
class MinimapOverlay extends StatelessWidget {
  const MinimapOverlay({
    super.key,
    required this.game,
    required this.gameState,
  });

  final DungeonGame game;
  final DungeonGameState gameState;

  static const double tileSize = 32;
  static const double mmScale = 3.2; // px per world tile on the minimap

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 76,
      right: 16,
      child: ValueListenableBuilder<int>(
        valueListenable: gameState.levelChangeCounter,
        builder: (context, _, __) {
          final level = game.currentLevel;
          if (level == null) return const SizedBox.shrink();

          final mapWidth = level.ground.isEmpty ? 0 : level.ground[0].length;
          final mapHeight = level.ground.length;

          return Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white24),
            ),
            child: SizedBox(
              width: mapWidth * mmScale,
              height: mapHeight * mmScale,
              child: ValueListenableBuilder<Vector2Value>(
                valueListenable: _PlayerPositionAdapter(game),
                builder: (context, playerPos, __) {
                  return CustomPaint(
                    painter: _MinimapPainter(
                      level: level,
                      playerGridPos: playerPos,
                      scale: mmScale,
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Small adapter so the painter can work with a plain (dx, dy) pair
/// without depending on Flame's Vector2 type inside the widget layer.
class Vector2Value {
  final double dx, dy;
  const Vector2Value(this.dx, this.dy);
}

class _PlayerPositionAdapter extends ValueNotifier<Vector2Value> {
  _PlayerPositionAdapter(DungeonGame game) : super(const Vector2Value(0, 0)) {
    final player = game.player;
    if (player != null) {
      player.positionNotifier.addListener(() {
        final p = player.positionNotifier.value;
        value = Vector2Value(p.x, p.y);
      });
      final p = player.positionNotifier.value;
      value = Vector2Value(p.x, p.y);
    }
  }
}

class _MinimapPainter extends CustomPainter {
  _MinimapPainter({
    required this.level,
    required this.playerGridPos,
    required this.scale,
  });

  final dynamic level; // DungeonLevel
  final Vector2Value playerGridPos;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final floorPaint = Paint()..color = Colors.white24;
    final wallPaint = Paint()..color = Colors.transparent;

    for (var y = 0; y < level.ground.length; y++) {
      for (var x = 0; x < level.ground[y].length; x++) {
        if (level.ground[y][x] != 0) {
          canvas.drawRect(
            Rect.fromLTWH(x * scale, y * scale, scale, scale),
            floorPaint,
          );
        }
      }
    }

    // exit marker
    final exit = level.exit;
    canvas.drawRect(
      Rect.fromLTWH((exit.x / 32) * scale, (exit.y / 32) * scale, scale, scale),
      Paint()..color = const Color(0xFF1E8C6E),
    );

    // locked door markers
    for (final door in level.lockedDoors) {
      canvas.drawRect(
        Rect.fromLTWH(
          (door.x / 32) * scale,
          (door.y / 32) * scale,
          scale * 1.5,
          scale,
        ),
        Paint()..color = const Color(0xFF784216),
      );
    }

    // player dot
    final px = (playerGridPos.dx / 32) * scale;
    final py = (playerGridPos.dy / 32) * scale;
    canvas.drawCircle(
      Offset(px, py),
      scale * 0.8,
      Paint()..color = const Color(0xFFFF7A1A),
    );
  }

  @override
  bool shouldRepaint(covariant _MinimapPainter oldDelegate) {
    return oldDelegate.playerGridPos.dx != playerGridPos.dx ||
        oldDelegate.playerGridPos.dy != playerGridPos.dy ||
        oldDelegate.level != level;
  }
}
