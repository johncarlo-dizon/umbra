import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:umbra/apps/fitlog/models/exercise.dart';
import 'package:umbra/apps/fitlog/models/workout.dart';
import 'package:umbra/apps/fitlog/models/workout_exercise.dart';
import 'package:umbra/apps/fitlog/models/workout_set.dart';
import 'package:umbra/apps/fitlog/services/fitlog_service.dart';
import 'package:umbra/apps/fitlog/screens/muscle_group_screen.dart';
import 'package:umbra/apps/fitlog/screens/exercise_instructions_sheet.dart';
import 'package:umbra/core/theme.dart';

enum _LoadState { loading, loaded, error }

/// Active/detail workout screen: add exercises, log sets, see the "last
/// time you did this" recall. Reached at /workouts/session/:workoutId,
/// both for a freshly-started workout and for reopening a past one from
/// history — same screen serves both, everything stays editable.
class WorkoutSessionScreen extends StatefulWidget {
  final String workoutId;

  const WorkoutSessionScreen({super.key, required this.workoutId});

  @override
  State<WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends State<WorkoutSessionScreen> {
  _LoadState _state = _LoadState.loading;
  Workout? _workout;
  List<WorkoutExercise> _exercises = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _state = _LoadState.loading);
    try {
      final results = await Future.wait([
        FitlogService.getWorkoutById(widget.workoutId),
        FitlogService.getWorkoutExercises(widget.workoutId),
      ]);
      if (!mounted) return;
      setState(() {
        _workout = results[0] as Workout;
        _exercises = results[1] as List<WorkoutExercise>;
        _state = _LoadState.loaded;
      });
    } on FitlogException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _state = _LoadState.error;
      });
    }
  }

  Future<void> _addExercise() async {
    final selected = await Navigator.of(context).push<Exercise>(
      MaterialPageRoute(builder: (_) => const MuscleGroupScreen()),
    );
    if (selected == null || !mounted) return;

    try {
      final workoutExercise = await FitlogService.addExerciseToWorkout(
        workoutId: widget.workoutId,
        exerciseName: selected.name,
        exerciseExternalId: selected.externalId,
        sortOrder: _exercises.length,
      );
      if (!mounted) return;
      setState(() => _exercises = [..._exercises, workoutExercise]);
    } on FitlogException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _removeExercise(WorkoutExercise exercise) async {
    try {
      await FitlogService.deleteWorkoutExercise(exercise.id);
      if (!mounted) return;
      setState(
        () =>
            _exercises = _exercises.where((e) => e.id != exercise.id).toList(),
      );
    } on FitlogException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _replaceExercise(WorkoutExercise updated) {
    setState(() {
      _exercises = _exercises
          .map((e) => e.id == updated.id ? updated : e)
          .toList();
    });
  }

  Future<void> _confirmDeleteWorkout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this workout?'),
        content: const Text(
          'This removes all logged exercises and sets. This can\'t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await FitlogService.deleteWorkout(widget.workoutId);
      if (mounted) context.pop();
    } on FitlogException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_workout?.displayName ?? 'Workout'),
        actions: [
          if (_state == _LoadState.loaded)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _confirmDeleteWorkout,
              tooltip: 'Delete workout',
            ),
        ],
      ),
      floatingActionButton: _state == _LoadState.loaded
          ? FloatingActionButton.extended(
              onPressed: _addExercise,
              icon: const Icon(Icons.add),
              label: const Text('Add exercise'),
            )
          : null,
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth;
            final contentMaxWidth = maxWidth > 700 ? 700.0 : maxWidth;

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentMaxWidth),
                child: _buildBody(colorScheme),
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
        return const Center(child: CircularProgressIndicator());

      case _LoadState.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: colorScheme.error, size: 36),
                const SizedBox(height: 12),
                Text(
                  _errorMessage ?? 'Something went wrong.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          ),
        );

      case _LoadState.loaded:
        if (_exercises.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.fitness_center,
                    color: colorScheme.onSurfaceVariant,
                    size: 36,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No exercises yet — tap "Add exercise" to get started.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          itemCount: _exercises.length,
          itemBuilder: (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _ExerciseCard(
              exercise: _exercises[index],
              workoutId: widget.workoutId,
              onDeleted: () => _removeExercise(_exercises[index]),
              onSetsChanged: _replaceExercise,
            ),
          ),
        );
    }
  }
}

class _ExerciseCard extends StatefulWidget {
  final WorkoutExercise exercise;
  final String workoutId;
  final VoidCallback onDeleted;
  final ValueChanged<WorkoutExercise> onSetsChanged;

  const _ExerciseCard({
    required this.exercise,
    required this.workoutId,
    required this.onDeleted,
    required this.onSetsChanged,
  });

