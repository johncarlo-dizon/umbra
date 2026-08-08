import 'package:go_router/go_router.dart';

import 'screens/dungeon_crawler_home_screen.dart';
import 'screens/dungeon_crawler_screen.dart';

final List<RouteBase> dungeonCrawlerRoutes = [
  GoRoute(
    path: '/dungeon-crawler',
    builder: (context, state) => const DungeonCrawlerHomeScreen(),
  ),
  GoRoute(
    path: '/dungeon-crawler/play',
    builder: (context, state) => const DungeonCrawlerScreen(),
  ),
];
