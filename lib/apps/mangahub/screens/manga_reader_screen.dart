import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/chapter.dart';
import '../services/mangahub_service.dart';
import '../services/mangahub_user_data_service.dart';

class MangaReaderScreen extends StatefulWidget {
  final String mangaId;
  final List<Chapter> chapters;
  final int initialChapterIndex;

  const MangaReaderScreen({
    super.key,
    required this.mangaId,
    required this.chapters,
    required this.initialChapterIndex,
  });

  @override
  State<MangaReaderScreen> createState() => _MangaReaderScreenState();
}

enum _LoadState { loading, loaded, empty, error }

class _MangaReaderScreenState extends State<MangaReaderScreen> {
  late int _chapterIndex;
  _LoadState _state = _LoadState.loading;
  List<String> _pageUrls = [];
  String? _errorMessage;
  final ScrollController _scrollController = ScrollController();

  Chapter get _currentChapter => widget.chapters[_chapterIndex];

  @override
  void initState() {
    super.initState();
    _chapterIndex = widget.initialChapterIndex;
    _scrollController.addListener(_onScroll);
    _loadChapter();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _pageUrls.isEmpty) return;

    // Estimate current "page" from scroll position for progress saving.
    final maxScroll = _scrollController.position.maxScrollExtent;
    final current = _scrollController.position.pixels;
    if (maxScroll <= 0) return;

    final estimatedPage = ((current / maxScroll) * (_pageUrls.length - 1))
        .round()
        .clamp(0, _pageUrls.length - 1);

    MangaHubUserDataService.saveProgress(
      mangaId: widget.mangaId,
      chapterId: _currentChapter.id,
      pageNumber: estimatedPage,
    );
  }

  Future<void> _loadChapter() async {
    setState(() => _state = _LoadState.loading);

    try {
      final pages = await MangaHubService.fetchChapterPageUrls(
        _currentChapter.id,
      );

      if (pages.isEmpty) {
        if (!mounted) return;
        setState(() => _state = _LoadState.empty);
        return;
      }

      if (!mounted) return;
      setState(() {
        _pageUrls = pages;
        _state = _LoadState.loaded;
      });

      // Jump to saved scroll position on next frame, once the list
      // has actually built and has a scroll extent to jump within.
      final progress = await MangaHubUserDataService.fetchProgress(
        widget.mangaId,
      );
      if (progress != null &&
          progress['chapter_id'] == _currentChapter.id &&
          mounted) {
        final savedPage = progress['page_number'] as int?;
        if (savedPage != null && savedPage > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              final maxScroll = _scrollController.position.maxScrollExtent;
              final fraction =
                  savedPage / (_pageUrls.length - 1).clamp(1, 1 << 30);
              _scrollController.jumpTo(maxScroll * fraction);
            }
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _state = _LoadState.error;
      });
    }
  }

  void _goToChapter(int newIndex) {
    if (newIndex < 0 || newIndex >= widget.chapters.length) return;
    setState(() => _chapterIndex = newIndex);
    _loadChapter();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          _currentChapter.displayLabel,
          style: const TextStyle(fontSize: 15),
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar:
          (_state == _LoadState.loaded || _state == _LoadState.empty)
          ? SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _chapterIndex > 0
                          ? () => _goToChapter(_chapterIndex - 1)
                          : null,
                      icon: const Icon(Icons.skip_previous),
                      label: const Text('Prev chapter'),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _chapterIndex < widget.chapters.length - 1
                          ? () => _goToChapter(_chapterIndex + 1)
                          : null,
                      icon: const Icon(Icons.skip_next),
                      label: const Text('Next chapter'),
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _LoadState.loading:
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );

      case _LoadState.empty:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.open_in_new, color: Colors.white, size: 48),
                const SizedBox(height: 12),
                const Text(
                  "This chapter isn't hosted here",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'It may only be available on an external site. '
                  'Try another chapter instead.',
                  style: TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );

      case _LoadState.error:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 48),
              const SizedBox(height: 12),
              Text(
                _errorMessage ?? 'Something went wrong',
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadChapter,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        );

      case _LoadState.loaded:
        return LayoutBuilder(
          builder: (context, constraints) {
            // Cap reading width on large screens so pages read like a
            // single continuous webtoon strip instead of stretching edge
            // to edge — matches how webtoon apps present vertical scroll.
            final readerWidth = constraints.maxWidth > 700
                ? 700.0
                : constraints.maxWidth;

            return Center(
              child: SizedBox(
                width: readerWidth,
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _pageUrls.length,
                  itemBuilder: (context, index) {
                    return CachedNetworkImage(
                      imageUrl: _pageUrls[index],
                      fit: BoxFit.fitWidth,
                      width: double.infinity,
                      placeholder: (context, url) => const SizedBox(
                        height: 400,
                        child: Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      ),
                      errorWidget: (context, url, error) => const SizedBox(
                        height: 200,
                        child: Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
    }
  }
}
