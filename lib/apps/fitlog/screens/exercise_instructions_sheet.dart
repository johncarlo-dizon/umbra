import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:umbra/apps/fitlog/models/exercise.dart';
import 'package:umbra/core/theme.dart';

/// Bottom sheet showing an exercise's reference photo, target muscles,
/// and step-by-step form instructions — sourced from free-exercise-db's
/// data (already seeded into exercise_library, just not surfaced in the
/// UI until now).
///
/// This is written guidance only, not live posture correction — that
/// would need computer vision analyzing the user in real time, which is
/// a different kind of product entirely.
class ExerciseInstructionsSheet extends StatelessWidget {
  final Exercise exercise;

  const ExerciseInstructionsSheet({super.key, required this.exercise});

  static Future<void> show(BuildContext context, Exercise exercise) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ExerciseInstructionsSheet(exercise: exercise),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (exercise.imageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    imageUrl: exercise.imageUrl!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) =>
                        const SizedBox.shrink(),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                exercise.name,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 8),
              if (exercise.primaryMuscles.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: exercise.primaryMuscles
                      .map(
                        (muscle) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.orange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            muscle,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              const SizedBox(height: 20),
              if (exercise.instructions.isEmpty)
                Text(
                  'No form instructions available for this exercise.',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                )
              else ...[
                Text(
                  'How to perform it',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 12),
                ...exercise.instructions.asMap().entries.map((entry) {
                  final stepNumber = entry.key + 1;
                  final step = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.orange.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$stepNumber',
                            style: const TextStyle(
                              color: AppColors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            step,
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        );
      },
    );
  }
}
