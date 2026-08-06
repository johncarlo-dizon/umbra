import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../audio/dungeon_audio.dart';
import '../dungeon_game.dart';
import 'player.dart';

/// Blocks a corridor/doorway until the player, holding the key with id
/// [requiresKey], walks into it — then opens (removes its own hitbox and
/// redraws as an open doorway) permanently for the rest of the run.
/// [requiresKey] is read from the `requiresKey` property on the Tiled
/// "LockedDoor" object.
class LockedDoor extends PositionComponent
    with CollisionCallbacks, HasGameRef<DungeonGame> {
  LockedDoor({
    required Vector2 position,
    required Vector2 size,
    required this.requiresKey,
  }) : super(position: position, size: size);
  TextComponent? _label;
  final String requiresKey;
  bool _open = false;
  RectangleHitbox? _hitbox;
  bool get isOpen => _open;
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    priority = (position.y + size.y).toInt();
    _hitbox = RectangleHitbox(collisionType: CollisionType.passive);
    add(_hitbox!);

    _label = TextComponent(
      text: 'DOOR ($requiresKey)',
      position: absolutePosition + Vector2(size.x / 2, -10),
      anchor: Anchor.bottomCenter,
      priority: 100, // always renders above player/enemies
      textRenderer: TextPaint(
        style: const TextStyle(color: Colors.white, fontSize: 8),
      ),
    );
    gameRef.world.add(_label!);
  }

  @override
  void render(Canvas canvas) {
    if (_open) {
      // Open: draw a slim threshold strip instead of a full solid block
      final stripHeight = size.y * 0.12;
      final stripRect = Rect.fromLTWH(
        0,
        size.y - stripHeight,
        size.x,
        stripHeight,
      );
      canvas.drawRect(stripRect, Paint()..color = const Color(0xFF604628));
      return;
    }

    // Locked: full solid block, reads clearly as an obstacle
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    canvas.drawRect(rect, Paint()..color = const Color(0xFF784216));
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      3,
      Paint()..color = const Color(0xFFFF7A1A),
    );
  }

  void _openDoor() {
    DungeonAudio.doorUnlock();
    _open = true;
    debugPrint('LockedDoor: opened with $requiresKey');
    if (_hitbox != null) {
      remove(_hitbox!);
      _hitbox = null;
    }
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (_open) return;
    if (other is Player && gameRef.inventory.hasKey(requiresKey)) {
      _openDoor();
    }
  }
}
