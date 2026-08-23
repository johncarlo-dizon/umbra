import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/shell_nav_state.dart';
import '../theme/friendbook_colors.dart';

/// Shown in place of a sub-app's real content when the user isn't signed
/// in — matches the Notes sub-app's convention: a plain AppBar (not any
/// custom themed top bar), centered icon + message, and a "Sign In"
/// button that sends them to Umbra's own sign-in via the shared
/// ShellNavState pattern (lands them on the Profile tab).
class SignInRequiredScreen extends StatelessWidget {
  final String appName;
  final String message;
  final IconData icon;

  const SignInRequiredScreen({
    super.key,
    required this.appName,
    required this.message,
    this.icon = Icons.groups_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(appName), centerTitle: true),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: kFriendBookBlue),
              const SizedBox(height: 16),
              Text(
                'Sign in to use $appName',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  ShellNavState.requestedTabIndex.value =
                      ShellNavState.profileTab;
                  context.go('/');
                },
                style: FilledButton.styleFrom(
                  backgroundColor: kFriendBookBlue,
                  foregroundColor: kFriendBookOnBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 12,
                  ),
                ),
                child: const Text('Sign In'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
