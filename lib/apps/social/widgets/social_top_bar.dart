import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/profile.dart';
import '../services/social_service.dart';
import '../theme/friendbook_colors.dart';
import 'social_avatar.dart';
import 'current_user_id_builder.dart';
import 'notification_bell.dart';

/// The top bar for Social's primary screens.
///
/// - Feed: logo + a separate back arrow (leaves Social entirely, back to
///   Umbra's Home) + search field + notification bell + your avatar.
/// - Profile / Comment Thread: logo only (tapping it returns to the
///   Feed — same as tapping Facebook's own logo) + notification bell +
///   your avatar. No back arrow, no search field — those only make
///   sense on the Feed.
///
/// Search opens a dedicated screen that matches on display name only —
/// post search isn't built yet.
class SocialTopBar extends StatelessWidget implements PreferredSizeWidget {
  /// Extra icon buttons inserted between the search field and the
  /// name/avatar. (Nothing uses this right now — the profile edit
  /// action lives inline on the profile page instead of up here.)
  final List<Widget> extraActions;

  /// Feed-only: shows a back arrow (leaves Social, back to Umbra Home)
  /// next to the logo.
  final bool showBackButton;

  /// Feed-only: shows the search field. Off on Profile/Comment Thread.
  final bool showSearchBar;

  const SocialTopBar({
    super.key,
    this.extraActions = const [],
    this.showBackButton = false,
    this.showSearchBar = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kFriendBookBlue,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: kToolbarHeight,
          child: Row(
            children: [
              if (showBackButton)
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: kFriendBookOnBlue),
                  onPressed: () => context.go('/'),
                ),
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => context.go('/social'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.asset(
                      'assets/icon/social.png',
                      width: 28,
                      height: 28,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.forum,
                        color: kFriendBookOnBlue,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
              if (showSearchBar) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => context.push('/social/search'),
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: kFriendBookOnBlue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.search,
                            size: 18,
                            color: kFriendBookOnBlue,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Search FriendBook',
                            style: TextStyle(
                              color: Color(0xDDFFFFFF),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ] else
                const Spacer(),
              ...extraActions,
              CurrentUserIdBuilder(
                builder: (context, userId) {
                  if (userId == null) return const SizedBox.shrink();
                  return const NotificationBell();
                },
              ),
              CurrentUserIdBuilder(
                builder: (context, userId) {
                  if (userId == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => context.push('/social/profile/$userId'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: ValueListenableBuilder<Profile?>(
                          valueListenable: SocialService.myProfileNotifier,
                          builder: (context, profile, _) => SocialAvatar(
                            avatarPath: profile?.avatarPath,
                            userId: userId,
                            displayName: profile?.displayName ?? userId,
                            radius: 16,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
