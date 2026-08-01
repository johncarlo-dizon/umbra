import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:umbra/apps/fitlog/models/exercise.dart';
import 'package:umbra/apps/fitlog/models/muscle_group.dart';
import 'package:umbra/apps/fitlog/services/fitlog_service.dart';
import 'package:umbra/apps/fitlog/screens/exercise_picker_screen.dart';
import 'package:umbra/core/theme.dart';

/// Muscle-group browser used as a picker flow: pushed (via plain
/// Navigator.push, not GoRouter) from WorkoutSessionScreen's "Add
/// exercise" action, and pops with the selected Exercise once the user
/// picks one — same contract as ExercisePickerScreen itself.
///
/// Lets a beginner browse by broad muscle group ("Back", "Legs", etc.)
/// without needing to know the precise terms — each row expands to the
/// granular muscles under it (see MuscleGroup model). "Search all
/// exercises" is offered for users who already know exactly what they want.
///
/// Each row is split into a photo thumbnail (left) and a plain title
/// panel (right) — not a full-bleed photo with overlaid text — so the
/// name stays legible regardless of the reference photo.
class MuscleGroupScreen extends StatefulWidget {
  const MuscleGroupScreen({super.key});

  @override
  State<MuscleGroupScreen> createState() => _MuscleGroupScreenState();
}

class _MuscleGroupScreenState extends State<MuscleGroupScreen> {
  // Session-level cache: avoids re-querying Supabase every time this
  // screen is revisited (e.g. adding a second exercise in the same workout).
  static final Map<String, Future<Exercise?>> _representativeExerciseCache = {};

  Future<Exercise?> _representativeExerciseFor(MuscleGroup group) {
    return _representativeExerciseCache.putIfAbsent(group.key, () async {
      try {
        final results = await FitlogService.getExercises(
          muscles: group.muscles,
          limit: 1,
        );
        return results.isNotEmpty ? results.first : null;
      } catch (_) {
        // Decorative only — fail soft, thumbnail falls back to a flat accent color.
        return null;
      }
    });
  }

  Future<void> _openPicker(BuildContext context, {MuscleGroup? group}) async {
    final selected = await Navigator.of(context).push<Exercise>(
      MaterialPageRoute(
        builder: (_) => ExercisePickerScreen(muscleGroup: group),
      ),
    );
    // Forward the result straight back up to whoever launched this
    // picker flow (WorkoutSessionScreen), rather than stopping here.
    if (selected != null && context.mounted) {
      Navigator.of(context).pop(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Add exercise')),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth;
            final contentMaxWidth = maxWidth > 900 ? 900.0 : maxWidth;

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentMaxWidth),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'What are you training today?',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...muscleGroups.map(
                        (group) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _MuscleGroupRow(
                            group: group,
                            exerciseFuture: _representativeExerciseFor(group),
                            onTap: () => _openPicker(context, group: group),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Material(
                        color: Colors.transparent,
                        clipBehavior: Clip.antiAlias,
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          onTap: () => _openPicker(context),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.navy.withValues(alpha: 0.08),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppColors.orange.withValues(
                                      alpha: 0.15,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.search,
                                    color: AppColors.orange,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Search all exercises',
                                        style: TextStyle(
                                          color: colorScheme.onSurface,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        'Already know what you\'re looking for?',
                                        style: TextStyle(
                                          color: colorScheme.onSurfaceVariant,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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
}

class _MuscleGroupRow extends StatelessWidget {
  final MuscleGroup group;
  final Future<Exercise?> exerciseFuture;
  final VoidCallback onTap;

  const _MuscleGroupRow({
    required this.group,
    required this.exerciseFuture,
    required this.onTap,
  });

  static const double _rowHeight = 76;
  static const double _imageWidth = 110;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: _rowHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.navy.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: _imageWidth,
                  child: FutureBuilder<Exercise?>(
                    future: exerciseFuture,
                    builder: (context, snapshot) {
                      final imageUrl = snapshot.data?.imageUrl;
                      if (imageUrl != null) {
                        return CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              Container(color: group.accent),
                          errorWidget: (context, url, error) =>
                              Container(color: group.accent),
                        );
                      }
                      return Container(color: group.accent);
                    },
                  ),
                ),
                Expanded(
                  child: Container(
                    color: colorScheme.surface,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            group.label,
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
