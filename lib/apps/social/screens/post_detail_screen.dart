import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/post.dart';
import '../services/social_service.dart';
import '../widgets/social_top_bar.dart';
import '../widgets/post_card.dart';

enum _LoadState { loading, loaded, error }

/// Shows a single post exactly as it looks in the Feed — same PostCard,
/// same like/comment/share row — but with its comment thread pre-expanded
/// since that's the whole reason to land here (from a notification, a
/// shared link, or tapping into a post from a profile grid).
class PostDetailScreen extends StatefulWidget {
  final String postId;
  const PostDetailScreen({super.key, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  _LoadState _state = _LoadState.loading;
  Post? _post;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _state = _LoadState.loading);
    try {
      final post = await SocialService.fetchPost(widget.postId);
      final profiles = await SocialService.fetchProfilesByIds([post.userId]);
      final profile = profiles[post.userId];
      setState(() {
        _post = profile == null
            ? post
            : post.copyWith(
                authorDisplayName: profile.displayName,
                authorAvatarPath: profile.avatarPath,
              );
        _state = _LoadState.loaded;
      });
    } on SocialException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _state = _LoadState.error;
      });
    }
  }

  Future<void> _toggleLike(Post post) async {
    final wasLiked = post.likedByMe;
    setState(() {
      _post = post.copyWith(
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
      setState(() => _post = post);
    }
  }

  void _sharePost(Post post) {
    Clipboard.setData(ClipboardData(text: '/social/post/${post.id}'));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Link copied')));
  }

  Future<void> _editPost(Post post, String newBody) async {
    final updated = await SocialService.updatePost(post.id, body: newBody);
    setState(() {
      _post = updated.copyWith(
        authorDisplayName: post.authorDisplayName,
        authorAvatarPath: post.authorAvatarPath,
      );
    });
  }

  Future<void> _deletePost(Post post) async {
    await SocialService.deletePost(post.id, imagePaths: post.imagePaths);
    // Nothing left to show on this screen once the post is gone.
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SocialTopBar(),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_state) {
      case _LoadState.loading:
        return const Center(child: CircularProgressIndicator());
      case _LoadState.error:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_errorMessage ?? 'Something went wrong.'),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        );
      case _LoadState.loaded:
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            PostCard(
              post: _post!,
              onLike: _toggleLike,
              onShare: _sharePost,
              onEdit: _editPost,
              onDelete: _deletePost,
              initiallyExpandedComments: true,
            ),
          ],
        );
    }
  }
}
