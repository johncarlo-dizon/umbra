import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/supabase_client.dart';
import '../../../core/shell_nav_state.dart';
import 'leaderboard_screen.dart';

/// Landing screen for the Dungeon Crawler sub-app — Play / Leaderboard
/// menu, shown when the tile is tapped from Umbra's Home tab. Actual
/// gameplay lives at `/dungeon-crawler/play`, reached via push so
/// popping back (game-over/victory "Back" buttons, the in-game close
/// button) returns here rather than exiting the sub-app entirely.
///
/// The login gate lives here, at the true entry point, rather than
/// inside the gameplay screen — guests get redirected before they ever
/// see a menu, matching "require login before entering the dungeon at
/// all."
class DungeonCrawlerHomeScreen extends StatefulWidget {
  const DungeonCrawlerHomeScreen({super.key});

  @override
  State<DungeonCrawlerHomeScreen> createState() =>
      _DungeonCrawlerHomeScreenState();
}

class _DungeonCrawlerHomeScreenState extends State<DungeonCrawlerHomeScreen> {
  bool _blockedForGuest = false;

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
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_blockedForGuest) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Dungeon Crawler')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.castle, size: 72, color: theme.colorScheme.primary),
                const SizedBox(height: 12),
                Text('Dungeon Crawler', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 4),
                Text(
                  'Fight through an endless dungeon. How deep can you go?',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () => context.push('/dungeon-crawler/play'),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Play'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(200, 48),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const LeaderboardScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.leaderboard),
                  label: const Text('Leaderboard'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(200, 48),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
