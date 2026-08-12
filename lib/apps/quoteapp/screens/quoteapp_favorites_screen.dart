import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme.dart';
import '../../../core/supabase_client.dart';
import '../../../core/shell_nav_state.dart';
import '../models/quote.dart';
import '../quoteapp_theme.dart';
import '../services/quoteapp_favorites_service.dart';

enum _LoadState { loading, loaded, error }

class QuoteAppFavoritesScreen extends StatefulWidget {
  const QuoteAppFavoritesScreen({super.key});

  @override
  State<QuoteAppFavoritesScreen> createState() =>
      _QuoteAppFavoritesScreenState();
}

class _QuoteAppFavoritesScreenState extends State<QuoteAppFavoritesScreen> {
  _LoadState _state = _LoadState.loading;
  List<Quote> _favorites = [];

  @override
  void initState() {
    super.initState();
    if (SupabaseService.isLoggedIn) _load();
  }

  Future<void> _load() async {
    setState(() => _state = _LoadState.loading);
    try {
      final favorites = await QuoteAppFavoritesService.fetchFavorites();
      if (!mounted) return;
      setState(() {
        _favorites = favorites;
        _state = _LoadState.loaded;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _state = _LoadState.error);
    }
  }

  Future<void> _remove(Quote quote) async {
    final removed = quote;
    setState(() => _favorites.removeWhere((q) => q.id == quote.id));

    try {
      await QuoteAppFavoritesService.removeFavorite(quote.id);
    } catch (e) {
      if (!mounted) return;
      // Put it back and let the user know the removal didn't stick.
      setState(() => _favorites.insert(0, removed));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not remove favorite')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Favorite Quotes'),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: _body(scheme),
          ),
        ),
      ),
    );
  }

  Widget _body(ColorScheme scheme) {
    if (!SupabaseService.isLoggedIn) return _guestState(scheme);

    switch (_state) {
      case _LoadState.loading:
        return const Center(child: CircularProgressIndicator());
      case _LoadState.error:
        return _errorState(scheme);
      case _LoadState.loaded:
        return _favorites.isEmpty ? _emptyState(scheme) : _list(scheme);
    }
  }

  Widget _guestState(ColorScheme scheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_border_rounded, size: 40, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              'Sign in to save and view favorite quotes',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: quoteAppAccent),
              onPressed: () {
                ShellNavState.requestedTabIndex.value =
                    ShellNavState.profileTab;
                context.go('/');
              },
              child: const Text('Sign in'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorState(ColorScheme scheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: 40, color: scheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            'Could not load your favorites.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(ColorScheme scheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.format_quote_rounded, size: 40, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              'No favorites yet — tap the heart on a quote to save it here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(ColorScheme scheme) {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _favorites.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _favoriteCard(scheme, _favorites[index]),
    );
  }

  Widget _favoriteCard(ColorScheme scheme, Quote quote) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quote.text,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '— ${quote.author}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _remove(quote),
            icon: const Icon(Icons.favorite_rounded, color: Colors.red, size: 20),
            tooltip: 'Remove from favorites',
          ),
        ],
      ),
    );
  }
}
