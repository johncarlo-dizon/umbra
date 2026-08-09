import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../services/leaderboard_service.dart';
import '../widgets/revive_overlay.dart';
import '../game/dungeon_game.dart';
import '../models/dungeon_game_state.dart';
import '../models/inventory.dart';
import '../widgets/game_over_overlay.dart';
import '../widgets/hp_bar_overlay.dart';
import '../widgets/inventory_overlay.dart';
import '../widgets/touch_controls_overlay.dart';
import '../widgets/victory_overlay.dart';
import 'package:go_router/go_router.dart';
import '../../../core/supabase_client.dart';
import '../../../core/shell_nav_state.dart';
import '../widgets/minimap_overlay.dart';
import '../services/pet_progress_service.dart';
import '../models/pet_definition.dart';

class DungeonCrawlerScreen extends StatefulWidget {
  const DungeonCrawlerScreen({super.key});

  @override
  State<DungeonCrawlerScreen> createState() => _DungeonCrawlerScreenState();
}

class _DungeonCrawlerScreenState extends State<DungeonCrawlerScreen> {
  late DungeonGameState _gameState;
  late Inventory _inventory;
  DungeonGame? _game;
  bool _blockedForGuest = false;
  bool _scoreSubmitted = false;

  void _submitScoreOnce(DungeonGame game) {
    PetProgressService.addGemsEarned(_inventory.gemsCollected);
    if (_scoreSubmitted) return;
    _scoreSubmitted = true;
    LeaderboardService.submitRunResult(
      floorReached: game.currentLevelNumber,
      coinsCollected: _inventory.totalCoinsCollected,
      revivesUsed: _gameState.revivesUsedThisRun,
    );
  }

  @override
  void initState() {
    super.initState();
    if (!SupabaseService.isLoggedIn) {
      _blockedForGuest = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ShellNavState.requestedTabIndex.value = ShellNavState.profileTab;
        context.go('/');
      });
      return;
    }
    _startNewRun();
  }

  Future<void> _startNewRun() async {
    _gameState = DungeonGameState();
    _inventory = Inventory();
    PetDefinition? equipped;
    final progress = await PetProgressService.fetch();
    if (progress.equippedPetId != null) {
      equipped = PetDefinition.byId(progress.equippedPetId!);
    }
    final newGame = DungeonGame(
      gameState: _gameState,
      inventory: _inventory,
      equippedPetDefinition: equipped,
    );
    if (mounted) {
      setState(() {
        _game = newGame;
        _scoreSubmitted = false;
      });
    }
  }

  void _retry() {
    _gameState.dispose();
    setState(() => _game = null);
    _startNewRun();
  }

  static const double _touchControlsBreakpoint = 700;

  bool _isTouchPlatform(BuildContext context) {
    return MediaQuery.sizeOf(context).width < _touchControlsBreakpoint;
  }

  @override
  void dispose() {
    _gameState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_blockedForGuest) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final game = _game;
    if (game == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: GameWidget(game: game)),
          SafeArea(
            child: Stack(
              children: [
                HpBarOverlay(gameState: _gameState),
                InventoryOverlay(inventory: _inventory),
                MinimapOverlay(game: game, gameState: _gameState),
                ValueListenableBuilder<String?>(
                  valueListenable: _gameState.banner,
                  builder: (context, text, _) {
                    return AnimatedOpacity(
                      opacity: text != null ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            text ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                if (_isTouchPlatform(context)) TouchControlsOverlay(game: game),
                if (!_isTouchPlatform(context)) const _KeyboardHintOverlay(),
                Positioned(
                  top: 16,
                  left: 210,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    tooltip: 'Exit dungeon',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ],
            ),
          ),
          ValueListenableBuilder<RunStatus>(
            valueListenable: _gameState.status,
            builder: (context, status, _) {
              if (status == RunStatus.downed) {
                return ReviveOverlay(
                  gameState: _gameState,
                  inventory: _inventory,
                  player: game.player,
                  onGiveUp: () => _gameState.declineRevive(),
                );
              }
              if (status == RunStatus.lost || status == RunStatus.won) {
                _submitScoreOnce(game);
              }
              if (status == RunStatus.lost) {
                return GameOverOverlay(
                  onRetry: _retry,
                  onExit: () => Navigator.of(context).maybePop(),
                );
              }
              if (status == RunStatus.won) {
                return VictoryOverlay(
                  inventory: _inventory,
                  onPlayAgain: _retry,
                  onExit: () => Navigator.of(context).maybePop(),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }
}

class _KeyboardHintOverlay extends StatelessWidget {
  const _KeyboardHintOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      bottom: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _HintLine(keys: 'WASD / Arrows', action: 'Move'),
            _HintLine(keys: 'Space / J', action: 'Attack'),
            _HintLine(keys: 'E', action: 'Drink Potion'),
          ],
        ),
      ),
    );
  }
}

class _HintLine extends StatelessWidget {
  const _HintLine({required this.keys, required this.action});
  final String keys;
  final String action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 12, color: Colors.white70),
          children: [
            TextSpan(
              text: '$keys  ',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextSpan(text: action),
          ],
        ),
      ),
    );
  }
}
