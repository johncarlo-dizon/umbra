class Note {
  final String id;
  final String userId;
  final String? folderId;
  final String title;
  final String body;
  final bool pinned;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Note({
    required this.id,
    required this.userId,
    required this.folderId,
    required this.title,
    required this.body,
    required this.pinned,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      folderId: map['folder_id'] as String?,
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      pinned: map['pinned'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Note copyWith({
    String? folderId,
    bool clearFolderId = false,
    String? title,
    String? body,
    bool? pinned,
  }) {
    return Note(
      id: id,
      userId: userId,
      folderId: clearFolderId ? null : (folderId ?? this.folderId),
      title: title ?? this.title,
      body: body ?? this.body,
      pinned: pinned ?? this.pinned,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
