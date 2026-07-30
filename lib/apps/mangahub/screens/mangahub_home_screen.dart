import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/manga.dart';
import '../services/mangahub_service.dart';
import '../../../core/supabase_client.dart';
import '../services/mangahub_user_data_service.dart';
import '../../../core/router.dart';
import '../../../core/theme.dart';
import '../../../core/shell_nav_state.dart';

class MangaHubHomeScreen extends StatefulWidget {
  const MangaHubHomeScreen({super.key});

  @override
  State<MangaHubHomeScreen> createState() => _MangaHubHomeScreenState();
}

enum _LoadState { loading, loaded, error, offlineCached }

class _MangaHubHomeScreenState extends State<MangaHubHomeScreen>
    with RouteAware {
  _LoadState _state = _LoadState.loading;
  List<Manga> _trending = [];
  String? _errorMessage;

  List<Manga>? _searchResults;
  bool _isSearching = false;
  final _searchController = TextEditingController();
  final _continueReadingKey = GlobalKey<_ContinueReadingRowState>();
  List<Map<String, String>> _genres = [];
  String? _selectedGenreId;
  String? _selectedGenreName;
  List<Manga>? _genreResults;
  bool _isLoadingGenre = false;

  @override
  void initState() {
    super.initState();
    _loadTrending();
    _loadGenres();
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() {
    _continueReadingKey.currentState?.refresh();
  }

  Future<void> _loadTrending() async {
    setState(() => _state = _LoadState.loading);

    try {
      final results = await MangaHubService.fetchTrending();
      if (!mounted) return;
      setState(() {
        _trending = results;
        _state = _LoadState.loaded;
      });
    } catch (e) {
      if (!mounted) return;

      final cached = MangaHubService.cachedTrending;
      if (cached != null && cached.isNotEmpty) {
        setState(() {
          _trending = cached;
          _state = _LoadState.offlineCached;
        });
      } else {
        setState(() {
          _errorMessage = e.toString();
          _state = _LoadState.error;
        });
      }
    }
  }

  Future<void> _loadGenres() async {
    try {
      final genres = await MangaHubService.fetchGenres();
      if (!mounted) return;
      setState(() => _genres = genres);
    } catch (_) {
      // Silent failure — genre chips just won't show. Not critical
      // enough to block the rest of the screen with an error state.
    }
  }

  Future<void> _selectGenre(String tagId, String name) async {
    if (_selectedGenreId == tagId) {
      // Tapping the same genre again clears the filter.
      setState(() {
        _selectedGenreId = null;
        _selectedGenreName = null;
        _genreResults = null;
      });
      return;
    }

    setState(() {
      _selectedGenreId = tagId;
      _selectedGenreName = name;
      _isLoadingGenre = true;
    });

    try {
      final results = await MangaHubService.fetchByGenre(tagId);
      if (!mounted) return;
      setState(() {
        _genreResults = results;
        _isLoadingGenre = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _genreResults = [];
        _isLoadingGenre = false;
      });
    }
  }

  Future<void> _onSearchChanged(String query) async {
    setState(() {}); // refresh clear-button visibility as text changes
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = null;
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final results = await MangaHubService.search(query);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MangaHub')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth;
            final contentMaxWidth = maxWidth > 1000 ? 1000.0 : maxWidth;
            final crossAxisCount = maxWidth >= 900
                ? 4
                : maxWidth >= 600
                ? 3
                : 2;

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentMaxWidth),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          textInputAction: TextInputAction.search,
                          style: Theme.of(context).textTheme.bodyLarge,
                          decoration: InputDecoration(
                            hintText: 'Search titles, genres, authors',
                            hintStyle: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            suffixIcon: _isSearching
                                ? Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                    ),
                                  )
                                : _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.close, size: 20),
                                    onPressed: () {
                                      _searchController.clear();
                                      _onSearchChanged('');
                                      setState(() {});
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: Colors.transparent,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(28),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(28),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(28),
                              borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_state == _LoadState.offlineCached)
                        _OfflineBanner(onRetry: _loadTrending),
                      Expanded(child: _buildBody(crossAxisCount)),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(int crossAxisCount) {
    if (_searchResults != null) {
      if (_searchResults!.isEmpty && !_isSearching) {
        return const Center(child: Text('No results found'));
      }
      return _MangaGrid(
        mangaList: _searchResults!,
        crossAxisCount: crossAxisCount,
      );
    }

    switch (_state) {
      case _LoadState.loading:
        return const Center(child: CircularProgressIndicator());

      case _LoadState.error:
        return _ErrorState(
          message: _errorMessage ?? 'Something went wrong',
          onRetry: _loadTrending,
        );

      case _LoadState.loaded:
      case _LoadState.offlineCached:
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ContinueReadingRow(key: _continueReadingKey),
              if (_genres.isNotEmpty) ...[
                Text(
                  'Browse by genre',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _genres.map((genre) {
                    final isSelected = _selectedGenreId == genre['id'];
                    return ChoiceChip(
                      label: Text(genre['name']!),
                      selected: isSelected,
                      selectedColor: AppColors.terracotta,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppColors.espresso,
                        fontWeight: FontWeight.w500,
                      ),
                      onSelected: (_) =>
                          _selectGenre(genre['id']!, genre['name']!),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
              ],
              if (_selectedGenreId != null) ...[
                Text(
                  _selectedGenreName!,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                if (_isLoadingGenre)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_genreResults != null && _genreResults!.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('No results found')),
                  )
                else if (_genreResults != null)
                  _MangaGrid(
                    mangaList: _genreResults!,
                    crossAxisCount: crossAxisCount,
                    shrinkWrap: true,
                  ),
                const SizedBox(height: 20),
              ] else ...[
                Text(
                  'Trending now',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _MangaGrid(
                  mangaList: _trending,
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true,
                ),
              ],
            ],
          ),
        );
    }
  }
}

