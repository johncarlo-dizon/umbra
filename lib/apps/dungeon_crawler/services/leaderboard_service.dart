import '../../../core/supabase_client.dart';

class LeaderboardEntry {
  final String userId;
  final int bestFloor;
  final int bestScore;

  const LeaderboardEntry({
    required this.userId,
    required this.bestFloor,
    required this.bestScore,
  });

  factory LeaderboardEntry.fromMap(Map<String, dynamic> m) => LeaderboardEntry(
    userId: m['user_id'] as String,
    bestFloor: m['best_floor'] as int? ?? 0,
    bestScore: m['best_score'] as int? ?? 0,
  );

  /// Short, non-identifying label for display — never show the raw
  /// user_id or anything PII-derived on a publicly-readable table.
  String get displayLabel => 'Player ${userId.substring(0, 4).toUpperCase()}';
}

/// Submits/reads run results from the `dungeon_crawler.leaderboard` table.
/// Guests are never submitted silently — `submitRunResult` no-ops if the
/// player isn't logged in; the calling screen is responsible for
/// prompting sign-in via the standard `ShellNavState` redirect pattern,
/// same as every other gated action in Umbra.
class LeaderboardService {
  LeaderboardService._();

  static const _table = 'leaderboard';
  static final _schema = SupabaseService.client.schema('dungeon_crawler');

  static Future<void> submitRunResult({
    required int floorReached,
    required int coinsCollected,
    required int revivesUsed,
  }) async {
    if (!SupabaseService.isLoggedIn) return;
    final userId = SupabaseService.currentSession!.user.id;
    final score = floorReached * 100 + coinsCollected;

    final existing = await _schema
        .from(_table)
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    final currentBest = existing == null
        ? 0
        : (existing['best_score'] as int? ?? 0);
    if (existing != null && score <= currentBest)
      return; // not a new best — don't overwrite

    await _schema.from(_table).upsert({
      'user_id': userId,
      'best_floor': floorReached,
      'best_score': score,
      'total_coins_collected': coinsCollected,
      'total_revives_used': revivesUsed,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id');
  }

  static Future<List<LeaderboardEntry>> fetchTopScores({int limit = 20}) async {
    final rows = await _schema
        .from(_table)
        .select()
        .order('best_score', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((r) => LeaderboardEntry.fromMap(r as Map<String, dynamic>))
        .toList();
  }
}
