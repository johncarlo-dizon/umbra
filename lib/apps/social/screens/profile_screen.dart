import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/supabase_client.dart';
import '../models/post.dart';
import '../models/profile.dart';
import '../models/profile_stats.dart';
import '../services/social_service.dart';
import '../utils/format_count.dart';
import '../widgets/social_avatar.dart';
import '../widgets/social_top_bar.dart';
import '../widgets/post_card.dart';

enum _LoadState { loading, loaded, error }

class ProfileScreen extends StatefulWidget {
  final String userId;
  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  _LoadState _state = _LoadState.loading;
  String? _errorMessage;
  ProfileStats? _stats;
  Profile? _profile;
  List<Post> _posts = [];
  bool _followBusy = false;

  bool get _isMe => SupabaseService.currentSession?.user.id == widget.userId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _state = _LoadState.loading);
    try {
      final stats = await SocialService.fetchProfileStats(widget.userId);
      final profile = await SocialService.fetchProfile(widget.userId);
      final posts = await SocialService.fetchUserPosts(widget.userId);
      setState(() {
        _stats = stats;
        _profile = profile;
        // Every post here is authored by the same profile we just loaded,
        // so stamp it in directly rather than a second batch profile
        // fetch — keeps the cards identical to how they render in Feed.
        _posts = posts
            .map(
              (p) => p.copyWith(
                authorDisplayName: profile.displayName,
                authorAvatarPath: profile.avatarPath,
              ),
            )
            .toList();
        _state = _LoadState.loaded;
      });
    } on SocialException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _state = _LoadState.error;
      });
    }
  }

  Future<void> _toggleLike(Post post) async {
    final wasLiked = post.likedByMe;
    setState(() {
      final idx = _posts.indexWhere((p) => p.id == post.id);
      _posts[idx] = post.copyWith(
        likedByMe: !wasLiked,
        likeCount: wasLiked ? post.likeCount - 1 : post.likeCount + 1,
      );
    });
    try {
      await SocialService.toggleLike(post.id, wasLiked);
    } on SocialException {
      setState(() {
        final idx = _posts.indexWhere((p) => p.id == post.id);
        _posts[idx] = post;
      });
    }
  }

  void _sharePost(Post post) {
    Clipboard.setData(ClipboardData(text: '/social/post/${post.id}'));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Link copied')));
  }

  Future<void> _toggleFollow() async {
    if (_stats == null || _followBusy) return;
    setState(() => _followBusy = true);
    final wasFollowing = _stats!.followedByMe;
    try {
      if (wasFollowing) {
        await SocialService.unfollow(widget.userId);
      } else {
        await SocialService.follow(widget.userId);
      }
      setState(() {
        _stats = ProfileStats(
          userId: _stats!.userId,
          followerCount: _stats!.followerCount + (wasFollowing ? -1 : 1),
          followingCount: _stats!.followingCount,
          postCount: _stats!.postCount,
          followedByMe: !wasFollowing,
        );
        _followBusy = false;
      });
    } on SocialException catch (e) {
      setState(() => _followBusy = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _openEditProfile() async {
    final changed = await context.push<bool>('/social/profile/edit');
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SocialTopBar(),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: _buildBody(context),
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
        final stats = _stats!;
        final profile = _profile!;
        final colorScheme = Theme.of(context).colorScheme;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: SocialAvatar(
                avatarPath: profile.avatarPath,
                userId: profile.userId,
                displayName: profile.displayName,
                radius: 44,
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                profile.displayName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (profile.bio != null && profile.bio!.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Center(
                child: Text(
                  profile.bio!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Posts',
                    value: formatCount(stats.postCount),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    label: 'Followers',
                    value: formatCount(stats.followerCount),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    label: 'Following',
                    value: formatCount(stats.followingCount),
                  ),
                ),
              ],
            ),
            if (!_isMe) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: _followBusy ? null : _toggleFollow,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
                child: Text(stats.followedByMe ? 'Unfollow' : 'Follow'),
              ),
            ] else ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _openEditProfile,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit Profile'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  minimumSize: const Size(double.infinity, 0),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Divider(color: colorScheme.outlineVariant),
            const SizedBox(height: 12),
            if (_posts.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('No posts yet.')),
              )
            else
              ..._posts.map(
                (post) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: PostCard(
                    post: post,
                    onLike: _toggleLike,
                    onShare: _sharePost,
                  ),
                ),
              ),
          ],
        );
    }
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(value, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
