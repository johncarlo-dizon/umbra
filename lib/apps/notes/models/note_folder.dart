class NoteFolder {
  final String id;
  final String userId;
  final String name;
  final DateTime createdAt;

  const NoteFolder({
    required this.id,
    required this.userId,
    required this.name,
    required this.createdAt,
  });

  factory NoteFolder.fromMap(Map<String, dynamic> map) {
    return NoteFolder(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      name: map['name'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