  @override
  State<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<_ExerciseCard> {
  late Future<WorkoutExercise?> _lastTimeFuture;
  bool _loadingInstructions = false;

  @override
  void initState() {
    super.initState();
    _lastTimeFuture = FitlogService.getLastTimeForExercise(
      widget.exercise.exerciseName,
      excludingWorkoutId: widget.workoutId,
    );
  }

  Future<void> _showInstructions() async {
    final externalId = widget.exercise.exerciseExternalId;
    if (externalId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No instructions available for a manually added exercise.',
          ),
        ),
      );
      return;
    }

    setState(() => _loadingInstructions = true);
    try {
      final fullExercise = await FitlogService.getExerciseByExternalId(
        externalId,
      );
      if (!mounted) return;
      setState(() => _loadingInstructions = false);
      if (fullExercise == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Instructions not found for this exercise.'),
          ),
        );
        return;
      }
      await ExerciseInstructionsSheet.show(context, fullExercise);
    } on FitlogException catch (e) {
      if (!mounted) return;
      setState(() => _loadingInstructions = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _addSet() async {
    final nextSetNumber = widget.exercise.sets.length + 1;
    try {
      final newSet = await FitlogService.addSet(
        workoutExerciseId: widget.exercise.id,
        setNumber: nextSetNumber,
      );
      widget.onSetsChanged(
        WorkoutExercise(
          id: widget.exercise.id,
          workoutId: widget.exercise.workoutId,
          userId: widget.exercise.userId,
          exerciseExternalId: widget.exercise.exerciseExternalId,
          exerciseName: widget.exercise.exerciseName,
          sortOrder: widget.exercise.sortOrder,
          createdAt: widget.exercise.createdAt,
          sets: [...widget.exercise.sets, newSet],
        ),
      );
    } on FitlogException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _deleteSet(WorkoutSet set) async {
    try {
      await FitlogService.deleteSet(set.id);
      widget.onSetsChanged(
        WorkoutExercise(
          id: widget.exercise.id,
          workoutId: widget.exercise.workoutId,
          userId: widget.exercise.userId,
          exerciseExternalId: widget.exercise.exerciseExternalId,
          exerciseName: widget.exercise.exerciseName,
          sortOrder: widget.exercise.sortOrder,
          createdAt: widget.exercise.createdAt,
          sets: widget.exercise.sets.where((s) => s.id != set.id).toList(),
        ),
      );
    } on FitlogException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _saveSet(WorkoutSet set, {double? weight, int? reps}) async {
    try {
      final updated = await FitlogService.updateSet(
        set.id,
        weight: weight,
        reps: reps,
      );
      widget.onSetsChanged(
        WorkoutExercise(
          id: widget.exercise.id,
          workoutId: widget.exercise.workoutId,
          userId: widget.exercise.userId,
          exerciseExternalId: widget.exercise.exerciseExternalId,
          exerciseName: widget.exercise.exerciseName,
          sortOrder: widget.exercise.sortOrder,
          createdAt: widget.exercise.createdAt,
          sets: widget.exercise.sets
              .map((s) => s.id == set.id ? updated : s)
              .toList(),
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Set saved'),
            duration: Duration(milliseconds: 800),
          ),
        );
      }
    } on FitlogException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.exercise.exerciseName,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                  onPressed: widget.onDeleted,
                  tooltip: 'Remove exercise',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 2),
            Material(
              color: Colors.transparent,
              clipBehavior: Clip.antiAlias,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: _loadingInstructions ? null : _showInstructions,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_loadingInstructions)
                        const SizedBox(
                          width: 13,
                          height: 13,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        const Icon(
                          Icons.menu_book_outlined,
                          size: 15,
                          color: AppColors.orange,
                        ),
                      const SizedBox(width: 5),
                      Text(
                        'How to perform',
                        style: TextStyle(
                          color: AppColors.orange,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            FutureBuilder<WorkoutExercise?>(
              future: _lastTimeFuture,
              builder: (context, snapshot) {
                final last = snapshot.data;
                if (last == null || last.sets.isEmpty)
                  return const SizedBox.shrink();
                final best = last.sets.reduce(
                  (a, b) => (a.weight ?? 0) >= (b.weight ?? 0) ? a : b,
                );
                final parts = <String>[];
                if (best.weight != null)
                  parts.add('${_formatNum(best.weight!)}kg');
                if (best.reps != null) parts.add('× ${best.reps} reps');
                if (parts.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: Text(
                    'Last time: ${parts.join(' ')} (best set)',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 4),
            ...widget.exercise.sets.map(
              (set) => _SetRow(
                set: set,
                onSave: (weight, reps) =>
                    _saveSet(set, weight: weight, reps: reps),
                onDelete: () => _deleteSet(set),
              ),
            ),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: _addSet,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add set'),
              style: TextButton.styleFrom(foregroundColor: AppColors.orange),
            ),
          ],
        ),
      ),
    );
  }

  String _formatNum(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
  }
}

class _SetRow extends StatefulWidget {
  final WorkoutSet set;
  final void Function(double? weight, int? reps) onSave;
  final VoidCallback onDelete;

  const _SetRow({
    required this.set,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<_SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<_SetRow> {
  late final TextEditingController _weightController;
  late final TextEditingController _repsController;

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController(
      text: widget.set.weight != null ? _formatNum(widget.set.weight!) : '',
    );
    _repsController = TextEditingController(
      text: widget.set.reps?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  String _formatNum(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
  }

  void _save() {
    final weight = double.tryParse(_weightController.text.trim());
    final reps = int.tryParse(_repsController.text.trim());
    widget.onSave(weight, reps);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              'Set ${widget.set.setNumber}',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _weightController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'kg',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _repsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'reps',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.check, size: 20),
            onPressed: _save,
            tooltip: 'Save set',
            color: AppColors.orange,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              size: 20,
              color: colorScheme.onSurfaceVariant,
            ),
            onPressed: widget.onDelete,
            tooltip: 'Delete set',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
