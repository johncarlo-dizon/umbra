import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_client.dart';
import '../widgets/app_tile.dart';
import '../theme.dart';
import '../shell_nav_state.dart';
import '../app_settings_state.dart';
import '../wallpapers.dart';
import 'auth_screen.dart';
import 'dev_screen.dart';
import 'settings_screen.dart';

/// Screen width above which the Home tab switches from a mobile-style
/// centered/scrolling icon grid to a desktop-style top-left icon grid.
const double _desktopBreakpoint = 700;

/// Taskbar width above which the search box stays permanently expanded
/// inline (like Windows 11's taskbar search box) instead of collapsing to
/// an icon that expands on tap (the mobile pattern).
const double _taskbarWideBreakpoint = 480;

class UmbraShellScreen extends StatefulWidget {
  const UmbraShellScreen({super.key});

  @override
  State<UmbraShellScreen> createState() => _UmbraShellScreenState();
}

class _UmbraShellScreenState extends State<UmbraShellScreen> {
  int _selectedNavIndex = 0;
  String _searchQuery = '';
  bool _searchExpanded = false;
  StreamSubscription<AuthState>? _authSubscription;

  static const List<_AppEntry> _apps = [
    _AppEntry(
      icon: Icons.menu_book_rounded,
      name: 'MangaHub',
      description: 'Read manga and webtoons',
      route: '/mangahub',
      color: AppColors.orange,
    ),
    _AppEntry(
      icon: Icons.fitness_center,
      name: 'FitLog',
      description: 'Log workouts and track progress',
      route: '/workouts',
      color: Colors.teal,
    ),
    _AppEntry(
      icon: Icons.calculate_outlined,
      name: 'Calculator',
      description: 'Quick everyday calculations',
      route: '/calculator',
      color: AppColors.orange, // or a new distinct color
    ),
    _AppEntry(
      icon: Icons.swap_horiz,
      name: 'Unit Converter',
      description: 'Length, weight, temperature & more',
      route: '/unit-converter',
      color: Colors.teal,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _authSubscription = SupabaseService.authStateChanges.listen((_) {
      if (mounted) setState(() {});
    });
    ShellNavState.requestedTabIndex.addListener(_handleTabRequest);

    final pending = ShellNavState.requestedTabIndex.value;
    if (pending != null) {
      _selectedNavIndex = pending;
      ShellNavState.requestedTabIndex.value = null;
    }
  }

  void _handleTabRequest() {
    final requested = ShellNavState.requestedTabIndex.value;
    if (requested != null) {
      setState(() => _selectedNavIndex = requested);
      ShellNavState.requestedTabIndex.value = null;
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    ShellNavState.requestedTabIndex.removeListener(_handleTabRequest);
    super.dispose();
  }

  /// Search lives in the taskbar, not the tab content, so toggling it also
  /// jumps to Home — the same way clicking a taskbar's search box on a real
  /// desktop brings you to search results regardless of which app/window
  /// currently has focus, rather than only working while already on Home.
  void _toggleSearch() {
    setState(() {
      _searchExpanded = !_searchExpanded;
      if (_searchExpanded) {
        _selectedNavIndex = 0;
      } else {
        _searchQuery = '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _buildSelectedTab()),
      bottomNavigationBar: _TaskbarNav(
        selectedIndex: _selectedNavIndex,
        onSelect: (index) => setState(() => _selectedNavIndex = index),
        searchExpanded: _searchExpanded,
        searchQuery: _searchQuery,
        onSearchToggle: _toggleSearch,
        onSearchChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  Widget _buildSelectedTab() {
    switch (_selectedNavIndex) {
      case 1:
        return _buildProfileTab();
      case 2:
        return const DevScreen();
      case 3:
        return const SettingsScreen();
      case 0:
      default:
        return _buildHomeTab();
    }
  }

  Widget _buildProfileTab() {
    final session = SupabaseService.currentSession;

    if (session == null) {
      return const AuthScreen();
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_circle, size: 64),
            const SizedBox(height: 12),
            Text(
              session.user.email ?? 'Signed in',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () async {
                await SupabaseService.client.auth.signOut();
              },
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Home tab: wallpaper behind app icons ONLY — no greeting, no search
  // (both moved to the taskbar). Mobile centers a scrolling grid; desktop
  // anchors icons top-left in columns, like an actual desktop.
  // ---------------------------------------------------------------------

  Widget _buildHomeTab() {
    final filteredApps = _apps
        .where(
          (app) => app.name.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();

    return ValueListenableBuilder<HomeWallpaper>(
      valueListenable: AppSettingsState.homeWallpaper,
      builder: (context, wallpaper, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= _desktopBreakpoint;

            return Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  wallpaper.assetPath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  ),
                ),
                // Soft overall scrim so white icon labels stay legible
                // against any wallpaper, without needing per-photo tuning.
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.18),
                  ),
                ),
                isDesktop
                    ? _buildDesktopHome(filteredApps)
                    : _buildMobileHome(filteredApps),
              ],
            );
          },
        );
      },
    );
  }

  /// Mobile: centered, scrolling icon grid — just the apps, nothing else.
  Widget _buildMobileHome(List<_AppEntry> filteredApps) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 92,
        mainAxisSpacing: 18,
        crossAxisSpacing: 8,
        childAspectRatio: 0.72,
      ),
      itemCount: filteredApps.length + 1,
      itemBuilder: (context, index) => _appOrPlaceholder(index, filteredApps),
    );
  }

  /// Desktop: icons anchored top-left, filling top-to-bottom and starting
  /// a new column when they run out of vertical room — matching the
  /// column arrangement of an actual Windows desktop, not a row-wrapping
  /// grid.
  Widget _buildDesktopHome(List<_AppEntry> filteredApps) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 28),
      child: LayoutBuilder(
        builder: (context, iconAreaConstraints) {
          return Align(
            alignment: Alignment.topLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                height: iconAreaConstraints.maxHeight,
                child: Wrap(
                  direction: Axis.vertical,
                  spacing: 24,
                  runSpacing: 28,
                  children: List.generate(
                    filteredApps.length + 1,
                    (index) => SizedBox(
                      width: 88,
                      child: _appOrPlaceholder(index, filteredApps),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _appOrPlaceholder(int index, List<_AppEntry> filteredApps) {
    if (index < filteredApps.length) {
      final app = filteredApps[index];
      return AppTile(
        icon: app.icon,
        name: app.name,
        description: app.description,
        color: app.color,
        onTap: () => context.push(app.route),
      );
    }
    return const AppTile(
      icon: Icons.add_circle_outline,
      name: 'More soon',
      description: 'New modules launch here',
      isPlaceholder: true,
    );
  }
}

/// The single taskbar — no more "standard vs floating" choice, because a
/// real OS taskbar doesn't have that toggle either: it's a plain full-width
/// bar, search box near the start, then icon buttons packed tightly right
/// next to each other (not spread across the remaining width), each one
/// showing a small underline when it's the active tab instead of a
/// text label — closer to how Windows shows an indicator under an open
/// app's pinned icon than to a Material bottom-nav bar.
class _TaskbarNav extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final bool searchExpanded;
  final String searchQuery;
  final VoidCallback onSearchToggle;
  final ValueChanged<String> onSearchChanged;

  const _TaskbarNav({
    required this.selectedIndex,
    required this.onSelect,
    required this.searchExpanded,
    required this.searchQuery,
    required this.onSearchToggle,
    required this.onSearchChanged,
  });

  @override
  State<_TaskbarNav> createState() => _TaskbarNavState();
}

class _TaskbarNavState extends State<_TaskbarNav> {
  late final TextEditingController _searchController;

  static const _items = [
    (icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
    (
      icon: Icons.person_outline,
      activeIcon: Icons.person_rounded,
      label: 'Profile',
    ),
    (icon: Icons.code_rounded, activeIcon: Icons.code_rounded, label: 'Dev'),
    (
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings_rounded,
      label: 'Settings',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchQuery);
  }

  @override
  void didUpdateWidget(covariant _TaskbarNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only push external changes (e.g. the query being cleared when search
    // collapses) into the controller — never overwrite it while the query
    // change originated from this same field, or the cursor jumps on every
    // keystroke.
    if (widget.searchQuery != _searchController.text &&
        widget.searchQuery.isEmpty) {
      _searchController.clear();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: scheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, barConstraints) {
            final wide = barConstraints.maxWidth >= _taskbarWideBreakpoint;

            if (wide) {
              // Desktop-width taskbar: search box permanently visible,
              // icon cluster packed right next to it — not spread across
              // the bar, just like a real taskbar's pinned-icon group.
              return Row(
                children: [
                  SizedBox(width: 200, child: _searchField(context)),
                  const SizedBox(width: 12),
                  ..._iconButtons(context),
                ],
              );
            }

            // Narrow/mobile taskbar: search collapses to an icon; the icon
            // cluster still stays tightly packed, just right after it.
            if (widget.searchExpanded) {
              return Row(
                children: [
                  Expanded(child: _searchField(context, autofocus: true)),
                  IconButton(
                    onPressed: widget.onSearchToggle,
                    icon: Icon(Icons.close, color: scheme.onSurfaceVariant),
                    tooltip: 'Close search',
                  ),
                ],
              );
            }
            return Row(
              children: [
                IconButton(
                  onPressed: widget.onSearchToggle,
                  icon: Icon(Icons.search, color: scheme.onSurfaceVariant),
                  tooltip: 'Search apps',
                ),
                const SizedBox(width: 4),
                ..._iconButtons(context),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _searchField(BuildContext context, {bool autofocus = false}) {
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: _searchController,
      autofocus: autofocus,
      onChanged: widget.onSearchChanged,
      style: TextStyle(fontSize: 14, color: scheme.onSurface),
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Search apps',
        hintStyle: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
        prefixIcon: Icon(
          Icons.search,
          size: 18,
          color: scheme.onSurfaceVariant,
        ),
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  /// Small, tightly packed icon-only buttons — no text pill, no spreading
  /// across the bar. Active tab gets a thin colored underline (like
  /// Windows' indicator under an open pinned app) instead of a label.
  /// Hover shows the name as a tooltip, the same pattern used on the Home
  /// tab's app icons.
  List<Widget> _iconButtons(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return List.generate(_items.length, (index) {
      final item = _items[index];
      final isSelected = widget.selectedIndex == index;
      return Tooltip(
        message: item.label,
        waitDuration: const Duration(milliseconds: 500),
        child: InkWell(
          onTap: () => widget.onSelect(index),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 44,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.orange.withValues(alpha: 0.14)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isSelected ? item.activeIcon : item.icon,
                  size: 22,
                  color: isSelected
                      ? AppColors.orange
                      : scheme.onSurfaceVariant,
                ),
                const SizedBox(height: 3),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 3,
                  width: isSelected ? 16 : 0,
                  decoration: BoxDecoration(
                    color: AppColors.orange,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _AppEntry {
  final IconData icon;
  final String name;
  final String description;
  final String route;
  final Color color;

  const _AppEntry({
    required this.icon,
    required this.name,
    required this.description,
    required this.route,
    required this.color,
  });
}
