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
                    if (entries.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.leaderboard,
                                size: 64,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No runs recorded yet — be the first!',
                                style: theme.textTheme.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final myIndex = myUserId == null
                        ? -1
                        : entries.indexWhere((e) => e.userId == myUserId);

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      children: [
                        Text(
                          'The deepest, bravest crawlers.',
                          style: theme.textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        _MyRankCard(
                          rank: myIndex == -1 ? null : myIndex + 1,
                          entry: myIndex == -1 ? null : entries[myIndex],
                          totalShown: entries.length,
                        ),
                        const SizedBox(height: 20),
                        ...List.generate(entries.length, (i) {
                          final entry = entries[i];
                          return _LeaderboardRow(
                            rank: i + 1,
                            entry: entry,
                            isMe: entry.userId == myUserId,
                          );
                        }),
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

class _MyRankCard extends StatelessWidget {
  const _MyRankCard({
    required this.rank,
    required this.entry,
    required this.totalShown,
  });

  final int? rank;
  final LeaderboardEntry? entry;
  final int totalShown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (rank == null || entry == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: DungeonTheme.dungeonWall,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DungeonTheme.dungeonFloor),
        ),
        child: Row(
          children: [
            Icon(
              Icons.person_search,
              color: theme.colorScheme.primary,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "You're not ranked in the top $totalShown yet — dive deeper!",
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: DungeonTheme.hpOrange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DungeonTheme.hpOrange, width: 2),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: DungeonTheme.hpOrange,
            foregroundColor: DungeonTheme.voidBlack,
            child: Text(
              '$rank',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Rank',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: DungeonTheme.hpOrange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.stairs,
                      size: 14,
                      color: DungeonTheme.potionGreen,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Floor ${entry!.bestFloor}',
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
            '${entry!.bestScore}',
            style: theme.textTheme.titleLarge?.copyWith(
              color: DungeonTheme.coinGold,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
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
