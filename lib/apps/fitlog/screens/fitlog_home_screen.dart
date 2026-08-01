import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:umbra/apps/fitlog/models/workout.dart';
import 'package:umbra/apps/fitlog/services/fitlog_service.dart';
import 'package:umbra/core/theme.dart';

enum _LoadState { loading, loaded, error, empty }

/// FitLog's true home: workout history + a "Start Workout" entry point.
/// Reached via the FitLog tile on Umbra's Home grid (route: /workouts).
class FitlogHomeScreen extends StatefulWidget {
  const FitlogHomeScreen({super.key});

  @override
  State<FitlogHomeScreen> createState() => _FitlogHomeScreenState();
}

class _FitlogHomeScreenState extends State<FitlogHomeScreen> {
  _LoadState _state = _LoadState.loading;
  List<Workout> _workouts = [];
  String? _errorMessage;
  bool _startingWorkout = false;

  @override
  void initState() {
    super.initState();
    _loadWorkouts();
  }

  Future<void> _loadWorkouts() async {
    setState(() => _state = _LoadState.loading);
    try {
      final workouts = await FitlogService.getWorkouts();
      if (!mounted) return;
      setState(() {
        _workouts = workouts;
        _state = workouts.isEmpty ? _LoadState.empty : _LoadState.loaded;
      });
    } on FitlogException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _state = _LoadState.error;
      });
    }
  }

  Future<void> _startWorkout() async {
    setState(() => _startingWorkout = true);
    try {
      final workout = await FitlogService.createWorkout();
      if (!mounted) return;
      // Push, not go — this is a drill-down into an active session, and we
      // want history to refresh (via the .then below) when the user comes back.
      await context.push('/workouts/session/${workout.id}');
      if (mounted) _loadWorkouts();
    } on FitlogException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _startingWorkout = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('FitLog')),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth;
            final contentMaxWidth = maxWidth > 900 ? 900.0 : maxWidth;

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentMaxWidth),
                child: RefreshIndicator(
                  onRefresh: _loadWorkouts,
                  child: CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                        sliver: SliverToBoxAdapter(
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _startingWorkout
                                  ? null
                                  : _startWorkout,
                              icon: _startingWorkout
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.add),
                              label: Text(
                                _startingWorkout
                                    ? 'Starting…'
                                    : 'Start Workout',
                              ),
                            ),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                        sliver: SliverToBoxAdapter(
                          child: Text(
                            'History',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      _buildBody(colorScheme),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
    switch (_state) {
      case _LoadState.loading:
        return const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          ),
        );

      case _LoadState.error:
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(Icons.error_outline, color: colorScheme.error, size: 36),
                const SizedBox(height: 12),
                Text(
                  _errorMessage ?? 'Something went wrong.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _loadWorkouts,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );

      case _LoadState.empty:
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Icon(
                  Icons.fitness_center,
                  color: colorScheme.onSurfaceVariant,
                  size: 36,
                ),
                const SizedBox(height: 12),
                Text(
                  'No workouts logged yet — start one above.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        );

      case _LoadState.loaded:
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          sliver: SliverList.builder(
            itemCount: _workouts.length,
            itemBuilder: (context, index) {
              final workout = _workouts[index];
              return _WorkoutHistoryTile(
                workout: workout,
                onTap: () async {
                  await context.push('/workouts/session/${workout.id}');
                  if (mounted) _loadWorkouts();
                },
              );
            },
          ),
        );
    }
  }
}

class _WorkoutHistoryTile extends StatelessWidget {
  final Workout workout;
  final VoidCallback onTap;

  const _WorkoutHistoryTile({required this.workout, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: colorScheme.surface,
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.orange.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.fitness_center,
                    color: AppColors.orange,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    workout.displayName,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
