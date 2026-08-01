import 'package:go_router/go_router.dart';
import 'package:umbra/apps/fitlog/screens/fitlog_home_screen.dart';
import 'package:umbra/apps/fitlog/screens/workout_session_screen.dart';

/// FitLog's routes. Spread into core/router.dart's routes: list as
/// ...fitlogRoutes, per the project's sub-app routing convention.
///
/// The muscle-group browser (MuscleGroupScreen) is intentionally NOT a
/// top-level route here — it's launched as a nested Navigator.push picker
/// flow from inside WorkoutSessionScreen's "Add exercise" action, since
/// it's a transient pick-and-return flow rather than a distinct destination.
final List<RouteBase> fitlogRoutes = [
  GoRoute(
    path: '/workouts',
    builder: (context, state) => const FitlogHomeScreen(),
  ),
  GoRoute(
    path: '/workouts/session/:workoutId',
    builder: (context, state) {
      final workoutId = state.pathParameters['workoutId']!;
      return WorkoutSessionScreen(workoutId: workoutId);
    },
  ),
];
