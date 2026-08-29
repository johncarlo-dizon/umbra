import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/profile.dart';
import '../services/social_service.dart';
import '../widgets/social_avatar.dart';
import '../widgets/social_top_bar.dart';

enum _LoadState { loading, loaded, error }

enum FollowListMode { followers, following }

class FollowListScreen extends StatefulWidget {
  final String userId;
  final FollowListMode mode;

  const FollowListScreen({super.key, required this.userId, required this.mode});

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  _LoadState _state = _LoadState.loading;
  String? _errorMessage;
  List<Profile> _profiles = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _state = _LoadState.loading);
    try {
      final profiles = widget.mode == FollowListMode.followers
          ? await SocialService.fetchFollowerProfiles(widget.userId)
          : await SocialService.fetchFollowingProfiles(widget.userId);
      setState(() {
        _profiles = profiles;
        _state = _LoadState.loaded;
      });
    } on SocialException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _state = _LoadState.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.mode == FollowListMode.followers
        ? 'Followers'
        : 'Following';
    return Scaffold(
      appBar: const SocialTopBar(),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Expanded(child: _buildBody(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_state) {
      case _LoadState.loading:
        return const Center(child: CircularProgressIndicator());
      case _LoadState.error:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_errorMessage ?? 'Something went wrong.'),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        );
      case _LoadState.loaded:
        if (_profiles.isEmpty) {
          return Center(
            child: Text(
              widget.mode == FollowListMode.followers
                  ? 'No followers yet.'
                  : 'Not following anyone yet.',
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: _profiles.length,
          separatorBuilder: (_, __) => const SizedBox(height: 4),
          itemBuilder: (context, i) {
            final p = _profiles[i];
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
