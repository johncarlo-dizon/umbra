import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/supabase_client.dart';
import '../models/profile.dart';
import '../services/social_service.dart';
import 'social_avatar.dart';

/// Appears top-right in every Social screen's AppBar, mirroring the
/// mockups: title on the left, your own avatar on the right, tappable
/// to jump straight to your profile. Reads SocialService.myProfileNotifier
/// so every header stays in sync without each screen re-fetching it.
class CurrentUserAvatarButton extends StatelessWidget {
  const CurrentUserAvatarButton({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = SupabaseService.currentSession?.user.id;
    if (userId == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Center(
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => context.push('/social/profile/$userId'),
          child: ValueListenableBuilder<Profile?>(
            valueListenable: SocialService.myProfileNotifier,
            builder: (context, profile, _) {
              return SocialAvatar(
                avatarPath: profile?.avatarPath,
                userId: userId,
                displayName: profile?.displayName ?? userId,
                radius: 16,
              );
            },
          ),
        ),
      ),
    );
  }
}
