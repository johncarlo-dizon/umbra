import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/manga.dart';
import '../models/chapter.dart';
import 'image_proxy.dart';

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
  static const _timeout = Duration(seconds: 10);

  static List<Manga>? _cachedTrending;
  static List<Manga>? get cachedTrending => _cachedTrending;

  /// Builds the actual request URL. In production (proxy configured),
  /// the full MangaDex path+query gets passed as a single "target"
  /// parameter to our own serverless proxy, which forwards it
  /// server-side (avoiding MangaDex's CORS restriction entirely).
  /// Locally, it just hits MangaDex directly.
  static Uri _buildUri(String pathAndQuery) {
    if (_proxyBaseUrl.isNotEmpty) {
      return Uri.parse(
        '$_proxyBaseUrl?target=${Uri.encodeQueryComponent(pathAndQuery)}',
      );
    }
    return Uri.parse('$_directBaseUrl/$pathAndQuery');
  }

  static Future<bool> _hasReadableChapter(String mangaId) async {
    final uri = _buildUri(
      'manga/$mangaId/feed'
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
      return true;
    }
  }

  static Future<List<Manga>> fetchTrending({int limit = 20}) async {
    final uri = _buildUri(
      'manga'
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

    final uri = _buildUri(
      'manga'
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

  static Future<Manga> fetchMangaDetail(String mangaId) async {
    final uri = _buildUri('manga/$mangaId?includes[]=cover_art');

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
    final uri = _buildUri(
      'manga/$mangaId/feed'
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

      final readable = allChapters.where((c) => c.isReadable).toList();

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
    final uri = _buildUri('at-home/server/$chapterId');

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
          .map((fileName) => ImageProxy.wrap('$baseUrl/data/$hash/$fileName'))
          .toList();
    } on MangaHubException {
      rethrow;
    } catch (e) {
      throw const MangaHubException(
        'Could not load chapter pages. Check your connection and try again.',
      );
    }
  }

  static List<Map<String, String>>? _cachedTags;

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

    final uri = _buildUri('manga/tag');

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

  static Future<List<Manga>> fetchByGenre(
    String tagId, {
    int limit = 20,
  }) async {
    final uri = _buildUri(
      'manga'
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
}
