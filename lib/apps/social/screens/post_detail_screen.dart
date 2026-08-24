import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../models/comment.dart';
import '../models/post.dart';
import '../services/social_service.dart';
import '../widgets/social_avatar.dart';
import '../widgets/social_top_bar.dart';
import '../widgets/current_user_id_builder.dart';
import '../utils/time_ago.dart';
import '../utils/format_count.dart';

enum _LoadState { loading, loaded, error }

class PostDetailScreen extends StatefulWidget {
  final String postId;
  const PostDetailScreen({super.key, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  _LoadState _state = _LoadState.loading;
  Post? _post;
  List<Comment> _comments = [];
  String? _errorMessage;

  final _commentController = TextEditingController();
  final _picker = ImagePicker();
  bool _posting = false;

  // Reply target — when set, the composer is posting a reply to this
  // top-level comment instead of a fresh top-level comment.
  Comment? _replyTarget;

  XFile? _pickedImage;
  Uint8List? _pickedImageBytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _state = _LoadState.loading);
    try {
      final post = await SocialService.fetchPost(widget.postId);
      final comments = await SocialService.fetchComments(widget.postId);
      final profiles = await SocialService.fetchProfilesByIds([
        post.userId,
        ...comments.map((c) => c.userId),
      ]);

      final postProfile = profiles[post.userId];
      final enrichedPost = postProfile == null
          ? post
          : post.copyWith(
              authorDisplayName: postProfile.displayName,
              authorAvatarPath: postProfile.avatarPath,
            );

      final enrichedComments = comments.map((c) {
        final profile = profiles[c.userId];
        if (profile == null) return c;
        return c.withAuthor(
          displayName: profile.displayName,
          avatarPath: profile.avatarPath,
        );
      }).toList();

      setState(() {
        _post = enrichedPost;
        _comments = enrichedComments;
        _state = _LoadState.loaded;
      });
    } on SocialException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _state = _LoadState.error;
      });
    }
  }

  void _startReply(Comment target) {
    setState(() => _replyTarget = target);
  }

  void _cancelReply() {
    setState(() => _replyTarget = null);
  }

  Future<void> _pickImage() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _pickedImage = file;
        _pickedImageBytes = bytes;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open image picker. ($e)')),
        );
      }
    }
  }

  void _removeImage() {
    setState(() {
      _pickedImage = null;
      _pickedImageBytes = null;
    });
  }

  String _extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    if (dot == -1 || dot == path.length - 1) return 'jpg';
    return path.substring(dot + 1).toLowerCase();
  }

  Future<void> _submitComment() async {
    final body = _commentController.text.trim();
    if ((body.isEmpty && _pickedImageBytes == null) || _posting) return;
    setState(() => _posting = true);
    try {
      String? imagePath;
      if (_pickedImageBytes != null && _pickedImage != null) {
        imagePath = await SocialService.uploadImage(
          _pickedImageBytes!,
          _extensionOf(_pickedImage!.path),
          kind: 'comment',
        );
      }

      var comment = await SocialService.addComment(
        widget.postId,
        body.isEmpty ? ' ' : body,
        parentCommentId: _replyTarget?.id,
        imagePath: imagePath,
        notifyUserId: _replyTarget?.userId ?? _post?.userId,
      );

      final profiles = await SocialService.fetchProfilesByIds([comment.userId]);
      final profile = profiles[comment.userId];
      if (profile != null) {
        comment = comment.withAuthor(
          displayName: profile.displayName,
          avatarPath: profile.avatarPath,
        );
      }

      setState(() {
        _comments = [..._comments, comment];
        if (_post != null) {
          _post = _post!.copyWith(commentCount: _post!.commentCount + 1);
        }
        _commentController.clear();
        _replyTarget = null;
        _pickedImage = null;
        _pickedImageBytes = null;
        _posting = false;
      });
    } on SocialException catch (e) {
      setState(() => _posting = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _toggleLike() async {
    final post = _post;
    if (post == null) return;
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

  Future<void> _toggleCommentLike(Comment comment) async {
    final wasLiked = comment.likedByMe;
    setState(() {
      _comments = _comments
          .map(
            (c) => c.id == comment.id
                ? c.copyWith(
                    likedByMe: !wasLiked,
                    likeCount: wasLiked ? c.likeCount - 1 : c.likeCount + 1,
                  )
                : c,
          )
          .toList();
    });
    try {
      await SocialService.toggleCommentLike(
        comment.id,
        wasLiked,
        commentOwnerId: comment.userId,
      );
    } on SocialException {
      setState(() {
        _comments = _comments
            .map((c) => c.id == comment.id ? comment : c)
            .toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SocialTopBar(),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            children: [
              Expanded(child: _buildBody(context)),
              if (_state == _LoadState.loaded) _buildComposer(context),
            ],
          ),
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
        final post = _post!;
        final topLevel = _comments.where((c) => !c.isReply).toList();
        final repliesByParent = <String, List<Comment>>{};
        for (final c in _comments.where((c) => c.isReply)) {
          repliesByParent.putIfAbsent(c.parentCommentId!, () => []).add(c);
        }

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _CompactPostExcerpt(post: post, onTapLike: _toggleLike),
            const SizedBox(height: 4),
            Divider(color: Theme.of(context).colorScheme.outlineVariant),
            if (topLevel.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: Text('No comments yet.')),
              )
            else
              for (final c in topLevel) ...[
                _CommentBubble(
                  comment: c,
                  onLike: () => _toggleCommentLike(c),
                  onReply: () => _startReply(c),
                ),
                for (final reply in repliesByParent[c.id] ?? [])
                  Padding(
                    padding: const EdgeInsets.only(left: 36),
                    child: _CommentBubble(
                      comment: reply,
                      onLike: () => _toggleCommentLike(reply),
                      onReply: () =>
                          _startReply(c), // reply-to-reply -> same parent
                    ),
                  ),
              ],
          ],
        );
    }
  }

  Widget _buildComposer(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_replyTarget != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Text(
                      'Replying to ${_replyTarget!.authorDisplayName ?? 'comment'}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: _cancelReply,
                      child: Icon(
                        Icons.close,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            if (_pickedImageBytes != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Stack(
                  alignment: Alignment.topRight,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        _pickedImageBytes!,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                      ),
                    ),
                    IconButton.filled(
                      onPressed: _removeImage,
                      icon: const Icon(Icons.close, size: 12),
                      constraints: const BoxConstraints(
                        minWidth: 22,
                        minHeight: 22,
                      ),
                      padding: EdgeInsets.zero,
                      style: IconButton.styleFrom(
                        backgroundColor: colorScheme.surface.withValues(
                          alpha: 0.85,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                CurrentUserIdBuilder(
                  builder: (context, userId) {
                    if (userId == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ValueListenableBuilder(
                        valueListenable: SocialService.myProfileNotifier,
                        builder: (context, profile, _) => SocialAvatar(
                          avatarPath: profile?.avatarPath,
                          userId: userId,
                          displayName: profile?.displayName ?? userId,
                          radius: 14,
                        ),
                      ),
                    );
                  },
                ),
                IconButton(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.image_outlined),
                ),
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Add a comment…',
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _posting ? null : _submitComment,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact version of the post shown at the top of the thread — avatar,
/// name, body text, and a like control, but no image grid or share row
/// (that full presentation lives on the feed/profile cards).
class _CompactPostExcerpt extends StatelessWidget {
  final Post post;
  final VoidCallback onTapLike;

  const _CompactPostExcerpt({required this.post, required this.onTapLike});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => context.push('/social/profile/${post.userId}'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SocialAvatar(
            avatarPath: post.authorAvatarPath,
            userId: post.userId,
            displayName: post.authorDisplayName ?? post.userId,
            radius: 16,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.authorDisplayName ?? post.userId.substring(0, 8),
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(post.body, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          InkWell(
            onTap: onTapLike,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                post.likedByMe ? Icons.favorite : Icons.favorite_border,
                size: 18,
                color: post.likedByMe
                    ? colorScheme.error
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentBubble extends StatelessWidget {
  final Comment comment;
  final VoidCallback onLike;
  final VoidCallback onReply;

  const _CommentBubble({
    required this.comment,
    required this.onLike,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => context.push('/social/profile/${comment.userId}'),
            child: SocialAvatar(
              avatarPath: comment.authorAvatarPath,
              userId: comment.userId,
              displayName: comment.authorDisplayName ?? comment.userId,
              radius: 16,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        comment.authorDisplayName ??
                            comment.userId.substring(0, 8),
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (comment.body.trim().isNotEmpty) Text(comment.body),
                      if (comment.imagePath != null) ...[
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            SocialService.imageUrl(comment.imagePath!),
                            width: 160,
                            height: 160,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  width: 160,
                                  height: 160,
                                  color: colorScheme.surface,
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.broken_image_outlined,
                                  ),
                                ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 14, top: 3),
                  child: Row(
                    children: [
                      Text(
                        timeAgo(comment.createdAt),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: onLike,
                        child: Row(
                          children: [
                            Icon(
                              comment.likedByMe
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 14,
                              color: comment.likedByMe
                                  ? colorScheme.error
                                  : colorScheme.onSurfaceVariant,
                            ),
                            if (comment.likeCount > 0) ...[
                              const SizedBox(width: 3),
                              Text(
                                formatCount(comment.likeCount),
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (!comment.isReply) ...[
                        const SizedBox(width: 12),
                        InkWell(
                          onTap: onReply,
                          child: Text(
                            'Reply',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
