import 'package:flutter/foundation.dart';

/// One picked-up item. [id] matches the `itemId` property set on the
/// corresponding object in the Tiled map (e.g. a LockedDoor's
/// `requiresKey` property is checked against held keys' [id]s).
class InventoryItem {
  final String id;
  final ItemKind kind;

  const InventoryItem({required this.id, required this.kind});
}

enum ItemKind { key, potion, coin, gem }

/// Session-only game state for a single dungeon run. Deliberately NOT
/// wired into Umbra's `AppSettingsState`/`SettingsService` — run progress
/// isn't a persisted device preference, it resets every time the player
/// starts a new run (see `DungeonGameState.reset()`).
class Inventory extends ChangeNotifier {
  final List<InventoryItem> _keys = [];
  int _potions = 0;
  int _coins = 0;
  int _totalCoinsCollected = 0;
  int get totalCoinsCollected => _totalCoinsCollected;
  List<InventoryItem> get keys => List.unmodifiable(_keys);
  int get potions => _potions;
  int get coins => _coins;
  int _gemsCollected = 0;
  int get gemsCollected => _gemsCollected;
  bool hasKey(String keyId) => _keys.any((k) => k.id == keyId);

  void addItem(String id, ItemKind kind) {
    switch (kind) {
      case ItemKind.key:
        _keys.add(InventoryItem(id: id, kind: kind));
        break;
      case ItemKind.potion:
        _potions++;
        break;
      case ItemKind.coin:
        _coins++;
        _totalCoinsCollected++;
        break;
      case ItemKind.gem:
        _gemsCollected++;
        break;
    }
    notifyListeners();
  }

  bool spendCoins(int amount) {
    if (_coins < amount) return false;
    _coins -= amount;
    notifyListeners();
    return true;
  }

  /// Consumes a potion for healing. Returns true if one was available.
  bool consumePotion() {
    if (_potions <= 0) return false;
    _potions--;
    notifyListeners();
    return true;
  }

  void reset() {
    _keys.clear();
    _potions = 0;
    _coins = 0;
    _gemsCollected = 0;
    notifyListeners();
  }
}
