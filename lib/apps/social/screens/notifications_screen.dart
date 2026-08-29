import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/app_notification.dart';
import '../services/social_service.dart';
import '../widgets/social_avatar.dart';
import '../widgets/social_top_bar.dart';
import '../utils/time_ago.dart';

enum _LoadState { loading, loaded, error }

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  _LoadState _state = _LoadState.loading;
  String? _errorMessage;
  List<AppNotification> _notifications = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _state = _LoadState.loading);
    try {
      final notifications = await SocialService.fetchNotifications();
      setState(() {
        _notifications = notifications;
        _state = _LoadState.loaded;
      });
      // Mark everything read once it's actually been shown — simpler than
      // per-item read tracking, and matches how most feeds behave (opening
      // the list is what clears the badge).
      SocialService.markAllNotificationsRead();
    } on SocialException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _state = _LoadState.error;
      });
    }
  }

  void _openNotification(AppNotification n) {
    if (n.postId != null) {
      context.push('/social/post/${n.postId}');
    } else if (n.type == NotificationType.follow) {
      context.push('/social/profile/${n.actorId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SocialTopBar(),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_state) {
      case _LoadState.loading:
        return const Center(child: CircularProgressIndicator());
      case _LoadState.error:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_errorMessage ?? 'Something went wrong.'),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        );
      case _LoadState.loaded:
        if (_notifications.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 40,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  const Text('No notifications yet.'),
                ],
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: _notifications.length,
          separatorBuilder: (_, __) => const SizedBox(height: 4),
          itemBuilder: (context, i) {
            final n = _notifications[i];
            final colorScheme = Theme.of(context).colorScheme;
            return InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _openNotification(n),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: n.read
                      ? Colors.transparent
                      : colorScheme.primaryContainer.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    SocialAvatar(
                      avatarPath: n.actorAvatarPath,
                      userId: n.actorId,
                      displayName: n.actorDisplayName ?? n.actorId,
                      radius: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: DefaultTextStyle.of(context).style,
                          children: [
                            TextSpan(
                              text:
                                  n.actorDisplayName ??
                                  n.actorId.substring(0, 8),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(text: ' ${n.message}'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeAgo(n.createdAt),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
    }
  }
}
