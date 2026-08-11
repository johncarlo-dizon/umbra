import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

/// Small floating text label used for combat flair that isn't a plain
/// damage number — e.g. "2x!" on a double-hit, "STUN" on a stun proc.
/// Floats upward and fades out, then removes itself.
///
/// NOTE: plain TextComponent doesn't implement OpacityProvider, so
/// OpacityEffect can't be used on it (throws "Can only apply this effect
/// to OpacityProvider"). Fade is done manually in update() instead.
class FloatingLabel extends TextComponent {
  FloatingLabel({
    required String text,
    required Vector2 position,
    required Color color,
  }) : _baseColor = color,
       super(
         text: text,
         position: position,
         anchor: Anchor.center,
         textRenderer: TextPaint(
           style: TextStyle(
             color: color,
             fontSize: 11,
             fontWeight: FontWeight.bold,
             shadows: const [Shadow(color: Colors.black, blurRadius: 2)],
           ),
         ),
       );

  final Color _baseColor;
  static const double _lifespan = 0.7;
  double _age = 0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(
      MoveEffect.by(
        Vector2(0, -18),
        EffectController(duration: _lifespan, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    if (_age >= _lifespan) {
      removeFromParent();
      return;
    }
    final alpha = (1 - (_age / _lifespan)).clamp(0.0, 1.0);
    textRenderer = TextPaint(
      style: TextStyle(
        color: _baseColor.withValues(alpha: alpha),
        fontSize: 11,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(color: Colors.black.withValues(alpha: alpha), blurRadius: 2),
        ],
      ),
    );
  }
}
