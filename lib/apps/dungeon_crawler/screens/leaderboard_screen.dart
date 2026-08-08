import 'package:flutter/material.dart';

import '../../../core/supabase_client.dart';
import '../services/leaderboard_service.dart';

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
                  child: Text('Couldn\'t load leaderboard: ${snapshot.error}'),
                );
              }
              final entries = snapshot.data ?? [];
              if (entries.isEmpty) {
                return const Center(
                  child: Text('No runs recorded yet — be the first!'),
                );
              }
              return ListView.builder(
                itemCount: entries.length,
                itemBuilder: (context, i) {
                  final entry = entries[i];
                  final isMe = entry.userId == myUserId;
                  return ListTile(
                    leading: CircleAvatar(child: Text('${i + 1}')),
                    title: Text(isMe ? 'You' : entry.displayLabel),
                    subtitle: Text('Floor ${entry.bestFloor}'),
                    trailing: Text(
                      '${entry.bestScore}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    tileColor: isMe
                        ? Theme.of(
                            context,
                          ).colorScheme.primaryContainer.withValues(alpha: 0.3)
                        : null,
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
