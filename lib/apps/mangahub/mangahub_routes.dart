import 'package:go_router/go_router.dart';
import 'screens/mangahub_home_screen.dart';
import 'screens/manga_detail_screen.dart';
import 'screens/manga_reader_screen.dart';
import 'models/reader_args.dart';

final List<RouteBase> mangahubRoutes = [
  GoRoute(
    path: '/mangahub',
    builder: (context, state) => const MangaHubHomeScreen(),
  ),
  GoRoute(
    path: '/mangahub/manga/:id',
    builder: (context, state) {
      final mangaId = state.pathParameters['id']!;
      return MangaDetailScreen(mangaId: mangaId);
    },
  ),
  GoRoute(
    path: '/mangahub/manga/:id/read',
    builder: (context, state) {
      final args = state.extra as ReaderScreenArgs;
      return MangaReaderScreen(
        mangaId: args.mangaId,
        chapters: args.chapters,
        initialChapterIndex: args.initialChapterIndex,
      );
    },
  ),
];
