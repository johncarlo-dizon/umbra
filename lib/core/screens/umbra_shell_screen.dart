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

  void _closeSearch() {
    setState(() {
      _searchExpanded = false;
      _searchQuery = '';
    });
  }

  List<_AppEntry> get _searchResults {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return const [];
    return _apps
        .where((app) => app.name.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    // Note: on the wide/desktop taskbar the search field is always visible
    // and never goes through _toggleSearch, so _searchExpanded stays false
    // while typing there — panel visibility must depend only on the query.
    final showResultsPanel = _searchQuery.trim().isNotEmpty;

    return Scaffold(
      // The panel lives inside the body's Stack rather than
      // Scaffold.bottomSheet, so it can be a narrow flyout anchored above
      // the search box's left edge (like Windows' taskbar search flyout)
      // instead of a full-width sheet stretching across the screen.
      // Positioning it at bottom:0 of the body already lines it up right
      // above the taskbar, since Scaffold shrinks body to exclude
      // bottomNavigationBar's height.
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: _buildSelectedTab()),
            if (showResultsPanel)
              Positioned(
                left: 12,
                bottom: 8,
                child: _SearchResultsPanel(
                  results: _searchResults,
                  query: _searchQuery,
                  onSelect: (app) {
                    _closeSearch();
                    context.push(app.route);
                  },
                ),
              ),
          ],
        ),
      ),
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
  //
  // The grid always shows every app, unfiltered — searching no longer
  // hides icons here, it surfaces matches in the floating panel above the
  // taskbar instead, the same way desktop search doesn't rearrange your
  // desktop icons while you type.
  // ---------------------------------------------------------------------

  Widget _buildHomeTab() {
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
                isDesktop ? _buildDesktopHome() : _buildMobileHome(),
              ],
            );
          },
        );
      },
    );
  }

  /// Mobile: centered, scrolling icon grid — just the apps, nothing else.
  Widget _buildMobileHome() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 92,
        mainAxisSpacing: 18,
        crossAxisSpacing: 8,
        childAspectRatio: 0.72,
      ),
      itemCount: _apps.length + 1,
      itemBuilder: (context, index) => _appOrPlaceholder(index),
    );
  }

  /// Desktop: icons anchored top-left, filling top-to-bottom and starting
  /// a new column when they run out of vertical room — matching the
  /// column arrangement of an actual Windows desktop, not a row-wrapping
  /// grid.
  Widget _buildDesktopHome() {
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
                    _apps.length + 1,
                    (index) =>
                        SizedBox(width: 88, child: _appOrPlaceholder(index)),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _appOrPlaceholder(int index) {
    if (index < _apps.length) {
      final app = _apps[index];
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

/// Floating panel of search matches, hovering directly above the taskbar
/// via Scaffold.bottomSheet — never covers the whole screen, never
/// reshuffles the Home grid underneath it.
class _SearchResultsPanel extends StatelessWidget {
  final List<_AppEntry> results;
  final String query;
  final ValueChanged<_AppEntry> onSelect;

  const _SearchResultsPanel({
    required this.results,
    required this.query,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      width: (screenWidth - 24).clamp(0, 340),
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: results.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Row(
                children: [
                  Icon(Icons.search_off, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No apps match "$query"',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: results.length,
              separatorBuilder: (context, index) =>
                  Divider(height: 1, color: scheme.outlineVariant),
              itemBuilder: (context, index) {
                final app = results[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: app.color.withValues(alpha: 0.16),
                    child: Icon(app.icon, color: app.color),
                  ),
                  title: Text(app.name),
                  subtitle: Text(app.description),
                  onTap: () => onSelect(app),
                );
              },
            ),
    );
  }
}

/// The single taskbar — no more "standard vs floating" choice, because a
/// real OS taskbar doesn't have that toggle either: it's a plain full-width
/// bar, search box near the start, then icon buttons packed tightly right
/// next to each other (not spread across the remaining width), each one
/// showing a small underline when it's the active tab instead of a
/// text label — closer to how Windows shows an indicator under an open
/// app's pinned icon than to a Material bottom-nav bar. A live clock sits
/// on the opposite end, the same corner a real taskbar clock lives in.
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
              // icon cluster packed right next to it, clock pinned to the
              // far end — just like a real taskbar's search-icons-clock
              // layout.
              return Row(
                children: [
                  SizedBox(width: 200, child: _searchField(context)),
                  const SizedBox(width: 12),
                  ..._iconButtons(context),
                  const Spacer(),
                  const _LiveClock(),
                ],
              );
            }

            // Narrow/mobile taskbar: search collapses to an icon; the icon
            // cluster still stays tightly packed, just right after it. The
            // clock hides while search is expanded so it doesn't fight the
            // text field for space, and shows compactly otherwise.
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
                const Spacer(),
                const _LiveClock(compact: true),
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

/// Live clock/date, ticking once a minute (no need for per-second
/// rebuilds on a taskbar readout), shown at the opposite end of the
/// taskbar from search — the same corner a system clock occupies.
class _LiveClock extends StatefulWidget {
  final bool compact;

  const _LiveClock({this.compact = false});

  @override
  State<_LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<_LiveClock> {
  late DateTime _now;
  Timer? _timer;

  static const _weekdayNames = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  static const _monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    // Align the first tick to the next minute boundary, then tick once a
    // minute after that — plenty for a clock nobody needs second-accurate.
    final msToNextMinute = 60000 - (_now.second * 1000 + _now.millisecond);
    Timer(Duration(milliseconds: msToNextMinute), () {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      _timer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) setState(() => _now = DateTime.now());
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _timeLabel() {
    final hour24 = _now.hour;
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final minute = _now.minute.toString().padLeft(2, '0');
    final period = hour24 < 12 ? 'AM' : 'PM';
    return '$hour12:$minute $period';
  }

  String _dateLabel() {
    final weekday = _weekdayNames[_now.weekday - 1];
    final month = _monthNames[_now.month - 1];
    return '$weekday, $month ${_now.day}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (widget.compact) {
      // Narrow taskbar: just the time, small, to avoid crowding the icons.
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          _timeLabel(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _timeLabel(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.1,
              color: scheme.onSurface,
            ),
          ),
          Text(
            _dateLabel(),
            style: TextStyle(
              fontSize: 11,
              height: 1.1,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
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
