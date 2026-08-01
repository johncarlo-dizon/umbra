import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:umbra/apps/fitlog/models/exercise.dart';
import 'package:umbra/core/theme.dart';

/// Shows an exercise's reference photo, target muscles, and step-by-step
/// form instructions — sourced from free-exercise-db's data (already
/// seeded into exercise_library).
///
/// This is written guidance only, not live posture correction — that
/// would need computer vision analyzing the user in real time, which is
/// a different kind of product entirely.
///
/// Responsive presentation: a draggable bottom sheet on narrow/mobile
/// viewports (the natural mobile pattern, with its drag handle), and a
/// proper centered dialog with an explicit close button on wide/desktop
/// viewports — a bottom sheet stretching off the bottom edge with no
/// visible way to close it reads as broken on desktop, not "mobile-style."
class ExerciseInstructionsSheet {
  static const double _desktopBreakpoint = 600;

  static Future<void> show(BuildContext context, Exercise exercise) {
    final isDesktop = MediaQuery.sizeOf(context).width >= _desktopBreakpoint;

    if (isDesktop) {
      return showDialog(
        context: context,
        builder: (context) => _InstructionsDialog(exercise: exercise),
      );
    }

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _InstructionsBottomSheet(exercise: exercise),
    );
  }
}

class _InstructionsDialog extends StatelessWidget {
  final Exercise exercise;

  const _InstructionsDialog({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Dialog(
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: screenHeight * 0.85,
        ),
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: _InstructionsContent(exercise: exercise),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: Icon(Icons.close, color: colorScheme.onSurfaceVariant),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Close',
                style: IconButton.styleFrom(
                  backgroundColor: colorScheme.surfaceContainerHighest,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InstructionsBottomSheet extends StatelessWidget {
  final Exercise exercise;

  const _InstructionsBottomSheet({required this.exercise});

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
              _InstructionsContent(exercise: exercise),
            ],
          ),
        );
      },
    );
  }
}

/// Shared content — photo, title, muscle tags, numbered steps — used by
/// both the mobile bottom sheet and the desktop dialog.
class _InstructionsContent extends StatelessWidget {
  final Exercise exercise;

  const _InstructionsContent({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (exercise.imageUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: CachedNetworkImage(
              imageUrl: exercise.imageUrl!,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              errorWidget: (context, url, error) => const SizedBox.shrink(),
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
    );
  }
}
