import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/social_service.dart';
import '../theme/friendbook_colors.dart';

/// Bell icon with a red unread-count badge. Fetches the count once on
/// mount and again whenever you return from the notifications screen —
/// no realtime subscription, so it won't update live if a notification
/// arrives while you're sitting on a screen that shows the bell.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final count = await SocialService.unreadNotificationCount();
    if (mounted) setState(() => _unreadCount = count);
  }

  Future<void> _open() async {
    await context.push('/social/notifications');
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(
            Icons.notifications_outlined,
            color: kFriendBookOnBlue,
          ),
          onPressed: _open,
        ),
        if (_unreadCount > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 16),
              child: Text(
                _unreadCount > 99 ? '99+' : '$_unreadCount',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
