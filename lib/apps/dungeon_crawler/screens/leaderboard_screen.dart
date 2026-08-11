import 'package:flutter/material.dart';

import '../../../core/supabase_client.dart';
import '../services/leaderboard_service.dart';
import '../theme/dungeon_theme.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late Future<List<LeaderboardEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = LeaderboardService.fetchTopScores();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: DungeonTheme.theme,
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          final myUserId = SupabaseService.currentSession?.user.id;

          return Scaffold(
            appBar: AppBar(title: const Text('Leaderboard')),
            body: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: FutureBuilder<List<LeaderboardEntry>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            "Couldn't load leaderboard: ${snapshot.error}",
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      );
                    }
                    final entries = snapshot.data ?? [];
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                          child: Column(
                            children: [
                              Icon(
                                Icons.leaderboard,
                                size: 72,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Leaderboard',
                                style: theme.textTheme.headlineMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'The deepest, bravest crawlers.',
                                style: theme.textTheme.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        if (entries.isEmpty)
                          Expanded(
                            child: Center(
                              child: Text(
                                'No runs recorded yet — be the first!',
                                style: theme.textTheme.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              itemCount: entries.length,
                              itemBuilder: (context, i) {
                                final entry = entries[i];
                                final isMe = entry.userId == myUserId;
                                return _LeaderboardRow(
                                  rank: i + 1,
                                  entry: entry,
                                  isMe: isMe,
                                );
                              },
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.rank,
    required this.entry,
    required this.isMe,
  });

  final int rank;
  final LeaderboardEntry entry;
  final bool isMe;

  Color? get _medalColor {
    switch (rank) {
      case 1:
        return DungeonTheme.coinGold;
      case 2:
        return const Color(0xFFC0C0C0);
      case 3:
        return const Color(0xFFCD7F32);
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final medal = _medalColor;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isMe ? DungeonTheme.hpOrange : DungeonTheme.dungeonFloor,
          width: isMe ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: medal ?? DungeonTheme.dungeonFloor,
              foregroundColor: medal != null
                  ? DungeonTheme.voidBlack
                  : theme.colorScheme.onSurface,
              child: medal != null
                  ? const Icon(Icons.military_tech, size: 18)
                  : Text(
                      '$rank',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isMe ? 'You' : entry.displayLabel,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(
                        Icons.stairs,
                        size: 14,
                        color: DungeonTheme.potionGreen,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Floor ${entry.bestFloor}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: DungeonTheme.potionGreen,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              '${entry.bestScore}',
              style: theme.textTheme.titleLarge?.copyWith(
                color: DungeonTheme.coinGold,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
