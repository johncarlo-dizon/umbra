class Manga {
  final String id;
  final String title;
  final String? description;
  final List<String> tags;
  final String? coverUrl;
  final List<String> availableLanguages;

  const Manga({
    required this.id,
    required this.title,
    this.description,
    this.tags = const [],
    this.coverUrl,
    this.availableLanguages = const [],
  });

  /// True if MangaDex has at least one English-translated chapter
  /// listed for this manga. Doesn't guarantee it's actually hosted
  /// (could still be external-only) but filters out the obvious dead ends.
  bool get hasEnglish => availableLanguages.contains('en');

  factory Manga.fromJson(Map<String, dynamic> json) {
    final attributes = json['attributes'] as Map<String, dynamic>? ?? {};
    final titleMap = attributes['title'] as Map<String, dynamic>? ?? {};
    final title =
        titleMap['en'] as String? ??
        (titleMap.values.isNotEmpty
            ? titleMap.values.first as String
            : 'Untitled');

    final descMap = attributes['description'] as Map<String, dynamic>? ?? {};
    final description = descMap['en'] as String?;

    final tagsList = (attributes['tags'] as List<dynamic>? ?? [])
        .map((tag) {
          final tagAttrs = tag['attributes'] as Map<String, dynamic>? ?? {};
          final tagName = tagAttrs['name'] as Map<String, dynamic>? ?? {};
          return tagName['en'] as String? ?? '';
        })
        .where((tag) => tag.isNotEmpty)
        .toList();

    final languages =
        (attributes['availableTranslatedLanguages'] as List<dynamic>? ?? [])
            .cast<String>();

    String? coverFileName;
    final relationships = json['relationships'] as List<dynamic>? ?? [];
    for (final rel in relationships) {
      if (rel['type'] == 'cover_art') {
        final relAttrs = rel['attributes'] as Map<String, dynamic>?;
        coverFileName = relAttrs?['fileName'] as String?;
      }
    }

    final mangaId = json['id'] as String;
    final coverUrl = coverFileName != null
        ? 'https://uploads.mangadex.org/covers/$mangaId/$coverFileName.256.jpg'
        : null;

    return Manga(
      id: mangaId,
      title: title,
      description: description,
      tags: tagsList,
      coverUrl: coverUrl,
      availableLanguages: languages,
    );
  }
}
