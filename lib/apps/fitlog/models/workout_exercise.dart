import 'package:umbra/apps/fitlog/models/workout_set.dart';

class WorkoutExercise {
  final String id;
  final String workoutId;
  final String userId;
  final String? exerciseExternalId;
  final String exerciseName;
  final int sortOrder;
  final DateTime createdAt;
  final List<WorkoutSet> sets;

  const WorkoutExercise({
    required this.id,
    required this.workoutId,
    required this.userId,
    this.exerciseExternalId,
    required this.exerciseName,
    required this.sortOrder,
    required this.createdAt,
    this.sets = const [],
  });

  factory WorkoutExercise.fromJson(Map<String, dynamic> json) {
    final rawSets = json['sets'] as List<dynamic>?;
    return WorkoutExercise(
      id: json['id'] as String,
      workoutId: json['workout_id'] as String,
      userId: json['user_id'] as String,
      exerciseExternalId: json['exercise_external_id'] as String?,
      exerciseName: json['exercise_name'] as String,
      sortOrder: json['sort_order'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      sets: rawSets != null
          ? (rawSets
                .map((s) => WorkoutSet.fromJson(s as Map<String, dynamic>))
                .toList()
              ..sort((a, b) => a.setNumber.compareTo(b.setNumber)))
          : const [],
    );
  }
}
