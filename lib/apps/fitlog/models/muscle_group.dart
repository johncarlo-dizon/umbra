import 'package:flutter/material.dart';

/// Beginner-friendly muscle group, mapping to one or more granular muscle
/// values as they actually appear in fitlog.exercise_library's
/// primary_muscles column (sourced from free-exercise-db's taxonomy).
///
/// Gym rats who know the precise muscle they want still see it on each
/// exercise card (see _ExerciseTile in exercise_picker_screen.dart) —
/// this grouping is just the entry point for people who don't yet know
/// e.g. that "lats" and "traps" both fall under "Back".
class MuscleGroup {
  final String key;
  final String label;
  final List<String> muscles;
  final Color accent;

  const MuscleGroup({
    required this.key,
    required this.label,
    required this.muscles,
    required this.accent,
  });
}

const List<MuscleGroup> muscleGroups = [
  MuscleGroup(
    key: 'chest',
    label: 'Chest',
    muscles: ['chest'],
    accent: Color(0xFFE5533D),
  ),
  MuscleGroup(
    key: 'back',
    label: 'Back',
    muscles: ['lats', 'middle back', 'lower back', 'traps'],
    accent: Color(0xFF3D6FE5),
  ),
  MuscleGroup(
    key: 'shoulders',
    label: 'Shoulders',
    muscles: ['shoulders'],
    accent: Color(0xFF8B5DE5),
  ),
  MuscleGroup(
    key: 'arms',
    label: 'Arms',
    muscles: ['biceps', 'triceps', 'forearms'],
    accent: Color(0xFF16A38A),
  ),
  MuscleGroup(
    key: 'legs',
    label: 'Legs',
    muscles: ['quadriceps', 'hamstrings', 'calves', 'abductors', 'adductors'],
    accent: Color(0xFF4CAF50),
  ),
  MuscleGroup(
    key: 'core',
    label: 'Core',
    muscles: ['abdominals'],
    accent: Color(0xFFD4A017),
  ),
  MuscleGroup(
    key: 'glutes',
    label: 'Glutes',
    muscles: ['glutes'],
    accent: Color(0xFFE0508A),
  ),
];

MuscleGroup? muscleGroupByKey(String key) {
  for (final group in muscleGroups) {
    if (group.key == key) return group;
  }
  return null;
}
