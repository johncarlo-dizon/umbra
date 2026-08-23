class ProfileStats {
  final String userId;
  final int followerCount;
  final int followingCount;
  final int postCount;
  final bool followedByMe;

  const ProfileStats({
    required this.userId,
    required this.followerCount,
    required this.followingCount,
    required this.postCount,
    required this.followedByMe,
  });
}
