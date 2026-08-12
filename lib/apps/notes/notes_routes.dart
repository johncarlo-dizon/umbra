import 'package:go_router/go_router.dart';

import 'models/note.dart';
import 'screens/note_detail_screen.dart';
import 'screens/notes_home_screen.dart';

/// Spread this into core/router.dart's routes list: `...notesRoutes`.
final List<RouteBase> notesRoutes = [
  GoRoute(path: '/notes', builder: (context, state) => const NotesHomeScreen()),
  GoRoute(
    path: '/notes/detail',
    builder: (context, state) => NoteDetailScreen(note: state.extra as Note),
  ),
];
