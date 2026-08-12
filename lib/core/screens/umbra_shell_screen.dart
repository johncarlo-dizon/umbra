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

const _weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _monthNames = [
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

class UmbraShellScreen extends StatefulWidget {
  const UmbraShellScreen({super.key});

  @override
  State<UmbraShellScreen> createState() => _UmbraShellScreenState();
}

class _UmbraShellScreenState extends State<UmbraShellScreen> {
  int _selectedNavIndex = 0;
  String _searchQuery = '';
  bool _searchExpanded = false;
  bool _calendarOpen = false;
  StreamSubscription<AuthState>? _authSubscription;

  static const List<_AppEntry> _apps = [
    _AppEntry(
      iconAsset: 'assets/icon/comics.png',
      name: 'MangaHub',
      description: 'Read manga and webtoons',
      route: '/mangahub',
      color: AppColors.orange,
    ),
    _AppEntry(
      iconAsset: 'assets/icon/fitness.png',
      name: 'FitLog',
      description: 'Log workouts and track progress',
      route: '/workouts',
      color: Colors.teal,
    ),
    _AppEntry(
      iconAsset: 'assets/icon/calculator.png',
      name: 'Calculator',
      description: 'Quick everyday calculations',
      route: '/calculator',
      color: AppColors.orange,
    ),
    _AppEntry(
      iconAsset: 'assets/icon/unit.png',
      name: 'Unit Converter',
      description: 'Length, weight, temperature & more',
      route: '/unit-converter',
      color: Colors.teal,
    ),
    _AppEntry(
      iconAsset: 'assets/icon/dungeon.png',
      name: 'Road Rage Runner',
      description: 'Fight through a dungeon, collect keys, find the exit.',
      route: '/dungeon-crawler',
      color: AppColors.orange,
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
        _calendarOpen = false; // only one flyout open at a time
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

  /// The clock, tapped — same idea as clicking Windows' taskbar clock to
  /// open its calendar flyout.
  void _toggleCalendar() {
    setState(() {
      _calendarOpen = !_calendarOpen;
      if (_calendarOpen) {
        _searchExpanded = false;
        _searchQuery = '';
      }
    });
  }

  void _closeOverlays() {
    setState(() {
      _searchExpanded = false;
      _searchQuery = '';
      _calendarOpen = false;
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
    final showAnyOverlay = showResultsPanel || _calendarOpen;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: _buildSelectedTab()),
            // Tapping anywhere outside a flyout closes it — same as
            // clicking away from Windows' search or calendar flyouts.
            if (showAnyOverlay)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _closeOverlays,
                ),
              ),
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
            if (_calendarOpen)
              const Positioned(right: 12, bottom: 8, child: _CalendarPanel()),
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
        onClockTap: _toggleCalendar,
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
        iconAsset: app.iconAsset,
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

/// Floating panel of search matches, hovering above the taskbar's left
/// side — never covers the whole screen, never reshuffles the Home grid
/// underneath it.
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
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Image.asset(app.iconAsset, fit: BoxFit.contain),
                    ),
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

/// Calendar flyout that opens when the taskbar clock is tapped — the same
/// interaction as clicking Windows' system-tray clock. Shows the current
/// month with today highlighted; pure date math, no package needed.
class _CalendarPanel extends StatelessWidget {
  const _CalendarPanel();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, 1);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final leadingBlanks = first.weekday - 1; // weekday: Mon=1 ... Sun=7
    final totalCells = leadingBlanks + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_monthNames[now.month - 1]} ${now.year}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: _weekdayNames
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Text(
                        d.substring(0, 2),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 6),
          for (int r = 0; r < rows; r++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: List.generate(7, (c) {
                  final cellIndex = r * 7 + c;
                  final day = cellIndex - leadingBlanks + 1;
                  final isValid = day >= 1 && day <= daysInMonth;
                  final isToday = isValid && day == now.day;
                  return Expanded(
                    child: Center(
                      child: Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: isToday
                            ? const BoxDecoration(
                                color: AppColors.orange,
                                shape: BoxShape.circle,
                              )
                            : null,
                        child: Text(
                          isValid ? '$day' : '',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isToday
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: isToday ? Colors.white : scheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

/// The single taskbar — search box near the start, icon buttons packed
/// tightly right next to it, a live clock pinned to the far end. Tapping
/// the clock opens the calendar flyout (see _CalendarPanel), the same as
/// clicking a real taskbar's clock.
class _TaskbarNav extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final bool searchExpanded;
  final String searchQuery;
  final VoidCallback onSearchToggle;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClockTap;

  const _TaskbarNav({
    required this.selectedIndex,
    required this.onSelect,
    required this.searchExpanded,
    required this.searchQuery,
    required this.onSearchToggle,
    required this.onSearchChanged,
    required this.onClockTap,
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
              return Row(
                children: [
                  SizedBox(width: 200, child: _searchField(context)),
                  const SizedBox(width: 12),
                  ..._iconButtons(context),
                  const Spacer(),
                  _LiveClock(onTap: widget.onClockTap),
                ],
              );
            }

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
                _LiveClock(compact: true, onTap: widget.onClockTap),
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

/// Live clock/date, ticking once a minute, tappable — opens the calendar
/// flyout via [onTap], same as clicking Windows' system-tray clock.
class _LiveClock extends StatefulWidget {
  final bool compact;
  final VoidCallback onTap;

  const _LiveClock({this.compact = false, required this.onTap});

  @override
  State<_LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<_LiveClock> {
  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
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

    final content = widget.compact
        ? Text(
            _timeLabel(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          )
        : Column(
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
          );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: content,
        ),
      ),
    );
  }
}

class _AppEntry {
  final String iconAsset;
  final String name;
  final String description;
  final String route;
  final Color color;

  const _AppEntry({
    required this.iconAsset,
    required this.name,
    required this.description,
    required this.route,
    required this.color,
  });
}
