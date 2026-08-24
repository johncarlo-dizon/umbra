import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/profile.dart';
import '../services/social_service.dart';
import '../widgets/social_avatar.dart';

enum _SearchState { idle, loading, loaded, error }

/// Full-screen search, opened by tapping the search field in the top
/// bar. Currently matches on display name only — post search isn't
/// built yet, flagged here rather than silently doing nothing.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  _SearchState _state = _SearchState.idle;
  List<Profile> _results = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _state = _SearchState.idle;
        _results = [];
      });
      return;
    }
    setState(() => _state = _SearchState.loading);
    try {
      final results = await SocialService.searchProfiles(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _state = _SearchState.loaded;
      });
    } on SocialException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _state = _SearchState.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: TextField(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: _search,
          decoration: const InputDecoration(
            hintText: 'Search people on FriendBook',
            border: InputBorder.none,
          ),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: _buildBody(context, colorScheme),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ColorScheme colorScheme) {
    switch (_state) {
      case _SearchState.idle:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Search for people by name.\n(Post search isn\'t available yet.)',
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ),
        );
      case _SearchState.loading:
        return const Center(child: CircularProgressIndicator());
      case _SearchState.error:
        return Center(child: Text(_errorMessage ?? 'Something went wrong.'));
      case _SearchState.loaded:
        if (_results.isEmpty) {
          return const Center(child: Text('No matches.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _results.length,
          itemBuilder: (context, i) {
            final p = _results[i];
            return ListTile(
              leading: SocialAvatar(
                avatarPath: p.avatarPath,
                userId: p.userId,
                displayName: p.displayName,
                radius: 20,
              ),
              title: Text(p.displayName),
              subtitle: p.bio != null && p.bio!.trim().isNotEmpty
                  ? Text(p.bio!, maxLines: 1, overflow: TextOverflow.ellipsis)
                  : null,
              onTap: () => context.push('/social/profile/${p.userId}'),
            );
          },
        );
    }
  }
}
