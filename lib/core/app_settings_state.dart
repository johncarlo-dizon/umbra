import 'package:flutter/material.dart';

enum NavBarStyle { standard, floating }

/// Holds the app's live settings as ValueNotifiers so any widget can
/// react instantly when they change, without threading state through
/// every screen. Values are loaded from disk once at boot by
/// SettingsService and written back whenever the user changes them.
class AppSettingsState {
  AppSettingsState._();

  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier(
    ThemeMode.light,
  );
  static final ValueNotifier<NavBarStyle> navBarStyle = ValueNotifier(
    NavBarStyle.standard,
  );
}
