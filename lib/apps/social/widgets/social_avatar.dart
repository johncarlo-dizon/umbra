import 'package:flutter/material.dart';
import '../services/social_service.dart';
import '../utils/initials.dart';

/// Shows a user's uploaded avatar photo, or a colored initials badge
/// (e.g. "JD" on blue) if they have none / it fails to load.
class SocialAvatar extends StatelessWidget {
  final String? avatarPath;
  final String userId;
  final String displayName;
  final double radius;

  const SocialAvatar({
    super.key,
    required this.avatarPath,
    required this.userId,
    required this.displayName,
    this.radius = 20,
  });

  Widget _initialsBadge() {
    return CircleAvatar(
      radius: radius,
      backgroundColor: avatarColorFor(userId),
      child: Text(
        initialsFor(displayName),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.75,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final path = avatarPath;
    if (path == null) return _initialsBadge();
    return ClipOval(
      child: Image.network(
        SocialService.imageUrl(path),
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _initialsBadge(),
      ),
    );
  }
}
