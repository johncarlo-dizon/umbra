import 'package:go_router/go_router.dart';

import 'screens/unit_converter_detail_screen.dart';
import 'screens/unit_converter_home_screen.dart';

/// Spread into `core/router.dart`'s `routes:` list as `...unitConverterRoutes`.
final List<RouteBase> unitConverterRoutes = [
  GoRoute(
    path: '/unit-converter',
    builder: (context, state) => const UnitConverterHomeScreen(),
  ),
  GoRoute(
    path: '/unit-converter/:categoryId',
    builder: (context, state) => UnitConverterDetailScreen(
      categoryId: state.pathParameters['categoryId']!,
    ),
  ),
];
