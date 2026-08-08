import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'screens/dungeon_crawler_home_screen.dart';
import 'screens/dungeon_crawler_screen.dart';
import 'theme/dungeon_theme.dart';

final List<RouteBase> dungeonCrawlerRoutes = [
  GoRoute(
    path: '/dungeon-crawler',
    builder: (context, state) => Theme(
      data: DungeonTheme.theme,
      child: const DungeonCrawlerHomeScreen(),
    ),
  ),
  GoRoute(
    path: '/dungeon-crawler/play',
    builder: (context, state) =>
        Theme(data: DungeonTheme.theme, child: const DungeonCrawlerScreen()),
  ),
];
