import '../../../core/supabase_client.dart';

/// Handles bookmarks and reading progress — all stored in Supabase's
/// `manga` schema, keyed by the signed-in user. Guests get safe no-ops
/// instead of errors, since these features are gated behind login.
class MangaHubUserDataService {
  MangaHubUserDataService._();

  static const _schema = 'manga';

  static String? get _userId => SupabaseService.client.auth.currentUser?.id;

  static Future<bool> isBookmarked(String mangaId) async {
    final userId = _userId;
    if (userId == null) return false;

    final result = await SupabaseService.client
        .schema(_schema)
        .from('bookmarks')
        .select('id')
        .eq('user_id', userId)
        .eq('manga_id', mangaId)
        .maybeSingle();

    return result != null;
  }

  static Future<void> addBookmark(String mangaId) async {
    final userId = _userId;
    if (userId == null) throw Exception('Not signed in');

    await SupabaseService.client.schema(_schema).from('bookmarks').insert({
      'user_id': userId,
      'manga_id': mangaId,
    });
  }

  static Future<void> removeBookmark(String mangaId) async {
    final userId = _userId;
    if (userId == null) return;

    await SupabaseService.client
        .schema(_schema)
        .from('bookmarks')
        .delete()
        .eq('user_id', userId)
        .eq('manga_id', mangaId);
  }

  /// Saves (or updates) the last-read chapter + page for a manga.
  /// Silently does nothing for guests — progress sync is a signed-in feature.
  static Future<void> saveProgress({
    required String mangaId,
    required String chapterId,
    required int pageNumber,
  }) async {
    final userId = _userId;
    if (userId == null) return;

    await SupabaseService.client
        .schema(_schema)
        .from('reading_progress')
        .upsert({
          'user_id': userId,
          'manga_id': mangaId,
          'chapter_id': chapterId,
          'page_number': pageNumber,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'user_id,manga_id');
  }

  static Future<Map<String, dynamic>?> fetchProgress(String mangaId) async {
    final userId = _userId;
    if (userId == null) return null;

    return await SupabaseService.client
        .schema(_schema)
        .from('reading_progress')
        .select()
        .eq('user_id', userId)
        .eq('manga_id', mangaId)
        .maybeSingle();
  }

  /// Fetches the user's most recent reading progress entries,
  /// most recently updated first. Returns raw rows — manga
  /// title/cover get looked up separately from MangaDex by ID.
  static Future<List<Map<String, dynamic>>> fetchAllProgress({
    int limit = 10,
  }) async {
    final userId = _userId;
    if (userId == null) return [];

    final result = await SupabaseService.client
        .schema(_schema)
        .from('reading_progress')
        .select()
        .eq('user_id', userId)
        .order('updated_at', ascending: false)
        .limit(limit);

    return (result as List).cast<Map<String, dynamic>>();
  }
}
