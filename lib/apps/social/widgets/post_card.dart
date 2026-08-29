import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/post.dart';
import '../services/social_service.dart';
import '../utils/format_count.dart';
import '../utils/time_ago.dart';
import 'social_avatar.dart';
import 'post_image_grid.dart';
import 'inline_comment_thread.dart';
import 'current_user_id_builder.dart';

/// The actual post card — avatar, name, time, body, image grid,
/// like/comment/share row, and an inline expandable comment thread.
/// Shared between the Feed and Profile so a post looks identical
/// everywhere it appears, rather than Profile showing a stripped-down
/// thumbnail-only version.
class PostCard extends StatefulWidget {
  final Post post;
  final void Function(Post) onLike;
  final void Function(Post) onShare;

  /// Both optional — if either is null (or you're not the post's
  /// author), the three-dot menu doesn't appear at all. Editing is
  /// text-only; there's no way to add/remove images on an existing post.
  final Future<void> Function(Post post, String newBody)? onEdit;
  final Future<void> Function(Post post)? onDelete;

  /// True on the post-detail screen (reached from a notification or
  /// share link, where the whole point is the comment thread) so it
  /// doesn't require an extra tap to see what you came for.
  final bool initiallyExpandedComments;

  const PostCard({
    super.key,
    required this.post,
    required this.onLike,
    required this.onShare,
    this.onEdit,
    this.onDelete,
    this.initiallyExpandedComments = false,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late bool _commentsExpanded = widget.initiallyExpandedComments;
  late int _commentCount = widget.post.commentCount;
  bool _busy = false;

  void _toggleComments() {
    setState(() => _commentsExpanded = !_commentsExpanded);
  }

  Future<void> _showEditDialog() async {
    final controller = TextEditingController(text: widget.post.body);
    final newBody = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit post'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: null,
          minLines: 3,
          maxLength: 2000,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newBody == null || newBody.isEmpty || newBody == widget.post.body) {
      return;
    }
    if (widget.onEdit == null) return;

    setState(() => _busy = true);
    try {
      await widget.onEdit!(widget.post, newBody);
    } on SocialException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text("This can't be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || widget.onDelete == null) return;

    setState(() => _busy = true);
    try {
      await widget.onDelete!(widget.post);
      // No further setState here on success — the parent removes this
      // post from its list and rebuilds, which unmounts this card.
    } on SocialException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => context.push('/social/profile/${post.userId}'),
                    child: Row(
                      children: [
                        SocialAvatar(
                          avatarPath: post.authorAvatarPath,
                          userId: post.userId,
                          displayName: post.authorDisplayName ?? post.userId,
                          radius: 20,
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.authorDisplayName ??
                                  post.userId.substring(0, 8),
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            Text(
                              timeAgo(post.createdAt),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (widget.onEdit != null || widget.onDelete != null)
                  CurrentUserIdBuilder(
                    builder: (context, userId) {
                      if (userId == null || userId != post.userId) {
                        return const SizedBox.shrink();
                      }
                      return PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_horiz,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        onSelected: (value) {
                          if (value == 'edit') _showEditDialog();
                          if (value == 'delete') _confirmDelete();
                        },
                        itemBuilder: (context) => [
                          if (widget.onEdit != null)
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 18),
                                  SizedBox(width: 8),
                                  Text('Edit post'),
                                ],
                              ),
                            ),
                          if (widget.onDelete != null)
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: colorScheme.error,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Delete post',
                                    style: TextStyle(color: colorScheme.error),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(post.body, style: Theme.of(context).textTheme.bodyMedium),
            if (post.imagePaths.isNotEmpty) ...[
              const SizedBox(height: 10),
              PostImageGrid(imagePaths: post.imagePaths),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    post.likedByMe ? Icons.favorite : Icons.favorite_border,
                    color: post.likedByMe
                        ? colorScheme.error
                        : colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () => widget.onLike(post),
                ),
                Text(formatCount(post.likeCount)),
                const SizedBox(width: 16),
                InkWell(
                  onTap: _toggleComments,
                  child: Row(
                    children: [
                      Icon(
                        _commentsExpanded
                            ? Icons.mode_comment
                            : Icons.mode_comment_outlined,
                        size: 20,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(formatCount(_commentCount)),
                    ],
                  ),
                ),
                const Spacer(),
                if (_busy)
                  const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    icon: Icon(
                      Icons.share_outlined,
                      size: 20,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    onPressed: () => widget.onShare(post),
                  ),
              ],
            ),
            if (_commentsExpanded)
              InlineCommentThread(
                postId: post.id,
                postOwnerId: post.userId,
                onCommentCountChanged: (count) {
                  setState(() => _commentCount = count);
                },
              ),
          ],
        ),
      ),
    );
  }
}
