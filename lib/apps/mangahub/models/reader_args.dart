import 'chapter.dart';

/// Bundles what the reader screen needs when navigated to from the
/// detail screen — avoids refetching the chapter list we already have.
class ReaderScreenArgs {
  final String mangaId;
  final List<Chapter> chapters;
  final int initialChapterIndex;

  const ReaderScreenArgs({
    required this.mangaId,
    required this.chapters,
    required this.initialChapterIndex,
  });
}
