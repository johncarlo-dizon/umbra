class Chapter {
  final String id;
  final String? title;
  final String? chapterNumber;
  final String? volumeNumber;
  final String? translatedLanguage;
  final String? externalUrl;
  final int? pages;

  const Chapter({
    required this.id,
    this.title,
    this.chapterNumber,
    this.volumeNumber,
    this.translatedLanguage,
    this.externalUrl,
    this.pages,
  });

  /// True if this chapter has no pages hosted on MangaDex — either it
  /// links out externally, or it's an empty placeholder entry with
  /// zero recorded pages. Both are dead ends if tapped.
  bool get isReadable => externalUrl == null && (pages == null || pages! > 0);

  factory Chapter.fromJson(Map<String, dynamic> json) {
    final attributes = json['attributes'] as Map<String, dynamic>? ?? {};
    return Chapter(
      id: json['id'] as String,
      title: attributes['title'] as String?,
      chapterNumber: attributes['chapter'] as String?,
      volumeNumber: attributes['volume'] as String?,
      translatedLanguage: attributes['translatedLanguage'] as String?,
      externalUrl: attributes['externalUrl'] as String?,
      pages: attributes['pages'] as int?,
    );
  }

  String get displayLabel {
    if (chapterNumber != null) {
      final base = 'Chapter $chapterNumber';
      return title != null && title!.isNotEmpty ? '$base — $title' : base;
    }
    return title?.isNotEmpty == true ? title! : 'Oneshot';
  }
}
