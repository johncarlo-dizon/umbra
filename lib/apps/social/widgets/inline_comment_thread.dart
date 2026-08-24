import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../models/comment.dart';
import '../services/social_service.dart';
import '../utils/time_ago.dart';
import '../utils/format_count.dart';
import 'social_avatar.dart';
import 'current_user_id_builder.dart';

enum _LoadState { loading, loaded, error }

/// Renders a post's comment thread inline (no navigation) — meant to be
/// dropped directly beneath a post card when the comment icon is tapped,
/// matching how Facebook expands comments in place rather than pushing
/// a new screen. Composer sits pinned at the bottom of this widget, not
/// the bottom of the whole screen.
class InlineCommentThread extends StatefulWidget {
  final String postId;
  final String postOwnerId;
  final ValueChanged<int>? onCommentCountChanged;

  const InlineCommentThread({
    super.key,
    required this.postId,
    required this.postOwnerId,
    this.onCommentCountChanged,
  });

  @override
  State<InlineCommentThread> createState() => _InlineCommentThreadState();
}

class _InlineCommentThreadState extends State<InlineCommentThread> {
  _LoadState _state = _LoadState.loading;
  List<Comment> _comments = [];
  String? _errorMessage;

  final _commentController = TextEditingController();
  final _picker = ImagePicker();
  bool _posting = false;
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
      final comments = await SocialService.fetchComments(widget.postId);
      final profiles = await SocialService.fetchProfilesByIds(
        comments.map((c) => c.userId),
      );
      final enriched = comments.map((c) {
        final profile = profiles[c.userId];
        if (profile == null) return c;
        return c.withAuthor(
          displayName: profile.displayName,
          avatarPath: profile.avatarPath,
        );
      }).toList();
      setState(() {
        _comments = enriched;
        _state = _LoadState.loaded;
      });
    } on SocialException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _state = _LoadState.error;
      });
    }
  }

  void _startReply(Comment target) => setState(() => _replyTarget = target);
  void _cancelReply() => setState(() => _replyTarget = null);

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
        notifyUserId: _replyTarget?.userId ?? widget.postOwnerId,
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
        _commentController.clear();
        _replyTarget = null;
        _pickedImage = null;
        _pickedImageBytes = null;
        _posting = false;
      });
      widget.onCommentCountChanged?.call(_comments.length);
    } on SocialException catch (e) {
      setState(() => _posting = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
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
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: colorScheme.outlineVariant, height: 20),
        _buildList(context),
        const SizedBox(height: 8),
        _buildComposer(context),
      ],
    );
  }

  Widget _buildList(BuildContext context) {
    switch (_state) {
      case _LoadState.loading:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      case _LoadState.error:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(child: Text(_errorMessage ?? 'Something went wrong.')),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        );
      case _LoadState.loaded:
        final topLevel = _comments.where((c) => !c.isReply).toList();
        final repliesByParent = <String, List<Comment>>{};
        for (final c in _comments.where((c) => c.isReply)) {
          repliesByParent.putIfAbsent(c.parentCommentId!, () => []).add(c);
        }
        if (topLevel.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No comments yet.'),
          );
        }
        return Column(
          children: [
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
                    onReply: () => _startReply(c),
                  ),
                ),
            ],
          ],
        );
    }
  }

  Widget _buildComposer(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
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
                    width: 56,
                    height: 56,
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
                  padding: const EdgeInsets.only(right: 6),
                  child: ValueListenableBuilder(
                    valueListenable: SocialService.myProfileNotifier,
                    builder: (context, profile, _) => SocialAvatar(
                      avatarPath: profile?.avatarPath,
                      userId: userId,
                      displayName: profile?.displayName ?? userId,
                      radius: 13,
                    ),
                  ),
                );
              },
            ),
            IconButton(
              onPressed: _pickImage,
              icon: const Icon(Icons.image_outlined, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            Expanded(
              child: TextField(
                controller: _commentController,
                decoration: InputDecoration(
                  hintText: 'Add a comment…',
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              onPressed: _posting ? null : _submitComment,
              icon: const Icon(Icons.send, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      ],
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
              radius: 14,
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
                            width: 140,
                            height: 140,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  width: 140,
                                  height: 140,
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
