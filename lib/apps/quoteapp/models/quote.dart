/// A single quote as returned by the QuoteSlate API.
///
/// [id] is QuoteSlate's own numeric ID for the quote. QuoteSlate has no
/// "fetch by ID" endpoint, so unlike MangaHub's bookmarks (which store only
/// an external ID and re-fetch full details from MangaDex on demand),
/// favorites here store a full snapshot of the quote text/author/tags
/// alongside the ID — there's nothing to re-fetch it from later, and the
/// content itself is tiny.
class Quote {
  final int id;
  final String text;
  final String author;
  final List<String> tags;

  const Quote({
    required this.id,
    required this.text,
    required this.author,
    required this.tags,
  });

  factory Quote.fromJson(Map<String, dynamic> json) {
    return Quote(
      id: json['id'] as int,
      text: json['quote'] as String,
      author: json['author'] as String,
      tags: (json['tags'] as List<dynamic>? ?? const [])
          .map((t) => t as String)
          .toList(),
    );
  }

  /// Rebuilds a [Quote] from a saved-favorite row in Supabase (see
  /// `quoteapp.favorites` — column names differ slightly from the API's
  /// raw JSON, e.g. `quote_text` instead of `quote`).
  factory Quote.fromFavoriteRow(Map<String, dynamic> row) {
    return Quote(
      id: row['quote_id'] as int,
      text: row['quote_text'] as String,
      author: row['author'] as String,
      tags: (row['tags'] as List<dynamic>? ?? const [])
          .map((t) => t as String)
          .toList(),
    );
  }
}
