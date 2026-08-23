class Comment {
  final String id;
  final String postId;
  final String userId;
  final String body;
  final DateTime createdAt;
  final String? parentCommentId; // null = top-level comment
  final String? imagePath;
  final int likeCount;
  final bool likedByMe;

  /// Populated separately via a batch profile fetch — null until then.
  final String? authorDisplayName;
  final String? authorAvatarPath;

  const Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.body,
    required this.createdAt,
    this.parentCommentId,
    this.imagePath,
    this.likeCount = 0,
    this.likedByMe = false,
    this.authorDisplayName,
    this.authorAvatarPath,
  });

  bool get isReply => parentCommentId != null;

  factory Comment.fromRow(
    Map<String, dynamic> row, {
    required String? myUserId,
  }) {
    final likesRaw = row['comment_likes'] as List<dynamic>? ?? const [];
    return Comment(
      id: row['id'] as String,
      postId: row['post_id'] as String,
      userId: row['user_id'] as String,
      body: row['body'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      parentCommentId: row['parent_comment_id'] as String?,
      imagePath: row['image_path'] as String?,
      likeCount: likesRaw.length,
      likedByMe: myUserId == null
          ? false
          : likesRaw.any((l) => (l as Map)['user_id'] == myUserId),
    );
  }

  Comment withAuthor({String? displayName, String? avatarPath}) {
    return copyWith(
      authorDisplayName: displayName ?? authorDisplayName,
      authorAvatarPath: avatarPath ?? authorAvatarPath,
    );
  }

  Comment copyWith({
    String? authorDisplayName,
    String? authorAvatarPath,
    int? likeCount,
    bool? likedByMe,
  }) {
    return Comment(
      id: id,
      postId: postId,
      userId: userId,
      body: body,
      createdAt: createdAt,
      parentCommentId: parentCommentId,
      imagePath: imagePath,
      likeCount: likeCount ?? this.likeCount,
      likedByMe: likedByMe ?? this.likedByMe,
      authorDisplayName: authorDisplayName ?? this.authorDisplayName,
      authorAvatarPath: authorAvatarPath ?? this.authorAvatarPath,
    );
  }
}
