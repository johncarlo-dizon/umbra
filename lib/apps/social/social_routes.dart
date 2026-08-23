import 'package:go_router/go_router.dart';
import 'screens/social_feed_screen.dart';
import 'screens/post_detail_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/create_post_screen.dart';

/// Spread this into core/router.dart's routes list: `...socialRoutes`.
/// No route-level auth guard here — matches the Notes sub-app's
/// convention: the entry screen itself checks sign-in status and shows
/// an in-place "Sign in to use X" prompt instead of the real content,
/// rather than redirecting away via the router.
final List<RouteBase> socialRoutes = [
  GoRoute(
    path: '/social',
    builder: (context, state) => const SocialFeedScreen(),
  ),
  GoRoute(
    path: '/social/compose',
    builder: (context, state) => const CreatePostScreen(),
  ),
  GoRoute(
    path: '/social/post/:id',
    builder: (context, state) =>
        PostDetailScreen(postId: state.pathParameters['id']!),
  ),
  // Registered before /social/profile/:userId so the literal "edit"
  // segment isn't swallowed as a :userId value.
  GoRoute(
    path: '/social/profile/edit',
    builder: (context, state) => const EditProfileScreen(),
  ),
  GoRoute(
    path: '/social/profile/:userId',
    builder: (context, state) =>
        ProfileScreen(userId: state.pathParameters['userId']!),
  ),
];
