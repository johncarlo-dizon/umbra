import '../../../core/supabase_client.dart';
import '../models/quote.dart';

/// Handles saved/favorited quotes — stored in Supabase's `quoteapp`
/// schema, keyed by the signed-in user. Guests get safe no-ops instead of
/// errors, since favoriting is gated behind login (the screen itself is
/// responsible for prompting sign-in on the actual tap).
class QuoteAppFavoritesService {
  QuoteAppFavoritesService._();

  static const _schema = 'quoteapp';

  static String? get _userId => SupabaseService.client.auth.currentUser?.id;

  static Future<bool> isFavorited(int quoteId) async {
    final userId = _userId;
    if (userId == null) return false;

    final result = await SupabaseService.client
        .schema(_schema)
        .from('favorites')
        .select('id')
        .eq('user_id', userId)
        .eq('quote_id', quoteId)
        .maybeSingle();

    return result != null;
  }

  static Future<void> addFavorite(Quote quote) async {
    final userId = _userId;
    if (userId == null) throw Exception('Not signed in');

    await SupabaseService.client.schema(_schema).from('favorites').insert({
      'user_id': userId,
      'quote_id': quote.id,
      'quote_text': quote.text,
      'author': quote.author,
      'tags': quote.tags,
    });
  }

  static Future<void> removeFavorite(int quoteId) async {
    final userId = _userId;
    if (userId == null) return;

    await SupabaseService.client
        .schema(_schema)
        .from('favorites')
        .delete()
        .eq('user_id', userId)
        .eq('quote_id', quoteId);
  }

  /// Fetches all of the signed-in user's saved quotes, most recently
  /// saved first. Returns an empty list for guests.
  static Future<List<Quote>> fetchFavorites() async {
    final userId = _userId;
    if (userId == null) return [];

    final result = await SupabaseService.client
        .schema(_schema)
        .from('favorites')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (result as List)
        .cast<Map<String, dynamic>>()
        .map(Quote.fromFavoriteRow)
        .toList();
  }
}
