import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/supabase_client.dart';
import '../models/profile.dart';
import '../services/social_service.dart';
import '../widgets/social_avatar.dart';
import '../theme/friendbook_colors.dart';

class _PickedImage {
  final XFile file;
  final Uint8List bytes;
  _PickedImage(this.file, this.bytes);
}

/// Full-screen post composer, pushed as its own route (not a bottom sheet)
/// to match Facebook's "What's on your mind?" composer. Pops with `true`
/// if a post was created, so the feed knows to refresh.
class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _controller = TextEditingController();
  final _picker = ImagePicker();
  final _focusNode = FocusNode();
  bool _submitting = false;
  String? _error;
  final List<_PickedImage> _images = [];
  Profile? _myProfile;

  @override
  void initState() {
    super.initState();
    _loadMyProfile();
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

  String? get _myUserId => SupabaseService.currentSession?.user.id;

  Future<void> _loadMyProfile() async {
    final userId = _myUserId;
    if (userId == null) return;
    try {
      final profile = await SocialService.fetchProfile(userId);
      if (mounted) setState(() => _myProfile = profile);
    } on SocialException {
      // Non-fatal — header just falls back to an initials badge.
    }
  }

  int get _remainingSlots => SocialService.maxImagesPerPost - _images.length;

  Future<void> _pickImages() async {
    if (_remainingSlots <= 0) return;
    try {
      final files = await _picker.pickMultiImage(
        maxWidth: 1600,
        imageQuality: 85,
        limit: _remainingSlots,
      );
      if (files.isEmpty) return;
      final toAdd = files.take(_remainingSlots);
      final loaded = await Future.wait(
        toAdd.map((f) async => _PickedImage(f, await f.readAsBytes())),
      );
      setState(() => _images.addAll(loaded));
    } catch (e) {
      setState(() => _error = 'Could not open image picker. ($e)');
    }
  }

  void _removeImageAt(int index) {
    setState(() => _images.removeAt(index));
  }

  String _extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    if (dot == -1 || dot == path.length - 1) return 'jpg';
    return path.substring(dot + 1).toLowerCase();
  }

  bool get _canPost => _controller.text.trim().isNotEmpty && !_submitting;

  Future<void> _submit() async {
    final body = _controller.text.trim();
    if (body.isEmpty) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final imagePaths = <String>[];
      for (final img in _images) {
        final path = await SocialService.uploadImage(
          img.bytes,
          _extensionOf(img.file.path),
          kind: 'post',
        );
        imagePaths.add(path);
      }
      await SocialService.createPost(body: body, imagePaths: imagePaths);
      if (mounted) Navigator.of(context).pop(true);
    } on SocialException catch (e) {
      setState(() {
        _error = e.message;
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final userId = _myUserId;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: const Text('Create post'),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: kFriendBookBlue,
                              width: 2,
                            ),
                          ),
                          child: SocialAvatar(
                            avatarPath: _myProfile?.avatarPath,
                            userId: userId ?? '',
                            displayName: _myProfile?.displayName ?? 'You',
                            radius: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _myProfile?.displayName ?? 'You',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.public,
                                    size: 12,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Public',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      maxLines: null,
                      minLines: 4,
                      maxLength: 2000,
                      style: Theme.of(context).textTheme.headlineSmall,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: "What's on your mind?",
                        hintStyle: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var i = 0; i < _images.length; i++)
                          Stack(
                            alignment: Alignment.topRight,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.memory(
                                  _images[i].bytes,
                                  width: 90,
                                  height: 90,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              IconButton.filled(
                                onPressed: () => _removeImageAt(i),
                                icon: const Icon(Icons.close, size: 14),
                                constraints: const BoxConstraints(
                                  minWidth: 26,
                                  minHeight: 26,
                                ),
                                padding: EdgeInsets.zero,
                                style: IconButton.styleFrom(
                                  backgroundColor: colorScheme.surface
                                      .withValues(alpha: 0.85),
                                  foregroundColor: colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        if (_remainingSlots > 0)
                          InkWell(
                            onTap: _pickImages,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: kFriendBookBlue.withValues(alpha: 0.06),
                                border: Border.all(
                                  color: kFriendBookBlue.withValues(alpha: 0.4),
                                  style: BorderStyle.solid,
                                ),
                              ),
                              child: Icon(
                                Icons.add_photo_alternate_outlined,
                                color: kFriendBookBlue,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: TextStyle(color: colorScheme.error)),
                    ],
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    border: Border(
                      top: BorderSide(color: colorScheme.outlineVariant),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.photo_library_outlined,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _images.isEmpty
                            ? 'No images added'
                            : '${_images.length} of ${SocialService.maxImagesPerPost} images added',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: _canPost ? _submit : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: kFriendBookBlue,
                          foregroundColor: kFriendBookOnBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 10,
                          ),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Post'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
