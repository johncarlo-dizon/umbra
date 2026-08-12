import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/quote.dart';

class QuoteAppException implements Exception {
  final String message;
  const QuoteAppException(this.message);

  @override
  String toString() => message;
}

/// Talks to the QuoteSlate API (https://github.com/Musheer360/QuoteSlate).
/// No API key required, and — unlike MangaDex — QuoteSlate sends
/// `Access-Control-Allow-Origin` headers for every response, so this is
/// the first sub-app since v3 that can call its API directly from the
/// browser build with no serverless proxy in front of it.
///
/// QuoteSlate's free public endpoint asks callers to be considerate about
/// request volume (see their README), so a fetched quote is cached
/// in-memory both as a last-known-good fallback for offline/error states
/// and to avoid a redundant call if the same screen rebuilds.
class QuoteAppService {
  QuoteAppService._();

  static const _baseUrl = 'https://quoteslate.vercel.app/api';
  static const _timeout = Duration(seconds: 10);

  static Quote? _cachedQuote;
  static Quote? get cachedQuote => _cachedQuote;

  static List<String>? _cachedTags;

  /// Fetches one random quote, optionally filtered to a single tag
  /// (e.g. "motivation", "wisdom" — see [fetchTags]).
  static Future<Quote> fetchRandom({String? tag}) async {
    final query = (tag != null && tag.isNotEmpty)
        ? '?tags=${Uri.encodeQueryComponent(tag)}'
        : '';
    final uri = Uri.parse('$_baseUrl/quotes/random$query');

    try {
      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode != 200) {
        throw QuoteAppException('QuoteSlate returned ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final quote = Quote.fromJson(decoded);
      _cachedQuote = quote;
      return quote;
    } on QuoteAppException {
      rethrow;
    } catch (e) {
      throw const QuoteAppException(
        'Could not reach QuoteSlate. Check your connection and try again.',
      );
    }
  }

  /// Fetches the full list of tags quotes can be filtered by. Cached for
  /// the app session — the tag list doesn't change at runtime.
  static Future<List<String>> fetchTags() async {
    if (_cachedTags != null) return _cachedTags!;

    final uri = Uri.parse('$_baseUrl/tags');

    try {
      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode != 200) {
        throw const QuoteAppException('Could not load tags.');
      }

      final decoded = jsonDecode(response.body) as List<dynamic>;
      final tags = decoded.map((t) => t as String).toList()..sort();
      _cachedTags = tags;
      return tags;
    } on QuoteAppException {
      rethrow;
    } catch (e) {
      throw const QuoteAppException('Could not load tags.');
    }
  }
}
