class Exercise {
  final String id;
  final String externalId;
  final String name;
  final String? category;
  final String? equipment;
  final List<String> primaryMuscles;
  final List<String> secondaryMuscles;
  final List<String> instructions;
  final String? imagePath;

  const Exercise({
    required this.id,
    required this.externalId,
    required this.name,
    this.category,
    this.equipment,
    this.primaryMuscles = const [],
    this.secondaryMuscles = const [],
    this.instructions = const [],
    this.imagePath,
  });

  /// Full hosted image URL, built client-side from the stored relative
  /// path — no image bytes are ever stored in Supabase. Null if the
  /// exercise has no image.
  String? get imageUrl {
    if (imagePath == null || imagePath!.isEmpty) return null;
    return 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/$imagePath';
  }

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'] as String,
      externalId: json['external_id'] as String,
      name: json['name'] as String,
      category: json['category'] as String?,
      equipment: json['equipment'] as String?,
      primaryMuscles: List<String>.from(json['primary_muscles'] ?? const []),
      secondaryMuscles: List<String>.from(
        json['secondary_muscles'] ?? const [],
      ),
      instructions: List<String>.from(json['instructions'] ?? const []),
      imagePath: json['image_path'] as String?,
    );
  }
}
