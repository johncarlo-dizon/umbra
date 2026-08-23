class Profile {
  final String userId;
  final String displayName;
  final String? avatarPath;
  final String? bio;

  const Profile({
    required this.userId,
    required this.displayName,
    required this.avatarPath,
    this.bio,
  });

  factory Profile.fromRow(Map<String, dynamic> row) {
    return Profile(
      userId: row['user_id'] as String,
      displayName: row['display_name'] as String,
      avatarPath: row['avatar_path'] as String?,
      bio: row['bio'] as String?,
    );
  }

  /// Used when no profile row exists yet for a user.
  factory Profile.fallback(String userId) {
    return Profile(
      userId: userId,
      displayName: userId.length >= 8 ? userId.substring(0, 8) : userId,
      avatarPath: null,
      bio: null,
    );
  }
}
