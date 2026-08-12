import '../../../core/supabase_client.dart';
import '../models/note.dart';
import '../models/note_folder.dart';

/// Thrown by [NotesService] with a user-facing message. Callers should
/// catch this specifically (not the raw Supabase/network exception) and
/// show `e.message` directly — see the resilience pattern in the project
/// brief.
class NotesException implements Exception {
  final String message;
  NotesException(this.message);

  @override
  String toString() => message;
}

/// All Notes sub-app Supabase access. Isolated to the `notes` Postgres
/// schema — never touches `public`. See `supabase/notes_schema.sql` for
/// the schema this expects to exist.
class NotesService {
  static const _schema = 'notes';
  static const _timeout = Duration(seconds: 10);

  static String get _userId {
    final id = SupabaseService.client.auth.currentUser?.id;
    if (id == null) {
      throw NotesException('You need to be signed in to use Notes.');
    }
    return id;
  }

  // ---- Folders ----------------------------------------------------------

  static Future<List<NoteFolder>> fetchFolders() async {
    try {
      final data = await SupabaseService.client
          .schema(_schema)
          .from('folders')
          .select()
          .order('name')
          .timeout(_timeout);
      return (data as List)
          .map((row) => NoteFolder.fromMap(row as Map<String, dynamic>))
          .toList();
    } on NotesException {
      rethrow;
    } catch (_) {
      throw NotesException(
        'Could not load folders. Check your connection and try again.',
      );
    }
  }

  static Future<NoteFolder> createFolder(String name) async {
    try {
      final data = await SupabaseService.client
          .schema(_schema)
          .from('folders')
          .insert({'name': name, 'user_id': _userId})
          .select()
          .single()
          .timeout(_timeout);
      return NoteFolder.fromMap(data);
    } on NotesException {
      rethrow;
    } catch (_) {
      throw NotesException('Could not create the folder. Try again.');
    }
  }

  static Future<void> deleteFolder(String id) async {
    try {
      await SupabaseService.client
          .schema(_schema)
          .from('folders')
          .delete()
          .eq('id', id)
          .timeout(_timeout);
    } on NotesException {
      rethrow;
    } catch (_) {
      throw NotesException('Could not delete the folder. Try again.');
    }
  }

  // ---- Notes --------------------------------------------------------------

  /// [folderId] null = "All Notes" (every note owned by the user).
  static Future<List<Note>> fetchNotes({String? folderId}) async {
    try {
      var query = SupabaseService.client.schema(_schema).from('notes').select();
      if (folderId != null) {
        query = query.eq('folder_id', folderId);
      }
      final data = await query
          .order('pinned', ascending: false)
          .order('updated_at', ascending: false)
          .timeout(_timeout);
      return (data as List)
          .map((row) => Note.fromMap(row as Map<String, dynamic>))
          .toList();
    } on NotesException {
      rethrow;
    } catch (_) {
      throw NotesException(
        'Could not load notes. Check your connection and try again.',
      );
    }
  }

  static Future<Note> createNote({String? folderId}) async {
    try {
      final data = await SupabaseService.client
          .schema(_schema)
          .from('notes')
          .insert({
            'user_id': _userId,
            'folder_id': folderId,
            'title': '',
            'body': '',
          })
          .select()
          .single()
          .timeout(_timeout);
      return Note.fromMap(data);
    } on NotesException {
      rethrow;
    } catch (_) {
      throw NotesException('Could not create the note. Try again.');
    }
  }

  static Future<Note> updateNote(Note note) async {
    try {
      final data = await SupabaseService.client
          .schema(_schema)
          .from('notes')
          .update({
            'title': note.title,
            'body': note.body,
            'folder_id': note.folderId,
            'pinned': note.pinned,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', note.id)
          .select()
          .single()
          .timeout(_timeout);
      return Note.fromMap(data);
    } on NotesException {
      rethrow;
    } catch (_) {
      throw NotesException('Could not save the note. Try again.');
    }
  }

  static Future<void> deleteNote(String id) async {
    try {
      await SupabaseService.client
          .schema(_schema)
          .from('notes')
          .delete()
          .eq('id', id)
          .timeout(_timeout);
    } on NotesException {
      rethrow;
    } catch (_) {
      throw NotesException('Could not delete the note. Try again.');
    }
  }
}
