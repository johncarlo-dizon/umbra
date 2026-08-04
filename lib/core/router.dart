import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'screens/umbra_shell_screen.dart';
import '../apps/mangahub/mangahub_routes.dart';
import '../apps/fitlog/fitlog_routes.dart';
import '../apps/calculator/calculator_routes.dart';
import '../apps/unit_converter/unit_converter_routes.dart';
import 'package:umbra/apps/dungeon_crawler/dungeon_crawler_routes.dart';

/// Lets screens detect when they've become visible again after
/// popping back from a pushed screen — used by MangaHub's home
/// screen to refresh reading history without a full rebuild.
final RouteObserver<PageRoute> appRouteObserver = RouteObserver<PageRoute>();

class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: '/',
    observers: [appRouteObserver],
    routes: [
      GoRoute(path: '/', builder: (context, state) => const UmbraShellScreen()),
      ...mangahubRoutes,
      ...fitlogRoutes,
      ...calculatorRoutes,
      ...unitConverterRoutes,
      ...dungeonCrawlerRoutes,
    ],
  );
}
