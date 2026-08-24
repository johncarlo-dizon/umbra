enum NotificationType {
  likePost,
  commentPost,
  replyComment,
  likeComment,
  follow,
}

NotificationType _typeFromString(String s) {
  switch (s) {
    case 'like_post':
      return NotificationType.likePost;
    case 'comment_post':
      return NotificationType.commentPost;
    case 'reply_comment':
      return NotificationType.replyComment;
    case 'like_comment':
      return NotificationType.likeComment;
    case 'follow':
      return NotificationType.follow;
    default:
      return NotificationType.likePost;
  }
}

class AppNotification {
  final String id;
  final String actorId;
  final NotificationType type;
  final String? postId;
  final String? commentId;
  final bool read;
  final DateTime createdAt;

  // Populated separately via a batch profile fetch.
  final String? actorDisplayName;
  final String? actorAvatarPath;

  const AppNotification({
    required this.id,
    required this.actorId,
    required this.type,
    required this.postId,
    required this.commentId,
    required this.read,
    required this.createdAt,
    this.actorDisplayName,
    this.actorAvatarPath,
  });

  factory AppNotification.fromRow(Map<String, dynamic> row) {
    return AppNotification(
      id: row['id'] as String,
      actorId: row['actor_id'] as String,
      type: _typeFromString(row['type'] as String),
      postId: row['post_id'] as String?,
      commentId: row['comment_id'] as String?,
      read: row['read'] as bool,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  AppNotification withActor({String? displayName, String? avatarPath}) {
    return AppNotification(
      id: id,
      actorId: actorId,
      type: type,
      postId: postId,
      commentId: commentId,
      read: read,
      createdAt: createdAt,
      actorDisplayName: displayName ?? actorDisplayName,
      actorAvatarPath: avatarPath ?? actorAvatarPath,
    );
  }

  String get message {
    switch (type) {
      case NotificationType.likePost:
        return 'liked your post';
      case NotificationType.commentPost:
        return 'commented on your post';
      case NotificationType.replyComment:
        return 'replied to your comment';
      case NotificationType.likeComment:
        return 'liked your comment';
      case NotificationType.follow:
        return 'started following you';
    }
  }
}
