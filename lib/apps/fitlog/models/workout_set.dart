class WorkoutSet {
  final String id;
  final String workoutExerciseId;
  final String userId;
  final int setNumber;
  final double? weight;
  final int? reps;
  final DateTime createdAt;

  const WorkoutSet({
    required this.id,
    required this.workoutExerciseId,
    required this.userId,
    required this.setNumber,
    this.weight,
    this.reps,
    required this.createdAt,
  });

  factory WorkoutSet.fromJson(Map<String, dynamic> json) {
    return WorkoutSet(
      id: json['id'] as String,
      workoutExerciseId: json['workout_exercise_id'] as String,
      userId: json['user_id'] as String,
      setNumber: json['set_number'] as int,
      weight: json['weight'] != null
          ? (json['weight'] as num).toDouble()
          : null,
      reps: json['reps'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
