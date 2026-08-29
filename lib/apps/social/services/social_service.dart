import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase_client.dart';
import '../models/post.dart';
import '../models/comment.dart';
import '../models/profile_stats.dart';
import '../models/profile.dart';
import '../models/app_notification.dart';

/// Thrown by every SocialService method on failure, with a message
/// safe to show directly in the UI's error state.
class SocialException implements Exception {
  final String message;
  SocialException(this.message);
  @override
  String toString() => message;
}

const _timeout = Duration(seconds: 10);
const _schema = 'social';
const _imagesBucket = 'social-images';

class SocialService {
  SocialService._();

  static SupabaseClient get _client => SupabaseService.client;

  /// Last-known-good feed, used as an offline fallback by the UI.
  static List<Post>? cachedFeed;

  static String? get _myUserId => SupabaseService.currentSession?.user.id;

  // ---------------- Feed ----------------

  static Future<List<Post>> fetchFeed({int limit = 30}) async {
    try {
      final rows = await _client
          .schema(_schema)
          .from('posts')
          .select(
            '*, likes(user_id), comments(id), post_images(image_path, position)',
          )
          .order('created_at', ascending: false)
          .limit(limit)
          .timeout(_timeout);

      final posts = (rows as List)
          .map(
            (r) => Post.fromRow(r as Map<String, dynamic>, myUserId: _myUserId),
          )
          .toList();

      cachedFeed = posts; // update offline fallback on success
      return posts;
    } on TimeoutException {
      throw SocialException('Request timed out. Check your connection.');
    } catch (e) {
      throw SocialException('Could not load the feed. ($e)');
    }
  }

  static Future<Post> fetchPost(String postId) async {
    try {
      final row = await _client
          .schema(_schema)
          .from('posts')
          .select(
            '*, likes(user_id), comments(id), post_images(image_path, position)',
          )
          .eq('id', postId)
          .single()
          .timeout(_timeout);

      return Post.fromRow(row, myUserId: _myUserId);
    } on TimeoutException {
      throw SocialException('Request timed out. Check your connection.');
    } catch (e) {
      throw SocialException('Could not load post. ($e)');
    }
  }

  static Future<List<Post>> fetchUserPosts(String userId) async {
    try {
      final rows = await _client
          .schema(_schema)
          .from('posts')
          .select(
            '*, likes(user_id), comments(id), post_images(image_path, position)',
          )
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .timeout(_timeout);

      return (rows as List)
          .map(
            (r) => Post.fromRow(r as Map<String, dynamic>, myUserId: _myUserId),
          )
          .toList();
    } on TimeoutException {
      throw SocialException('Request timed out. Check your connection.');
    } catch (e) {
      throw SocialException('Could not load posts. ($e)');
    }
  }

  /// Max images per post, enforced client-side (composer) — no DB-level cap.
  static const maxImagesPerPost = 10;

  static Future<Post> createPost({
    required String body,
    List<String> imagePaths = const [],
  }) async {
    final userId = _myUserId;
    if (userId == null) throw SocialException('You must be signed in to post.');

    try {
      final row = await _client
          .schema(_schema)
          .from('posts')
          .insert({'user_id': userId, 'body': body})
          .select()
          .single()
          .timeout(_timeout);

      final postId = row['id'] as String;

      if (imagePaths.isNotEmpty) {
        await _client
            .schema(_schema)
            .from('post_images')
            .insert([
              for (var i = 0; i < imagePaths.length; i++)
                {'post_id': postId, 'image_path': imagePaths[i], 'position': i},
            ])
            .timeout(_timeout);
      }

      return Post.fromRow(row, myUserId: userId).copyWithImages(imagePaths);
    } on TimeoutException {
      throw SocialException('Request timed out. Try again.');
    } catch (e) {
      throw SocialException('Could not create post. ($e)');
    }
  }

