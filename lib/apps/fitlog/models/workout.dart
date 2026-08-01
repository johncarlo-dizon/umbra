class Workout {
  final String id;
  final String userId;
  final String? name;
  final DateTime workoutDate;
  final String? notes;
  final DateTime createdAt;

  const Workout({
    required this.id,
    required this.userId,
    this.name,
    required this.workoutDate,
    this.notes,
    required this.createdAt,
  });

  /// Display label — falls back to a date-based label if no name was set.
  String get displayName {
    if (name != null && name!.trim().isNotEmpty) return name!;
    return 'Workout on ${_formatDate(workoutDate)}';
  }

  static String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  factory Workout.fromJson(Map<String, dynamic> json) {
    return Workout(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String?,
      workoutDate: DateTime.parse(json['workout_date'] as String),
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'name': name,
      'workout_date': workoutDate.toIso8601String().split('T').first,
      'notes': notes,
    };
  }
}
