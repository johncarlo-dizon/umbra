import 'package:go_router/go_router.dart';

import 'screens/calculator_screen.dart';

/// Spread into `core/router.dart`'s `routes:` list as `...calculatorRoutes`.
final List<RouteBase> calculatorRoutes = [
  GoRoute(
    path: '/calculator',
    builder: (context, state) => const CalculatorScreen(),
  ),
];
