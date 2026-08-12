import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme.dart';
import '../../../core/supabase_client.dart';
import '../models/quote.dart';
import '../quoteapp_theme.dart';
import '../services/quoteapp_service.dart';
import '../services/quoteapp_favorites_service.dart';

enum _LoadState { loading, loaded, error }

class QuoteAppHomeScreen extends StatefulWidget {
  const QuoteAppHomeScreen({super.key});

  @override
  State<QuoteAppHomeScreen> createState() => _QuoteAppHomeScreenState();
}

class _QuoteAppHomeScreenState extends State<QuoteAppHomeScreen> {
  _LoadState _state = _LoadState.loading;
  Quote? _quote;
  bool _isFavorited = false;
  bool _favoriteBusy = false;
  bool _usingCache = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _state = _LoadState.loading);

    try {
      final quote = await QuoteAppService.fetchRandom();
      final favorited = await QuoteAppFavoritesService.isFavorited(quote.id);

      if (!mounted) return;
      setState(() {
        _quote = quote;
        _isFavorited = favorited;
        _usingCache = false;
        _state = _LoadState.loaded;
      });
    } catch (e) {
      // Resilience pattern: fall back to the last-known-good quote
      // instead of a bare error screen, if one is available.
      final cached = QuoteAppService.cachedQuote;
      if (!mounted) return;

      if (cached != null) {
        setState(() {
          _quote = cached;
          _isFavorited = false;
          _usingCache = true;
          _state = _LoadState.loaded;
        });
      } else {
        setState(() {
          _errorMessage = e.toString();
          _state = _LoadState.error;
        });
      }
    }
  }

  Future<void> _toggleFavorite() async {
    final quote = _quote;
    if (quote == null || _usingCache) return;

    if (!SupabaseService.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to save favorite quotes')),
      );
      return;
    }

    setState(() => _favoriteBusy = true);
    try {
      if (_isFavorited) {
        await QuoteAppFavoritesService.removeFavorite(quote.id);
      } else {
        await QuoteAppFavoritesService.addFavorite(quote);
      }
      if (!mounted) return;
      setState(() => _isFavorited = !_isFavorited);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update favorite')),
      );
    } finally {
      if (mounted) setState(() => _favoriteBusy = false);
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
        title: const Text('Quotely'),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_rounded),
            tooltip: 'Favorites',
            onPressed: () => context.push('/quotes/favorites'),
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _body(scheme),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(ColorScheme scheme) {
    switch (_state) {
      case _LoadState.loading:
        return const Center(child: CircularProgressIndicator());
      case _LoadState.error:
        return _errorState(scheme);
      case _LoadState.loaded:
        return _loadedState(scheme);
    }
  }

  Widget _errorState(ColorScheme scheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 40,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            _errorMessage ?? 'Something went wrong.',
            textAlign: TextAlign.center,
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

  Widget _loadedState(ColorScheme scheme) {
    final quote = _quote!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_usingCache) _offlineBanner(scheme),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.navy.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.format_quote_rounded,
                color: quoteAppAccent,
                size: 32,
              ),
              const SizedBox(height: 12),
              Text(
                quote.text,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '— ${quote.author}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (quote.tags.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: quote.tags.map(_tagChip).toList(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: quoteAppAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('New Quote'),
              ),
            ),
            const SizedBox(width: 12),
            IconButton.filledTonal(
              onPressed: _favoriteBusy ? null : _toggleFavorite,
              icon: _favoriteBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _isFavorited
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: _isFavorited ? Colors.red : null,
                    ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _offlineBanner(ColorScheme scheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.wifi_off_rounded,
            size: 16,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Offline — showing last saved quote',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tagChip(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: quoteAppAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        tag,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: quoteAppAccent,
        ),
      ),
    );
  }
}
