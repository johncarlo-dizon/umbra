class Post {
  final String id;
  final String userId;
  final String body;
  final List<String>
  imagePaths; // storage object paths, not full URLs, in display order
  final DateTime createdAt;
  final int likeCount;
  final int commentCount;
  final bool likedByMe;

  /// Populated separately via a batch profile fetch — null until then.
  final String? authorDisplayName;
  final String? authorAvatarPath;

  const Post({
    required this.id,
    required this.userId,
    required this.body,
    required this.imagePaths,
    required this.createdAt,
    required this.likeCount,
    required this.commentCount,
    required this.likedByMe,
    this.authorDisplayName,
    this.authorAvatarPath,
  });

  factory Post.fromRow(Map<String, dynamic> row, {required String? myUserId}) {
    final likesRaw = row['likes'] as List<dynamic>? ?? const [];
    final commentsRaw = row['comments'] as List<dynamic>? ?? const [];
    final imagesRaw = row['post_images'] as List<dynamic>? ?? const [];
    final sortedImages = List<Map<String, dynamic>>.from(imagesRaw)
      ..sort(
        (a, b) => ((a['position'] as int?) ?? 0).compareTo(
          (b['position'] as int?) ?? 0,
        ),
      );
    return Post(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      body: row['body'] as String,
      imagePaths: sortedImages.map((r) => r['image_path'] as String).toList(),
      createdAt: DateTime.parse(row['created_at'] as String),
      likeCount: likesRaw.length,
      commentCount: commentsRaw.length,
      likedByMe: myUserId == null
          ? false
          : likesRaw.any((l) => (l as Map)['user_id'] == myUserId),
    );
  }

  Post copyWith({
    int? likeCount,
    bool? likedByMe,
    int? commentCount,
    String? authorDisplayName,
    String? authorAvatarPath,
  }) {
    return Post(
      id: id,
      userId: userId,
      body: body,
      imagePaths: imagePaths,
      createdAt: createdAt,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      likedByMe: likedByMe ?? this.likedByMe,
      authorDisplayName: authorDisplayName ?? this.authorDisplayName,
      authorAvatarPath: authorAvatarPath ?? this.authorAvatarPath,
    );
  }

  /// Used right after creating a post, before a fresh fetch would embed
  /// the post_images rows — stamps the just-uploaded paths in locally.
  Post copyWithImages(List<String> imagePaths) {
    return Post(
      id: id,
      userId: userId,
      body: body,
      imagePaths: imagePaths,
      createdAt: createdAt,
      likeCount: likeCount,
      commentCount: commentCount,
      likedByMe: likedByMe,
      authorDisplayName: authorDisplayName,
      authorAvatarPath: authorAvatarPath,
    );
  }
}
