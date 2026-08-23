import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/profile.dart';
import '../services/social_service.dart';
import '../theme/friendbook_colors.dart';
import 'social_avatar.dart';
import 'current_user_id_builder.dart';

/// The card that sits above the feed: an avatar + "What's on your mind?"
/// row, then a single "Add Photos" quick action below. Only one photo
/// action, not a Photo/Video vs Photo Album split — this app doesn't
/// support video, and both would have opened the identical composer
/// anyway, so a second option added nothing but confusion.
class ComposerEntryCard extends StatelessWidget {
  final VoidCallback onTap;

  const ComposerEntryCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
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
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  CurrentUserIdBuilder(
                    builder: (context, userId) {
                      if (userId == null) return const SizedBox.shrink();
                      return InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => context.push('/social/profile/$userId'),
                        child: ValueListenableBuilder<Profile?>(
                          valueListenable: SocialService.myProfileNotifier,
                          builder: (context, profile, _) => SocialAvatar(
                            avatarPath: profile?.avatarPath,
                            userId: userId,
                            displayName: profile?.displayName ?? userId,
                            radius: 18,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: onTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "What's on your mind?",
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Opens the same composer as the text field — this
                  // isn't a real submit action at this stage (there's no
                  // text yet), just another entry point into composing.
                  FilledButton(
                    onPressed: onTap,
                    style: FilledButton.styleFrom(
                      backgroundColor: kFriendBookBlue,
                      foregroundColor: kFriendBookOnBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                    ),
                    child: const Text('Post'),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colorScheme.outlineVariant),
            InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.photo_library_outlined,
                      size: 18,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Add Photos',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
