import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/shell_nav_state.dart';
import '../../../core/supabase_client.dart';
import '../models/note.dart';
import '../models/note_folder.dart';
import '../services/notes_service.dart';

class NotesHomeScreen extends StatefulWidget {
  const NotesHomeScreen({super.key});

  @override
  State<NotesHomeScreen> createState() => _NotesHomeScreenState();
}

enum _LoadState { loading, loaded, error }

class _NotesHomeScreenState extends State<NotesHomeScreen> {
  _LoadState _state = _LoadState.loading;
  String? _errorMessage;
  List<NoteFolder> _folders = [];
  List<Note> _notes = [];
  String? _selectedFolderId; // null = All Notes
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    if (SupabaseService.isLoggedIn) {
      _load();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _state = _LoadState.loading);
    try {
      final folders = await NotesService.fetchFolders();
      final notes = await NotesService.fetchNotes(folderId: _selectedFolderId);
      if (!mounted) return;
      setState(() {
        _folders = folders;
        _notes = notes;
        _state = _LoadState.loaded;
      });
    } on NotesException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _state = _LoadState.error;
      });
    }
  }

  void _selectFolder(String? folderId) {
    setState(() => _selectedFolderId = folderId);
    _load();
  }

  Future<void> _createFolder() async {
    final name = await _promptForText(
      title: 'New Folder',
      hint: 'Folder name',
      confirmLabel: 'Create',
    );
    if (name == null || name.trim().isEmpty) return;
    try {
      await NotesService.createFolder(name.trim());
      _load();
    } on NotesException catch (e) {
      _showError(e.message);
    }
  }

  Future<void> _createNote() async {
    try {
      final note = await NotesService.createNote(folderId: _selectedFolderId);
      if (!mounted) return;
      await context.push('/notes/detail', extra: note);
      if (mounted) _load();
    } on NotesException catch (e) {
      _showError(e.message);
    }
  }

  Future<void> _openNote(Note note) async {
    await context.push('/notes/detail', extra: note);
    if (mounted) _load();
  }

  Future<void> _togglePin(Note note) async {
    try {
      await NotesService.updateNote(note.copyWith(pinned: !note.pinned));
      _load();
    } on NotesException catch (e) {
      _showError(e.message);
    }
  }

  Future<void> _deleteNote(Note note) async {
    try {
      await NotesService.deleteNote(note.id);
      _load();
    } on NotesException catch (e) {
      _showError(e.message);
      _load(); // undo the optimistic Dismissible removal
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<String?> _promptForText({
    required String title,
    required String hint,
    required String confirmLabel,
  }) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  List<Note> get _visibleNotes {
    if (_searchQuery.trim().isEmpty) return _notes;
    final q = _searchQuery.toLowerCase();
    return _notes
        .where(
          (n) =>
              n.title.toLowerCase().contains(q) ||
              n.body.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!SupabaseService.isLoggedIn) {
      return _SignInPrompt(theme: theme);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Notes')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: _buildBody(theme),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNote,
        tooltip: 'New note',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Search notes',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(26),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _FolderChip(
                label: 'All Notes',
                selected: _selectedFolderId == null,
                onTap: () => _selectFolder(null),
              ),
              for (final f in _folders)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: _FolderChip(
                    label: f.name,
                    selected: _selectedFolderId == f.id,
                    onTap: () => _selectFolder(f.id),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: ActionChip(
                  avatar: const Icon(
                    Icons.create_new_folder_outlined,
                    size: 18,
                  ),
                  label: const Text('New Folder'),
                  onPressed: _createFolder,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: _buildList(theme)),
      ],
    );
  }

  Widget _buildList(ThemeData theme) {
    switch (_state) {
      case _LoadState.loading:
        return const Center(child: CircularProgressIndicator());

      case _LoadState.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off, color: theme.colorScheme.error, size: 40),
                const SizedBox(height: 12),
                Text(
                  _errorMessage ?? 'Something went wrong',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          ),
        );

      case _LoadState.loaded:
        final notes = _visibleNotes;
        if (notes.isEmpty) {
          return Center(
            child: Text(
              _searchQuery.isEmpty
                  ? 'No notes yet — tap + to add one'
                  : 'No matching notes',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          itemCount: notes.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final note = notes[i];
            return _NoteCard(
              note: note,
              onTap: () => _openNote(note),
              onTogglePin: () => _togglePin(note),
              onDelete: () => _deleteNote(note),
            );
          },
        );
    }
  }
}

class _SignInPrompt extends StatelessWidget {
  final ThemeData theme;
  const _SignInPrompt({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notes')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.note_alt_outlined,
                size: 48,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text('Sign in to use Notes', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                'Notes sync to your account across devices.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  ShellNavState.requestedTabIndex.value =
                      ShellNavState.profileTab;
                  context.go('/');
                },
                child: const Text('Sign In'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FolderChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FolderChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: theme.colorScheme.primary.withOpacity(0.18),
      labelStyle: TextStyle(
        color: selected
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurface,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
      side: BorderSide(color: theme.colorScheme.outlineVariant),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback onTogglePin;
  final VoidCallback onDelete;

  const _NoteCard({
    required this.note,
    required this.onTap,
    required this.onTogglePin,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dismissible(
      key: ValueKey(note.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(
          Icons.delete_outline,
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
      confirmDismiss: (_) async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete note?'),
            content: const Text("This can't be undone."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        return confirmed ?? false;
      },
      onDismissed: (_) => onDelete(),
      // Note-card gotcha: this uses Material + InkWell (not a ListTile
      // variant), but the same "needs its own Material ancestor" rule
      // applies to InkWell ripple/clipping — see project brief.
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        elevation: 1,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note.title.isEmpty ? 'New Note' : note.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        note.body.isEmpty ? 'No additional text' : note.body,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    note.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                    color: note.pinned
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                  tooltip: note.pinned ? 'Unpin' : 'Pin',
                  onPressed: onTogglePin,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
