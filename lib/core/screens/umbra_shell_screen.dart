import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_client.dart';
import '../widgets/app_tile.dart';
import 'auth_screen.dart';
import 'dev_screen.dart';
import '../theme.dart';
import '../shell_nav_state.dart';

class UmbraShellScreen extends StatefulWidget {
  const UmbraShellScreen({super.key});

  @override
  State<UmbraShellScreen> createState() => _UmbraShellScreenState();
}

class _UmbraShellScreenState extends State<UmbraShellScreen> {
  int _selectedNavIndex = 0;
  String _searchQuery = '';
  StreamSubscription<AuthState>? _authSubscription;

  static const List<_AppEntry> _apps = [
    _AppEntry(
      icon: Icons.menu_book_rounded,
      name: 'MangaHub',
      description: 'Read manga and webtoons',
      route: '/mangahub',
      color: AppColors.terracotta,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _authSubscription = SupabaseService.authStateChanges.listen((_) {
      if (mounted) setState(() {});
    });
    ShellNavState.requestedTabIndex.addListener(_handleTabRequest);

    // Check for a request that was set BEFORE this screen existed
    // (e.g. tapped from MangaHub) — the listener alone only catches
    // changes that happen after this point, not ones already pending.
    final pending = ShellNavState.requestedTabIndex.value;
    if (pending != null) {
      _selectedNavIndex = pending;
      ShellNavState.requestedTabIndex.value = null;
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    ShellNavState.requestedTabIndex.removeListener(_handleTabRequest);
    super.dispose();
  }

  void _handleTabRequest() {
    final requested = ShellNavState.requestedTabIndex.value;
    if (requested != null) {
      setState(() => _selectedNavIndex = requested);
      ShellNavState.requestedTabIndex.value = null; // consume it
    }
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _buildSelectedTab()),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedNavIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedNavIndex = index);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
          NavigationDestination(icon: Icon(Icons.code_rounded), label: 'Dev'),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
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
        return const Center(child: Text('Settings — coming soon'));
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

  Widget _buildHomeTab() {
    final isLoggedIn = SupabaseService.isLoggedIn;
    final userName = SupabaseService.currentSession?.user.email
        ?.split('@')
        .first;
    final filteredApps = _apps
        .where(
          (app) => app.name.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final contentMaxWidth = maxWidth > 900 ? 900.0 : maxWidth;
        final crossAxisCount = maxWidth >= 900
            ? 3
            : maxWidth >= 600
            ? 2
            : 1;

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentMaxWidth),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.espresso, AppColors.espressoLight],
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Image.asset(
                          'assets/images/logo.png',
                          width: 44,
                          height: 44,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isLoggedIn
                                    ? '$_greeting, $userName'
                                    : _greeting,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                isLoggedIn
                                    ? 'Welcome back to Umbra'
                                    : 'One hub for all your apps',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimary
                                          .withValues(alpha: 0.9),
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  sliver: SliverToBoxAdapter(
                    child: TextField(
                      onChanged: (value) {
                        setState(() => _searchQuery = value);
                      },
                      decoration: InputDecoration(
                        hintText: 'Search apps',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'Your apps',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      mainAxisExtent: 96,
                    ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      if (index < filteredApps.length) {
                        final app = filteredApps[index];
                        return AppTile(
                          icon: app.icon,
                          name: app.name,
                          description: app.description,
                          color: app.color,
                          onTap: () {
                            context.push(app.route);
                          },
                        );
                      }
                      return const AppTile(
                        icon: Icons.add_circle_outline,
                        name: 'More apps coming soon',
                        description: 'New modules launch here',
                        isPlaceholder: true,
                      );
                    }, childCount: filteredApps.length + 1),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
