import 'package:flutter/material.dart';

import '../game/dungeon_game.dart';

/// Bottom-left drag joystick + bottom-right attack/potion buttons, shown
/// only on mobile (see `DungeonCrawlerScreen`'s platform check). Plain
/// Flutter overlay rather than a Flame `JoystickComponent` — see the
/// class doc from the original version for the reasoning.
class TouchControlsOverlay extends StatefulWidget {
  const TouchControlsOverlay({super.key, required this.game});

  final DungeonGame game;

  @override
  State<TouchControlsOverlay> createState() => _TouchControlsOverlayState();
}

class _TouchControlsOverlayState extends State<TouchControlsOverlay> {
  static const double _baseRadius = 55;
  static const double _knobRadius = 24;

  Offset _knobOffset = Offset.zero;
  bool _dragging = false;

  void _updateFromLocal(Offset local) {
    final center = Offset(_baseRadius, _baseRadius);
    var delta = local - center;
    final maxDistance = _baseRadius - _knobRadius / 2;
    if (delta.distance > maxDistance) {
      delta = Offset.fromDirection(delta.direction, maxDistance);
    }
    setState(() => _knobOffset = delta);

    final normalized = delta / maxDistance;
    final dir = widget.game.player?.joystickDirection;
    if (dir != null) {
      dir.x = normalized.dx.clamp(-1.0, 1.0);
      dir.y = normalized.dy.clamp(-1.0, 1.0);
    }
  }

  void _reset() {
    setState(() {
      _knobOffset = Offset.zero;
      _dragging = false;
    });
    widget.game.player?.joystickDirection.setZero();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 24,
          bottom: 24,
          child: GestureDetector(
            onPanStart: (details) {
              _dragging = true;
              _updateFromLocal(details.localPosition);
            },
            onPanUpdate: (details) => _updateFromLocal(details.localPosition),
            onPanEnd: (_) => _reset(),
            onPanCancel: _reset,
            child: SizedBox(
              width: _baseRadius * 2,
              height: _baseRadius * 2,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.35),
                      border: Border.all(color: Colors.white24, width: 2),
                    ),
                  ),
                  Positioned(
                    left: _baseRadius - _knobRadius + _knobOffset.dx,
                    top: _baseRadius - _knobRadius + _knobOffset.dy,
                    child: Container(
                      width: _knobRadius * 2,
                      height: _knobRadius * 2,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            (_dragging
                                    ? const Color(0xFFFF7A1A)
                                    : Colors.white24)
                                .withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Potion button — sits above the attack button so both are
        // reachable with the same thumb without overlapping.
        Positioned(
          right: 28,
          bottom: 110,
          child: GestureDetector(
            onTap: () => widget.game.player?.usePotion(),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE91E63).withValues(alpha: 0.85),
                border: Border.all(color: Colors.white24, width: 2),
              ),
              child: const Icon(
                Icons.local_drink,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
        ),

        // Attack button
        Positioned(
          right: 28,
          bottom: 32,
          child: GestureDetector(
            onTap: () => widget.game.player?.attack(),
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF7A1A).withValues(alpha: 0.85),
                border: Border.all(color: Colors.white24, width: 2),
              ),
              child: const Icon(Icons.bolt, color: Colors.white, size: 30),
            ),
          ),
        ),
      ],
    );
  }
}
