import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../models/post.dart';
import '../services/social_service.dart';
import '../widgets/social_top_bar.dart';
import '../widgets/composer_entry_card.dart';
import '../widgets/sign_in_required_screen.dart';
import '../widgets/post_card.dart';
import '../../../core/supabase_client.dart';
import 'create_post_screen.dart';

enum _FeedState { loading, loaded, error, offlineCached, empty }

class SocialFeedScreen extends StatefulWidget {
  const SocialFeedScreen({super.key});

  @override
  State<SocialFeedScreen> createState() => _SocialFeedScreenState();
}

class _SocialFeedScreenState extends State<SocialFeedScreen> {
  _FeedState _state = _FeedState.loading;
  List<Post> _posts = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    SocialService.ensureProfile(); // fire-and-forget, non-fatal if it fails
    _load();
  }

  Future<void> _load() async {
    setState(() => _state = _FeedState.loading);
    try {
      final posts = await SocialService.fetchFeed();
      final enriched = await _withAuthors(posts);
      setState(() {
        _posts = enriched;
        _state = enriched.isEmpty ? _FeedState.empty : _FeedState.loaded;
      });
    } on SocialException catch (e) {
      final cached = SocialService.cachedFeed;
      if (cached != null && cached.isNotEmpty) {
        setState(() {
          _posts = cached;
          _state = _FeedState.offlineCached;
        });
      } else {
        setState(() {
          _errorMessage = e.message;
          _state = _FeedState.error;
        });
      }
    }
  }

  Future<List<Post>> _withAuthors(List<Post> posts) async {
    final profiles = await SocialService.fetchProfilesByIds(
      posts.map((p) => p.userId),
    );
    return posts.map((p) {
      final profile = profiles[p.userId];
      if (profile == null) return p;
      return p.copyWith(
        authorDisplayName: profile.displayName,
        authorAvatarPath: profile.avatarPath,
      );
    }).toList();
  }

  Future<void> _toggleLike(Post post) async {
    final wasLiked = post.likedByMe;
    setState(() {
      final idx = _posts.indexWhere((p) => p.id == post.id);
      _posts[idx] = post.copyWith(
        likedByMe: !wasLiked,
        likeCount: wasLiked ? post.likeCount - 1 : post.likeCount + 1,
      );
    });
    try {
      await SocialService.toggleLike(
        post.id,
        wasLiked,
        postOwnerId: post.userId,
      );
    } on SocialException {
      setState(() {
        final idx = _posts.indexWhere((p) => p.id == post.id);
        _posts[idx] = post;
      });
    }
  }

  Future<void> _openComposer() async {
    final created = await context.push<bool>('/social/compose');
    if (created == true) _load();
  }

  void _sharePost(Post post) {
    // No dedicated deep-link/share service yet — copies a path reference
    // to the clipboard as a lightweight stand-in for a real share sheet.
    Clipboard.setData(ClipboardData(text: '/social/post/${post.id}'));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Link copied')));
  }

  Future<void> _editPost(Post post, String newBody) async {
    final updated = await SocialService.updatePost(post.id, body: newBody);
    setState(() {
      final idx = _posts.indexWhere((p) => p.id == post.id);
      if (idx != -1) {
        // updatePost's query doesn't join profile info — carry it over
        // from the post we already had, same as elsewhere in this file.
        _posts[idx] = updated.copyWith(
          authorDisplayName: post.authorDisplayName,
          authorAvatarPath: post.authorAvatarPath,
        );
      }
    });
  }

  Future<void> _deletePost(Post post) async {
    await SocialService.deletePost(post.id, imagePaths: post.imagePaths);
    setState(() {
      _posts.removeWhere((p) => p.id == post.id);
      if (_posts.isEmpty) _state = _FeedState.empty;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!SupabaseService.isLoggedIn) {
      return const SignInRequiredScreen(
        appName: 'FriendBook',
        message: 'Connect with friends and share what\'s on your mind.',
        icon: Icons.dynamic_feed,
      );
    }

    return Scaffold(
      appBar: const SocialTopBar(showBackButton: true, showSearchBar: true),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            children: [
              ComposerEntryCard(onTap: _openComposer),
              Expanded(child: _buildBody(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_state) {
      case _FeedState.loading:
        return const Center(child: CircularProgressIndicator());

      case _FeedState.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 40,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 12),
                Text(
                  _errorMessage ?? 'Something went wrong.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          ),
        );

      case _FeedState.empty:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.dynamic_feed,
                  size: 40,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 12),
                const Text('No posts yet. Be the first to share something.'),
              ],
            ),
          ),
        );

      case _FeedState.loaded:
      case _FeedState.offlineCached:
        return RefreshIndicator(
          onRefresh: _load,
          child: Column(
            children: [
              if (_state == _FeedState.offlineCached)
                Container(
                  width: double.infinity,
                  color: Theme.of(context).colorScheme.errorContainer,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Offline — showing saved posts',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _posts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => PostCard(
                    post: _posts[i],
                    onLike: _toggleLike,
                    onShare: _sharePost,
                    onEdit: _editPost,
                    onDelete: _deletePost,
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }
}
