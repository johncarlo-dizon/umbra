import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

/// A floating "-12" that rises briefly then removes itself. Spawned on
/// every successful hit — melee connecting with an enemy, or an enemy's
/// contact damage landing on the player.
class DamageNumber extends TextComponent {
  DamageNumber({
    required Vector2 position,
    required int amount,
    Color color = Colors.white,
  }) : super(
         text: '-$amount',
         position: position,
         anchor: Anchor.bottomCenter,
         textRenderer: TextPaint(
           style: TextStyle(
             color: color,
             fontSize: 14,
             fontWeight: FontWeight.bold,
             shadows: const [
               Shadow(color: Colors.black, blurRadius: 2, offset: Offset(1, 1)),
             ],
           ),
         ),
       );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final rise = MoveEffect.by(
      Vector2(0, -24),
      EffectController(duration: 0.7, curve: Curves.easeOut),
    );
    rise.onComplete = () => removeFromParent();
    add(rise);
  }
}
