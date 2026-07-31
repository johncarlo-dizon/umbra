import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'core/supabase_client.dart';
import 'core/theme.dart';
import 'core/router.dart';
import 'core/app_settings_state.dart';
import 'core/settings_service.dart';

Future<void> main() async {
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();

  await SupabaseService.initialize();
  await SettingsService.load();

  runApp(const UmbraApp());
}

class UmbraApp extends StatelessWidget {
  const UmbraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppSettingsState.themeMode,
      builder: (context, mode, _) {
        return MaterialApp.router(
          title: 'Umbra',
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,
          routerConfig: AppRouter.router,
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
