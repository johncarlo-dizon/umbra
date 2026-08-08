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

/// Top-level screen for the Dungeon Crawler sub-app.
///
/// Deliberately does NOT use the `Align + ConstrainedBox(maxWidth: 480)`
/// wrapper every other Umbra screen uses (see the "Adding a new sub-app"
/// checklist, item 9) — that pattern is for form/list-style content that
/// looks broken stretched full-width. A game canvas is the opposite: it
/// needs the full viewport to be playable, so this screen intentionally
/// breaks from that convention. Everything else in the checklist still
/// applies (own folder, own routes file, no cross-app imports, etc).
class DungeonCrawlerScreen extends StatefulWidget {
  const DungeonCrawlerScreen({super.key});

  @override
  State<DungeonCrawlerScreen> createState() => _DungeonCrawlerScreenState();
}

class _DungeonCrawlerScreenState extends State<DungeonCrawlerScreen> {
  late DungeonGameState _gameState;
  late Inventory _inventory;
  late DungeonGame _game;
  bool _blockedForGuest = false;
  bool _scoreSubmitted = false;

  void _submitScoreOnce() {
    if (_scoreSubmitted) return;
    _scoreSubmitted = true;
    LeaderboardService.submitRunResult(
      floorReached: _game.currentLevelNumber,
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

  void _startNewRun() {
    _gameState = DungeonGameState();
    _inventory = Inventory();
    _game = DungeonGame(gameState: _gameState, inventory: _inventory);
  }

  void _retry() {
    setState(() {
      _gameState.dispose();
      _startNewRun();
    });
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: GameWidget(game: _game)),
          SafeArea(
            child: Stack(
              children: [
                HpBarOverlay(gameState: _gameState),
                InventoryOverlay(inventory: _inventory),
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
                if (_isTouchPlatform(context))
                  TouchControlsOverlay(game: _game),
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
                  player: _game.player,
                  onGiveUp: () => _gameState.declineRevive(),
                );
              }
              if (status == RunStatus.lost || status == RunStatus.won) {
                _submitScoreOnce();
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
