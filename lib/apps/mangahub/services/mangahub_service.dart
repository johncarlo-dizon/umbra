import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/manga.dart';
import '../models/chapter.dart';

class MangaHubException implements Exception {
  final String message;
  const MangaHubException(this.message);

  @override
  String toString() => message;
}

class MangaHubService {
  MangaHubService._();

  static const _directBaseUrl = 'https://api.mangadex.org';
  static const _proxyBaseUrl = String.fromEnvironment('MANGADEX_PROXY_BASE');
  static String get _baseUrl =>
      _proxyBaseUrl.isNotEmpty ? _proxyBaseUrl : _directBaseUrl;
  static const _timeout = Duration(seconds: 10);

  static List<Manga>? _cachedTrending;
  static List<Manga>? get cachedTrending => _cachedTrending;

  /// Checks whether a manga has at least one genuinely readable
  /// English chapter (not external-only, not zero-page). Used to
  /// filter trending/search results so we don't show dead-end titles.
  static Future<bool> _hasReadableChapter(String mangaId) async {
    final uri = Uri.parse(
      '$_baseUrl/manga/$mangaId/feed'
      '?translatedLanguage[]=en'
      '&order[chapter]=asc'
      '&limit=20'
      '&contentRating[]=safe'
      '&contentRating[]=suggestive',
    );

    try {
      final response = await http.get(uri).timeout(_timeout);
      if (response.statusCode != 200) return false;

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final data = decoded['data'] as List<dynamic>? ?? [];

      return data
          .map((item) => Chapter.fromJson(item as Map<String, dynamic>))
          .any((chapter) => chapter.isReadable);
    } catch (_) {
      // If the check itself fails, don't punish the manga for it —
      // let it through rather than hiding something that might be fine.
      return true;
    }
  }

