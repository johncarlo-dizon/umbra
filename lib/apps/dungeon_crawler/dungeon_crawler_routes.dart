import 'package:go_router/go_router.dart';

import 'screens/dungeon_crawler_screen.dart';

/// Spread into `core/router.dart`'s `routes:` list as `...dungeonCrawlerRoutes`,
/// alongside `...mangahubRoutes`, `...fitlogRoutes`, etc.
final List<RouteBase> dungeonCrawlerRoutes = [
  GoRoute(
    path: '/dungeon-crawler',
    builder: (context, state) => const DungeonCrawlerScreen(),
  ),
];
