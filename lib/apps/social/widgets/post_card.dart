import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/post.dart';
import '../utils/format_count.dart';
import '../utils/time_ago.dart';
import 'social_avatar.dart';
import 'post_image_grid.dart';
import 'inline_comment_thread.dart';

/// The actual post card — avatar, name, time, body, image grid,
/// like/comment/share row, and an inline expandable comment thread.
/// Shared between the Feed and Profile so a post looks identical
/// everywhere it appears, rather than Profile showing a stripped-down
/// thumbnail-only version.
class PostCard extends StatefulWidget {
  final Post post;
  final void Function(Post) onLike;
  final void Function(Post) onShare;

  const PostCard({
    super.key,
    required this.post,
    required this.onLike,
    required this.onShare,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _commentsExpanded = false;
  late int _commentCount = widget.post.commentCount;

  void _toggleComments() {
    setState(() => _commentsExpanded = !_commentsExpanded);
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
            InkWell(
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
                        post.authorDisplayName ?? post.userId.substring(0, 8),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        timeAgo(post.createdAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
