import 'package:flutter/foundation.dart';

/// Lets screens outside the Umbra shell (like MangaHub) request that
/// the shell switch to a specific bottom-nav tab once it's opened.
class ShellNavState {
  ShellNavState._();

  static final ValueNotifier<int?> requestedTabIndex = ValueNotifier(null);

  static const int homeTab = 0;
  static const int profileTab = 1;
  static const int devTab = 2;
  static const int settingsTab = 3;
}