  static Future<List<Manga>> fetchTrending({int limit = 20}) async {
    final uri = Uri.parse(
      '$_baseUrl/manga'
      '?limit=$limit'
      '&order[followedCount]=desc'
      '&includes[]=cover_art'
      '&contentRating[]=safe'
      '&contentRating[]=suggestive',
    );

    try {
      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode != 200) {
        throw MangaHubException('MangaDex returned ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final data = decoded['data'] as List<dynamic>? ?? [];

      final candidates = data
          .map((item) => Manga.fromJson(item as Map<String, dynamic>))
          .where((manga) => manga.hasEnglish)
          .toList();

      // Verify each candidate actually has a readable chapter — run
      // these checks concurrently since it's one extra request per title.
      final checks = await Future.wait(
        candidates.map((manga) => _hasReadableChapter(manga.id)),
      );

      final results = <Manga>[
        for (var i = 0; i < candidates.length; i++)
          if (checks[i]) candidates[i],
      ];

      _cachedTrending = results;
      return results;
    } on MangaHubException {
      rethrow;
    } catch (e) {
      throw const MangaHubException(
        'Could not reach MangaDex. Check your connection and try again.',
      );
    }
  }

  static Future<List<Manga>> search(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) return [];

    final uri = Uri.parse(
      '$_baseUrl/manga'
      '?title=${Uri.encodeQueryComponent(query)}'
      '&limit=$limit'
      '&includes[]=cover_art'
      '&contentRating[]=safe'
      '&contentRating[]=suggestive',
    );

    try {
      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode != 200) {
        throw MangaHubException('MangaDex returned ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final data = decoded['data'] as List<dynamic>? ?? [];

      final candidates = data
          .map((item) => Manga.fromJson(item as Map<String, dynamic>))
          .where((manga) => manga.hasEnglish)
          .toList();

      final checks = await Future.wait(
        candidates.map((manga) => _hasReadableChapter(manga.id)),
      );

      return <Manga>[
        for (var i = 0; i < candidates.length; i++)
          if (checks[i]) candidates[i],
      ];
    } on MangaHubException {
      rethrow;
    } catch (e) {
      throw const MangaHubException(
        'Search failed. Check your connection and try again.',
      );
    }
  }

  static List<Map<String, String>>? _cachedTags;

  /// Fetches MangaDex's official tag list (genres/themes/etc.) and
  /// filters down to a curated set of common genres for browsing.
  /// Tag data is static/rarely changes, so we cache it after first fetch.
  static Future<List<Map<String, String>>> fetchGenres() async {
    if (_cachedTags != null) return _cachedTags!;

    const curatedNames = [
      'Action',
      'Romance',
      'Comedy',
      'Fantasy',
      'Isekai',
      'Horror',
      'Drama',
      'Slice of Life',
      'Sports',
      'Mystery',
      'Sci-Fi',
      'Historical',
    ];

    final uri = Uri.parse('$_baseUrl/manga/tag');

    try {
      final response = await http.get(uri).timeout(_timeout);
      if (response.statusCode != 200) {
        throw MangaHubException('MangaDex returned ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final data = decoded['data'] as List<dynamic>? ?? [];

      final allTags = <Map<String, String>>[];
      for (final tag in data) {
        final attributes = tag['attributes'] as Map<String, dynamic>? ?? {};
        final nameMap = attributes['name'] as Map<String, dynamic>? ?? {};
        final name = nameMap['en'] as String?;
        if (name != null) {
          allTags.add({'id': tag['id'] as String, 'name': name});
        }
      }

      // Keep only our curated genres, in our preferred display order.
      final genres = <Map<String, String>>[];
      for (final name in curatedNames) {
        final match = allTags.where((t) => t['name'] == name);
        if (match.isNotEmpty) genres.add(match.first);
      }

      _cachedTags = genres;
      return genres;
    } catch (e) {
      throw const MangaHubException('Could not load genres.');
    }
  }

  /// Fetches manga tagged with a specific genre tag ID.
  static Future<List<Manga>> fetchByGenre(
    String tagId, {
    int limit = 20,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/manga'
      '?limit=$limit'
      '&includedTags[]=$tagId'
      '&order[followedCount]=desc'
      '&includes[]=cover_art'
      '&contentRating[]=safe'
      '&contentRating[]=suggestive',
    );

    try {
      final response = await http.get(uri).timeout(_timeout);
      if (response.statusCode != 200) {
        throw MangaHubException('MangaDex returned ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final data = decoded['data'] as List<dynamic>? ?? [];

      final candidates = data
          .map((item) => Manga.fromJson(item as Map<String, dynamic>))
          .where((manga) => manga.hasEnglish)
          .toList();

      final checks = await Future.wait(
        candidates.map((manga) => _hasReadableChapter(manga.id)),
      );

      return <Manga>[
        for (var i = 0; i < candidates.length; i++)
          if (checks[i]) candidates[i],
      ];
    } on MangaHubException {
      rethrow;
    } catch (e) {
      throw const MangaHubException(
        'Could not load this genre. Check your connection and try again.',
      );
    }
  }

  static Future<Manga> fetchMangaDetail(String mangaId) async {
    final uri = Uri.parse('$_baseUrl/manga/$mangaId?includes[]=cover_art');

    try {
      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode != 200) {
        throw MangaHubException('MangaDex returned ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final data = decoded['data'] as Map<String, dynamic>;

      return Manga.fromJson(data);
    } on MangaHubException {
      rethrow;
    } catch (e) {
      throw const MangaHubException(
        'Could not load manga details. Check your connection and try again.',
      );
    }
  }

  static Future<List<Chapter>> fetchChapters(String mangaId) async {
    final uri = Uri.parse(
      '$_baseUrl/manga/$mangaId/feed'
      '?translatedLanguage[]=en'
      '&order[chapter]=asc'
      '&limit=100'
      '&contentRating[]=safe'
      '&contentRating[]=suggestive',
    );

    try {
      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode != 200) {
        throw MangaHubException('MangaDex returned ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final data = decoded['data'] as List<dynamic>? ?? [];

      final allChapters = data
          .map((item) => Chapter.fromJson(item as Map<String, dynamic>))
          .toList();

      // Drop dead-end chapters (external-only or zero-page entries).
      final readable = allChapters.where((c) => c.isReadable).toList();

      // De-duplicate by chapter number — multiple scanlation groups
      // often upload the same numbered chapter.
      final seen = <String>{};
      final deduped = <Chapter>[];
      for (final chapter in readable) {
        final key = chapter.chapterNumber ?? chapter.id;
        if (seen.add(key)) {
          deduped.add(chapter);
        }
      }

      return deduped;
    } on MangaHubException {
      rethrow;
    } catch (e) {
      throw const MangaHubException(
        'Could not load chapters. Check your connection and try again.',
      );
    }
  }

  static Future<List<String>> fetchChapterPageUrls(String chapterId) async {
    final uri = Uri.parse('$_baseUrl/at-home/server/$chapterId');

    try {
      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode != 200) {
        throw MangaHubException('MangaDex returned ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final baseUrl = decoded['baseUrl'] as String;
      final chapterData = decoded['chapter'] as Map<String, dynamic>;
      final hash = chapterData['hash'] as String;
      final fileNames = (chapterData['data'] as List<dynamic>).cast<String>();

      return fileNames
          .map((fileName) => '$baseUrl/data/$hash/$fileName')
          .toList();
    } on MangaHubException {
      rethrow;
    } catch (e) {
      throw const MangaHubException(
        'Could not load chapter pages. Check your connection and try again.',
      );
    }
  }
}