class _MangaGrid extends StatelessWidget {
  final List<Manga> mangaList;
  final int crossAxisCount;
  final bool shrinkWrap;

  const _MangaGrid({
    required this.mangaList,
    required this.crossAxisCount,
    this.shrinkWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap
          ? const NeverScrollableScrollPhysics()
          : const AlwaysScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.62,
      ),
      itemCount: mangaList.length,
      itemBuilder: (context, index) {
        final manga = mangaList[index];
        return _MangaCard(manga: manga);
      },
    );
  }
}

class _MangaCard extends StatelessWidget {
  final Manga manga;

  const _MangaCard({required this.manga});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/mangahub/manga/${manga.id}'),
      borderRadius: BorderRadius.circular(12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: manga.coverUrl != null
                  ? CachedNetworkImage(
                      imageUrl: manga.coverUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.broken_image_outlined),
                    )
                  : const ColoredBox(
                      color: Colors.black12,
                      child: Icon(Icons.menu_book_outlined),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                manga.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 48),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  final VoidCallback onRetry;

  const _OfflineBanner({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 18,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Offline — showing saved data',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
                fontSize: 13,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _ContinueReadingRow extends StatefulWidget {
  const _ContinueReadingRow({super.key});

  @override
  State<_ContinueReadingRow> createState() => _ContinueReadingRowState();
}

class _ContinueReadingRowState extends State<_ContinueReadingRow> {
  bool _loading = true;
  List<Manga> _inProgressManga = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> refresh() => _load();

  Future<void> _load() async {
    if (!SupabaseService.isLoggedIn) {
      setState(() => _loading = false);
      return;
    }

    setState(() => _loading = true);

    try {
      final progressRows = await MangaHubUserDataService.fetchAllProgress();

      if (progressRows.isEmpty) {
        if (!mounted) return;
        setState(() {
          _inProgressManga = [];
          _loading = false;
        });
        return;
      }

      final mangaList = await Future.wait(
        progressRows.map(
          (row) => MangaHubService.fetchMangaDetail(row['manga_id'] as String),
        ),
      );

      if (!mounted) return;
      setState(() {
        _inProgressManga = mangaList;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = SupabaseService.isLoggedIn;

    if (!isLoggedIn) {
      return _buildMessageBox(
        context,
        'Continue reading — sign in to sync your progress',
      );
    }

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_inProgressManga.isEmpty) {
      return _buildMessageBox(
        context,
        'No reading history yet — start a manga to see it here',
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Continue reading',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _inProgressManga.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final manga = _inProgressManga[index];
                return SizedBox(
                  width: 120,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => context.push('/mangahub/manga/${manga.id}'),
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: manga.coverUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: manga.coverUrl!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    errorWidget: (context, url, error) =>
                                        const Icon(Icons.broken_image_outlined),
                                  )
                                : const ColoredBox(
                                    color: Colors.black12,
                                    child: Icon(Icons.menu_book_outlined),
                                  ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(6),
                            child: Text(
                              manga.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBox(BuildContext context, String message) {
    final isLoggedIn = SupabaseService.isLoggedIn;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isLoggedIn
              ? null
              : () {
                  ShellNavState.requestedTabIndex.value =
                      ShellNavState.profileTab;
                  context.go('/');
                },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.history,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
                if (!isLoggedIn)
                  Icon(
                    Icons.chevron_right,
                    color: Theme.of(context).colorScheme.outline,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
