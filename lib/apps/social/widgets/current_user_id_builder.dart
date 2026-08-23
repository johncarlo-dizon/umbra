import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase_client.dart';

/// Wraps [builder] and re-invokes it every time Supabase's auth state
/// changes (sign-in, sign-out, token refresh, and — importantly on web —
/// the initial async session restore). Anything that needs the current
/// user's id should read it through here rather than reading
/// SupabaseService.currentSession directly in build(), since a plain
/// synchronous read can run before web's session restore finishes and
/// then never update.
class CurrentUserIdBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, String? userId) builder;

  const CurrentUserIdBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: SupabaseService.authStateChanges,
      builder: (context, snapshot) {
        final userId = SupabaseService.currentSession?.user.id;
        return builder(context, userId);
      },
    );
  }
}
