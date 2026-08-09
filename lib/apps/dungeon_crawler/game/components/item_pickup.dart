import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import '../../audio/dungeon_audio.dart';
import '../dungeon_game.dart';
import '../../models/inventory.dart';
import 'player.dart';

/// A key, potion, or coin sitting on the map. [itemId] must be unique and
/// is what `LockedDoor.requiresKey` compares against for keys — it comes
/// straight from the `itemId` property on the Tiled object.
///
/// Potions and coins use real looping sprite animations
/// (`potion_spritesheet.png` / `coin_spritesheet.png`, both in
/// `assets/images/`). Keys still use a flat-color placeholder square —
/// no key art was generated yet.
class ItemPickup extends PositionComponent
    with CollisionCallbacks, HasGameRef<DungeonGame> {
  ItemPickup({
    required Vector2 position,
    required this.itemId,
    required this.kind,
  }) : super(position: position, size: Vector2.all(20), anchor: Anchor.center);

  final String itemId;
  final ItemKind kind;

  SpriteAnimationComponent? _animComponent;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox(collisionType: CollisionType.passive));

    switch (kind) {
      case ItemKind.potion:
        final image = await gameRef.images.load('potion_spritesheet.png');
        final sheet = SpriteSheet(image: image, srcSize: Vector2(106, 157));
        final anim = sheet.createAnimation(
          row: 0,
          stepTime: 0.2,
          to: 4,
          loop: true,
        );
        _animComponent = SpriteAnimationComponent(
          animation: anim,
          size: Vector2(18, 26),
          anchor: Anchor.center,
          position: size / 2,
        );
        add(_animComponent!);
        break;
      case ItemKind.coin:
        final image = await gameRef.images.load('coin_spritesheet.png');
        final sheet = SpriteSheet(image: image, srcSize: Vector2(103, 100));
        final anim = sheet.createAnimation(
          row: 0,
          stepTime: 0.12,
          to: 6,
          loop: true,
        );
        _animComponent = SpriteAnimationComponent(
          animation: anim,
          size: Vector2(16, 16),
          anchor: Anchor.center,
          position: size / 2,
        );
        add(_animComponent!);
        break;
      case ItemKind.key:
        final keyImage = await gameRef.images.load('key_spritesheet.png');
        final keySheet = SpriteSheet(
          image: keyImage,
          srcSize: Vector2(169, 335),
        );
        final keyAnim = keySheet.createAnimation(
          row: 0,
          stepTime: 0.15,
          to: 4,
          loop: true,
        );
        _animComponent = SpriteAnimationComponent(
          animation: keyAnim,
          size: Vector2(14, 28),
          anchor: Anchor.center,
          position: size / 2,
        );
        add(_animComponent!);
        break;
      case ItemKind.gem:
        final gemImage = await gameRef.images.load('diamond.png');
        final gemSheet = SpriteSheet(
          image: gemImage,
          srcSize: Vector2(228, 316),
        );
        final gemAnim = gemSheet.createAnimation(
          row: 0,
          stepTime: 0.15,
          to: 4,
          loop: true,
        );
        _animComponent = SpriteAnimationComponent(
          animation: gemAnim,
          size: Vector2(16, 22),
          anchor: Anchor.center,
          position: size / 2,
        );
        add(_animComponent!);
        break;
    }
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Player) {
      gameRef.inventory.addItem(itemId, kind);
      if (kind == ItemKind.coin) {
        DungeonAudio.coinCollect();
      } else {
        DungeonAudio.itemPickup();
      }
      removeFromParent();
    }
  }
}