  /// Text-only edit — this app doesn't support adding/removing images
  /// on an existing post, only on creation. The returned Post has no
  /// author display info populated (this query doesn't join profiles);
  /// callers should copy that over from the pre-edit Post they already
  /// have, same as elsewhere in this file.
  static Future<Post> updatePost(String postId, {required String body}) async {
    final userId = _myUserId;
    if (userId == null) throw SocialException('You must be signed in.');

    try {
      final row = await _client
          .schema(_schema)
          .from('posts')
          .update({'body': body})
          .eq('id', postId)
          .eq('user_id', userId)
          .select(
            '*, likes(user_id), comments(id), post_images(image_path, position)',
          )
          .single()
          .timeout(_timeout);

      return Post.fromRow(row, myUserId: userId);
    } on TimeoutException {
      throw SocialException('Request timed out. Try again.');
    } catch (e) {
      throw SocialException('Could not update post. ($e)');
    }
  }

  /// [imagePaths] triggers a best-effort storage cleanup — non-fatal if
  /// it fails, since the actual post row (and its post_images rows, via
  /// cascade) are what matter and get deleted regardless.
  static Future<void> deletePost(
    String postId, {
    List<String> imagePaths = const [],
  }) async {
    final userId = _myUserId;
    if (userId == null) throw SocialException('You must be signed in.');

    if (imagePaths.isNotEmpty) {
      try {
        await _client.storage.from(_imagesBucket).remove(imagePaths);
      } catch (_) {
        // Non-fatal — an orphaned storage file isn't worth failing the
        // whole delete over.
      }
    }

    try {
      await _client
          .schema(_schema)
          .from('posts')
          .delete()
          .eq('id', postId)
          .eq('user_id', userId)
          .timeout(_timeout);
    } on TimeoutException {
      throw SocialException('Request timed out. Try again.');
    } catch (e) {
      throw SocialException('Could not delete post. ($e)');
    }
  }

  /// [kind] is folded into the filename (not a subfolder) so the storage
  /// RLS policy — which checks the first path segment equals the user's
  /// id — still applies unchanged to both post images and avatars.
  static Future<String> uploadImage(
    List<int> bytes,
    String fileExtension, {
    String kind = 'post',
  }) async {
    final userId = _myUserId;
    if (userId == null)
      throw SocialException('You must be signed in to upload.');

    final path =
        '$userId/${kind}_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
    try {
      await _client.storage
          .from(_imagesBucket)
          .uploadBinary(path, bytes as dynamic)
          .timeout(_timeout);
      return path;
    } on TimeoutException {
      throw SocialException('Image upload timed out.');
    } catch (e) {
      throw SocialException('Could not upload image. ($e)');
    }
  }

  static String imageUrl(String imagePath) {
    return _client.storage.from(_imagesBucket).getPublicUrl(imagePath);
  }

  // ---------------- Profiles ----------------

  /// Live-updating cache of the signed-in user's own profile, so any
  /// screen's header can show your avatar without re-fetching it —
  /// same ValueNotifier pattern as AppSettingsState in core/.
  static final ValueNotifier<Profile?> myProfileNotifier =
      ValueNotifier<Profile?>(null);

