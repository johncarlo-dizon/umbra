import 'package:go_router/go_router.dart';
import 'screens/quoteapp_home_screen.dart';
import 'screens/quoteapp_favorites_screen.dart';

final List<RouteBase> quoteAppRoutes = [
  GoRoute(
    path: '/quotes',
    builder: (context, state) => const QuoteAppHomeScreen(),
  ),
  GoRoute(
    path: '/quotes/favorites',
    builder: (context, state) => const QuoteAppFavoritesScreen(),
  ),
];
