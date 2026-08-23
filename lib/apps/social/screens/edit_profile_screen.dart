import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/supabase_client.dart';
import '../services/social_service.dart';
import '../widgets/social_avatar.dart';
import '../theme/friendbook_colors.dart';

enum _LoadState { loading, loaded, error }

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  _LoadState _state = _LoadState.loading;
  String? _errorMessage;
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _picker = ImagePicker();

  String? _userId;
  String? _existingAvatarPath;
  Uint8List? _pickedAvatarBytes;
  XFile? _pickedAvatar;
  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final userId = SupabaseService.currentSession?.user.id;
    if (userId == null) {
      setState(() {
        _errorMessage = 'You must be signed in to edit your profile.';
        _state = _LoadState.error;
      });
      return;
    }
    setState(() => _state = _LoadState.loading);
    try {
      final profile = await SocialService.fetchProfile(userId);
      setState(() {
        _userId = userId;
        _nameController.text = profile.displayName;
        _bioController.text = profile.bio ?? '';
        _existingAvatarPath = profile.avatarPath;
        _state = _LoadState.loaded;
      });
    } on SocialException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _state = _LoadState.error;
      });
    }
  }

  Future<void> _pickAvatar() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _pickedAvatar = file;
        _pickedAvatarBytes = bytes;
      });
    } catch (e) {
      setState(() => _saveError = 'Could not open image picker. ($e)');
    }
  }

  String _extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    if (dot == -1 || dot == path.length - 1) return 'jpg';
    return path.substring(dot + 1).toLowerCase();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _saveError = 'Display name cannot be empty.');
      return;
    }

    setState(() {
      _saving = true;
      _saveError = null;
    });

    try {
      String? avatarPath = _existingAvatarPath;
      if (_pickedAvatar != null && _pickedAvatarBytes != null) {
        avatarPath = await SocialService.uploadImage(
          _pickedAvatarBytes!,
          _extensionOf(_pickedAvatar!.path),
          kind: 'avatar',
        );
      }
      await SocialService.updateProfile(
        displayName: name,
        avatarPath: avatarPath,
        bio: _bioController.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on SocialException catch (e) {
      setState(() {
        _saveError = e.message;
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
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
        final colorScheme = Theme.of(context).colorScheme;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Stack(
                children: [
                  _pickedAvatarBytes != null
                      ? ClipOval(
                          child: Image.memory(
                            _pickedAvatarBytes!,
                            width: 96,
                            height: 96,
                            fit: BoxFit.cover,
                          ),
                        )
                      : SocialAvatar(
                          avatarPath: _existingAvatarPath,
                          userId: _userId ?? '',
                          displayName: _nameController.text,
                          radius: 48,
                        ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickAvatar,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(
                            color: colorScheme.surface,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.camera_alt,
                          size: 16,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              maxLength: 60,
              decoration: InputDecoration(
                labelText: 'Display name',
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bioController,
              maxLength: 160,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Bio',
                hintText: 'e.g. Full-stack developer, Pampanga PH',
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            if (_saveError != null) ...[
              const SizedBox(height: 8),
              Text(_saveError!, style: TextStyle(color: colorScheme.error)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: kFriendBookBlue,
                foregroundColor: kFriendBookOnBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        );
    }
  }
}