  /// Upserts a profile row for the current user if one doesn't exist yet.
  /// Safe to call repeatedly (e.g. every time Social opens) — a no-op
  /// if a profile already exists, since it only sets defaults on insert.
  /// Always refreshes myProfileNotifier on success.
  static Future<void> ensureProfile() async {
    final userId = _myUserId;
    if (userId == null) return;

    try {
      final existing = await _client
          .schema(_schema)
          .from('profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle()
          .timeout(_timeout);

      if (existing == null) {
        final row = await _client
            .schema(_schema)
            .from('profiles')
            .insert({'user_id': userId})
            .select()
            .single()
            .timeout(_timeout);
        myProfileNotifier.value = Profile.fromRow(row);
      } else {
        myProfileNotifier.value = Profile.fromRow(existing);
      }
    } catch (_) {
      // Non-fatal — UI just falls back to initials badges if this fails.
    }
  }

  static Future<Profile> fetchProfile(String userId) async {
    try {
      final row = await _client
          .schema(_schema)
          .from('profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle()
          .timeout(_timeout);

      final profile = row == null
          ? Profile.fallback(userId)
          : Profile.fromRow(row);
      if (userId == _myUserId) myProfileNotifier.value = profile;
      return profile;
    } on TimeoutException {
      throw SocialException('Request timed out. Check your connection.');
    } catch (e) {
      throw SocialException('Could not load profile. ($e)');
    }
  }

  /// Batch fetch — used by the feed and comment threads to resolve display
  /// names/avatars for many authors in one round trip.
  static Future<Map<String, Profile>> fetchProfilesByIds(
    Iterable<String> userIds,
  ) async {
    final ids = userIds.toSet().toList();
    if (ids.isEmpty) return {};

    try {
      final rows = await _client
          .schema(_schema)
          .from('profiles')
          .select()
          .inFilter('user_id', ids)
          .timeout(_timeout);

      final map = <String, Profile>{
        for (final r in (rows as List))
          (r as Map<String, dynamic>)['user_id'] as String: Profile.fromRow(r),
      };
      // Anyone without a profile row yet gets the fallback.
      for (final id in ids) {
        map.putIfAbsent(id, () => Profile.fallback(id));
      }
      return map;
    } on TimeoutException {
      throw SocialException('Request timed out. Check your connection.');
    } catch (e) {
      // Non-fatal for the caller's overall load — fall back for everyone
      // rather than failing the whole feed over a display-name lookup.
      return {for (final id in ids) id: Profile.fallback(id)};
    }
  }

  static Future<void> updateProfile({
    String? displayName,
    String? avatarPath,
    String? bio,
  }) async {
    final userId = _myUserId;
    if (userId == null) throw SocialException('You must be signed in.');

    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (displayName != null) updates['display_name'] = displayName;
    if (avatarPath != null) updates['avatar_path'] = avatarPath;
    if (bio != null) updates['bio'] = bio;

    try {
      final row = await _client
          .schema(_schema)
          .from('profiles')
          .upsert({'user_id': userId, ...updates})
          .select()
          .single()
          .timeout(_timeout);
      myProfileNotifier.value = Profile.fromRow(row);
    } on TimeoutException {
      throw SocialException('Request timed out. Try again.');
    } catch (e) {
      throw SocialException('Could not update profile. ($e)');
    }
  }

  // ---------------- Likes ----------------

  static Future<void> toggleLike(
    String postId,
    bool currentlyLiked, {
    String? postOwnerId,
  }) async {
    final userId = _myUserId;
    if (userId == null)
      throw SocialException('You must be signed in to like posts.');

    try {
      if (currentlyLiked) {
        await _client
            .schema(_schema)
            .from('likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', userId)
            .timeout(_timeout);
      } else {
        await _client
            .schema(_schema)
            .from('likes')
            .insert({'post_id': postId, 'user_id': userId})
            .timeout(_timeout);
        if (postOwnerId != null) {
          _createNotification(
            recipientId: postOwnerId,
            type: 'like_post',
            postId: postId,
          );
        }
      }
    } on TimeoutException {
      throw SocialException('Request timed out. Try again.');
    } catch (e) {
      throw SocialException('Could not update like. ($e)');
    }
  }

  // ---------------- Comments ----------------

  static Future<List<Comment>> fetchComments(String postId) async {
    try {
      final rows = await _client
          .schema(_schema)
          .from('comments')
          .select('*, comment_likes(user_id)')
          .eq('post_id', postId)
          .order('created_at', ascending: true)
          .timeout(_timeout);

      return (rows as List)
          .map(
            (r) =>
                Comment.fromRow(r as Map<String, dynamic>, myUserId: _myUserId),
          )
          .toList();
    } on TimeoutException {
      throw SocialException('Request timed out. Check your connection.');
    } catch (e) {
      throw SocialException('Could not load comments. ($e)');
    }
  }

  /// [parentCommentId] set = this is a reply. The DB enforces only one
  /// level of nesting (a reply's parent can't itself be a reply).
  /// [notifyUserId] is the recipient of the resulting notification — the
  /// post owner for a top-level comment, or the parent comment's author
  /// for a reply. Passed in explicitly by the caller rather than looked
  /// up here, since callers already have that id on hand.
  static Future<Comment> addComment(
    String postId,
    String body, {
    String? parentCommentId,
    String? imagePath,
    String? notifyUserId,
  }) async {
    final userId = _myUserId;
    if (userId == null)
      throw SocialException('You must be signed in to comment.');

    try {
      final row = await _client
          .schema(_schema)
          .from('comments')
          .insert({
            'post_id': postId,
            'user_id': userId,
            'body': body,
            if (parentCommentId != null) 'parent_comment_id': parentCommentId,
            if (imagePath != null) 'image_path': imagePath,
          })
          .select()
          .single()
          .timeout(_timeout);

      if (notifyUserId != null) {
        _createNotification(
          recipientId: notifyUserId,
          type: parentCommentId != null ? 'reply_comment' : 'comment_post',
          postId: postId,
          commentId: row['id'] as String,
        );
      }

      return Comment.fromRow(row, myUserId: userId);
    } on TimeoutException {
      throw SocialException('Request timed out. Try again.');
    } catch (e) {
      throw SocialException('Could not post comment. ($e)');
    }
  }

  static Future<void> toggleCommentLike(
    String commentId,
    bool currentlyLiked, {
    String? commentOwnerId,
    String? postId,
  }) async {
    final userId = _myUserId;
    if (userId == null)
      throw SocialException('You must be signed in to like comments.');

    try {
      if (currentlyLiked) {
        await _client
            .schema(_schema)
            .from('comment_likes')
            .delete()
            .eq('comment_id', commentId)
            .eq('user_id', userId)
            .timeout(_timeout);
      } else {
        await _client
            .schema(_schema)
            .from('comment_likes')
            .insert({'comment_id': commentId, 'user_id': userId})
            .timeout(_timeout);
        if (commentOwnerId != null) {
          _createNotification(
            recipientId: commentOwnerId,
            type: 'like_comment',
            commentId: commentId,
            postId: postId,
          );
        }
      }
    } on TimeoutException {
      throw SocialException('Request timed out. Try again.');
    } catch (e) {
      throw SocialException('Could not update like. ($e)');
    }
  }

  // ---------------- Follows ----------------

  static Future<void> follow(String targetUserId) async {
    final userId = _myUserId;
    if (userId == null)
      throw SocialException('You must be signed in to follow.');

    try {
      await _client
          .schema(_schema)
          .from('follows')
          .insert({'follower_id': userId, 'following_id': targetUserId})
          .timeout(_timeout);
      _createNotification(recipientId: targetUserId, type: 'follow');
    } on TimeoutException {
      throw SocialException('Request timed out. Try again.');
    } catch (e) {
      throw SocialException('Could not follow user. ($e)');
    }
  }

  static Future<void> unfollow(String targetUserId) async {
    final userId = _myUserId;
    if (userId == null) throw SocialException('You must be signed in.');

    try {
      await _client
          .schema(_schema)
          .from('follows')
          .delete()
          .eq('follower_id', userId)
          .eq('following_id', targetUserId)
          .timeout(_timeout);
    } on TimeoutException {
      throw SocialException('Request timed out. Try again.');
    } catch (e) {
      throw SocialException('Could not unfollow user. ($e)');
    }
  }

  static Future<ProfileStats> fetchProfileStats(String userId) async {
    try {
      final followers = await _client
          .schema(_schema)
          .from('follows')
          .select('id')
          .eq('following_id', userId)
          .timeout(_timeout);

      final following = await _client
          .schema(_schema)
          .from('follows')
          .select('id')
          .eq('follower_id', userId)
          .timeout(_timeout);

      final posts = await _client
          .schema(_schema)
          .from('posts')
          .select('id')
          .eq('user_id', userId)
          .timeout(_timeout);

      bool followedByMe = false;
      final me = _myUserId;
      if (me != null && me != userId) {
        final edge = await _client
            .schema(_schema)
            .from('follows')
            .select('id')
            .eq('follower_id', me)
            .eq('following_id', userId)
            .maybeSingle()
            .timeout(_timeout);
        followedByMe = edge != null;
      }

      return ProfileStats(
        userId: userId,
        followerCount: (followers as List).length,
        followingCount: (following as List).length,
        postCount: (posts as List).length,
        followedByMe: followedByMe,
      );
    } on TimeoutException {
      throw SocialException('Request timed out. Check your connection.');
    } catch (e) {
      throw SocialException('Could not load profile. ($e)');
    }
  }

  /// Profiles of everyone following [userId].
  static Future<List<Profile>> fetchFollowerProfiles(String userId) async {
    try {
      final edges = await _client
          .schema(_schema)
          .from('follows')
          .select('follower_id')
          .eq('following_id', userId)
          .timeout(_timeout);

      final ids = (edges as List).map(
        (e) => (e as Map<String, dynamic>)['follower_id'] as String,
      );
      final profiles = await fetchProfilesByIds(ids);
      return profiles.values.toList();
    } on TimeoutException {
      throw SocialException('Request timed out. Check your connection.');
    } catch (e) {
      throw SocialException('Could not load followers. ($e)');
    }
  }

  /// Profiles of everyone [userId] follows.
  static Future<List<Profile>> fetchFollowingProfiles(String userId) async {
    try {
      final edges = await _client
          .schema(_schema)
          .from('follows')
          .select('following_id')
          .eq('follower_id', userId)
          .timeout(_timeout);

      final ids = (edges as List).map(
        (e) => (e as Map<String, dynamic>)['following_id'] as String,
      );
      final profiles = await fetchProfilesByIds(ids);
      return profiles.values.toList();
    } on TimeoutException {
      throw SocialException('Request timed out. Check your connection.');
    } catch (e) {
      throw SocialException('Could not load following. ($e)');
    }
  }

  // ---------------- Search ----------------

  /// Matches on display name only — post search isn't implemented yet.
  static Future<List<Profile>> searchProfiles(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    try {
      final rows = await _client
          .schema(_schema)
          .from('profiles')
          .select()
          .ilike('display_name', '%$trimmed%')
          .limit(20)
          .timeout(_timeout);

      return (rows as List)
          .map((r) => Profile.fromRow(r as Map<String, dynamic>))
          .toList();
    } on TimeoutException {
      throw SocialException('Request timed out. Check your connection.');
    } catch (e) {
      throw SocialException('Search failed. ($e)');
    }
  }

  // ---------------- Notifications ----------------

  /// Fire-and-forget on purpose — a failed notification insert should
  /// never block the like/comment/follow action that triggered it.
  /// Never notifies yourself (e.g. liking or commenting on your own post).
  static void _createNotification({
    required String recipientId,
    required String type,
    String? postId,
    String? commentId,
  }) {
    final actorId = _myUserId;
    if (actorId == null || actorId == recipientId) return;

    _client
        .schema(_schema)
        .from('notifications')
        .insert({
          'user_id': recipientId,
          'actor_id': actorId,
          'type': type,
          if (postId != null) 'post_id': postId,
          if (commentId != null) 'comment_id': commentId,
        })
        .then(
          (_) {},
          onError: (_) {
            // Non-fatal — see doc comment above.
          },
        );
  }

  static Future<List<AppNotification>> fetchNotifications({
    int limit = 50,
  }) async {
    final userId = _myUserId;
    if (userId == null) return [];

    try {
      final rows = await _client
          .schema(_schema)
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit)
          .timeout(_timeout);

      final notifications = (rows as List)
          .map((r) => AppNotification.fromRow(r as Map<String, dynamic>))
          .toList();

      final profiles = await fetchProfilesByIds(
        notifications.map((n) => n.actorId),
      );

      return notifications.map((n) {
        final profile = profiles[n.actorId];
        if (profile == null) return n;
        return n.withActor(
          displayName: profile.displayName,
          avatarPath: profile.avatarPath,
        );
      }).toList();
    } on TimeoutException {
      throw SocialException('Request timed out. Check your connection.');
    } catch (e) {
      throw SocialException('Could not load notifications. ($e)');
    }
  }

  static Future<int> unreadNotificationCount() async {
    final userId = _myUserId;
    if (userId == null) return 0;

    try {
      final rows = await _client
          .schema(_schema)
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('read', false)
          .timeout(_timeout);
      return (rows as List).length;
    } catch (_) {
      return 0; // non-fatal — badge just shows nothing if this fails
    }
  }

  static Future<void> markAllNotificationsRead() async {
    final userId = _myUserId;
    if (userId == null) return;

    try {
      await _client
          .schema(_schema)
          .from('notifications')
          .update({'read': true})
          .eq('user_id', userId)
          .eq('read', false)
          .timeout(_timeout);
    } catch (_) {
      // Non-fatal — worst case the badge count is stale until next fetch.
    }
  }
}
