import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/manga.dart';
import '../models/chapter.dart';
import '../models/reader_args.dart';
import '../services/mangahub_service.dart';
import '../services/mangahub_user_data_service.dart';
import '../../../core/supabase_client.dart';

class MangaDetailScreen extends StatefulWidget {
  final String mangaId;

  const MangaDetailScreen({super.key, required this.mangaId});

  @override
  State<MangaDetailScreen> createState() => _MangaDetailScreenState();
}

enum _LoadState { loading, loaded, error }

class _MangaDetailScreenState extends State<MangaDetailScreen> {
  _LoadState _state = _LoadState.loading;
  Manga? _manga;
  List<Chapter> _chapters = [];
  String? _errorMessage;
  bool _isBookmarked = false;
  bool _bookmarkBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _state = _LoadState.loading);

    try {
      final results = await Future.wait([
        MangaHubService.fetchMangaDetail(widget.mangaId),
        MangaHubService.fetchChapters(widget.mangaId),
        MangaHubUserDataService.isBookmarked(widget.mangaId),
      ]);

      if (!mounted) return;
      setState(() {
        _manga = results[0] as Manga;
        _chapters = results[1] as List<Chapter>;
        _isBookmarked = results[2] as bool;
        _state = _LoadState.loaded;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _state = _LoadState.error;
      });
    }
  }

  Future<void> _toggleBookmark() async {
    if (!SupabaseService.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to save bookmarks')),
      );
      return;
    }

    setState(() => _bookmarkBusy = true);
    try {
      if (_isBookmarked) {
        await MangaHubUserDataService.removeBookmark(widget.mangaId);
      } else {
        await MangaHubUserDataService.addBookmark(widget.mangaId);
      }
      if (!mounted) return;
      setState(() => _isBookmarked = !_isBookmarked);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update bookmark')),
      );
    } finally {
      if (mounted) setState(() => _bookmarkBusy = false);
    }
  }

  void _openReader(int chapterIndex) {
    context.push(
      '/mangahub/manga/${widget.mangaId}/read',
      extra: ReaderScreenArgs(
        mangaId: widget.mangaId,
        chapters: _chapters,
        initialChapterIndex: chapterIndex,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_manga?.title ?? 'Manga'),
        actions: [
          if (_state == _LoadState.loaded)
            IconButton(
              onPressed: _bookmarkBusy ? null : _toggleBookmark,
              icon: Icon(
                _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _LoadState.loading:
        return const Center(child: CircularProgressIndicator());

      case _LoadState.error:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 48),
              const SizedBox(height: 12),
              Text(
                _errorMessage ?? 'Something went wrong',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        );

      case _LoadState.loaded:
        final manga = _manga!;
        return LayoutBuilder(
          builder: (context, constraints) {
            final contentMaxWidth = constraints.maxWidth > 800
                ? 800.0
                : constraints.maxWidth;

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentMaxWidth),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 120,
                            height: 170,
                            child: manga.coverUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: manga.coverUrl!,
                                    fit: BoxFit.cover,
                                    errorWidget: (context, url, error) =>
                                        const Icon(Icons.broken_image_outlined),
                                  )
                                : const ColoredBox(
                                    color: Colors.black12,
                                    child: Icon(Icons.menu_book_outlined),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                manga.title,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              if (manga.tags.isNotEmpty)
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: manga.tags
                                      .map(
                                        (tag) => Chip(
                                          label: Text(tag),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      )
                                      .toList(),
                                ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: _chapters.isEmpty
                                    ? null
                                    : () => _openReader(0),
                                icon: const Icon(Icons.play_arrow),
                                label: Text(
                                  _chapters.isEmpty
                                      ? 'No chapters available'
                                      : 'Start reading',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (manga.description != null &&
                        manga.description!.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text(
                        'Description',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(manga.description!),
                    ],
                    const SizedBox(height: 24),
                    if (_chapters.isNotEmpty &&
                        _chapters.first.chapterNumber != '1') ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Note: earlier chapters may not be available in English here — '
                          'the list below starts at Chapter ${_chapters.first.chapterNumber ?? "?"}.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                    Text(
                      'Chapters (${_chapters.length})',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_chapters.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('No English chapters found yet.'),
                      )
                    else
                      ..._chapters.asMap().entries.map(
                        (entry) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.menu_book_outlined),
                          title: Text(entry.value.displayLabel),
                          onTap: () => _openReader(entry.key),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
    }
  }
}
