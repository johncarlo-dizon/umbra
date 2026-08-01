import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:umbra/apps/fitlog/models/exercise.dart';
import 'package:umbra/apps/fitlog/models/muscle_group.dart';
import 'package:umbra/apps/fitlog/services/fitlog_service.dart';
import 'package:umbra/apps/fitlog/screens/exercise_instructions_sheet.dart';
import 'package:umbra/core/theme.dart';

enum _LoadState { loading, loaded, error, empty }

/// Search/select screen for choosing an exercise from the shared library.
/// Pops with the selected Exercise via Navigator.pop(context, exercise)
/// when used as a picker; can also be used purely for browsing.
///
/// If [muscleGroup] is provided, results are pre-filtered to that group
/// (e.g. arriving from the "Back" tile on MuscleGroupScreen); the search
/// bar still narrows further within that group. If null, all exercises
/// are searchable (the "Search all exercises" entry point).
class ExercisePickerScreen extends StatefulWidget {
  final MuscleGroup? muscleGroup;

  const ExercisePickerScreen({super.key, this.muscleGroup});

  @override
  State<ExercisePickerScreen> createState() => _ExercisePickerScreenState();
}

class _ExercisePickerScreenState extends State<ExercisePickerScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  _LoadState _state = _LoadState.loading;
  List<Exercise> _exercises = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadExercises({String? searchTerm}) async {
    setState(() => _state = _LoadState.loading);
    try {
      final results = await FitlogService.getExercises(
        searchTerm: searchTerm,
        muscles: widget.muscleGroup?.muscles,
      );
      if (!mounted) return;
      setState(() {
        _exercises = results;
        _state = results.isEmpty ? _LoadState.empty : _LoadState.loaded;
      });
    } on FitlogException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _state = _LoadState.error;
      });
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _loadExercises(searchTerm: value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.muscleGroup?.label ?? 'Search exercises'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: _SearchBar(
              controller: _searchController,
              onChanged: _onSearchChanged,
              hintText: widget.muscleGroup != null
                  ? 'Search within ${widget.muscleGroup!.label}'
                  : 'Search exercises',
            ),
          ),
          Expanded(child: _buildBody(colorScheme)),
        ],
      ),
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
    switch (_state) {
      case _LoadState.loading:
        return const Center(child: CircularProgressIndicator());

      case _LoadState.error:
        return _ErrorState(
          message: _errorMessage ?? 'Something went wrong.',
          onRetry: () => _loadExercises(searchTerm: _searchController.text),
        );

      case _LoadState.empty:
        return Center(
          child: Text(
            'No exercises found.',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        );

      case _LoadState.loaded:
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _exercises.length,
          itemBuilder: (context, index) {
            final exercise = _exercises[index];
            return _ExerciseTile(
              exercise: exercise,
              onTap: () => Navigator.pop(context, exercise),
            );
          },
        );
    }
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hintText;

  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(10),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search,
                size: 18,
                color: AppColors.orange,
              ),
            ),
          ),
          filled: true,
          fillColor: colorScheme.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  final Exercise exercise;
  final VoidCallback onTap;

  const _ExerciseTile({required this.exercise, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: colorScheme.surface,
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () =>
                      ExerciseInstructionsSheet.show(context, exercise),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: exercise.imageUrl != null
                            ? CachedNetworkImage(
                                imageUrl: exercise.imageUrl!,
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) =>
                                    _placeholder(colorScheme),
                                placeholder: (context, url) =>
                                    _placeholder(colorScheme),
                              )
                            : _placeholder(colorScheme),
                      ),
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.menu_book_outlined,
                            size: 11,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.name,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (exercise.equipment != null)
                        Text(
                          exercise.equipment!,
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      if (exercise.primaryMuscles.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: exercise.primaryMuscles
                              .map(
                                (muscle) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.orange.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    muscle,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.orange,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder(ColorScheme colorScheme) {
    return Container(
      width: 56,
      height: 56,
      color: colorScheme.surfaceContainerHighest,
      child: Icon(Icons.fitness_center, color: colorScheme.onSurfaceVariant),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: colorScheme.error, size: 40),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
